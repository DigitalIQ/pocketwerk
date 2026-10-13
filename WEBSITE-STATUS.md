# Website status

Where the Pocketwerk website stands. Process: skill `website-bauen`, run fully autonomously by the website agent. Every point where the skill asks a person to decide was decided by the agent; the reasons are below.

Status: ✅ done · 🔄 running · ⬜ open · ⏭ skipped

| Phase | Name | Status | Date |
|---|---|---|---|
| 0 | Setup | ✅ | 2026-10-13 |
| 1 | Foundation (brand, logo, app icon, PRODUCT.md) | ✅ | 2026-10-13 |
| 2 | Research | ✅ (manual, no DataForSEO) | 2026-10-13 |
| 3 | Texts | ✅ | 2026-10-13 |
| 4 | Design direction | ✅ | 2026-10-13 |
| 5 | Build | 🔄 | |
| 6 | Review and polish | ⬜ | |
| 7 | Launch (technical SEO and GEO only) | ⬜ | |
| 8 | Afterwards | ⏭ skipped by brief | |

## Where things are

- `site/`: the deployable static site (GitHub Pages, base path `/pocketwerk/`, all URLs relative).
- `site/assets/brand/`: logo, app icon, `AppIcon.iconset/`, favicons.
- `site/video/`: HyperFrames composition for the product video.
- `website/`: process files that are not deployed: `PRODUCT.md`, `texte.md`, `recherche/`, `referenzen/`, `logo/` (concept rounds), `design/richtung.md` (direction contract), `DESIGN.md`.

## Starting point

- Existing website or brand: none. New brand, name fixed: Pocketwerk, by DigitalIQ.
- Main goal of the page: visitors understand the pocket idea and install the app (DMG or Homebrew), including the one-time "Open Anyway".
- Hosting: GitHub Pages via `.github/workflows/pages.yml`, `https://digitaliq.github.io/pocketwerk/`. No deploy by this agent.
- Tools: impeccable ✅ (see note) · Playwright ✅ (venv in `.tmp/venv`, system Chrome) · DataForSEO ⏭ (paid, skipped) · Hosting MCP ⏭ · Form target ⏭ (no forms)

Setup notes:
- `npx impeccable@4.5.2 install --project` failed twice (bundle download timed out at impeccable.style). Fallback: copied the impeccable 4.1.1 skill that another local project already had into `.claude/skills/impeccable/` of this worktree (local only, not committed).
- Playwright 1.48.0 in `.tmp/venv`, using the installed Google Chrome (`channel="chrome"`), so no browser download.
- Fonts and helpers via `npm install` inside `.tmp/npm` (Archivo variable 5.3.0, opentype.js). fontTools, brotli, uharfbuzz in the venv.

## Brand

| Role | Value |
|---|---|
| Main colour (board green) | #1B5546, deep #164A3E, lit #24735F |
| Accent (pocket orange) | #FF6B2C; as text on light #B83A08, on dark #FF8A55 |
| Light surface | #E9EFEB ground, #F4F6F3 paper |
| Text | #0F1B17 ink on light, #F4F6F3 on board and dark |
| Headings | Archivo variable, width 118 to 125, weight 800 |
| Body | Archivo variable, width 100, weight 400 to 500 |
| Code | system monospace (SF Mono on Macs), only for the Homebrew command |
| Traits | perforated board texture, orange pocket hanging on pegs, three app tiles peeking out, one even line weight in drawings |

Logo: mark (pegboard plate, orange pocket, three tiles: paper, yellow, mint) plus the wordmark "Pocketwerk" in Archivo expanded 780 weight, converted to outlines with HarfBuzz shaping (kerning applied). App icon: 1024 canvas, plate 852 px (scale 0.832), corner radius 0.2237 x 852, soft shadow inside the canvas; 16 and 32 px use a simplified drawing without holes and stitching. `iconutil -c icns` on the iconset was tested and works.

## Decisions (all autonomous, 2026-10-13)

1. Phase 0: process files live in `website/` at the worktree root so they are not deployed with `site/`; this status file sits at the worktree root as the brief allows.
2. Phase 1, name: fixed by the brief. Logo round 1: six mono concepts (`website/logo/entwuerfe/konzepte.png`). Chosen: concept 1, the hanging pocket, because it carries both halves of the name (pocket, and "werk" as the workshop wall) and stays legible at 16 px. Weak and dropped: Dock with speech bubble (generic grid), fanned stack from a slot (reads as a toaster), shadow-board outline (reads as a shopping bag), compartment (abstract). The stitched denim pocket was the clearest "pocket" but pulls toward fashion, not tools.
3. Phase 1, round 2: five colour variants (`website/logo/entwuerfe/runde2.png`). Chosen: variant a (bin with three fanned tiles), with the stitch line of variant c added. Variant c (soft pouch) read as a smiling face at small sizes.
4. Phase 1, PRODUCT.md: written from the brief only. impeccable's init interview was not run because the brief requires autonomy.
5. Phase 2, references: no favourite sites from a person; references taken from the product's world (workshop pegboard, the macOS Dock, equipment plates). See `website/referenzen/notizen.md`.
6. Phase 2, palette: board green plus pocket orange, chosen to stand apart from blue-dominant Mac app icons and from the dark-glow look of the category. Cream, terracotta and neon-on-black avoided on purpose.
7. Phase 2, research: manual search, no volumes. Competitors anonymised in the notes because the brief forbids naming other Dock apps.
8. Phase 3, language: English only for now (global audience on GitHub). German page is a later option.
9. Phase 3, no invented claims: no version number, no URL-scheme syntax, no "contributions welcome", no counts or ratings. Example themes and profiles on the page are labelled as examples.
10. Phase 4: concept seed rolled direction 3 of 7, the workshop pegboard. Two declined challengers raised it (one even line weight; one saturated field owning whole regions, monumental numerals only for ⌘1-9). No image generation, so code-led. Contract in `website/design/richtung.md` and as an HTML comment at the top of `site/index.html`.

## Open questions for the maker

1. Are issues and pull requests welcome? Not claimed until confirmed.
2. Add a `LICENSE` file at the repo root; the footer links the repository meanwhile.
3. Public syntax of the URL scheme and the CLI for profile switching.
4. Version number for the download button.

## Update routine after launch

1. Change the page and `website/texte.md` together.
2. No build step: `site/` is served as is.
3. Upload: push to `main`, the Pages workflow deploys `site/`.
4. Cache: GitHub Pages, about 10 minutes.
5. Check live.
