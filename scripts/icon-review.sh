#!/bin/zsh
# Adapted from BAMA by Dave Ebbelaar (MIT): https://github.com/daveebbelaar/bama
# Renders Icon/AppIcon.icon the way macOS shows it, with Icon Composer's ictool,
# into one contact sheet:
#   row 1: Default, Dark, TintedLight, TintedDark, ClearLight, ClearDark at 256 pt
#   row 2: Default and Dark at 64, 32 and 16 pt
# Usage: scripts/icon-review.sh [out.png]   (default .tmp/icon-review/icon.png)
# Run scripts/make-icon.sh first: ictool renders an empty icon for a missing layer file.
set -euo pipefail

cd "${0:A:h}/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

OUT="${1:-.tmp/icon-review/icon.png}"
ICTOOL="$DEVELOPER_DIR/../Applications/Icon Composer.app/Contents/Executables/ictool"
[[ -x "$ICTOOL" ]] || { echo "error: ictool not found. Install Xcode 26 or later." >&2; exit 1; }
mkdir -p "${OUT:h}" .tmp
WORK="$(mktemp -d "$PWD/.tmp/icon-review.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

render() { # rendition size file
  "$ICTOOL" Icon/AppIcon.icon --export-image --output-file "$WORK/$3" \
    --platform macOS --rendition "$1" --width "$2" --height "$2" --scale 2 >/dev/null
}
render Default 256 a1.png
render Dark 256 a2.png
render TintedLight 256 a3.png
render TintedDark 256 a4.png
render ClearLight 256 a5.png
render ClearDark 256 a6.png
render Default 64 b1.png
render Dark 64 b2.png
render Default 32 b3.png
render Dark 32 b4.png
render Default 16 b5.png
render Dark 16 b6.png
xcrun swift scripts/icon-sheet.swift "$OUT" "$WORK"/a{1,2,3,4,5,6}.png -- "$WORK"/b{1,2,3,4,5,6}.png
echo "Wrote $OUT"
