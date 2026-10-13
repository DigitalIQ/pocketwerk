# Pocketwerk user guide

This guide covers Pocketwerk 1.0. For installation and the first launch, see the [README](../README.md#install).

Three words come up everywhere:

- A **group** (a pocket) is a named set of apps, files, folders and links with its own look.
- A **Dock icon** (a slot) is one tile in the macOS Dock. It shows one or more groups.
- A **Dock profile** is a saved copy of your whole macOS Dock.

## Contents

1. [The main window](#the-main-window)
2. [Groups and items](#groups-and-items)
3. [Dock icons](#dock-icons)
4. [The popup](#the-popup)
5. [Design Studio](#design-studio)
6. [Dock profiles](#dock-profiles)
7. [Hotkeys](#hotkeys)
8. [Menu bar and app Dock icon](#menu-bar-and-app-dock-icon)
9. [Backup and sync folder](#backup-and-sync-folder)
10. [Updates](#updates)
11. [Accessibility](#accessibility)
12. [Keyboard shortcuts](#keyboard-shortcuts)

## The main window

Open it with **Window > Pocketwerk** (⌘0), from the menu bar icon or by clicking Pocketwerk's own Dock icon. The sidebar lists:

- **Groups**: your groups. Pinned groups stay at the top.
- **Dock**: **Dock Icons** and **Dock Profiles**.
- **Settings**: General, Popup, Hotkeys, Backup, Updates and About.

**View > Toggle Sidebar** (⌃⌘S) hides the sidebar.

On first launch a welcome window offers a few starter groups, including a Most Used group that fills itself as you work. Take them or skip.

## Groups and items

### Create, rename, delete

- **New group**: **File > New Group** (⌘N) or the + button above the sidebar. The new group is selected right away.
- **Rename**: right-click the group in the sidebar and choose **Rename**, or edit the name in the group's view.
- **Delete**: right-click the group and choose **Delete…**. Its Dock icon goes too. ⌘Z brings both back.

Each group has three tabs: **Items**, **Appearance** (the Design Studio) and **Options**.

### Add items

- **Add Apps…** (⇧⌘A) opens the App Drawer: search, filter by category, show recently installed apps or apps not in any group, and pick several at once. **Hide menu bar apps** in Settings > General keeps background helpers out of the list.
- **Add Files…** (⇧⌘F) adds files and folders.
- **Add Link…** (⇧⌘L) adds a web link. **Add Current Browser Tab** takes the front tab of Safari, Chrome, Arc or Brave. The first time, macOS asks whether Pocketwerk may control that browser (see [Permissions](#permissions)).
- Drag apps, files or folders from the Finder onto the item list, onto a group in the sidebar, into an open popup or onto a Pocketwerk Dock icon.
- Select a link, file or text with links in any app and choose **Services > Add to Pocketwerk**. Pocketwerk asks which group to use.

### Arrange items

- **Sort By**: Manual, Name, Kind, Date Added, Last Opened or Most Opened.
- In manual order, drag items to reorder them, in the list or in the popup. **Move Up** and **Move Down** are in the item's context menu.
- **Rename** gives an item its own name. **Use Original Name** goes back.
- **Move to Group** and **Add to Group** in the popup's context menu move or copy an item. A group never holds the same item twice.
- **Remove from Group**, ⌘⌫ in the popup, or drag an item out of the popup and drop it on an empty spot of the desktop.

### Missing items

When an app, file or folder is gone, its item is marked as missing. Apps that moved are found again by their bundle ID. **Remove Missing** in a group cleans up. Settings > General > **Missing Items** can remove missing items automatically.

### Group options

- **Shortcut**: a global hotkey for this group. Without one, the first nine groups use ⌥⇧1 to ⌥⇧9.
- **Emoji**: shown next to the group name.
- **Pin to top of the sidebar**.
- **Hide from All Groups**: the group no longer appears in "Show All Groups", but its own Dock icon and hotkey still open it.
- **Use default look**: follow the shared default style instead of an own look.

### Smart groups

**File > New Smart Group** creates a group that fills itself:

- **Most Used**: apps you launch most, counted on this Mac only.
- **Recently Opened**: items and apps you opened most recently.
- **Running Apps**: apps that are running right now.

Settings > Popup > **Show the Most Used group** controls whether Most Used appears among all groups.

## Dock icons

A group only gets a tile in the Dock when you give it a Dock icon.

1. Open **Dock Icons** in the sidebar and click **Add Slot**.
2. Name the slot and choose the group or groups it shows. With several groups, the popup lets you swipe between them.
3. Click **Add to Dock**.

Pocketwerk builds a small launcher app for each slot in `~/Applications/Pocketwerk/` and adds it to the Dock. Adding or removing a tile restarts the Dock once. Launchers update in place, so a pinned tile stays valid when you rename the slot or change its icon.

On the Dock tile:

- **Click** opens the popup above the tile. Click again to close it.
- **Drop files or links** on the tile to add them to the slot's first group.
- **Right-click** lists the items, plus **Open All**, **Hide All** and **Quit All**.

In the slot's menu (the ⋯ button):

- **Customize Icon…** opens the icon editor. **Use Group Icon** shows the first group's icon.
- **Remove from Dock** takes the tile out of the Dock but keeps the slot.
- **Uninstall Launcher** removes the launcher app as well.
- **Reload Dock** restarts the Dock once so pinned tiles pick up new icons.
- **Delete Slot** removes the slot.

If a launcher cannot be built, Pocketwerk shows the error with a **Copy Details** button. Include those details in a bug report.

### Spacers

**Add Spacer** creates a Dock tile that only shows text or an image, to label a part of your Dock. Set the text, the text color and a background color.

## The popup

The popup opens right above the Dock icon you clicked. It also opens from a hotkey, the menu bar or a URL.

### Layout

- Three views: **Grid**, **List** and **Tiles**, set in the Design Studio under Grid.
- With **Auto Layout** the popup picks columns and rows from the number of items. You can also fix columns and rows.
- When items do not fit, the popup shows pages with page dots. Scroll, swipe or use the arrow keys to move between pages.
- A popup that shows several groups (all groups, or a Dock icon with several groups) moves to the next group after the last page. ⌘1 to ⌘9 jump straight to a group.

### Opening things

- **Click** opens an item. Settings > General > **Close the popup after opening an item** decides whether the popup stays.
- **⌘-click** selects several items. **Open** in the header opens the selection.
- **⌥-click** on a running app quits it.
- **Folders** open inside the popup. Delete or **Back** goes up again.
- **Space** or ⌘Y shows Quick Look for the selected item.
- Drop a file on an app in the popup to open the file with that app.

### Group actions

The header holds:

- **Open All**: opens every item. With **Ask before Open All** on, the first click shows "Open N?" and a second click within three seconds opens. **Pause between apps in Open All** spaces out the launches.
- **Hide All**: hides the group's apps. Hold ⌥ for **Quit All**, ⌘ for **Force Quit All**.
- **Keep Open as Window** (the pin): the popup stays open as a window until you close it.

### Search

Start typing while the popup is open. The popup filters to matching items and selects the first one. Return opens it. Esc clears the search.

### Context menu

Right-click (or Control-click) an item for **Open**, **Open With**, **Quick Look**, **Show in Finder**, **Rename…**, **Move to Group**, **Add to Group** and **Remove from Group**. Running apps also get **Hide**, **Quit** and **Force Quit**.

### Placement

Settings > Popup > **Placement** sets where the popup appears, separately for Dock clicks and for shortcuts: above the Dock icon, at the center of the Dock, at the pointer or at the center of the screen. **Distance from the Dock** moves it up or down. **Keep the size while swiping** stops the popup from resizing between groups.

**Animation speed** (Settings > General) is Slow, Medium, Fast or Off.

## Design Studio

Open a group and choose the **Appearance** tab. On the left is a gallery of looks, in the middle a live preview, on the right the inspector with three tabs: **Icon** (⌥⌘1), **Popup** (⌥⌘2) and **Grid** (⌥⌘3).

### Looks

The gallery holds dozens of built-in themes and presets. Click one to apply it, or search by name. **Save as Theme** stores the current popup and Dock icon look under a name, ready for any group. Your own themes can be renamed, deleted or overwritten with **Update with Current Look**. Groups that use a deleted theme keep their look.

### Popup

- **Fill**: Glass (Liquid Glass with a tint), a solid color, a gradient, a mesh, a photo, your desktop picture (blurred behind the popup), a texture or a living effect.
- **Living effects**: animated backgrounds such as Aurora, Rain, Snow, Waves, Lava, Starfield, Plasma or Glyph Rain. Many react to the pointer. Choose the colors, speed and variant.
- **Glass and Finish**: glass amount, opacity, shadow.
- **Border and Corners**: border color and width, corner radius.
- **Labels**: show names always, on hover or never; font, size, color, text shadow and a text backdrop.
- **Header and Hover**: header alignment or no header, hover highlight.
- **Icon Plate**: a colored plate behind each item icon.
- **Appearance**: follow the system, or force light or dark.
- **Popup Follows Dock Icon**: matches the popup to the Dock icon.

### Grid

View (Grid, List, Tiles), Auto Layout, columns, rows, pages and page dots, density, icon size and spacing, the running indicator under running apps, and the sort order. In the popup, ⌘+ and ⌘- change the icon size of the current group.

### Icon

The Dock icon of the group:

- **Content**: a grid of the items inside (2×2, 3×3, 4×4 or Auto), a fanned stack of items, an SF Symbol from an icon pack, an emoji, text, a monogram or your own image.
- **Shape**: squircle, rounded square, circle, square, folder or none.
- **Style**: background fill, foreground color, border, opacity, glossy finish, lift, dense grid, round items.
- **Stack**: direction, depth, fade, blur and shuffled apps.
- **Match Theme** takes the colors of the popup look.

## Dock profiles

A profile is a saved copy of your whole Dock: apps, folders, files, links and spacers.

### Create

Open **Dock Profiles** and click the + button:

- **From Current Dock** saves the Dock as it is now.
- **Empty Profile** starts blank. Add tiles with **App…**, **File or Folder…**, **Add Link**, **Spacer**, **Small Spacer** and **Flexible Spacer**, or drop apps, files and folders on the list.

**Duplicate**, **Export…** and **Import…** (a JSON file per profile) are in the profile's menu.

### Apply

Select a profile and click **Apply** (⌘Return). Pocketwerk rewrites the Dock and restarts it once. Tiles whose file is gone are left out and listed. Two profiles are never applied at the same time, so a profile is never half applied.

Other ways to switch:

- a hotkey per profile, or one hotkey for **Next Dock profile**
- the menu bar menu and the right-click menu of Pocketwerk's Dock icon
- the URL `pocketwerk://profile?name=<name>` or `pocketwerk profiles apply <name>` (see [Automation](../README.md#automation))

### When applied

- **Quit apps that are not in this profile**, with a **Keep running** list of apps that must never quit.
- **Open the profile's apps in the background**.
- **Open after applying**: files, folders or links to open.
- **Skip if already active**.
- **Save Dock into active profile before switching** keeps changes you made to the Dock by hand.

**Save Current Dock Here** replaces a profile's tiles with what the Dock shows now. **Apply at startup** applies one profile whenever Pocketwerk starts.

## Hotkeys

Settings > Hotkeys lists every hotkey in one place:

- **Show all groups**
- **Next Dock profile**
- **Save Dock into active profile**
- one per group, per Dock icon and per profile
- **⌥⇧1 to ⌥⇧9 open the first nine groups**: automatic hotkeys for groups without their own. Turn them off here.

Click a hotkey field and press the keys. Pocketwerk warns when another app or another Pocketwerk target already uses the combination. Hotkeys work everywhere, also in full screen apps, and need no Accessibility permission.

## Menu bar and app Dock icon

Settings > General > **Show Pocketwerk in**: **Menu bar only**, **Menu bar and Dock** or **Dock only**. **Launch at login** registers Pocketwerk as a login item. If macOS asks you to allow it, **Open Login Items** takes you there.

Clicking the menu bar icon shows all groups as a popup, or a menu if you choose **A menu** under Settings > Popup > Menu Bar. A right-click always shows the menu: **Show All Groups**, each group with **Show Group**, **Open All** and **Edit Group…**, **Dock Profiles**, **New Group…**, **Settings…** and **Quit Pocketwerk**. When an update is available, the menu says so at the top.

A right-click on Pocketwerk's own Dock icon shows every group as a submenu (its items, then Open All, Hide All, Quit All) and your Dock profiles.

## Backup and sync folder

Everything lives in `~/Library/Application Support/Pocketwerk/`:

- `library.json`: groups, Dock icons, profiles, themes, hotkeys and settings
- `Images/`: images you picked for icons and backgrounds
- `Favicons/`: icons of your links

Pocketwerk saves after every change. If the file ever cannot be read, it is copied aside and never overwritten.

Settings > Backup:

- **Export Backup…** writes one readable JSON file with groups, Dock icons, profiles, shortcuts and settings.
- **Import Backup…** shows what the file contains, then lets you **Merge** (adds only what is new, never deletes) or **Replace All**. Both can be undone with ⌘Z. Launchers are rebuilt after an import.
- **Show in Finder** opens the data folder.
- **Copy to Another Folder**: Pocketwerk writes a copy of the library there after every change, for example to iCloud Drive. It never reads that copy back on its own; to use it on another Mac, import it there.

## Updates

With **Check for updates once a day** on (Settings > Updates), Pocketwerk asks the GitHub releases API for the latest version. Nothing else is sent. When a newer version exists, a notice appears in the main window and the menu bar menu. **Open Download Page** takes you to the release; **Skip This Version** hides the notice for that version. **Check Now** checks right away.

Pocketwerk does not install updates by itself. Download the new DMG, or run `brew upgrade --cask pocketwerk`.

## Accessibility

- Controls have VoiceOver labels, and the popup works fully from the keyboard.
- With **Reduce Motion** on, popups and pages fade instead of sliding, and living effects stand still.
- With **Reduce Transparency** on, glass and see-through fills become opaque.
- In **Low Power Mode**, living effects stop animating.
- **Animation speed: Off** turns popup animations off for everyone.

## Permissions

Pocketwerk needs no permission to work. The only prompt you may see is **Automation**, when you use **Add Current Browser Tab**: macOS asks once whether Pocketwerk may read the front tab of that browser. If you said no, allow it under System Settings > Privacy & Security > Automation.

## Keyboard shortcuts

### In the popup

| Keys | Action |
|---|---|
| ← → ↑ ↓ | Move the selection. At the edge, go to the next page or group |
| Return | Open the selected item (or the first search result) |
| ⌘Return | Open All |
| Space or ⌘Y | Quick Look |
| Type letters | Search the group |
| Delete | Remove the last search letter, or leave the open folder |
| Esc | Close Quick Look, clear the search, leave the folder, clear the selection, then close the popup |
| Tab / ⇧Tab | Next / previous group |
| ⌘← ⌘→ or ⌥← ⌥→ | Previous / next page or group |
| ⌘1 to ⌘9 | Jump to group 1 to 9 of this popup |
| ⌘A | Select all items |
| ⌘O | Open the selected items, or all items |
| ⌘⌫ | Remove the selected item from the group |
| ⌘+ / ⌘- | Bigger / smaller icons in this group |
| ⌘W | Close the popup |

### Mouse in the popup

| Action | Result |
|---|---|
| Click | Open the item (folders open inside the popup) |
| ⌘-click | Add to or remove from the selection |
| ⌥-click on a running app | Quit the app |
| Right-click or Control-click | Context menu |
| Scroll or swipe | Next / previous page or group |
| ⌥ or ⌘ on the Hide All button | Quit All / Force Quit All |
| Drag inside the popup | Reorder |
| Drag out to an empty spot | Remove from the group |

### Global (from any app)

| Keys | Action |
|---|---|
| ⌥⇧1 to ⌥⇧9 | Open group 1 to 9 (default, can be turned off) |
| Your own hotkeys | Show all groups, a group, a Dock icon, a profile, the next profile, save the Dock into the active profile |

### In the main window

| Keys | Action |
|---|---|
| ⌘N | New group |
| ⇧⌘A | Add apps |
| ⇧⌘F | Add files |
| ⇧⌘L | Add link |
| ⌘Z / ⇧⌘Z | Undo / redo (also for deleted groups and imports) |
| ⌃⌘S | Toggle sidebar |
| ⌥⌘1 / ⌥⌘2 / ⌥⌘3 | Design Studio: Icon / Popup / Grid |
| ⌘Return | Apply the selected Dock profile |
| ⌘0 | Show the main window |
| ⌘, | Settings |
| ⌘W | Close the window |
| ⌘Q | Quit Pocketwerk |
