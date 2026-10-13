#!/bin/zsh
# Builds Pocketwerk.app into ./build and, with --install, copies it to ~/Applications.
# --intents (or INTENTS=1) adds App Intents metadata so Shortcuts and Siri can find the actions.
# Uses the Xcode toolchain without changing xcode-select.
set -euo pipefail

INSTALL=0
WITH_INTENTS="${INTENTS:-0}"
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=1 ;;
    --intents) WITH_INTENTS=1 ;;
  esac
done

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
for lproj in Resources/Localization/*.lproj(N); do cp -R "$lproj" "$APP/Contents/Resources/"; done

# App Intents metadata: swift build compiles the intents but skips Xcode's metadata step.
# The compiler's const-value files sit in Swift Build's internal layout, which can change with a toolchain update.
if [[ "$WITH_INTENTS" == "1" ]]; then
  OBJ_ROOT="$SCRATCH/out/Intermediates.noindex/Pocketwerk.build/${(C)CONFIG}/Pocketwerk-p.build/Objects-normal"
  OBJ=""
  for candidate in "$OBJ_ROOT/arm64" "$OBJ_ROOT"/*(N/); do
    if [[ -d "$candidate" ]]; then OBJ="$candidate"; break; fi
  done
  if [[ -z "$OBJ" ]]; then
    echo "error: no compiler output for App Intents in $OBJ_ROOT" >&2
    exit 1
  fi
  LISTS=".tmp/intents"
  mkdir -p "$LISTS"
  find "$PWD/Sources/Pocketwerk" -name '*.swift' > "$LISTS/sources.txt"
  find "${OBJ:A}" -name '*.swiftconstvalues' > "$LISTS/constvalues.txt"
  if [[ ! -s "$LISTS/constvalues.txt" ]]; then
    echo "error: no .swiftconstvalues in $OBJ" >&2
    exit 1
  fi
  xcrun appintentsmetadataprocessor \
    --output "$APP/Contents/Resources" \
    --toolchain-dir "$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain" \
    --module-name Pocketwerk \
    --sdk-root "$(xcrun --sdk macosx --show-sdk-path)" \
    --xcode-version "$(xcodebuild -version | awk '/Build version/{print $3}')" \
    --platform-family macOS --deployment-target 26.0 --target-triple "${OBJ:t}-apple-macos26.0" \
    --source-file-list "$LISTS/sources.txt" --swift-const-vals-list "$LISTS/constvalues.txt" \
    --binary-file "$APP/Contents/MacOS/Pocketwerk"
  rm -rf "$LISTS"
  echo "Added App Intents metadata"
fi

# Launcher template: the main app copies this bundle once per Dock slot.
LAUNCHER="$APP/Contents/Resources/LauncherTemplate.app"
mkdir -p "$LAUNCHER/Contents/MacOS"
cp "$BIN/PocketwerkLauncher" "$LAUNCHER/Contents/MacOS/PocketwerkLauncher"
cp Resources/LauncherInfo.plist "$LAUNCHER/Contents/Info.plist"

codesign --force --sign - "$LAUNCHER"
codesign --force --sign - --entitlements Resources/Pocketwerk.entitlements "$APP"
echo "Built $APP"

if [[ "$INSTALL" == "1" ]]; then
  DEST="$HOME/Applications/Pocketwerk.app"
  mkdir -p "$HOME/Applications"
  osascript -e 'tell application id "io.github.digitaliq.pocketwerk" to quit' >/dev/null 2>&1 || true
  sleep 1
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
  echo "Installed $DEST"
fi
