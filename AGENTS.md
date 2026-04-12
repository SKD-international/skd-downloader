# SKD Downloader — Shared Agent Context

## What This Is
Electron downloader app built around `yt-dlp`, aimed at replacing MediaHuman with a simpler GUI for Mac and Windows.

- **GitHub:** `Bonchaloo/skd-downloader`
- **Primary platforms:** macOS + Windows

## Current State
- Bundled downloader path is fixed; packaged builds include `bin/yt-dlp`.
- Bundled media wrappers are present for `ffmpeg` and `ffprobe`.
- Cookie handling is normalized through `lib/yt-dlp-config.js`.
- On this Mac, the app defaults to Chrome cookies so signed-in YouTube/Premium downloads work.
- The next meaningful validation is a real GUI smoke test inside the Electron app window.

## Run
```bash
npm install
npm start
```

## Build
```bash
npm run dist:mac
npm run dist:win
```

## Test
```bash
npm test
```

## Architecture
| File | Purpose |
|------|---------|
| `main.js` | Electron main process, IPC handlers, downloader subprocesses, config/history persistence |
| `preload.js` | Context bridge exposing `window.api` to the renderer |
| `src/index.html` | App markup, settings modal, history modal, first-launch wizard |
| `src/styles.css` | Visual system and layout |
| `src/app.js` | Renderer logic: queue, history, settings, download flow |
| `lib/yt-dlp-config.js` | Shared cookie/default normalization for yt-dlp config |
| `bin/` | Bundled `yt-dlp`, `ffmpeg`, and `ffprobe` wrappers/binaries |
| `tests/` | Automated tests for config/bootstrap logic |

## Config & Data
- macOS config: `~/Library/Application Support/skd-downloader/config.json`
- macOS history: `~/Library/Application Support/skd-downloader/history.json`
- Windows app data root: `%APPDATA%/skd-downloader/`

## Download Flow
```text
Paste URL
  -> `get-video-info`
  -> spawn yt-dlp metadata query
  -> renderer receives title/thumbnail/formats

Start download
  -> `start-download`
  -> spawn yt-dlp with normalized config + wrapper paths
  -> parse progress from stdout
  -> emit progress events
  -> emit final path on completion
```

## Gotchas
- `yt-dlp` path selection and cookie handling are the most failure-prone parts of the app.
- `ffmpeg` is required for merge/extract flows.
- Packaged builds must include `bin/**/*` and `lib/**/*`.
- Late IPC events can still affect queue state if the renderer clears a job while subprocess output is in flight.
