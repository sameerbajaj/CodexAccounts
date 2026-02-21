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

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$OUTPUT_DMG"

echo "Created DMG: $OUTPUT_DMG"
