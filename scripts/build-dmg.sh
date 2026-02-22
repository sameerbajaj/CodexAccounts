#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CodexAccounts"
SCHEME="CodexAccounts"
PROJECT="CodexAccounts.xcodeproj"
CONFIGURATION="Release"

VERSION_SUFFIX="${1:-}"
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

xcodebuild \
  -project "$ROOT_DIR/$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  clean build

APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found at $APP_PATH"
  exit 1
fi

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# ── Set DMG volume icon ──────────────────────────────────────────────────────
ICNS_SRC="$APP_PATH/Contents/Resources/AppIcon.icns"
TMP_RW_DMG="$BUILD_DIR/tmp_rw_$APP_NAME.dmg"

if [[ -f "$ICNS_SRC" ]]; then
  echo "Setting DMG volume icon from $ICNS_SRC…"

  # Create a writable intermediate DMG
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDRW \
    -o "$TMP_RW_DMG"

  # Attach in background (no Finder window)
  MOUNT_OUTPUT=$(hdiutil attach "$TMP_RW_DMG" -nobrowse -noautoopen)
  MOUNT_DIR=$(echo "$MOUNT_OUTPUT" | awk '/Apple_HFS/ { for(i=3;i<=NF;i++) printf "%s ", $i; print "" }' | xargs)

  if [[ -d "$MOUNT_DIR" ]]; then
    # Copy icon as the volume icon
    cp "$ICNS_SRC" "$MOUNT_DIR/.VolumeIcon.icns"

    # Mark the volume as having a custom icon (requires Xcode CLT)
    SETFILE="$(xcode-select -p 2>/dev/null)/usr/bin/SetFile"
    if [[ -x "$SETFILE" ]]; then
      "$SETFILE" -a C "$MOUNT_DIR"
    else
      # Fallback: set the custom-icon Finder flag via xattr (bit 10 at offset 8)
      python3 - "$MOUNT_DIR" <<'PYEOF'
import sys, struct, subprocess, os
path = sys.argv[1]
try:
    current = subprocess.check_output(['xattr', '-px', 'com.apple.FinderInfo', path], stderr=subprocess.DEVNULL)
    data = bytearray(bytes.fromhex(current.decode().replace(' ', '').replace('\n', '')))
except subprocess.CalledProcessError:
    data = bytearray(32)
if len(data) < 16:
    data = bytearray(32)
data[8] |= 0x04  # set HasCustomIcon flag
hex_str = ' '.join(f'{b:02x}' for b in data)
subprocess.run(['xattr', '-wx', 'com.apple.FinderInfo', hex_str, path], check=False)
PYEOF
    fi

    hdiutil detach "$MOUNT_DIR" -quiet
  fi

  # Convert to final compressed read-only DMG
  hdiutil convert "$TMP_RW_DMG" -format UDZO -o "$OUTPUT_DMG"
  rm -f "$TMP_RW_DMG"
else
  echo "Warning: could not mount temp DMG to set icon, falling back to plain DMG"
  rm -f "$TMP_RW_DMG"
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$OUTPUT_DMG"
fi
# ─────────────────────────────────────────────────────────────────────────────

echo "Created DMG: $OUTPUT_DMG"
