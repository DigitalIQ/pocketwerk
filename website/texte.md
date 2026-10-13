# Texts for pocketwerk site

Source of truth for every string on `site/index.html`. Language: English. Change here and in the page together.

## 1. Meta

- Title: `Pocketwerk: app folders for the Mac Dock. Free, open source`
- Meta description: `Group apps, files, folders and links into pockets that open right above their own Dock icon. Free, MIT licensed, no account. For macOS 26 Tahoe.`
- Open Graph image text: "Pockets for your Dock." / "Free, open-source app folders for the Mac Dock."

## 2. Sections

### Navigation

Logo "Pocketwerk" (home). Links: Features, Design, Profiles, Install, FAQ. Button: "Download".

### Hero

- H1: Pockets for your Dock.
- Subtext: Free, open-source app folders for the Mac Dock. Each pocket gets its own Dock icon and opens right above it.
- Primary button: Download for Mac
- Secondary: Homebrew command `brew install --cask digitaliq/tap/pocketwerk` with a button "Copy" (after copying: "Copied")
- Scene alt text: "A glass Dock with pockets of app icons hanging above three of its icons. One pocket is open."

### Video

- H2 (visually hidden): Pocketwerk in action
- Caption: A pocket opens from the Dock, changes its look and switches the Dock profile.

### What it does

- H2: One Dock icon, a whole group
- Intro: Put the apps, files, folders and links you use together into a pocket. Give it a Dock icon. Click once to open it, click again to close it.
- Idea 1, heading: Opens where you click. Text: The popup appears right above the pocket's Dock icon. Show it as a grid, a list or tiles; it adapts to what's inside and pages through the rest.
- Idea 2, heading: Apps, files, folders, links. Text: Folders open inside the popup. Press Space for Quick Look. Drag items in, drag them out to wherever you need them.
- Idea 3, heading: The whole group at once. Text: Open All, Hide All or Quit All for a pocket. ⌥-click quits a single app, ⌘-click picks several to open together.
- Idea 4, heading: Pockets that fill themselves. Text: Smart pockets show your Most Used, Recently Opened and Running Apps.
- Demo label: Try it: an example pocket. Buttons: Grid, List, Tiles. Note under demo: Example pocket, drawn for this page.

### Design Studio

- H2: Make every pocket look its own way
- Text: The Design Studio styles each popup with Liquid Glass, colors, gradients, photos, your blurred desktop picture, textures or animated backgrounds that react to the pointer. Set borders, fonts and corner radius. Start from dozens of built-in themes and presets, then save your own.
- Swatch rail label: Example looks. Swatches: Glass, Board, Signal, Night, Paper, Pointer
- Dock icon part, heading: An icon to match
- Dock icon text: The pocket's Dock icon can show a mini grid of the apps inside, a fanned stack, a folder shape, an icon from the SF Symbol packs, an emoji, a word or your own image.
- Icon labels: Mini grid, Stack, Folder, Symbol, Emoji, Text, Image

### Dock profiles

- H2: A different Dock for every kind of work
- Text: Save the whole macOS Dock as a profile. Switch with a hotkey, from the menu bar, the command line or a URL. Pocketwerk can quit and launch apps as it switches, and custom spacers keep long Docks readable.
- Profile tabs (examples): Work, Studio, Evening
- Note: Example profiles. Yours are whatever you save.
- Code line: `open "pocketwerk://…"` is not shown (syntax not public yet). Show only "Hotkey, menu bar, CLI or URL".

### Keyboard and power features

- H2: Fast from the keyboard
- Keys and captions:
  - ⌘1 to ⌘9: jump to a pocket
  - Arrow keys and Return: move and open
  - Space: Quick Look
  - Type: search the pocket
  - Swipe or scroll: next pocket
- List heading: And the rest of the toolbox
- List:
  - Global hotkeys for every pocket and every profile. No Accessibility permission needed.
  - Menu bar mode, if you'd rather keep Pocketwerk out of the Dock.
  - Launch at login.
  - English and German.
