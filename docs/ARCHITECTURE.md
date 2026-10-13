# Pocketwerk architecture

Pocketwerk is a native macOS app (Swift 6.2 toolchain, Swift 5 language mode, AppKit + SwiftUI, macOS 26+). It is built with SwiftPM and assembled into an app bundle by `scripts/build-app.sh`. There is no Xcode project.

## Targets

| Target | Kind | Purpose |
|---|---|---|
| `PocketwerkShared` | library | Constants shared by the app and the launchers: bundle IDs, URL scheme, notification names, Info.plist keys. Keep it tiny. |
| `PocketwerkKit` | library | Everything the app does. Default actor isolation is `MainActor`. |
| `Pocketwerk` | executable | `main.swift` only. Calls `PocketwerkMain.run()`. |
| `PocketwerkLauncher` | executable | Tiny app copied into every generated Dock launcher bundle. |
| `PocketwerkKitTests` | tests | Swift Testing (`import Testing`). |

## Build

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift build                                  # debug build
swift test                                   # tests
UNIVERSAL=0 ./scripts/build-app.sh           # app bundle for this Mac only
./scripts/build-app.sh --install             # universal app, copied to ~/Applications
```

`build-app.sh` copies `Resources/Info.plist`, `Resources/AppIcon.icns`, `Resources/Localization/*.lproj` and the launcher template (`Contents/Resources/LauncherTemplate.app`), then signs ad hoc. SwiftPM resource bundles are not used: `PocketwerkKit` has no `resources:`. Images and sounds are drawn in code or loaded from `Contents/Resources` via `Bundle.main`.

## Data

- `Model/Model.swift`: every persisted type. All model types are `nonisolated`, `Codable`, `Hashable`, `Sendable`, and every stored property has a default value.
- `Store/LibraryStore.swift`: the single source of truth. Every change goes through `mutate` (or the helpers built on it), which records undo, saves `~/Library/Application Support/Pocketwerk/library.json` (debounced, atomic) and posts `.libraryDidChange`.
- Older files are read with `LibraryStore.decodeLeniently`, which fills missing keys from defaults. A file that still cannot be read is copied aside, never overwritten.

Terms: a **group** is a named set of items (apps, files, folders, links) with its own look. A **slot** is one icon in the macOS Dock; it shows one or more groups and the popup swipes between them. A **profile** is a saved copy of the whole macOS Dock.

## Modules and entry points

| Folder | Entry points other modules call |
|---|---|
| `App/` | `PocketwerkMain.run()`, `AppCoordinator`, `URLRouter.handle(_:)`, `MainMenu.install()`, `MenuAction.item(...)` |
| `Dock/` | `DockManager.shared`: `start()`, `installLauncher(for:)`, `removeLauncher(for:)`, `addToDock(slotID:)`, `removeFromDock(slotID:)`, `isInDock(slotID:)`, `refreshIcons()`. `DockProfiles.shared`: `captureCurrent(name:)`, `apply(_:)` |
| `Icons/` | `IconRenderer.icon(for:size:)`, `groupIcon(_:size:)`, `slotIcon(_:library:size:)`, `render(spec:style:name:items:size:)` |
| `Popup/` | `PopupController.shared`: `prepare()` (at launch), `toggle(slotID:anchor:source:)`, `toggleAll(anchor:source:)`, `toggle(groupIDs:slotID:anchor:source:)`, `show(...)`, `hide()`. `anchor` = pointer position of the Dock click (Cocoa coordinates, nil = current mouse location); `source` `.dock` / `.hotkey` / `.menuBar` picks `placement` or `hotkeyPlacement`. `PopupGroupView(group:preview:)`. `ItemOpener.open(_:in:)`, `openAll(_:)`, `hideAll(_:)`, `quitAll(_:force:)`. `PopupIconCache.shared.icon(for:size:)`. `PopupController.shared.previewOffset(_:)` (live distance preview, nil ends it), `chooseGroup(for:at:)` (group picker for drops without a clear target), `PopoverOffsetSlider` (settings control with preview). `DockGeometry` (Dock edge, Dock screen, magnification gap, placement; pure functions) |
| `Theme/` | `ThemeLibrary.builtIn`, `ThemeLibrary.apply(_:to:)`, `StyleBackgroundView(background:pointer:isActive:)` |
| `Studio/` | `DesignStudioView(groupID:)` |
| `Settings/` | `MainWindowController.shared.show(selecting:)` |
| `MenuBar/` | `MenuBarController.shared.install()` |
| `Hotkeys/` | `HotkeyCenter.shared.start()`, `HotkeyCenter.describe(_:)`, `HotkeyRecorder` view |
| `Assistant/` | `AssistantView(groupID:)` |
| `Services/` | `ServicesProvider.shared.register()` |

A module may add new types and files inside its own folder. Signatures in the table above stay stable; extend them with default parameters if needed.

## Dock launchers

Each slot gets a small app bundle in `~/Applications/Pocketwerk/`, copied from `LauncherTemplate.app`, with its own bundle ID (`io.github.digitaliq.pocketwerk.slot.<UUID>`), name and icon, signed ad hoc. A click on its Dock tile sends `PWShared.openSlotNotification` (distributed notification, slot ID plus pointer position) to the main app, which opens the popup above that tile. If the main app is not running, the launcher opens `pocketwerk://open?slot=<UUID>&x=..&y=..` instead. Launchers are updated in place so Dock pins stay valid.

## Conventions

- UI strings are English in code. SwiftUI `Text("...")` literals are localized automatically; AppKit strings use `String(localized:)`. German lives in `Resources/Localization/de.lproj/Localizable.strings`.
- No third-party packages. No network access except the daily update check against the GitHub releases API and favicon fetches for link items.
- No telemetry.
- Animations respect Reduce Motion, Reduce Transparency and Low Power Mode.
- Every pure function (geometry, layout, sorting, plist building) gets a test.
