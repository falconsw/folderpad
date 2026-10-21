#!/bin/zsh
# Builds a Developer ID signed, notarized Folderpad DMG for GitHub Releases and the Homebrew tap.
#
#   ./scripts/release.sh                      # uses the "notary" notarytool keychain profile
#   NOTARY_PROFILE=other ./scripts/release.sh
#
# Create a profile once with:
#   xcrun notarytool store-credentials notary --apple-id <email> --team-id <TEAM_ID>
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(grep -m1 'MARKETING_VERSION' project.yml | sed -E 's/.*"(.*)".*/\1/')
# Select the certificate by its SHA-1: names with non-ASCII letters (Ö) get mangled by `security`.
IDENTITY_LINE=$(security find-identity -v -p codesigning | grep -m1 "Developer ID Application" || true)
[[ -n "$IDENTITY_LINE" ]] || { echo "No Developer ID Application certificate found." >&2; exit 1; }
IDENTITY=$(echo "$IDENTITY_LINE" | awk '{print $2}')
TEAM_ID=$(echo "$IDENTITY_LINE" | sed -E 's/.*\(([A-Z0-9]+)\)"$/\1/')

command -v xcodegen >/dev/null && xcodegen generate --quiet
rm -rf build/release build/dmg
# CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO keeps get-task-allow out; notarization rejects it.
xcodebuild -project Folderpad.xcodeproj -scheme Folderpad -configuration Release \
  -derivedDataPath build/release -destination 'generic/platform=macOS' \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO ENABLE_HARDENED_RUNTIME=YES OTHER_CODE_SIGN_FLAGS=--timestamp \
  clean build -quiet

APP=build/release/Build/Products/Release/Folderpad.app
codesign --verify --strict --deep "$APP"

mkdir -p build/dmg dist
cp -R "$APP" build/dmg/
ln -s /Applications build/dmg/Applications
DMG="dist/Folderpad-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Folderpad" -srcfolder build/dmg -ov -format UDZO "$DMG" -quiet
codesign --sign "$IDENTITY" --timestamp "$DMG"

xcrun notarytool submit "$DMG" --keychain-profile "${NOTARY_PROFILE:-notary}" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"

echo "Package: $DMG"
echo "sha256: $(shasum -a 256 "$DMG" | cut -d' ' -f1)"
