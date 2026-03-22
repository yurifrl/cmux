#!/usr/bin/env bash
# Write fork version marker into a built cmux.app bundle.
# Usage: ./scripts/write-fork-version.sh <app-path> <version>
# Example: ./scripts/write-fork-version.sh build/Build/Products/Release/cmux.app 0.62.2-fork.3

set -euo pipefail

APP_PATH="${1:?Usage: $0 <app-path> <version>}"
VERSION="${2:?Usage: $0 <app-path> <version>}"

if [ ! -d "$APP_PATH" ]; then
  echo "Error: App not found at $APP_PATH" >&2
  exit 1
fi

# Write to Resources
RESOURCES_DIR="$APP_PATH/Contents/Resources"
mkdir -p "$RESOURCES_DIR"
echo "$VERSION" > "$RESOURCES_DIR/.cmux-fork-version"

# Write next to CLI binary
MACOS_DIR="$APP_PATH/Contents/MacOS"
if [ -d "$MACOS_DIR" ]; then
  echo "$VERSION" > "$MACOS_DIR/.cmux-fork-version"
fi

echo "Wrote fork version $VERSION to $APP_PATH"
