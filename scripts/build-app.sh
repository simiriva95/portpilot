#!/usr/bin/env bash
# Builds a universal PortPilot.app plus .zip and .dmg into ./dist
#   VERSION=0.1.0 ./scripts/build-app.sh
#   CODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)" ./scripts/build-app.sh
set -euo pipefail

APP="PortPilot"
VERSION="${VERSION:-0.1.0}"
BUILD="${BUILD:-$(date +%Y%m%d%H%M)}"
IDENTITY="${CODESIGN_IDENTITY:--}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
BUNDLE="$DIST/$APP.app"

cd "$ROOT"
echo "▸ Building $APP $VERSION (universal)"
swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf "$DIST"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN_DIR/$APP" "$BUNDLE/Contents/MacOS/$APP"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$BUNDLE/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$BUNDLE/Contents/Resources/"
cp -R Sources/PortPilot/Resources/GIFs "$BUNDLE/Contents/Resources/"
# SwiftPM copies .xcstrings uncompiled, so compile the catalog into <lang>.lproj for Bundle.main.
xcrun xcstringstool compile Resources/Localizable.xcstrings --output-directory "$BUNDLE/Contents/Resources"

echo "▸ Signing with identity: $IDENTITY"
if [ "$IDENTITY" = "-" ]; then
  codesign --force --sign - "$BUNDLE"
else
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$BUNDLE"
fi
codesign --verify --deep --strict "$BUNDLE"

echo "▸ Packaging"
ditto -c -k --keepParent "$BUNDLE" "$DIST/$APP-$VERSION.zip"
STAGE="$(mktemp -d)"
cp -R "$BUNDLE" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
[ "$IDENTITY" = "-" ] && cp Resources/Install.txt "$STAGE/Install.txt"  # unsigned builds: how to open them
hdiutil create -volname "$APP" -srcfolder "$STAGE" -ov -format UDZO "$DIST/$APP-$VERSION.dmg" >/dev/null
rm -rf "$STAGE"
[ "$IDENTITY" != "-" ] && codesign --force --sign "$IDENTITY" "$DIST/$APP-$VERSION.dmg"

echo "✓ $DIST/$APP-$VERSION.dmg"
