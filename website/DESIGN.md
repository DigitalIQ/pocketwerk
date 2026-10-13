---
name: Pocketwerk
description: Workshop pegboard for the Mac Dock. Board green fields, orange pockets, paper tiles.
colors:
  board: "#1b5546"
  board-deep: "#164a3e"
  board-lit: "#24735f"
  hole: "#0c3a30"
  orange: "#ff6b2c"
  orange-hover: "#ff8148"
  orange-ink: "#b83a08"
  ink: "#0f1b17"
  paper: "#f4f6f3"
  yellow: "#ffd15c"
  mint: "#9fdcc4"
  ground-light: "#e9efeb"
  ground-dark: "#0d1512"
  surface-dark: "#16211d"
  muted-light: "#3c5049"
  muted-dark: "#a7bab1"
  on-board-muted: "#c9ddd4"
typography:
  display:
    fontFamily: "Archivo, Archivo Fallback, system-ui, sans-serif"
    fontSize: "clamp(2.9rem, 1.4rem + 5.2vw, 5.6rem)"
    fontWeight: 800
    lineHeight: 0.98
    letterSpacing: "-0.035em"
  headline:
    fontFamily: "Archivo, Archivo Fallback, system-ui, sans-serif"
    fontSize: "clamp(2.05rem, 1.25rem + 2.7vw, 3.6rem)"
    fontWeight: 800
    lineHeight: 1.03
    letterSpacing: "-0.03em"
  title:
    fontFamily: "Archivo, Archivo Fallback, system-ui, sans-serif"
    fontSize: "1.22rem"
    fontWeight: 750
    lineHeight: 1.2
    letterSpacing: "-0.01em"
  body:
    fontFamily: "Archivo, Archivo Fallback, system-ui, sans-serif"
    fontSize: "1.0625rem"
    fontWeight: 420
    lineHeight: 1.55
    letterSpacing: "normal"
  code:
    fontFamily: "ui-monospace, SF Mono, Menlo, monospace"
    fontSize: "0.86rem"
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: "normal"
rounded:
  tile: "13px"
  control: "14px"
  panel: "22px"
  stage: "28px"
  pill: "999px"
spacing:
  gutter: "clamp(16px, 4vw, 48px)"
  section: "clamp(72px, 10vw, 140px)"
  hole: "22px"
components:
  button-primary:
    backgroundColor: "{colors.orange}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "0 24px"
    height: "52px"
  button-primary-hover:
    backgroundColor: "{colors.orange-hover}"
  button-paper:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "11px"
    height: "40px"
  swatch:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
    height: "44px"
  dock-icon:
    rounded: "{rounded.tile}"
    size: "50px"
---

# Design System: Pocketwerk

Recorded from the shipped site (`site/index.html`, `site/assets/css/site.css`, `site/assets/js/hero.js`) on 2026-10-13. Written in-thread (no subagents in this run), following impeccable's documenter spec.

## Overview

A workshop wall for the Dock. The page alternates painted pegboard fields (board green with a 22 px hole grid) with calm light or dark ground. Orange is reserved for pockets and the primary action. The product's own surfaces (Dock, popups) are the only glass on the page. Display type is Archivo stretched wide and heavy, like lettering on equipment plates.

## Colors

### Primary
- **Board green** `#1b5546`: whole-section fields (hero, profiles, footer), the app icon plate. Deep `#164a3e` for the demo desk and video frame; lit `#24735f` for Dock icon plates and step markers; hole `#0c3a30`.

### Secondary
- **Pocket orange** `#ff6b2c`: the pockets in the hero, the primary button, the ⌘ keycap, the final install step. Text in orange uses `#b83a08` on light and `#ff8a55` on dark.

### Tertiary
- **Tile yellow** `#ffd15c` and **mint** `#9fdcc4`: only inside illustrations and example items.

### Neutral
- Ink `#0f1b17`, paper `#f4f6f3`, light ground `#e9efeb`, dark ground `#0d1512`, dark surface `#16211d`. Muted text `#3c5049` (light) and `#a7bab1` (dark); on board `#c9ddd4`.

### Named Rules
- **One field, one accent.** A section is either board green, ground, or ink. Orange never fills a section.
- **Orange means pocket or action.** Nothing decorative is orange.

## Typography

One variable family, Archivo (weight 100 to 900, width 62 to 125 %), self-hosted as a 80 KB Latin subset, with a metric-matched Arial fallback to keep the swap from shifting layout. Code uses the system monospace with ligatures off.

### Hierarchy
- Display (H1): width 122 %, weight 800, line height 0.98, tracking -0.035em.
- Headline (H2): width 116 %, weight 800, line height 1.03.
- Title (H3, list heads): width 106 to 110 %, weight 700 to 760.
- Body: width 100 %, weight 420, 1.0625rem, line height 1.55, measure up to 62ch.

### Named Rules
- **Width carries the voice.** Emphasis comes from stretch and weight of the same family, never a second display face.

## Layout

Max width 1200 px, gutter `clamp(16px, 4vw, 48px)`, section rhythm `clamp(72px, 10vw, 140px)`. Every section uses a different layout family: full-bleed hero with a 3D stage, an overlapping video frame, split copy and live demo, full-width studio stage with a swatch rail, split profiles on the board, a keycap row, a two-column statement on ink, a vertical install track with the icon beside it, a split FAQ. All multi-column grids collapse to `minmax(0, 1fr)` below 860 px.

## Elevation & Depth

Depth comes from the physical world: soft tinted drop shadows (`0 22px 44px -22px rgba(11,45,37,.5)`), never black. Glass (`backdrop-filter: blur(22px) saturate(1.4)`) only on the Dock and popup components. Keycaps get an inset bottom edge, not an offset shadow. The hero is real 3D (three.js 0.186.1): shadows cast by pockets onto the board.

## Shapes

Tiles and Dock icons follow the macOS icon radius (about 22 % of the edge). Controls 11 to 14 px, panels 20 to 22 px, stages 26 to 28 px, swatches and chips fully round. All illustration lines use one even 2 to 2.4 px stroke with round caps.

## Components

### Buttons
Primary: orange fill, ink label, 52 px tall, 14 px radius, lifts 1 px on hover, presses 1 px on active. Secondary: paper fill on board, 40 px. Copy buttons sit inside the Homebrew field and turn mint with a check after copying.

### Chips
Swatch buttons: pill, 44 px, colour chip plus label, pressed state shown by a 2 px ink ring.

### Cards / Containers
No generic cards. Containers are objects from the world: the pocket popup, the desk (board panel), the icon shelf, the dashed "slot" for a feature not yet hung on the wall.

### Navigation
Single-line bar inside the hero, links in muted paper, Download as a paper button. Below 860 px only the brand and Download remain.

### Pocket popup (signature component)
Grid (3 columns), list and tiles views; looks Glass, Board, Signal, Night, Paper and Pointer swap fill, border, radius and label width. Opens with the product's own motion: 200 ms fade with an 8 px rise from the Dock icon.

## Do's and Don'ts

### Do:
- Use the hole grid only on board fields, aligned to 22 px.
- Label example data as examples.
- Keep every animation off under `prefers-reduced-motion`.

### Don't:
- Name other Dock apps.
- Put eyebrows or kickers above headings.
- Add glass to anything that isn't the product.
- Use orange as decoration.

Not canonized: the `🧰` emoji inside the "Emoji" Dock-icon sample is content (it shows that feature), not an icon convention.
