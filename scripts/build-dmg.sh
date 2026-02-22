#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CodexAccounts"
SCHEME="CodexAccounts"
PROJECT="CodexAccounts.xcodeproj"
CONFIGURATION="Release"

VERSION_SUFFIX="${1:-}"
MARKETING_VERSION="${2:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$BUILD_DIR/dmg-staging"
DERIVED_DATA_DIR="$BUILD_DIR/DerivedData"

if [[ -n "$VERSION_SUFFIX" ]]; then
  OUTPUT_DMG="$DIST_DIR/${APP_NAME}-${VERSION_SUFFIX}.dmg"
else
  OUTPUT_DMG="$DIST_DIR/${APP_NAME}.dmg"
fi

rm -rf "$STAGING_DIR" "$DERIVED_DATA_DIR"
mkdir -p "$STAGING_DIR" "$DIST_DIR"

# ── Build ─────────────────────────────────────────────────────────────────────
XCBUILD_EXTRA_ARGS=()
# Always stamp CURRENT_PROJECT_VERSION with a Unix timestamp so the update
# checker can detect newer rolling builds by comparing against published_at.
BUILD_TIMESTAMP=$(date +%s)
XCBUILD_EXTRA_ARGS+=("CURRENT_PROJECT_VERSION=$BUILD_TIMESTAMP")

if [[ -n "$MARKETING_VERSION" ]]; then
  XCBUILD_EXTRA_ARGS+=("MARKETING_VERSION=$MARKETING_VERSION")
  echo "Stamping version: $MARKETING_VERSION"
fi

xcodebuild \
  -project "$ROOT_DIR/$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  "${XCBUILD_EXTRA_ARGS[@]+${XCBUILD_EXTRA_ARGS[@]}}" \
  clean build

APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found at $APP_PATH"
  exit 1
fi

# ── Inject ICNS if Xcode didn't compile one ───────────────────────────────────
ICNS_DEST="$APP_PATH/Contents/Resources/AppIcon.icns"
if [[ ! -f "$ICNS_DEST" ]]; then
  echo "No AppIcon.icns found in built app — generating from source…"

  ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET_DIR"
  ICON_1024="$(mktemp).png"

  swift "$ROOT_DIR/scripts/generate-icon.swift" "$ICON_1024"

  sips -z 16   16   "$ICON_1024" --out "$ICONSET_DIR/icon_16x16.png"      > /dev/null
  sips -z 32   32   "$ICON_1024" --out "$ICONSET_DIR/icon_16x16@2x.png"   > /dev/null
  sips -z 32   32   "$ICON_1024" --out "$ICONSET_DIR/icon_32x32.png"      > /dev/null
  sips -z 64   64   "$ICON_1024" --out "$ICONSET_DIR/icon_32x32@2x.png"   > /dev/null
  sips -z 128  128  "$ICON_1024" --out "$ICONSET_DIR/icon_128x128.png"    > /dev/null
  sips -z 256  256  "$ICON_1024" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
  sips -z 256  256  "$ICON_1024" --out "$ICONSET_DIR/icon_256x256.png"    > /dev/null
  sips -z 512  512  "$ICON_1024" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
  sips -z 512  512  "$ICON_1024" --out "$ICONSET_DIR/icon_512x512.png"    > /dev/null
  cp "$ICON_1024"                      "$ICONSET_DIR/icon_512x512@2x.png"

  iconutil -c icns "$ICONSET_DIR" -o "$ICNS_DEST"
  echo "Injected AppIcon.icns"
fi

# ── Ad-hoc code signing (prevents "damaged app" Gatekeeper error) ─────────────
echo "Ad-hoc signing…"
codesign --force --deep --sign - "$APP_PATH"

# ── Stage app + Applications shortcut ─────────────────────────────────────────
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# ── Build DMG with volume icon ─────────────────────────────────────────────────
TMP_RW_DMG="$BUILD_DIR/tmp_rw_${APP_NAME}.dmg"
rm -f "$TMP_RW_DMG"

echo "Creating writable DMG…"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  -o "$TMP_RW_DMG"

# hdiutil appends .dmg automatically when -o lacks the extension; normalise
[[ -f "$TMP_RW_DMG" ]] || TMP_RW_DMG="${TMP_RW_DMG}.dmg"

echo "Mounting writable DMG to set volume icon…"
MOUNT_OUTPUT=$(hdiutil attach "$TMP_RW_DMG" -nobrowse -noautoopen)
MOUNT_DIR=$(echo "$MOUNT_OUTPUT" | grep -E '/Volumes/' | awk '{print $NF}')

if [[ -d "$MOUNT_DIR" ]]; then
  cp "$ICNS_DEST" "$MOUNT_DIR/.VolumeIcon.icns"
  chflags hidden "$MOUNT_DIR/.VolumeIcon.icns"

  # Set HasCustomIcon Finder flag on the volume root
  python3 - "$MOUNT_DIR" <<'PYEOF'
import sys, subprocess
path = sys.argv[1]
try:
    raw = subprocess.check_output(['xattr', '-px', 'com.apple.FinderInfo', path],
                                   stderr=subprocess.DEVNULL)
    data = bytearray(bytes.fromhex(raw.decode().replace(' ', '').replace('\n', '')))
except subprocess.CalledProcessError:
    data = bytearray(32)
if len(data) < 32:
    data = bytearray(32)
data[8] |= 0x04  # kHasCustomIcon
hex_str = ' '.join(f'{b:02x}' for b in data)
subprocess.run(['xattr', '-wx', 'com.apple.FinderInfo', hex_str, path], check=False)
print(f"Set HasCustomIcon on {path}")
PYEOF

  # ── Set Finder window layout (icon positions, view, window size) ────────────
  VOLUME_NAME="$APP_NAME"
  osascript <<APPLESCRIPT 2>/dev/null || echo "Note: Finder layout step skipped (headless)"
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {100, 100, 660, 440}
    set theViewOptions to icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 80
    set position of item "${APP_NAME}.app" of container window to {170, 185}
    set position of item "Applications" of container window to {420, 185}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

  hdiutil detach "$MOUNT_DIR" -quiet
else
  echo "Warning: could not determine mount point — skipping volume icon"
  hdiutil detach "$(echo "$MOUNT_OUTPUT" | awk 'NR==1{print $1}')" -quiet 2>/dev/null || true
fi

# ── Convert to final compressed read-only DMG ──────────────────────────────────
echo "Converting to final DMG: $OUTPUT_DMG"
hdiutil convert "$TMP_RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT_DMG"
rm -f "$TMP_RW_DMG"

echo "✓ Created DMG: $OUTPUT_DMG ($(du -sh "$OUTPUT_DMG" | cut -f1))"
