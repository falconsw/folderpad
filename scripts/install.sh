#!/bin/zsh
# Builds a Release copy of Folderpad and installs it to /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null && xcodegen generate --quiet
xcodebuild -project Folderpad.xcodeproj -scheme Folderpad -configuration Release \
  -derivedDataPath build -destination 'platform=macOS' build -quiet

APP=build/Build/Products/Release/Folderpad.app
TARGET=/Applications/Folderpad.app

osascript -e 'quit app id "com.falconsw.folderpad"' 2>/dev/null || true
rm -rf "$TARGET"
cp -R "$APP" "$TARGET"

echo "Installed: $TARGET"
