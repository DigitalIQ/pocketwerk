#!/bin/zsh
# Adapted from BAMA by Dave Ebbelaar (MIT): https://github.com/daveebbelaar/bama
# Builds Pocketwerk and saves one PNG per page in light and dark to .tmp/shots, then quits.
# Look at the PNGs before you commit a UI change.
#   scripts/snap.sh                  every page
#   PAGES=studio,popup scripts/snap.sh   only these pages (a name, or a prefix before a dash)
#   LANGUAGE=de scripts/snap.sh          another UI language (default en, so shots look the same on every Mac)
# The run uses a fresh test library in .tmp/snap-store and fake Dock and launcher folders in .tmp/.
# It never touches the real Dock or ~/Library/Application Support/Pocketwerk. The windows are captured
# with screencapture, which needs Screen Recording permission for your terminal.
set -euo pipefail

cd "${0:A:h}/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

ROOT="$PWD"
STORE="$ROOT/.tmp/snap-store"
SHOTS="${SHOTS:-$ROOT/.tmp/shots}"
APP="build/Pocketwerk.app/Contents/MacOS/Pocketwerk"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Resources/Info.plist)"

UNIVERSAL=0 CONFIG=debug ./scripts/build-app.sh >/dev/null

# Seed data only fills an empty library, so start from nothing. A crashed run leaves saved window
# state, and the next launch would wait on a "reopen windows?" alert.
rm -rf "$STORE" "$SHOTS" "$ROOT/.tmp/snap-launchers" "$ROOT/.tmp/snap-dock.plist"
rm -rf "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState"
mkdir -p "$STORE" "$SHOTS"

POCKETWERK_DATA_DIR="$STORE" \
POCKETWERK_DOCK_PLIST="$ROOT/.tmp/snap-dock.plist" \
POCKETWERK_LAUNCHER_DIR="$ROOT/.tmp/snap-launchers" \
POCKETWERK_SNAPSHOT_DIR="$SHOTS" \
POCKETWERK_SNAPSHOT_PAGES="${PAGES:-}" \
  "$APP" --snapshot -AppleLanguages "(${LANGUAGE:-en})"
