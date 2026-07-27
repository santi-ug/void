#!/usr/bin/env bash
#
# Cuts a release: builds the DMG, publishes it to GitHub, and rewrites the
# Homebrew cask to match.
#
# Usage:  scripts/release.sh [path-to-homebrew-tap]
#
# The cask's version and sha256 have to agree with the published DMG exactly or
# `brew install` fails the checksum. Deriving both from the artifact that was
# just built is the only way to keep them in step.
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAP_PATH="${1:-$HOME/Documents/code/projects/homebrew-tap}"

if ! command -v gh >/dev/null 2>&1; then
  echo "✗ gh not found. Install it with: brew install gh" >&2
  exit 1
fi

# --- Build ------------------------------------------------------------------

"$PROJECT_ROOT/scripts/build-dmg.sh"

DMG_PATH="$(find "$PROJECT_ROOT/dist" -name 'void-*.dmg' -maxdepth 1 | sort | tail -1)"
VERSION="$(basename "$DMG_PATH" .dmg | sed 's/^void-//')"
CHECKSUM="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
TAG="v$VERSION"

echo
echo "→ Releasing $TAG"

# --- Publish ----------------------------------------------------------------

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "  release $TAG exists, replacing its asset"
  gh release upload "$TAG" "$DMG_PATH" --clobber
else
  gh release create "$TAG" "$DMG_PATH" \
    --title "void $VERSION" \
    --generate-notes
fi

# --- Update the cask --------------------------------------------------------

CASK_PATH="$TAP_PATH/Casks/void.rb"

if [ ! -f "$CASK_PATH" ]; then
  echo
  echo "! No cask at $CASK_PATH — skipping cask update."
  echo "  Pass the tap's path as the first argument, or clone it there."
  echo "  version $VERSION / sha256 $CHECKSUM"
  exit 0
fi

/usr/bin/sed -i '' \
  -e "s/^  version \".*\"$/  version \"$VERSION\"/" \
  -e "s/^  sha256 \".*\"$/  sha256 \"$CHECKSUM\"/" \
  "$CASK_PATH"

echo
echo "✓ Updated $CASK_PATH to $VERSION"
echo "  Commit and push the tap to finish:"
echo "    git -C \"$TAP_PATH\" commit -am \"void $VERSION\" && git -C \"$TAP_PATH\" push"
