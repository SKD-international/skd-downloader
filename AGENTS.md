# SKD Downloader — Shared Agent Context

## What This Is
Downloader app built around `yt-dlp`, aimed at replacing MediaHuman with a simpler GUI.

- **GitHub:** `SKD-international/skd-downloader`
- **Current release lane:** native Swift macOS app distributed through Homebrew
- **Legacy lane:** Electron app for the older cross-platform Mac/Windows build

## Current State
- Native Swift sources live under `Sources/DownloaderCore` and `Sources/DownloaderUI`.
- Native release packages are universal `arm64` + `x86_64`, macOS 14+ app bundles.
- The Homebrew cask installs `yt-dlp` and `ffmpeg`; the app uses Homebrew-managed tools instead of bundling mutable binaries.
- Legacy Electron sources remain in `main.js`, `preload.js`, `src/`, `lib/`, and `bin/`.
- Cookie handling is still normalized through `lib/yt-dlp-config.js` for the Electron lane.

## Run
Native macOS:
```bash
npm run native:verify
```

Legacy Electron:
```bash
npm install
npm start
```

## Build
Native macOS:
```bash
npm run native:build
npm run native:package
npm run native:release
```

Legacy Electron:
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
| `Package.swift` | Native Swift package manifest |
| `Sources/DownloaderCore/` | Native downloader engine, presets, probing, media library models |
| `Sources/DownloaderUI/` | Native SwiftUI app state, queue, media library, player, settings |
| `script/build_and_run.sh` | Native app build, package, launch, and local verification |
| `script/release_native.sh` | Native release packaging, signing, notarization, upload, and cask metadata |
| `homebrew/skd-downloader.rb` | Homebrew cask for the native app |
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
- Do not confuse the Homebrew cask with the legacy Electron package. The current cask is for the native Swift app.
- Public casks should use the stable GitHub release download URL and load without `HOMEBREW_GITHUB_API_TOKEN`.
- Private beta casks require explicit `SKD_RELEASE_PRIVATE_ASSET=1` release mode.
- `yt-dlp` path selection and cookie handling are the most failure-prone parts of the app.
- `ffmpeg` is required for merge/extract flows.
- Packaged builds must include `bin/**/*` and `lib/**/*`.
- Late IPC events can still affect queue state if the renderer clears a job while subprocess output is in flight.
