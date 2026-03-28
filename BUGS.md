# SKD Downloader — Known Bugs to Fix

## Bug 1: Queue count doesn't reset after clearing
**Status:** Fixed
**Fix:** Guards in all IPC listeners (`onDownloadProgress`, `onDownloadComplete`, `onDownloadError`, `onDownloadDestination`) check `queue.find()` and return early if item was removed. `renderQueueItem` has a duplicate guard. Late IPC events from killed yt-dlp processes are silently ignored.

## Bug 2: Downloads show "Error" / open as WebM
**Status:** Fixed
**Problem:** Format selection filtered by `ext=mp4` which fails when sites don't serve mp4 streams. Fell through to webm/AV1 which macOS can't play.
**Fix:** Replaced ext-based filtering with yt-dlp `-S "vcodec:h264,acodec:aac"` format sorting. Prefers H.264+AAC (universal playback) and `--merge-output-format mp4` ensures mp4 container. Also improved error reporting — stderr is buffered and actual error shown in UI badge.

## Bug 3: Open folder button
**Status:** Fixed
**Fix:** Changed to event delegation, capture file path from merger/extract output too.

## Bug 4: Can't edit URL input
**Status:** Fixed
**Fix:** Added `user-select: text` for inputs, added Edit menu for Cmd+V/C/X/A.

## Bug 5: Download folder path
**Status:** Fixed
**Fix:** Resolve `~` to real home dir, auto-create directory.

---

## Architecture Notes for Continuation

### Project: `~/yt-dlp-gui/`
### GitHub: https://github.com/Bonchaloo/skd-downloader
### Tech: Electron + HTML/CSS/JS + yt-dlp subprocess

### Files:
- `main.js` — Electron main process, IPC handlers, yt-dlp spawning
- `preload.js` — Context bridge (api object)
- `src/index.html` — UI markup (main view, settings modal, history modal, first-launch wizard)
- `src/styles.css` — Dark cinematic theme
- `src/app.js` — Renderer logic (queue management, settings, history)

### Config: `~/Library/Application Support/skd-downloader/config.json`
### History: `~/Library/Application Support/skd-downloader/history.json`

### How yt-dlp integration works:
1. `get-video-info`: spawns `yt-dlp --dump-json` to get title/thumbnail
2. `start-download`: spawns yt-dlp with `--progress-template` for progress parsing
3. Progress parsed from stdout, errors from stderr
4. File path captured from `[download] Destination:` and `[Merger] Merging formats into` output

### Format selection (main.js buildArgs):
Uses yt-dlp `-S` (format sorting) instead of ext-based filtering:
```
-f "bestvideo+bestaudio/best" -S "vcodec:h264,acodec:aac" --merge-output-format mp4
```
Prefers H.264+AAC for universal playback. Falls back to other codecs if unavailable.
