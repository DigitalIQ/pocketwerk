#!/bin/zsh
# Packs build/Pocketwerk.app into build/Pocketwerk-<version>.dmg with an Applications link.
set -euo pipefail

cd "${0:A:h}/.."
APP="build/Pocketwerk.app"
[[ -d "$APP" ]] || { echo "Run scripts/build-app.sh first" >&2; exit 1; }
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="build/Pocketwerk-$VERSION.dmg"
STAGE=".tmp/dmg-stage"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/First launch.txt" <<'EOF'
Pocketwerk is free and open source. It is not notarized by Apple.

1. Drag Pocketwerk to Applications.
2. Open it once. macOS says it cannot check the app.
3. Open System Settings > Privacy & Security, scroll down and click "Open Anyway".
4. Confirm with your password.

You only do this once. Details: https://github.com/DigitalIQ/pocketwerk#install
EOF

hdiutil create -volname "Pocketwerk $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null
rm -rf "$STAGE"
shasum -a 256 "$DMG"
