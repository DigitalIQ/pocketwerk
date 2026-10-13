# Product video (HyperFrames)

`index.html` is a HyperFrames 0.8.153 composition, 1280 x 800, 16.5 s, 30 fps. It uses the site's brand mark and font and three screenshots from `site/assets/shots/`.

Render (Node 22+, FFmpeg installed):

```sh
sh site/video/render.sh
```

The script mirrors the shared assets into `site/video/assets/` (git-ignored; HyperFrames only reads files inside its project folder), lints, renders `pocketwerk.mp4` and `pocketwerk.webm`, and writes the poster frame (5 s, the open pocket) to `site/assets/img/video-poster.webp`. Afterwards set `data-video-ready="true"` on `#film` in `site/index.html`; the page then swaps the poster for the video (muted, loops while visible, never autoplays under reduced motion).

A test render with the placeholder screenshots produced a 458 KB MP4.
