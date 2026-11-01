#!/bin/bash
#
# Build the Reef lock-screen widget plugin bundle.
# No admin rights needed to build; install.sh (sudo) installs it.
#
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$DIR/ReefLockWidget/ReefLockWidget.m"
PLIST="$DIR/ReefLockWidget/Info.plist"
OUT="$DIR/build/ReefLockWidget.bundle"

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS"
cp "$PLIST" "$OUT/Contents/Info.plist"

clang -bundle -arch arm64 \
    -fobjc-arc \
    -mmacosx-version-min=14.0 \
    -framework Foundation -framework AppKit -framework Security \
    -o "$OUT/Contents/MacOS/ReefLockWidget" "$SRC"

# Ad-hoc signature so SecurityAgent will load it locally.
codesign --force --sign - "$OUT"

echo "Built $OUT"
