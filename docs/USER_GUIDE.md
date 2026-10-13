# Pocketwerk user guide

This guide covers Pocketwerk 1.1. For installation and the first launch, see the [README](../README.md#install). Inside the app, **Help > Pocketwerk Help** (⌘?) has short topics that work offline.

Three words come up everywhere:

- A **group** (a pocket) is a named set of apps, files, folders and links with its own look.
- A **Dock icon** (a slot) is one tile in the macOS Dock. It shows one or more groups.
- A **Dock profile** is a saved copy of your whole macOS Dock.

## Contents

1. [The main window](#the-main-window)
2. [Groups and items](#groups-and-items)
3. [Assistant and suggestions](#assistant-and-suggestions)
4. [Dock icons](#dock-icons)
5. [The popup](#the-popup)
6. [Design Studio](#design-studio)
7. [Dock profiles](#dock-profiles)
8. [Hotkeys, leader key and hot corner](#hotkeys-leader-key-and-hot-corner)
9. [Shortcuts, Siri and Focus](#shortcuts-siri-and-focus)
10. [Menu bar and app Dock icon](#menu-bar-and-app-dock-icon)
11. [Backup and sync folder](#backup-and-sync-folder)
12. [Help and diagnostics](#help-and-diagnostics)
13. [Updates](#updates)
14. [Accessibility](#accessibility)
15. [Permissions](#permissions)
16. [Keyboard shortcuts](#keyboard-shortcuts)

## The main window

Open it with **Window > Pocketwerk** (⌘0), from the menu bar icon or by clicking Pocketwerk's own Dock icon. Settings > General > **Open this window when Pocketwerk starts** decides whether it appears at launch. The sidebar lists:

- **Groups**: your groups. Pinned groups stay at the top.
- **Dock**: **Dock Icons** and **Dock Profiles**.
- **Settings**: General, Popup, Hotkeys, Backup, Diagnostics, Updates and About.

**View > Toggle Sidebar** (⌃⌘S) hides the sidebar.

On first launch a welcome window offers a few starter groups, including a Most Used group that fills itself as you work. Take them or skip.

Settings > General also holds:

- **App Icon**: Standard, Honey, Ocean, Graphite or Iris. The variant is applied to Pocketwerk's Dock tile while it runs; the app bundle stays unchanged. If **Live main Dock icon** is on (see [Menu bar and app Dock icon](#menu-bar-and-app-dock-icon)), the Dock shows the live icon instead.
- **Seasonal touches**: light snowfall in the app windows in December. Off by default, and still under Reduce Motion or Low Power Mode.

## Groups and items

### Create, rename, delete

- **New group**: **File > New Group** (⌘N) or the + menu above the sidebar. The new group is selected right away.
- **Rename**: right-click the group in the sidebar and choose **Rename**, or edit the name in the group's view.
- **Delete**: right-click the group and choose **Delete…**. Its Dock icon goes too. ⌘Z brings both back.

Each group has four tabs: **Items**, **Appearance** (the Design Studio), **Options** and **Assistant**.

### Add items

- **Add Apps…** (⇧⌘A) opens the App Drawer: search, filter by category, show recently installed apps or apps not in any group, and pick several at once. Suggested apps for the group appear at the top (see [Assistant and suggestions](#assistant-and-suggestions)). **Hide menu bar apps** in Settings > General keeps background helpers out of the list.
- **Add Files…** (⇧⌘F) adds files and folders.
- **Add Link…** (⇧⌘L) adds a web link. **Add Current Browser Tab** takes the front tab of Safari, Chrome, Arc or Brave. The first time, macOS asks whether Pocketwerk may control that browser (see [Permissions](#permissions)).
- Drag apps, files or folders from the Finder onto the item list, onto a group in the sidebar, into an open popup or onto a Pocketwerk Dock icon. When the target does not say which group to use (a smart group, a folder view or Pocketwerk's own Dock icon), a small menu asks.
- Select a link, file or text with links in any app and choose **Services > Add to Pocketwerk**. Pocketwerk asks which group to use.

### Arrange items

- **Sort By**: Manual, Name, Kind, Date Added, Last Opened or Most Opened.
- In manual order, drag items to reorder them, in the list or in the popup. **Move Up** and **Move Down** are in the item's context menu.
- **Rename** gives an item its own name. **Use Original Name** goes back.
- **Move to Group** and **Add to Group** in the popup's context menu move or copy an item. A group never holds the same item twice.
- **Remove from Group**, ⌘⌫ in the popup, or drag an item out of the popup and drop it on an empty spot of the desktop.

### Missing items

When an app, file or folder is gone, its item is marked as missing. Apps that moved are found again by their bundle ID. In the popup, click a missing item and choose **Locate…** to point Pocketwerk to the new place, or **Remove from Group**. In the main window, **Locate…** is in the item's menu and **Remove Missing** cleans up a whole group. Settings > General > **Missing Items** can remove missing items automatically.

### Group options

- **Shortcut**: a global hotkey for this group. Without one, the first nine groups use ⌥⇧1 to ⌥⇧9.
- **Emoji**: shown next to the group name.
- **Category**, for example Office, Design or Games. It helps app suggestions.
- **Leader letter**: the letter that opens this group after the leader key.
- **Rows per page**, **Swipe between pages (otherwise scroll)** and **Show page dots**.
- **Pin to top of the sidebar**.
- **Hide from All Groups**: the group no longer appears in "Show All Groups", but its own Dock icon and hotkey still open it.
- **Use default look**: follow the shared default style instead of an own look.

### Smart groups

**File > New Smart Group** creates a group that fills itself:

- **Most Used**: apps you launch most, counted on this Mac only.
- **Recently Opened**: items and apps you opened most recently.
- **Running Apps**: apps that are running right now.

Settings > Popup > **Show the Most Used group** controls whether Most Used appears among all groups.

## Assistant and suggestions

### Assistant

The **Assistant** tab of a group changes it from plain language. Examples:

- "Make it dark blue with a list view"
- "Use a warm gradient and round corners"
- "Show labels only on hover"
- "Add my music apps"
- "Rename it to Studio and pick a fitting emoji"

It can change the look, labels, layout, Dock icon and name, and add or remove apps. Send with ⌘Return. Every change is listed with an **Undo** button. Items are only removed after you click **Remove**; **Keep** cancels. **Clear Conversation** starts over. The conversation is forgotten when Pocketwerk quits.

The assistant needs Apple Intelligence: a supported Mac with macOS 26 and Apple Intelligence turned on in System Settings. It runs on this Mac and nothing leaves it. If it is unavailable, the tab says why. Settings > General > **Apple Intelligence** can turn off the assistant and the app suggestions.

### App suggestions

The App Drawer shows apps that fit the group. With Apple Intelligence they are "Picked on this Mac by Apple Intelligence"; without it they come from app categories, words in the group name and category, and apps you use together. Add a suggestion with +, dismiss it with ×, or ask for new suggestions. Setting a **Category** in the group's options improves them.

### Suggested groups

The + menu above the sidebar has **Suggested Groups…**. It lists apps you often open within a few minutes of each other and that are not a group yet. **Create** turns a suggestion into a group. Usage is counted on this Mac only, so suggestions appear after a few days of use.

## Dock icons

A group only gets a tile in the Dock when you give it a Dock icon.

1. Open **Dock Icons** in the sidebar and click **Add Slot**.
2. Name the slot and choose the group or groups it shows. With several groups, the popup lets you swipe between them or shows a sidebar.
3. Click **Add to Dock**.

Pocketwerk builds a small launcher app for each slot in `~/Applications/Pocketwerk/` and adds it to the Dock. Adding or removing a tile restarts the Dock once. Launchers update in place, so a pinned tile stays valid when you rename the slot or change its icon. After an update that changes the launcher format, Pocketwerk rebuilds all launchers once by itself.

On the Dock tile:

- **Click** opens the popup above the tile. Click again to close it.
- **Drop files or links** on the tile to add them to the slot's first group.
- **Hold a drag** over the tile and the popup opens (spring-loading). Drop the item exactly where you want it, or on an app to open it with that app.
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

The popup opens right above the Dock icon you clicked. It also opens from a hotkey, the leader key, the hot corner, the menu bar, Shortcuts or a URL.

### Layout

- Three views: **Grid**, **List** and **Tiles**, set in the Design Studio under Grid.
- With **Auto Layout** the popup picks columns and rows from the number of items. You can also fix columns and rows.
- When items do not fit, the popup shows pages with page dots. Scroll, swipe or use the arrow keys to move between pages.

### Several groups

A popup can show several groups: all groups, or a Dock icon with several groups. Settings > Popup > **Navigation** picks how you move between them:

- **Carousel (swipe between groups)**: swipe, scroll or use the arrow keys. After the last page comes the next group.
- **Sidebar (list of groups)**: a list on the left side of the popup. Each row shows the group name and its ⌘ number. The button at the top switches between names and a compact icon rail. Drop items on a row to add them to that group.

⌘1 to ⌘9 jump straight to a group in both modes. **Keep the size while swiping** stops the popup from resizing between groups.

### Opening things

- **Click** opens an item. Settings > General > **Close the popup after opening an item** decides whether the popup stays.
- **1 to 9** open the first nine items of the current page. Hold ⌃ to see the numbers on the items.
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

Start typing letters while the popup is open. The popup filters to matching items and selects the first one. Return opens it. Esc clears the search. Digits open items instead of searching.

### Context menu

Right-click (or Control-click) an item for **Open**, **Open With**, **Quick Look**, **Show in Finder**, **Rename…**, **Move to Group**, **Add to Group** and **Remove from Group**. Running apps also get **Hide**, **Quit** and **Force Quit**.

### Placement

Settings > Popup > **Placement** sets where the popup appears, separately for Dock clicks and for shortcuts: above the Dock icon, at the center of the Dock, at the pointer or at the center of the screen. **Distance from the Dock** moves it up or down; while you drag the slider, a preview shows the distance above the Dock.

**Animation speed** (Settings > General) is Slow, Medium, Fast or Off.

## Design Studio

Open a group and choose the **Appearance** tab. On the left is a gallery of looks, in the middle a live preview, on the right the inspector with three tabs: **Icon** (⌥⌘1), **Popup** (⌥⌘2) and **Grid** (⌥⌘3).

### Looks

The gallery holds dozens of built-in themes and presets. Click one to apply it, or search by name. **Save as Theme** stores the current popup and Dock icon look under a name, ready for any group. Your own themes can be renamed, deleted or overwritten with **Update with Current Look**. Groups that use a deleted theme keep their look.

### Popup

- **Fill**: Glass (Liquid Glass with a tint), a solid color, a gradient (with ready-made gradient swatches), a mesh, a photo, your desktop picture (blurred behind the popup), a texture or a living effect.
- **Textures** can get **Falling Snow** on top.
- **Living effects**: animated backgrounds such as Aurora, Rain, Snow, Waves, Lava, Starfield, Plasma or Glyph Rain. Many react to the pointer. Choose the colors, speed and variant.
- **Glass and Finish**: glass effect, opacity, matte, **Glow** and **Depth**.
- **Border and Corners**: border color and width, corner radius.
- **Labels**: show names always, on hover or never; font, size, color, text shadow and a text backdrop.
- **Header and Hover**: header alignment or no header, hover highlight.
- **Icon Plate**: a colored plate behind each item icon.
- **Appearance**: follow the system, or force light or dark.
- **Popup Follows Dock Icon**: matches the popup to the Dock icon.

Living effects cost little: they stop drawing when the popup is hidden or covered, slow down while the pointer is elsewhere, run at most 30 frames per second on battery, and stand still under Reduce Motion or Low Power Mode.

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

The profile's menu has **Duplicate**, **Export…**, **Share…** and **Delete**. **Import…** and **Export All…** sit above the list. Profiles are exchanged as JSON files.

### Tiles

Each tile in the profile editor can carry:

- a **note**, for your own reference (it does not change the Dock),
- for folders: the Dock's stack options **View** (Automatic, Fan, Grid, List), **Display as** (Stack, Folder) and **Sort by**,
- for apps: actions that run when the profile is applied: **Open When Applied**, **Open Project or Folder…** (opens that folder with the app), or **Open Profile "…"** for a browser profile. Browser profiles are read on request with **Find … Profiles** and work with Chrome, Edge, Brave, Vivaldi, Arc and Firefox.

### Apply

Select a profile and click **Apply** (⌘Return). Pocketwerk rewrites the Dock and restarts it once. Tiles whose file is gone are left out and listed. Two profiles are never applied at the same time, so a profile is never half applied.

Other ways to switch:

- a hotkey per profile, a leader letter, or one hotkey for **Next Dock profile**
- the menu bar menu and the right-click menu of Pocketwerk's Dock icon
- Shortcuts, Siri and Focus (see [Shortcuts, Siri and Focus](#shortcuts-siri-and-focus))
- the URL `pocketwerk://profile?name=<name>` or `pocketwerk profiles apply <name>` (see [Automation](../README.md#automation))

### When applied

- **Quit apps that are not in this profile**, with a **Keep running** list of apps that must never quit.
- **Open the profile's apps in the background**.
- **Open after applying**: files, folders or links to open.
- **Skip if already active**.
- **Save Dock into active profile before switching** keeps changes you made to the Dock by hand.

**Save Current Dock Here** replaces a profile's tiles with what the Dock shows now. **Apply at startup** applies one profile whenever Pocketwerk starts.

### More options per profile

- **Keep this profile's apps open when switching away**.
- **Skip in "Next Profile"**: the profile is left out when you cycle with Next Dock profile.
- **Private (left out of Export All and sharing)**.
- **Tags**, for your own order.
- **Last context note**: see below.
- **Apply automatically on**: Spaces and displays, see below.

### Spaces and displays

Turn on **Switch with Spaces and displays** in Dock Profiles. Then, in a profile's options, click **Link This Space** or **Link This Display**. When you move to that Space or display, Pocketwerk applies the linked profile. A Space link wins over a display link, and a Space or display belongs to one profile only. `pocketwerk spaces` prints the ids of the current Space and display.

Pocketwerk reads the current Space through an undocumented macOS interface. If a future macOS removes it, profiles can still be linked to displays.

### Last context

Turn on **Ask for a note when switching away** in Dock Profiles. When you leave a profile, Pocketwerk asks for a short note ("Where you left off"). When you switch back, the note shows at the top of the screen for a few seconds. **Skip** keeps the previous note.

### Commands

**Commands…** in Dock Profiles lists the Siri phrases, Shortcuts actions, URLs and command line calls for your groups and profiles, each with a Copy button.

## Hotkeys, leader key and hot corner

### Hotkeys

Settings > Hotkeys lists every hotkey in one place:

- **Show all groups**
- **Next Dock profile**
- **Save Dock into active profile**
- one per group, per Dock icon and per profile
- **⌥⇧1 to ⌥⇧9 open the first nine groups**: automatic hotkeys for groups without their own. Turn them off here.

Click a hotkey field and press the keys. Pocketwerk warns when another app or another Pocketwerk target already uses the combination. The **…** button next to a hotkey makes it a double or triple press, or adds a follow-up key, for example ⌃⌥G then W. Hotkeys work everywhere, also in full screen apps, and need no Accessibility permission.

### Leader key

The leader key works like a prefix. Set it under Settings > Hotkeys > **Leader Key**, then give groups and profiles a letter (in the same list, or in a group's options). Press the leader key, then the letter. A small list shows the available letters while Pocketwerk waits. **Wait for the letter** sets how long it waits (0.5 to 4 seconds).

While it waits, Pocketwerk briefly reserves the plain letter keys, so typing in other apps pauses for that moment.

### Hot corner

Settings > Popup > **Hot Corner** picks a screen corner. Rest the pointer there for a moment to show all groups. Move the pointer away before it can fire again. Pick a corner that macOS does not use for its own hot corners. The hot corner needs no permission.

## Shortcuts, Siri and Focus

Pocketwerk offers actions in the Shortcuts app: **Show Group**, **Open All Items of Group**, **Hide Apps of Group**, **Quit Apps of Group**, **Apply Dock Profile** and **Apply Next Dock Profile**. Siri understands:

- "Show *group* in Pocketwerk"
- "Open all of *group* in Pocketwerk"
- "Quit *group* in Pocketwerk"
- "Switch Pocketwerk to *profile*"
- "Next Dock profile in Pocketwerk"

In System Settings > Focus, add the **Set Dock Profile** filter to a Focus to apply a profile when that Focus turns on.

The actions appear once macOS has indexed Pocketwerk. Keep the app in `/Applications` or `~/Applications` and open it once. If they are still missing, quit and relaunch Pocketwerk, or log out and in again. The `pocketwerk://` URLs always work with the Shortcuts action "Open URLs".

## Menu bar and app Dock icon

Settings > General > **Show Pocketwerk in**: **Menu bar only**, **Menu bar and Dock** or **Dock only**. **Launch at login** registers Pocketwerk as a login item. If macOS asks you to allow it, **Open Login Items** takes you there.

Settings > Popup > Menu Bar:

- **Clicking the menu bar icon shows** all groups as a popup, or a menu.
- **Icon**: Outline, Filled, Dots or Group colors.

A right-click always shows the menu: **Show All Groups**, each group with a color swatch and the submenu **Show Group**, **Open All** and **Edit Group…**, **Dock Profiles**, **Open Pocketwerk**, **New Group…**, **Settings…**, **Help** and **Quit Pocketwerk**. When an update is available, the menu says so at the top.

Pocketwerk's own Dock icon shows a live mini grid of your first group. Turn this off with **Live main Dock icon** under Dock Icons. A right-click on it shows every group as a submenu (its items, then Open All, Hide All, Quit All) and your Dock profiles. Files dropped on it go to a group you pick.

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

## Help and diagnostics

**Help > Pocketwerk Help** (⌘?) opens a searchable help window with short topics. **Help > Report a Problem…** opens the issue tracker in your browser; nothing is sent automatically.

Settings > Diagnostics shows counts of groups, items, Dock icons, profiles, missing items and active shortcuts. **Export Diagnostics…** saves the last five hours of Pocketwerk's own log and a short summary as a text file. Nothing is sent. Look at the file before you share it. **Show Data Folder** opens the data folder.

## Updates

With **Check for updates once a day** on (Settings > Updates), Pocketwerk asks the GitHub releases API for the latest version. Nothing else is sent. When a newer version exists, a notice appears in the main window and the menu bar menu. **Open Download Page** takes you to the release; **Skip This Version** hides the notice for that version. **Check Now** checks right away.

Pocketwerk does not install updates by itself. Download the new DMG, or run `brew upgrade --cask pocketwerk`.

## Accessibility

- Controls have VoiceOver labels, and the popup works fully from the keyboard.
- With **Reduce Motion** on, popups and pages fade instead of sliding, and living effects and seasonal snow stand still.
- With **Reduce Transparency** on, glass and see-through fills become opaque.
- In **Low Power Mode**, living effects stop animating.
- **Animation speed: Off** turns popup animations off for everyone.

## Permissions

Pocketwerk needs no permission to work. Hotkeys, the leader key and the hot corner run without Accessibility. The only prompt you may see is **Automation**, when you use **Add Current Browser Tab**: macOS asks once whether Pocketwerk may read the front tab of that browser. If you said no, allow it under System Settings > Privacy & Security > Automation.

**Find … Profiles** in the profile editor reads the browser's own profile list from its folder in `~/Library/Application Support`. It only runs when you click it, and macOS may ask whether Pocketwerk may access data from other apps.

## Keyboard shortcuts

### In the popup

| Keys | Action |
|---|---|
| ← → ↑ ↓ | Move the selection. At the edge, go to the next page or group |
| Return | Open the selected item (or the first search result) |
| ⌘Return | Open All |
| 1 to 9 | Open item 1 to 9 of the current page (hold ⌃ to see the numbers) |
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
| Click a missing item | Locate… or Remove from Group |
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
| Leader key, then a letter | Open a group or apply a profile |
| Your own hotkeys | Show all groups, a group, a Dock icon, a profile, the next profile, save the Dock into the active profile. Each can be a double or triple press or have a follow-up key |

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
| ⌘Return | Assistant: send. Dock Profiles: apply the selected profile |
| ⌘0 | Show the main window |
| ⌘, | Settings |
| ⌘? | Pocketwerk Help |
| ⌘W | Close the window |
| ⌘Q | Quit Pocketwerk |
