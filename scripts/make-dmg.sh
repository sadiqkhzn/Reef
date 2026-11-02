#!/usr/bin/env bash
# Build a Release Reef.app and package it into a styled, distributable .dmg
# (custom background, positioned icons, and a custom volume icon).
# Usage: scripts/make-dmg.sh
set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="Reef"
APP_NAME="Reef"
VOL="$APP_NAME"
BUILD_DIR="$PWD/.dmgbuild"
STAGE="$BUILD_DIR/stage"
DIST="$PWD/dist"
BG_SRC="$PWD/Packaging/dmg-background.tiff"
ICONSET_SRC="$PWD/Reef/Assets.xcassets/AppIcon.appiconset"

VERSION="$(/usr/bin/grep -E 'MARKETING_VERSION' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
VERSION="${VERSION:-0.0.0}"
RW_DMG="$BUILD_DIR/rw.dmg"
FINAL="$DIST/${APP_NAME}-${VERSION}.dmg"

echo "==> Building ${APP_NAME} ${VERSION} (Release)"
rm -rf "$BUILD_DIR"
mkdir -p "$STAGE" "$DIST"
# Clear any stale mount so Finder resolves the volume by name correctly.
hdiutil detach "/Volumes/$VOL" >/dev/null 2>&1 || true

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

echo "==> Staging app, Applications shortcut, and background"
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$STAGE/.background"
cp "$BG_SRC" "$STAGE/.background/dmg-background.tiff"

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

echo "==> Creating a writable image"
rm -f "$RW_DMG"
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$RW_DMG" >/dev/null

echo "==> Applying the window layout"
# Mount at the default /Volumes/$VOL so Finder can address it by name.
DEVICE="$(hdiutil attach "$RW_DMG" -nobrowse -noverify -noautoopen | grep '^/dev/' | head -1 | awk '{print $1}')"
MNT="/Volumes/$VOL"
osascript <<APPLESCRIPT || echo "warning: Finder layout step failed; the DMG is still built (unstyled)."
tell application "Finder"
  tell disk "$VOL"
    open
    delay 1
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 520}
    set vo to the icon view options of container window
    set arrangement of vo to not arranged
    set icon size of vo to 112
    set background picture of vo to file ".background:dmg-background.tiff"
    set position of item "${APP_NAME}.app" of container window to {170, 205}
    set position of item "Applications" of container window to {490, 205}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

# Place the volume icon last, after Finder has finished touching the volume, and
# flag the volume to use it (staging it via -srcfolder does not stick).
cp "$VOL_ICNS" "$MNT/.VolumeIcon.icns"
SetFile -a C "$MNT" 2>/dev/null || true

sync
hdiutil detach "$DEVICE" >/dev/null 2>&1 || hdiutil detach "$MNT" -force >/dev/null 2>&1 || true

echo "==> Compressing"
rm -f "$FINAL"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL" >/dev/null

rm -rf "$BUILD_DIR"
echo "==> Done: $FINAL"
