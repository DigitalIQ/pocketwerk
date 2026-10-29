# Changelog

All notable changes to Pocketwerk are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Liquid Glass app icon with dark, tinted and clear looks. The Honey, Ocean, Graphite and Iris variants are glass too.

### Fixed

- Dock profiles and Dock icons now share one copy of a test Dock file, so a profile captured in a test sees the slots added before it.
- Opening the main window no longer focuses the group name and selects its text. The sidebar takes the focus; a new group still opens its name for typing.
- Safari and the other system apps in the cryptex show `/Applications` as their path, not `/System/Volumes/Preboot/Cryptexes/App/System/Applications`.
- The Record Shortcut buttons use the normal button font instead of a monospaced one.
- Dock Icons page: a grouped layout like the settings pages, without the group name repeated under each slot. A slot's groups and its place in the list are in its … menu.

### Development

- `scripts/snap.sh` saves light and dark pictures of every page to `.tmp/shots`.
- `scripts/selftest.sh` runs the real app functions on a test library and prints PASS or FAIL per step. `release.sh` runs it before the DMG is made.

## [1.1.0] - 2026-10-13

### Added

- Assistant tab: change a group from a plain sentence (look, labels, layout, Dock icon, name, apps), on device with Apple Intelligence. Every change can be undone; removals wait for confirmation.
- App suggestions in the App Drawer, from Apple Intelligence or, without it, from app categories and apps used together. A group category helps them.
- Suggested Groups: apps you often open together, offered as new groups.
- Sidebar navigation in the popup as an alternative to the carousel, with group names or a compact icon rail, ⌘ number badges and drop targets per group.
- Keys 1 to 9 open the items of the current popup page; hold ⌃ to see the numbers.
- Locate… for missing items, in the popup and the main window.
- Group picker for drops that do not name a group (smart groups, folder views, Pocketwerk's own Dock icon).
- Live preview of the popup distance while you drag the slider.
- Dock profiles that switch with the Space or display (`pocketwerk spaces` shows the ids).
- Tile actions in profiles: open an app, open a project or folder with it, or open a browser profile (Chrome, Edge, Brave, Vivaldi, Arc, Firefox). Tile notes and folder stack options.
- Last context notes: a short note when you leave a profile, shown when you return.
- Next-profile cycling with per-profile opt out, a hotkey, `pocketwerk://profile?action=next` and `pocketwerk profiles next`.
- Private profiles, Export All, Share…, and `pocketwerk profiles export` / `import`.
- Tags and "keep apps open when switching away" per profile.
- App Intents: Shortcuts actions for groups and profiles, Siri phrases, and a "Set Dock Profile" Focus filter.
- `pocketwerk://group?action=openAll|hideAll|quitAll&name=…` URLs.
- Commands window listing every phrase, URL and command with a Copy button.
- Live main Dock icon showing a mini grid of the first group.
- Spring-loading on Dock tiles: hold a drag over a Pocketwerk Dock icon to open its popup and drop inside.
- Hot corner that shows all groups.
- Leader key with a letter per group and profile, and hotkeys with double or triple press or a follow-up key.
- Menu bar icon styles: Outline, Filled, Dots, Group colors.
- Built-in help window (⌘?) and Report a Problem.
- Diagnostics page with Export Diagnostics (local text file only).
- App icon variants: Standard, Honey, Ocean, Graphite, Iris.
- Glow and depth for popups, falling snow over textures, gradient swatches.
- Seasonal touches in the app windows, off by default.
- Option to open the main window at launch.

### Changed

- Animated backgrounds use less CPU: they stop when hidden or covered, slow down while the pointer is elsewhere and run at most 30 frames per second on battery.
- Digits typed in the popup open items instead of starting a search.
- Dock launchers use a new format and are rebuilt once automatically after the update.

## [1.0.0] - 2026-10-13

First public release.

### Added

- Groups of apps, files, folders and links, with manual or automatic sort order, renamable items, emoji and pinning.
- Smart groups: Most Used, Recently Opened and Running Apps.
- Dock icons: each slot gets a small launcher app in `~/Applications/Pocketwerk` and shows one or more groups. Drop files on a tile to add them; right-click a tile for its items, Open All, Hide All and Quit All.
- Popup right above the clicked Dock icon, in grid, list or tiles view, with adaptive layout, pages, and swiping or scrolling between groups.
- Popup actions: Open All (with optional confirmation), Hide All, Quit All, Force Quit All, ⌥-click to quit an app, ⌘-click to select several items, Keep Open as Window.
- Folders that open inside the popup, Quick Look with Space, type to search, full keyboard control.
- Drag and drop: add items, reorder them, drag them out to remove them, drop a file on an app to open it with that app.
- Design Studio with Liquid Glass, colors, gradients, mesh fills, photos, the blurred desktop picture, textures and animated backgrounds that react to the pointer; borders, fonts, labels, corner radius and grid settings; dozens of built-in themes and presets; your own saved themes.
- Dock icon styles: mini grid of the items, fanned stack, folder shape, SF Symbol icon packs, emoji, text, monogram and your own image.
- Dock profiles: save the whole Dock, edit its tiles, apply it with one click, a hotkey, the menu bar, the CLI or a URL. Optional quitting and launching of apps on apply, a startup profile, import and export per profile.
- Custom Dock spacers with text.
- Global hotkeys for all groups, each group, each Dock icon, each profile and the next profile, plus automatic ⌥⇧1 to ⌥⇧9. No Accessibility permission needed.
- Menu bar mode, launch at login, and a right-click menu on the app's Dock icon.
- `pocketwerk://` URL scheme and a command line mode (`Pocketwerk --cli`, wrapper in `scripts/pocketwerk`).
- Services menu entry "Add to Pocketwerk" and "Add Current Browser Tab" for Safari, Chrome, Arc and Brave.
- App Drawer to add several apps at once, with search, categories and filters.
- Missing item detection; moved apps are found again by bundle ID.
- Backup export and import with Merge or Replace, an optional copy of the library in another folder, undo for every change.
- Daily update check against GitHub releases.
- English and German interface.
- Support for Reduce Motion, Reduce Transparency and Low Power Mode.

[Unreleased]: https://github.com/DigitalIQ/pocketwerk/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/DigitalIQ/pocketwerk/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/DigitalIQ/pocketwerk/releases/tag/v1.0.0
