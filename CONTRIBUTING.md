# Contributing to Pocketwerk

Thanks for helping. Bug reports, ideas, translations and pull requests are all welcome.

- **Bugs and ideas**: open an issue with one of the templates.
- **Security issues**: do not open a public issue. See [SECURITY.md](SECURITY.md).
- **Larger changes**: open an issue first, so we can agree on the approach before you write the code.

## Build

Requirements: macOS 26 and Xcode with the Swift 6.2 toolchain. There is no Xcode project; everything is built with SwiftPM.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift build                                  # debug build
swift test                                   # tests
UNIVERSAL=0 ./scripts/build-app.sh           # app bundle for this Mac only, in build/
./scripts/build-app.sh --install             # universal app, copied to ~/Applications
./scripts/build-app.sh --intents             # adds App Intents metadata (Shortcuts, Siri, Focus)
```

`build-app.sh` assembles `build/Pocketwerk.app`: it copies `Resources/Info.plist` and the app icon, compiles the string catalog into `en.lproj` and `de.lproj`, embeds the launcher template and signs everything ad hoc.

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) before you change code. It lists the targets, the data model, the module entry points and the conventions below in more detail.

## Run without touching your real Dock and data

Pocketwerk writes to the macOS Dock and to `~/Library/Application Support/Pocketwerk`. For development runs, point it somewhere else:

| Variable | Replaces |
|---|---|
| `POCKETWERK_DATA_DIR` | the data folder `~/Library/Application Support/Pocketwerk` |
| `POCKETWERK_LAUNCHER_DIR` | the launcher folder `~/Applications/Pocketwerk` |
| `POCKETWERK_DOCK_PLIST` | the real Dock: reads and writes a plist file instead, and never restarts the Dock |
| `POCKETWERK_LAUNCHER_TEMPLATE` | the launcher template inside the app bundle |

Use a `.tmp/` folder in your checkout (it is ignored by git), for example:

```bash
mkdir -p .tmp
POCKETWERK_DATA_DIR=$PWD/.tmp/data \
POCKETWERK_LAUNCHER_DIR=$PWD/.tmp/launchers \
POCKETWERK_DOCK_PLIST=$PWD/.tmp/dock.plist \
  build/Pocketwerk.app/Contents/MacOS/Pocketwerk
```

## Test

Tests use Swift Testing (`import Testing`) and live in `Tests/PocketwerkKitTests/`. `swift test` must pass before you open a pull request.

- Every pure function (geometry, layout, sorting, plist building, URL parsing) gets a test.
- Tests use temporary folders. They never touch the real Dock, the real data folder or `~/Applications`.
- Render tests that write PNGs of views are opt-in. They run when `POCKETWERK_SHOTS` points to an output folder and the development variables above are set.

## Localization

The UI is written in English in code. German translations live in the string catalog `Resources/Localization/Localizable.xcstrings`.

- SwiftUI `Text("...")` literals are localized automatically.
- AppKit and computed strings use `String(localized: "...")`.
- Keep strings short and plain. Controls say what happens.

After you add or change UI text:

```bash
./scripts/localize.sh
```

The script builds the sources with the compiler's string extraction, syncs the result into `Localizable.xcstrings` and prints how many strings have no German translation yet. New strings appear untranslated; existing translations are kept. Add the German text in Xcode's string catalog editor or directly in the JSON, then run `./scripts/build-app.sh` to check it in the app.

A new language needs an entry in `CFBundleLocalizations` in `Resources/Info.plist` and translations in the catalog.

## Code conventions

- Swift 6.2 toolchain, Swift 5 language mode. `PocketwerkKit` runs on the `MainActor` by default; mark pure value helpers `nonisolated` when they must run off the main actor.
- **No third-party packages.** Everything is built on Apple frameworks.
- **No network access** except the daily update check against the GitHub releases API and favicon fetches for link items. **No telemetry.**
- Model types in `Model/Model.swift` are `nonisolated`, `Codable`, `Hashable` and `Sendable`, and every stored property has a default value. Add new fields at the end of a struct, with a default. Never rename, remove or reorder existing fields: users' `library.json` files must keep loading.
- Every change to the library goes through `LibraryStore.mutate` or a helper built on it. That records undo, saves the file and notifies the UI.
- Each module owns its folder under `Sources/PocketwerkKit/`. The entry points listed in `docs/ARCHITECTURE.md` stay stable; extend them with default parameters.
- SwiftPM resource bundles are not used. Images and effects are drawn in code or loaded from `Contents/Resources` via `Bundle.main`.
- The popup must appear within one frame of the click: cache icons, never scan the disk when it opens.
- Animations respect Reduce Motion, Reduce Transparency and Low Power Mode. Controls get VoiceOver labels and are reachable by keyboard.
- Match the style of the surrounding code: naming, comment density, short doc comments that say why.
- No compiler warnings.

## Pull requests

- One topic per pull request. Describe what changes for the user and how you tested it.
- Include screenshots for visible changes.
- Run `swift build`, `swift test` and, for UI text changes, `./scripts/localize.sh`.
- Add a line to the "Unreleased" section of [CHANGELOG.md](CHANGELOG.md).

## How releases are made

Releases are cut by the maintainer with `scripts/release.sh`:

```bash
./scripts/release.sh 1.2.0             # build only
./scripts/release.sh 1.2.0 --publish   # build and publish
```

The script:

1. sets `CFBundleShortVersionString` to the version and `CFBundleVersion` to the commit count,
2. runs `swift test`,
3. builds the universal app with `build-app.sh` and the DMG with `make-dmg.sh`, and prints its SHA-256.

With `--publish` it also:

4. commits the version change, tags `v<version>` and pushes,
5. creates the GitHub release with the DMG and the notes from `docs/releases/<version>.md` (the script stops if that file is missing),
6. updates the Homebrew cask in `DigitalIQ/homebrew-tap` from `packaging/pocketwerk.rb.in`.

Before a release, move the "Unreleased" entries in `CHANGELOG.md` under the new version and write `docs/releases/<version>.md`.

## License

By contributing you agree that your contribution is released under the [MIT License](LICENSE).
