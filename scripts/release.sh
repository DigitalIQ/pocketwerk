#!/bin/zsh
# Usage: scripts/release.sh 1.0.0 [--publish]
# Sets the version, builds the universal app and the DMG, and with --publish creates the
# git tag, the GitHub release and updates the Homebrew cask in DigitalIQ/homebrew-tap.
set -euo pipefail

cd "${0:A:h}/.."
VERSION="${1:?version like 1.0.0}"
PUBLISH="${2:-}"
BUILD_NUMBER="$(git rev-list --count HEAD)"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Resources/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" Resources/Info.plist

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swift test
./scripts/build-app.sh --intents
# The in-app self-test against the release build, before anything is packaged.
./scripts/selftest.sh --no-build
SHA="$(./scripts/make-dmg.sh | awk '{print $1}')"
DMG="build/Pocketwerk-$VERSION.dmg"
echo "DMG $DMG sha256 $SHA"

[[ "$PUBLISH" == "--publish" ]] || exit 0

git add Resources/Info.plist
git commit -m "Release $VERSION" || true
git tag -a "v$VERSION" -m "Pocketwerk $VERSION"
git push origin main "v$VERSION"

NOTES="docs/releases/$VERSION.md"
[[ -f "$NOTES" ]] || { echo "Missing $NOTES" >&2; exit 1; }
gh release create "v$VERSION" "$DMG" --repo DigitalIQ/pocketwerk --title "Pocketwerk $VERSION" --notes-file "$NOTES"

# Homebrew cask
TAP=".tmp/homebrew-tap"
rm -rf "$TAP"
gh repo clone DigitalIQ/homebrew-tap "$TAP" -- --depth 1
mkdir -p "$TAP/Casks"
sed -e "s/@VERSION@/$VERSION/g" -e "s/@SHA256@/$SHA/g" packaging/pocketwerk.rb.in > "$TAP/Casks/pocketwerk.rb"
git -C "$TAP" add Casks/pocketwerk.rb
git -C "$TAP" -c user.name=DigitalIQ -c user.email=30226996+DigitalIQ@users.noreply.github.com commit -m "pocketwerk $VERSION"
git -C "$TAP" push
rm -rf "$TAP"
echo "Released $VERSION"
