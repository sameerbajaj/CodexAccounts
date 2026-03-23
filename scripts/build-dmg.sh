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

XCBUILD_EXTRA_ARGS=()
# Always stamp CURRENT_PROJECT_VERSION with a Unix timestamp so the update
# checker can detect newer rolling builds by comparing against published_at.
BUILD_TIMESTAMP=$(date +%s)
XCBUILD_EXTRA_ARGS+=("CURRENT_PROJECT_VERSION=$BUILD_TIMESTAMP")

if [[ -n "$MARKETING_VERSION" ]]; then
    XCBUILD_EXTRA_ARGS+=("MARKETING_VERSION=$MARKETING_VERSION")
    echo "Stamping version: $MARKETING_VERSION"
fi

# ── Detect signing identity ──────────────────────────────────────────────────
# Priority 1: explicit env var (CI mode)
SIGNING_IDENTITY="${APPLE_SIGNING_IDENTITY:-}"
TEAM_ID="${APPLE_DEVELOPER_TEAM_ID:-}"

# Priority 2: auto-detect from local keychain
if [[ -z "$SIGNING_IDENTITY" ]]; then
    DETECTED=$(security find-identity -v -p codesigning 2>/dev/null \
        | grep "Developer ID Application" \
        | head -1 \
        | sed 's/.*"\(.*\)".*/\1/' || true)
    if [[ -n "$DETECTED" ]]; then
        SIGNING_IDENTITY="$DETECTED"
        TEAM_ID=$(echo "$DETECTED" | grep -o '([A-Z0-9]*)' | tr -d '()' | head -1 || true)
        echo "Auto-detected signing identity: $SIGNING_IDENTITY"
    fi
fi

# ── Build ────────────────────────────────────────────────────────────────────
if [[ -n "$SIGNING_IDENTITY" ]]; then
    echo "🔨 Building $APP_NAME ($CONFIGURATION) with Developer ID signing..."
    SIGN_ARGS=(
        "CODE_SIGN_IDENTITY=$SIGNING_IDENTITY"
        "CODE_SIGN_STYLE=Manual"
        "CODE_SIGN_ENTITLEMENTS=$ROOT_DIR/CodexAccounts/CodexAccounts.entitlements"
        "ENABLE_HARDENED_RUNTIME=YES"
        "AD_HOC_CODE_SIGNING_ALLOWED=NO"
        "CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO"
        "OTHER_CODE_SIGN_FLAGS=--options=runtime"
        "TIMESTAMP_SERVER_URL=http://timestamp.apple.com/ts0881"
    )
    [[ -n "$TEAM_ID" ]] && SIGN_ARGS+=("DEVELOPMENT_TEAM=$TEAM_ID")

    xcodebuild \
        -project "$ROOT_DIR/$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        "${SIGN_ARGS[@]}" \
        "${XCBUILD_EXTRA_ARGS[@]}" \
        clean build
else
    echo "⚠️  No Developer ID identity found. Building unsigned (ad-hoc)..."
    xcodebuild \
        -project "$ROOT_DIR/$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        CODE_SIGNING_ALLOWED=NO \
        "${XCBUILD_EXTRA_ARGS[@]}" \
        clean build
fi

APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ Build failed. App not found at $APP_PATH"
    exit 1
fi

# ── Inject ICNS if Xcode didn't compile one ──────────────────────────────────
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

# ── Re-sign or ad-hoc sign ────────────────────────────────────────────────────
if [[ -n "$SIGNING_IDENTITY" ]]; then
    echo "🔁 Re-signing app bundle with secure timestamp..."
    codesign -f \
        -s "Developer ID Application: Sameer Bajaj (BZ685BB6M6)" \
        --options runtime \
        "$APP_PATH"
else
    echo "🔏 Ad-hoc signing…"
    codesign --force --deep --sign - "$APP_PATH"
fi

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# ── Create DMG ────────────────────────────────────────────────────────────────
echo "📦 Creating DMG..."
if command -v create-dmg >/dev/null 2>&1; then
    rm -f "$OUTPUT_DMG"
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 150 190 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 450 190 \
        "$OUTPUT_DMG" \
        "$STAGING_DIR"
else
    TMP_RW_DMG="$BUILD_DIR/tmp_rw_${APP_NAME}.dmg"
    rm -f "$TMP_RW_DMG" "$OUTPUT_DMG"

    echo "Creating writable DMG…"
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$STAGING_DIR" \
        -ov \
        -format UDRW \
        -o "$TMP_RW_DMG"

    [[ -f "$TMP_RW_DMG" ]] || TMP_RW_DMG="${TMP_RW_DMG}.dmg"

    echo "Mounting writable DMG to set volume icon…"
    MOUNT_OUTPUT=$(hdiutil attach "$TMP_RW_DMG" -nobrowse -noautoopen)
    MOUNT_DIR=$(echo "$MOUNT_OUTPUT" | grep -E '/Volumes/' | awk '{print $NF}')

    if [[ -d "$MOUNT_DIR" ]]; then
        cp "$ICNS_DEST" "$MOUNT_DIR/.VolumeIcon.icns"
        chflags hidden "$MOUNT_DIR/.VolumeIcon.icns"

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

    echo "Converting to final DMG: $OUTPUT_DMG"
    hdiutil convert "$TMP_RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT_DMG"
    rm -f "$TMP_RW_DMG"
fi

# ── Sign, notarize, staple ────────────────────────────────────────────────────
if [[ -n "$SIGNING_IDENTITY" ]]; then
    echo "🔏 Signing DMG..."
    codesign --force --sign "$SIGNING_IDENTITY" "$OUTPUT_DMG"

    echo "🚀 Submitting for notarization..."
    NOTARY_ARGS=(
        "--wait"
        "--timeout" "600s"
    )

    if [[ -n "${APPLE_ID:-}" && -n "${APPLE_ID_PASSWORD:-}" && -n "${TEAM_ID:-}" ]]; then
        xcrun notarytool submit "$OUTPUT_DMG" \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_ID_PASSWORD" \
            --team-id "$TEAM_ID" \
            "${NOTARY_ARGS[@]}"
    else
        xcrun notarytool submit "$OUTPUT_DMG" \
            --keychain-profile "CodexAccounts-Notarize" \
            "${NOTARY_ARGS[@]}"
    fi

    echo "📎 Stapling notarization ticket..."
    xcrun stapler staple "$OUTPUT_DMG"

    echo "✅ Signed, notarized, and stapled: $OUTPUT_DMG"
else
    echo "✅ DMG created (unsigned) at $OUTPUT_DMG"
fi
