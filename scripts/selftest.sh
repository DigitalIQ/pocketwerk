#!/bin/zsh
# Adapted from BAMA by Dave Ebbelaar (MIT): https://github.com/daveebbelaar/bama
# Runs the in-app self-test (Pocketwerk --selftest) against fresh test folders in .tmp/selftest.
# Never touches the real Dock, ~/Applications or the real data folder. Exit code 0 when every step passed.
#   scripts/selftest.sh              debug build for this Mac, then the self-test
#   scripts/selftest.sh --no-build   test build/Pocketwerk.app as it is (release.sh uses this)
set -uo pipefail

cd "${0:A:h}/.."
zmodload zsh/datetime
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ "${1:-}" != "--no-build" ]]; then
  mkdir -p .tmp
  UNIVERSAL=0 CONFIG=debug ./scripts/build-app.sh >.tmp/selftest-build.log 2>&1 \
    || { cat .tmp/selftest-build.log >&2; echo "selftest: build failed" >&2; exit 1; }
fi
BIN="build/Pocketwerk.app/Contents/MacOS/Pocketwerk"
[[ -x "$BIN" ]] || { echo "selftest: $BIN is missing" >&2; exit 1; }

ROOT="$PWD/.tmp/selftest"
rm -rf "$ROOT"
mkdir -p "$ROOT/data" "$ROOT/launchers"

start=$EPOCHREALTIME
POCKETWERK_DATA_DIR="$ROOT/data" \
POCKETWERK_DOCK_PLIST="$ROOT/dock.plist" \
POCKETWERK_LAUNCHER_DIR="$ROOT/launchers" \
  "$BIN" --selftest -ApplePersistenceIgnoreState YES
code=$?
printf 'selftest: exit %d after %.1f s\n' $code $(( EPOCHREALTIME - start ))
exit $code
