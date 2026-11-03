#!/usr/bin/env bash
# Build a Release Reef.app and package it into a distributable .dmg using
# sindresorhus/create-dmg (via npx) — the same recipe Atoll ships with. It
# auto-generates the window background, the Applications drop-link, the icon
# layout, and a volume icon from the app icon.
# Usage: scripts/make-dmg.sh
set -euo pipefail

cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCHEME="Reef"
APP_NAME="Reef"
BUILD_DIR="$PWD/.dmgbuild"
OUT="$BUILD_DIR/out"
DIST="$PWD/dist"

if ! command -v npx >/dev/null 2>&1; then
  echo "error: npx (Node.js) not found. Install Node, e.g. brew install node" >&2
  exit 1
fi

VERSION="$(/usr/bin/grep -E 'MARKETING_VERSION' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
VERSION="${VERSION:-0.0.0}"
FINAL="$DIST/${APP_NAME}-${VERSION}.dmg"

echo "==> Building ${APP_NAME} ${VERSION} (Release)"
rm -rf "$BUILD_DIR"
mkdir -p "$OUT" "$DIST"

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

echo "==> Creating the DMG (sindresorhus/create-dmg)"
# create-dmg writes "<Name> <version>.dmg" into the destination directory. It can
# exit non-zero on a cosmetic warning while still producing the image, so check
# for the file afterwards.
( cd "$OUT" && npx --yes create-dmg "$APP_PATH" . --overwrite --no-code-sign ) || true

GENERATED="$(find "$OUT" -maxdepth 1 -name '*.dmg' | head -1)"
if [[ -z "$GENERATED" ]]; then
  echo "error: create-dmg produced no .dmg in $OUT" >&2
  exit 1
fi

rm -f "$FINAL"
mv "$GENERATED" "$FINAL"
rm -rf "$BUILD_DIR"
echo "==> Done: $FINAL"
