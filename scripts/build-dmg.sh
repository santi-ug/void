#!/usr/bin/env bash
#
# Builds void in Release and packages it into a laid-out DMG.
#
# Prints the SHA-256 of the result at the end — that is the value the Homebrew
# cask needs, so a release never has to be hashed by hand.
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="void"
VOLUME_NAME="void"
BUILD_DIR="$PROJECT_ROOT/.build"
DERIVED_DATA="$BUILD_DIR/xcode"
STAGING="$BUILD_DIR/dmg-staging"
DIST_DIR="$PROJECT_ROOT/dist"

# A machine with Command Line Tools selected has an xcodebuild that refuses to
# build projects. Point at the full Xcode rather than making the caller run
# `sudo xcode-select` first.
if ! xcodebuild -version >/dev/null 2>&1; then
  export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
fi

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "✗ create-dmg not found. Install it with: brew install create-dmg" >&2
  exit 1
fi

VERSION="$(
  xcodebuild -project "$PROJECT_ROOT/void.xcodeproj" \
             -scheme "$SCHEME" \
             -configuration Release \
             -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ MARKETING_VERSION /{gsub(/ /,"",$2); print $2; exit}'
)"

if [ -z "$VERSION" ]; then
  echo "✗ Could not read MARKETING_VERSION from the project" >&2
  exit 1
fi

DMG_PATH="$DIST_DIR/void-$VERSION.dmg"

echo "→ Building $SCHEME $VERSION (Release)..."
xcodebuild \
  -project "$PROJECT_ROOT/void.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  -destination 'platform=macOS' \
  build \
  | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)" || true

APP_PATH="$(find "$DERIVED_DATA/Build/Products/Release" -maxdepth 1 -name "void.app" | head -1)"
if [ -z "$APP_PATH" ]; then
  echo "✗ Build produced no void.app" >&2
  exit 1
fi

echo "→ Staging..."
rm -rf "$STAGING"
mkdir -p "$STAGING" "$DIST_DIR"
cp -R "$APP_PATH" "$STAGING/void.app"

# Reuse the app's own icon as the mounted volume's icon.
VOLICON_ARGS=()
if [ -f "$STAGING/void.app/Contents/Resources/void.icns" ]; then
  VOLICON_ARGS=(--volicon "$STAGING/void.app/Contents/Resources/void.icns")
fi

echo "→ Creating $(basename "$DMG_PATH")..."
rm -f "$DMG_PATH"
create-dmg \
  --volname "$VOLUME_NAME" \
  "${VOLICON_ARGS[@]}" \
  --window-pos 200 120 \
  --window-size 640 400 \
  --icon-size 120 \
  --icon "void.app" 160 190 \
  --app-drop-link 480 190 \
  --hide-extension "void.app" \
  --no-internet-enable \
  "$DMG_PATH" \
  "$STAGING"

rm -rf "$STAGING"

CHECKSUM="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"

echo
echo "✓ $DMG_PATH"
echo "  version  $VERSION"
echo "  sha256   $CHECKSUM"
