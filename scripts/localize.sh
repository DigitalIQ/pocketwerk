#!/bin/zsh
# Collects every localizable string from the Swift sources into Resources/Localization/Localizable.xcstrings.
# New strings appear untranslated; existing translations are kept. Run after UI text changes.
set -euo pipefail
cd "${0:A:h}/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
OUT=".tmp/l10n"
rm -rf "$OUT/data" && mkdir -p "$OUT/data"
swift build --scratch-path "$OUT/build" -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc "$PWD/$OUT/data" >/dev/null
xcrun xcstringstool sync Resources/Localization/Localizable.xcstrings --stringsdata "$OUT"/data/*.stringsdata
python3 - <<'PY'
import json
d = json.load(open('Resources/Localization/Localizable.xcstrings'))
missing = [k for k, v in d['strings'].items() if 'de' not in v.get('localizations', {}) and v.get('shouldTranslate', True)]
print(f"{len(d['strings'])} strings, {len(missing)} without German")
PY
