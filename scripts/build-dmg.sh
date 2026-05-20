#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="void"
BUILD_DIR="$PROJECT_ROOT/.build"
APP_NAME="Void"
DMG_NAME="$APP_NAME.dmg"
STAGING="$BUILD_DIR/dmg-staging"

echo "→ Building $SCHEME..."
xcodebuild \
  -project "$PROJECT_ROOT/void.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/xcode" \
  build \
  | xcpretty 2>/dev/null || grep -E "error:|Build succeeded|Build failed"

APP_PATH=$(find "$BUILD_DIR/xcode" -name "void.app" -maxdepth 6 | head -1)
if [ -z "$APP_PATH" ]; then
  echo "✗ Could not find built void.app"
  exit 1
fi

echo "→ Staging DMG contents..."
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"

echo "→ Creating $DMG_NAME..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$PROJECT_ROOT/$DMG_NAME"

rm -rf "$STAGING"
echo "✓ Done: $PROJECT_ROOT/$DMG_NAME"
