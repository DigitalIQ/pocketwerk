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
| 5 | Build | ✅ | 2026-10-13 |
| 6 | Review and polish | ✅ (in-thread review, no tweak panel) | 2026-10-13 |
| 7 | Launch (technical SEO and GEO only, no deploy) | ✅ | 2026-10-13 |
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

11. Phase 5, stack: static HTML, CSS, JS. three.js 0.186.1 via import map from jsDelivr, loaded only on the first pointer, touch, scroll, wheel or key event, never under reduced motion or Save-Data; render-on-demand loop that sleeps when the pockets settle, pauses off screen, pixel ratio capped at 2. Poster images are renders of the same scene, so the switch to live 3D is seamless.
12. Phase 5, live demos instead of fake screenshots: the example pocket (grid, list, tiles, keyboard, ⌘-click, ⌥-click, type to search, Dock icon toggles it), the Design Studio preview with six example looks, the Dock profile switcher. All labelled as examples.
13. Phase 5, video: HyperFrames composition with three placeholder screenshots; until real screenshots arrive the page shows the title-card frame as poster. `site/video/render.sh` renders MP4, WebM and a new poster (frame at 5 s).
14. Phase 6, review: the impeccable finish reviewer and documenter ran in-thread (subagents were not allowed in this run). Verdict after one fix round: ship. Fixed on the way: horizontal overflow on mobile (grid minmax), keycap offset shadows replaced by inset edges, a CSS blur filter that cost 490 ms TBT replaced by a 2 KB pre-blurred image, dock row semantics (list without list items). The detector ran in degraded regex mode (parser modules missing); its one finding (a "grid-line background") is the FAQ plus icon, a false positive.
15. Phase 6, tweak panel skipped: it exists for a person to drag values; no person in this run.
16. Phase 7: meta, canonical, Open Graph image (1200 x 630), `robots.txt` (all crawlers incl. AI crawlers), `sitemap.xml`, `llms.txt`, JSON-LD `SoftwareApplication` plus `FAQPage`. No legal texts, no cookie banner: the site sets no cookies, loads no trackers and has no forms; the only third-party request is three.js from jsDelivr after the first interaction. Note: on a GitHub Pages project site, crawlers read robots.txt at the domain root, so `site/robots.txt` mainly documents intent.

## Measurements (local, `python3 -m http.server`, Lighthouse 12.8.2)

| Run | Performance | Accessibility | Best practices | SEO | LCP | TBT | CLS |
|---|---|---|---|---|---|---|---|
| Mobile | 99 | 100 | 100 | 100 | 2.2 s | 0 ms | 0 |
| Desktop | 100 | 100 | 100 | 100 | 0.5 s | 0 ms | 0 |

GitHub Pages serves with compression and a CDN, so live numbers should be equal or better. Not re-measured live (no deploy).

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
