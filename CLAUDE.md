# SKD Downloader — Claude Rules

## What This Is
Free yt-dlp GUI replacing MediaHuman. Electron app, dark cinematic UI, cross-platform Mac + Windows.

## Run
```bash
npm start
```

## Build
```bash
npm run dist:mac   # DMG
npm run dist:win   # EXE
```

## Architecture
| File | Purpose |
|------|---------|
| `main.js` | Electron main process — window, IPC handlers, yt-dlp subprocess spawning, config/history persistence |
| `preload.js` | Context bridge — exposes `window.api` to renderer |
| `src/index.html` | All UI markup — main view, settings modal (7 tabs), history modal, first-launch wizard |
| `src/styles.css` | Dark cinematic theme — CSS variables, DM Sans + JetBrains Mono, electric cyan accent |
| `src/app.js` | Renderer logic — queue management, download control, settings load/save, history |
| `BUGS.md` | Known bugs with root causes and fix notes |

## Config & Data
- Config: `~/Library/Application Support/skd-downloader/config.json`
- History: `~/Library/Application Support/skd-downloader/history.json`

## How yt-dlp Integration Works
1. `get-video-info` → spawns `yt-dlp --dump-json` for title/thumbnail
2. `start-download` → spawns yt-dlp with `--progress-template` for progress parsing
3. Progress parsed from stdout lines, errors from stderr
4. File path captured from `[download] Destination:`, `[Merger] Merging formats into`, `[ExtractAudio] Destination:`

## Current Bugs (see BUGS.md for details)
1. Queue count doesn't fully reset after clearing — late IPC events
2. Download errors — format selection in `buildArgs()` too strict, needs forgiving fallback
3. Needs full end-to-end test

## Design
- **Aesthetic:** Dark cinematic — `#06060b` base, `#00c8ff` cyan accent, glassmorphism
- **Fonts:** DM Sans (UI) + JetBrains Mono (code/mono)
- **Grandpa-friendly:** Big paste field, big download button, advanced options hidden

## GitHub
https://github.com/Bonchaloo/skd-downloader
