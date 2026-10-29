#!/bin/zsh
# Adapted from BAMA by Dave Ebbelaar (MIT): https://github.com/daveebbelaar/bama
# Compiles Icon/AppIcon.icon (an Icon Composer file) with actool and writes:
#   Resources/Assets.car     the Liquid Glass icon (default, dark, tinted, clear)
#   Resources/AppIcon.icns   flat fallback for Finder views that read .icns
#   Resources/AppIconVariants/AppIcon-<variant>.heic   glass pictures of the color variants
# All outputs are committed, so build-app.sh does not need to run this.
set -euo pipefail

cd "${0:A:h}/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

ICON="Icon/AppIcon.icon"
ICTOOL="$DEVELOPER_DIR/../Applications/Icon Composer.app/Contents/Executables/ictool"
mkdir -p .tmp
WORK="$(mktemp -d "$PWD/.tmp/make-icon.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# actool fails on a missing layer image, so it doubles as the validator.
# The .icon must be named AppIcon.icon to match --app-icon, or actool
# writes nothing and still exits 0. Check the output to catch that.
xcrun actool "$ICON" --compile "$WORK" --platform macosx \
  --minimum-deployment-target 26.0 --app-icon AppIcon \
  --output-partial-info-plist "$WORK/partial.plist" \
  --output-format human-readable-text --errors --warnings >"$WORK/log" 2>&1 || { cat "$WORK/log"; exit 1; }
[[ -f "$WORK/Assets.car" && -f "$WORK/AppIcon.icns" ]] || { cat "$WORK/log"; echo "actool wrote no icon" >&2; exit 1; }
cp "$WORK/Assets.car" "$WORK/AppIcon.icns" Resources/
echo "Wrote Resources/Assets.car and Resources/AppIcon.icns"

# Color variants (AppIconVariant in Sources/PocketwerkKit/Icons/AppIconVariants.swift).
# NSApp.applicationIconImage shows a flat picture without glass, so each variant is
# rendered here: the same layers on another background, top and bottom color.
[[ -x "$ICTOOL" ]] || { echo "error: ictool not found. Install Xcode 26 or later." >&2; exit 1; }
typeset -A FILLS=(
  honey    "0.7608,0.5294,0.1843 0.4745,0.3333,0.1176"
  ocean    "0.1490,0.3843,0.7333 0.0941,0.2431,0.4588"
  graphite "0.3922,0.4157,0.4510 0.2471,0.2627,0.2824"
  iris     "0.4353,0.2902,0.7725 0.2745,0.1804,0.4824"
)
mkdir -p Resources/AppIconVariants
for name in ${(ok)FILLS}; do
  colors=(${=FILLS[$name]})
  cp -R "$ICON" "$WORK/$name.icon"
  plutil -replace fill-specializations \
    -json "[{\"value\":{\"linear-gradient\":[\"srgb:${colors[1]},1\",\"srgb:${colors[2]},1\"]}}]" "$WORK/$name.icon/icon.json"
  # ictool draws the rounded square edge to edge; the Dock wants Apple's margin (824 of 1024).
  "$ICTOOL" "$WORK/$name.icon" --export-image --output-file "$WORK/$name.png" \
    --platform macOS --rendition Default --width 412 --height 412 --scale 2 >/dev/null
  sips --padToHeightWidth 1024 1024 "$WORK/$name.png" --out "$WORK/$name-padded.png" >/dev/null
  sips -s format heic "$WORK/$name-padded.png" --out "Resources/AppIconVariants/AppIcon-$name.heic" >/dev/null
done
echo "Wrote ${#FILLS} variants to Resources/AppIconVariants"
