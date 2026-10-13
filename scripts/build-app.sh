#!/bin/zsh
# Builds Pocketwerk.app into ./build and, with --install, copies it to ~/Applications.
# Uses the Xcode toolchain without changing xcode-select.
set -euo pipefail

cd "${0:A:h}/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

CONFIG="${CONFIG:-release}"
SCRATCH="${SCRATCH:-.build}"
# UNIVERSAL=0 builds only for this Mac (faster during development).
if [[ "${UNIVERSAL:-1}" == "1" ]]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
else
  ARCH_FLAGS=()
fi
swift build -c "$CONFIG" --scratch-path "$SCRATCH" "${ARCH_FLAGS[@]}" --product Pocketwerk
swift build -c "$CONFIG" --scratch-path "$SCRATCH" "${ARCH_FLAGS[@]}" --product PocketwerkLauncher
BIN="$(swift build -c "$CONFIG" --scratch-path "$SCRATCH" "${ARCH_FLAGS[@]}" --show-bin-path)"

APP="build/Pocketwerk.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Pocketwerk" "$APP/Contents/MacOS/Pocketwerk"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Localizations: SwiftUI Text("...") and String(localized:) look these up in Bundle.main.
# The string catalog is compiled into en.lproj / de.lproj (Localizable.strings + .stringsdict).
xcrun xcstringstool compile Resources/Localization/Localizable.xcstrings --output-directory "$APP/Contents/Resources" >/dev/null

# Launcher template: the main app copies this bundle once per Dock slot.
LAUNCHER="$APP/Contents/Resources/LauncherTemplate.app"
mkdir -p "$LAUNCHER/Contents/MacOS"
cp "$BIN/PocketwerkLauncher" "$LAUNCHER/Contents/MacOS/PocketwerkLauncher"
cp Resources/LauncherInfo.plist "$LAUNCHER/Contents/Info.plist"

codesign --force --sign - "$LAUNCHER"
codesign --force --sign - --entitlements Resources/Pocketwerk.entitlements "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  DEST="$HOME/Applications/Pocketwerk.app"
  mkdir -p "$HOME/Applications"
  osascript -e 'tell application id "io.github.digitaliq.pocketwerk" to quit' >/dev/null 2>&1 || true
  sleep 1
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
  echo "Installed $DEST"
fi
