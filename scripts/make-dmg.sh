#!/usr/bin/env bash
# Build a Release Reef.app and package it into a styled, distributable .dmg
# (custom background with a drag-to-Applications chevron, positioned icons, and
# a custom volume icon). Uses create-dmg (brew install create-dmg).
# Usage: scripts/make-dmg.sh
set -euo pipefail

cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCHEME="Reef"
APP_NAME="Reef"
VOL="$APP_NAME"
BUILD_DIR="$PWD/.dmgbuild"
STAGE="$BUILD_DIR/stage"
DIST="$PWD/dist"
BG_SRC="$PWD/Packaging/dmg-background.png"
ICONSET_SRC="$PWD/Reef/Assets.xcassets/AppIcon.appiconset"

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "error: create-dmg not found. Install it with: brew install create-dmg" >&2
  exit 1
fi

VERSION="$(/usr/bin/grep -E 'MARKETING_VERSION' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
VERSION="${VERSION:-0.0.0}"
FINAL="$DIST/${APP_NAME}-${VERSION}.dmg"

echo "==> Building ${APP_NAME} ${VERSION} (Release)"
rm -rf "$BUILD_DIR"
mkdir -p "$STAGE" "$DIST"

xcodebuild \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR/dd" \
  build >/dev/null

APP_PATH="$BUILD_DIR/dd/Build/Products/Release/${APP_NAME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "error: built app not found at $APP_PATH" >&2
  exit 1
fi

# create-dmg packages everything in the source folder, and adds the Applications
# drop-link itself, so the folder must hold only the app.
echo "==> Staging app"
cp -R "$APP_PATH" "$STAGE/"

echo "==> Building the volume icon from the app icon"
ICS="$BUILD_DIR/Reef.iconset"
mkdir -p "$ICS"
cp "$ICONSET_SRC/icon_16.png"   "$ICS/icon_16x16.png"
cp "$ICONSET_SRC/icon_32.png"   "$ICS/icon_16x16@2x.png"
cp "$ICONSET_SRC/icon_32.png"   "$ICS/icon_32x32.png"
cp "$ICONSET_SRC/icon_64.png"   "$ICS/icon_32x32@2x.png"
cp "$ICONSET_SRC/icon_128.png"  "$ICS/icon_128x128.png"
cp "$ICONSET_SRC/icon_256.png"  "$ICS/icon_128x128@2x.png"
cp "$ICONSET_SRC/icon_256.png"  "$ICS/icon_256x256.png"
cp "$ICONSET_SRC/icon_512.png"  "$ICS/icon_256x256@2x.png"
cp "$ICONSET_SRC/icon_512.png"  "$ICS/icon_512x512.png"
cp "$ICONSET_SRC/icon_1024.png" "$ICS/icon_512x512@2x.png"
VOL_ICNS="$BUILD_DIR/VolumeIcon.icns"
iconutil -c icns "$ICS" -o "$VOL_ICNS"

echo "==> Creating the styled DMG"
# Clear any stale mount so create-dmg's Finder step resolves the volume cleanly.
hdiutil detach "/Volumes/$VOL" >/dev/null 2>&1 || true
rm -f "$FINAL"
# create-dmg can exit non-zero even when the image was produced; check the file.
create-dmg \
  --volname "$VOL" \
  --volicon "$VOL_ICNS" \
  --background "$BG_SRC" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 112 \
  --text-size 13 \
  --icon "${APP_NAME}.app" 170 205 \
  --app-drop-link 490 205 \
  --no-internet-enable \
  "$FINAL" \
  "$STAGE" || true

if [[ ! -f "$FINAL" ]]; then
  echo "error: DMG was not produced at $FINAL" >&2
  exit 1
fi

rm -rf "$BUILD_DIR"
echo "==> Done: $FINAL"
