# SKD Downloader — Known Bugs to Fix

## Bug 1: Queue count doesn't reset after clearing
**Status:** Partially fixed, needs verification
**Problem:** When removing items or clearing queue, the "X items" count in the header sometimes persists.
**Root cause:** Late-arriving IPC events (download-error, download-complete) from killed yt-dlp processes call `renderQueueItem` → `updateStatus()` which re-renders the count after it was cleared.
**Fix applied:** Added guard in `renderQueueItem` to skip if item no longer in queue array. Needs testing.

## Bug 2: Downloads show "Error" status
**Status:** Needs investigation
**Problem:** Downloads fail with Error badge. Need to check yt-dlp stderr output.
**Likely causes:**
- Format selection args might be too strict (e.g., `bestvideo[ext=mp4]` fails when mp4 isn't available)
- Download folder might not exist
- yt-dlp version mismatch with flags used
**To debug:** Open DevTools (Cmd+Option+I) and check Console for error messages.

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

### Key fix needed in format selection (main.js buildArgs):
The format string `bestvideo[ext=mp4]+bestaudio/best[ext=mp4]` is too strict.
Should fallback more gracefully:
```
bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best
```
