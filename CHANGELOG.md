# Changelog

All notable changes to Pocketwerk are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

Planned for 1.1.0.

### Added

- On-device assistant that edits a group from a plain sentence, with undo. Uses Apple Intelligence on supported Macs with macOS 26.
- App suggestions for a group.
- Dock profiles per Space.
- App Intents, so groups and profiles show up in the Shortcuts app.
- Sidebar navigation in the popup as an alternative to swiping between groups.
- Spring-loading on Dock tiles: hover a drag over a Pocketwerk Dock icon and its popup opens, then drop inside.

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

[Unreleased]: https://github.com/DigitalIQ/pocketwerk/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/DigitalIQ/pocketwerk/releases/tag/v1.0.0
