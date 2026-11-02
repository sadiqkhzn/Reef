#!/usr/bin/env bash
# Build a Release Reef.app and package it into a distributable .dmg.
# Usage: scripts/make-dmg.sh
set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="Reef"
APP_NAME="Reef"
BUILD_DIR="$PWD/.dmgbuild"
STAGE_DIR="$BUILD_DIR/stage"
DIST_DIR="$PWD/dist"

VERSION="$(/usr/bin/grep -E 'MARKETING_VERSION' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
VERSION="${VERSION:-0.0.0}"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"

echo "==> Building ${APP_NAME} ${VERSION} (Release)"
rm -rf "$BUILD_DIR"
mkdir -p "$STAGE_DIR" "$DIST_DIR"

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

echo "==> Staging app + Applications shortcut"
cp -R "$APP_PATH" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

echo "==> Creating DMG"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE_DIR" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$DMG_PATH" >/dev/null

rm -rf "$BUILD_DIR"
echo "==> Done: $DMG_PATH"