- Coming in 1.1: An on-device assistant edits a pocket from a plain sentence, with undo. It uses Apple Intelligence on supported Macs with macOS 26.

### Privacy

- H2: It stays on your Mac
- Text: There is no account, no tracking and no analytics. Your pockets live in one JSON file on your Mac. Pocketwerk goes online for two things only: a daily update check and the small icons (favicons) of your links.
- Second line: This website sets no cookies either.
- Link: Read the source on GitHub

### Install

- H2: Install Pocketwerk
- Requirement line: macOS 26 Tahoe or later. Apple Silicon and Intel.
- Step 1 heading: Get the app. Text: Download the DMG from GitHub Releases and drag Pocketwerk into Applications. Or install it with Homebrew.
- Step 2 heading: Open it once. Text: Pocketwerk isn't notarized by Apple, so the first launch is blocked. Close the message.
- Step 3 heading: Allow it in System Settings. Text: Open System Settings, go to Privacy & Security, scroll down and click "Open Anyway" next to Pocketwerk. Confirm, and from then on it opens like any other app.
- Illustration label: Privacy & Security, illustrated. Row text: "Pocketwerk" was blocked to protect your Mac. Button: Open Anyway
- Buttons: Download for Mac, Copy (Homebrew)

### FAQ

- H2: Questions
1. Is Pocketwerk really free? Yes. It's free and open source under the MIT license. There's no account and nothing to buy.
2. Why does macOS block the first launch? Pocketwerk isn't notarized by Apple. macOS stops the first launch of apps like that. Click "Open Anyway" once in System Settings > Privacy & Security and it opens normally from then on.
3. How is a pocket different from a folder in the Dock? A Dock folder shows the files inside one Finder folder. A pocket mixes apps, files, folders and links, has its own Dock icon and look, and can open, hide or quit all its apps at once.
4. Does Pocketwerk need the Accessibility permission? Not for its hotkeys. Global hotkeys for pockets and profiles work without it.
5. What leaves my Mac? A daily update check and requests for your links' favicons. Nothing else. Your pockets are stored in one JSON file on your Mac.
6. Which Macs does it run on? Macs with macOS 26 Tahoe or later, both Apple Silicon and Intel.
7. Which languages does it speak? English and German.
8. Where is the source code? The full source is on GitHub at github.com/DigitalIQ/pocketwerk.

### Footer

- Text: Pocketwerk is made by DigitalIQ and released under the MIT license.
- Links: Source on GitHub, Releases, MIT License
- Small: No cookies, no tracking.

## 3. Form

None. The site has no forms.

## 4. Fact sentences

- Pocketwerk is a free, open-source macOS app released under the MIT license by DigitalIQ.
- Pocketwerk groups apps, files, folders and links into "pockets" that can each get their own icon in the macOS Dock.
- Clicking a pocket's Dock icon opens a themed popup directly above that icon; a second click closes it.
- Pocketwerk runs on macOS 26 Tahoe and later, on Apple Silicon and Intel Macs.
- Pocketwerk can save the whole macOS Dock as a profile and switch profiles with a hotkey, the menu bar, the command line or a URL.
- Pocketwerk's global hotkeys work without the macOS Accessibility permission.
- Pocketwerk has no account, no tracking and no analytics; its data stays in a JSON file on the Mac.
- Pocketwerk is installed from GitHub Releases as a DMG or with `brew install --cask digitaliq/tap/pocketwerk`.
- Pocketwerk is not notarized, so the first launch needs "Open Anyway" in System Settings > Privacy & Security once.
- Pocketwerk's interface is available in English and German.

## 5. Open questions (for the maker)

1. Are issues and pull requests welcome on GitHub? (Not claimed until confirmed.)
2. Is there a LICENSE file at the repo root? The footer links the repository until it exists.
3. URL scheme and CLI syntax for profile switching: not shown until public.
4. Version number for the download button: not shown.
