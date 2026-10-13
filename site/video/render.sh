#!/bin/sh
# Renders the product video for the website.
# 1. Put real screenshots into site/assets/shots/ (popup.png, design-studio.png, profiles.png).
# 2. Run this script from anywhere: sh site/video/render.sh
# Output: site/video/pocketwerk.mp4, site/video/pocketwerk.webm, site/assets/img/video-poster.webp
set -e
cd "$(dirname "$0")"
HF="npx -y hyperframes@0.8.153"
export DO_NOT_TRACK=1
# HyperFrames only reads files inside its project folder, so mirror the shared assets here (git-ignored).
mkdir -p assets/shots assets/brand assets/fonts
cp ../assets/shots/*.png assets/shots/
cp ../assets/brand/mark.svg assets/brand/
cp ../assets/fonts/archivo-var.woff2 assets/fonts/
$HF lint
$HF render --format mp4 -f 30 -q standard --crf 28 -o pocketwerk.mp4
$HF render --format webm -f 30 --crf 40 -o pocketwerk.webm
$HF snapshot --at 5 --no-end -o ../../.tmp/video-poster
POSTER=$(ls ../../.tmp/video-poster/*.png | head -1)
cwebp -quiet -q 82 "$POSTER" -o ../assets/img/video-poster.webp
ls -la pocketwerk.mp4 pocketwerk.webm ../assets/img/video-poster.webp
echo "Now set data-video-ready=\"true\" on #film in site/index.html."
