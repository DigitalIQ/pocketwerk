# Product

<!-- impeccable:product-schema 1 -->

Scope: the public product website for Pocketwerk (`site/`), deployed to GitHub Pages at `https://digitaliq.github.io/pocketwerk/`. Written autonomously from the website brief; nothing here came from an interview (see `../WEBSITE-STATUS.md`).

## Platform

web

## Stack

delegated: plain static HTML, CSS and JavaScript in `site/`, no build step. Relative asset URLs so the `/pocketwerk/` base path works. three.js 0.186.1 from jsDelivr via an import map for the hero scene. Self-hosted fonts. Product video rendered with HyperFrames 0.8.153.

## Users

Mac users on macOS 26 Tahoe with a crowded Dock: developers, designers, students and anyone who keeps many apps, projects and links within reach. They usually arrive from GitHub, a Homebrew search, a forum thread or a link shared by another Mac user. They know the Dock well and are curious, but cautious about utilities that want accounts, subscriptions or broad permissions.

## Product Purpose

Pocketwerk is a free, open-source (MIT) macOS app that puts groups ("pockets") of apps, files, folders and links into the Dock. Each pocket can get its own Dock icon. A click opens a themed popup right above that icon; a second click closes it. The website explains this in seconds, shows how it looks, and gets the visitor to install it (DMG or Homebrew) and past the one-time "Open Anyway" step.

Success: a visitor understands the pocket idea from the first viewport, trusts that it is free, open and private, and finishes the install.

## Positioning

A Dock that holds more than it shows: one Dock icon opens a whole pocket, styled the way you like, with no account, no tracking and the full source on GitHub. Free and MIT licensed.

## Operating Context

- Runs on macOS 26 Tahoe and later, Apple Silicon and Intel.
- Install: DMG from `https://github.com/DigitalIQ/pocketwerk/releases/latest` or `brew install --cask digitaliq/tap/pocketwerk`.
- Not notarized: the first launch needs System Settings > Privacy & Security > "Open Anyway" once.
- UI in English and German.
- Made by DigitalIQ. Source at `https://github.com/DigitalIQ/pocketwerk`.

## Capabilities and Constraints

- Pockets hold apps, files, folders and links. Each pocket can get its own Dock icon. Click opens a themed popup right above the icon, a second click closes it.
- Popup views: grid, list, tiles. Adaptive layout, pages, keyboard (arrows, Return, Space for Quick Look, type to search, ⌘1-9), mouse wheel and trackpad swipes between pockets.
- Open All, Hide All, Quit All per pocket. ⌥-click quits an app. ⌘-click selects several items to open together.
- Folders open inside the popup. Quick Look with Space. Drag and drop in and out.
- Design Studio: Liquid Glass, colors, gradients, photos, the blurred desktop picture, textures and animated backgrounds that react to the pointer; borders, fonts, corner radius; dozens of built-in themes and presets; save your own.
- Dock icon styles: mini grid of the contained apps, fanned stack, folder shape, SF Symbol icon packs, emoji, text, own image.
- Dock profiles: save the whole macOS Dock as a profile and switch with a hotkey, the menu bar, the CLI or a URL; optionally quit or launch apps when switching; custom spacers.
- Global hotkeys per pocket and per profile, no Accessibility permission needed. Menu bar mode. Launch at login.
- Smart pockets: Most Used, Recently Opened, Running Apps.
- On-device assistant (Apple Intelligence, macOS 26+ on supported Macs) that edits a pocket in plain language, with undo. Ships in 1.1; the site calls it "coming in 1.1" while 1.0 is current.
- Private: no account, no tracking, no analytics. Data stays in a JSON file on the Mac. Network only for a daily update check and link favicons.

## Brand Commitments

- Name: Pocketwerk. Maker: DigitalIQ.
- Never name or compare with other Dock apps. No real person's name anywhere.
- No Impressum, no cookie banner, no forms, no cookies, no tracking.
- Voice: plain, concrete, a little warm. Short sentences. Controls say what happens.

## Evidence on Hand

- The product itself (repo, MIT license), the feature list above.
- No screenshots yet: real app screenshots arrive later in `site/assets/shots/`. Until then the page uses authored, clearly illustrative renderings.
- None of: testimonials, ratings, download counts, press quotes, user numbers. Never fabricate them.

## Product Principles

1. The Dock stays the home base: everything starts from a Dock click.
2. Yours to shape: every pocket can look the way its owner wants.
3. Private by construction: no account, nothing leaves the Mac except an update check and favicons.
4. Fast and native: the popup appears within a frame, keyboard reaches everything.
5. Open: free, MIT, source on GitHub.

## Accessibility & Inclusion

WCAG 2.2 AA for the website: contrast, keyboard focus, semantic landmarks, alt texts, reduced motion respected (the 3D hero and the video never animate under `prefers-reduced-motion`), no layout shift, dark and light mode.
