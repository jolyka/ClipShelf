#!/bin/zsh

set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
OUTPUT_DIR="$PROJECT_DIR/outputs"
APP_DIR="$OUTPUT_DIR/ClipShelf.app"
ARCHIVE_PATH="$OUTPUT_DIR/ClipShelf-macOS.zip"
ARM_BUILD_DIR="$PROJECT_DIR/.build-arm64"
INTEL_BUILD_DIR="$PROJECT_DIR/.build-x86_64"
ARM_BINARY="$ARM_BUILD_DIR/arm64-apple-macosx/release/ClipShelf"
INTEL_BINARY="$INTEL_BUILD_DIR/x86_64-apple-macosx/release/ClipShelf"

cd "$PROJECT_DIR"
swift build -c release \
    --triple arm64-apple-macosx14.0 \
    --scratch-path "$ARM_BUILD_DIR"
swift build -c release \
    --triple x86_64-apple-macosx14.0 \
    --scratch-path "$INTEL_BUILD_DIR"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

lipo -create \
    "$ARM_BINARY" \
    "$INTEL_BINARY" \
    -output "$APP_DIR/Contents/MacOS/ClipShelf"
cp "$PROJECT_DIR/App/Info.plist" "$APP_DIR/Contents/Info.plist"

codesign --force --deep --sign - "$APP_DIR"
rm -f "$ARCHIVE_PATH"
ditto -c -k --norsrc --noextattr --keepParent "$APP_DIR" "$ARCHIVE_PATH"

echo "$APP_DIR"
echo "$ARCHIVE_PATH"
