# SKD Downloader Feature Brainstorm - 2026-05-01

## Context

SKD Downloader is a native macOS `yt-dlp` workbench focused on queueing, inspecting, and saving video/audio downloads without using a terminal. Current native coverage already includes queue controls, format selection, cookies, proxy, subtitles, SponsorBlock, thumbnails, tags, history, command preview, and per-job activity logs.

Sources checked:

- Official `yt-dlp` README: https://github.com/yt-dlp/yt-dlp/blob/master/README.md
- Official `yt-dlp` post-processing guide: https://yt-dlp-yt-dlp.mintlify.app/guides/post-processing
- MediaHuman YouTube Downloader: https://www.mediahuman.com/youtube-downloader/
- MediaHuman UI notes: https://www.mediahuman.com/howto/user-interface-in-detail5.html
- MediaHuman changelog: https://www.mediahuman.com/youtube-downloader/changelog.html

## Ideas

### Product Manager Perspective

1. Persistent download archive to skip previously downloaded playlist/channel items across app launches.
2. Channel and playlist tracking for automatic new-upload checks.
3. Clipboard watcher that detects copied media URLs and offers a one-click queue action.
4. Per-site presets for cookies, output folder, format, and subtitle defaults.
5. Release-safe engine health panel showing `yt-dlp`, `ffmpeg`, and Homebrew dependency state.

### Product Designer Perspective

1. A compact "Smart Mode" preset strip for common jobs: Video, Music, Archive, Captions.
2. Per-job diagnostics panel that shows command, activity log, output path, and retry cause together.
3. Queue filtering by status, source, mode, and completion date.
4. Batch edit sheet for changing mode, format, folder, and options on selected queue items.
5. Onboarding checklist that confirms permissions, browser cookies, and output folders.

### Software Engineer Perspective

1. Expose official `yt-dlp --download-archive` for duplicate protection.
2. Expose official `yt-dlp -N/--concurrent-fragments` for segmented HLS/DASH acceleration.
3. Add sidecar metadata toggles for `--write-info-json` and `--write-description`.
4. Add chapter controls for `--embed-chapters` and later `--split-chapters`.
5. Add a safe update/doctor flow for Homebrew-managed `yt-dlp` and `ffmpeg`.

## Prioritized Top 5

1. Persistent download archive
   - Reason: high value for playlist/channel users; low implementation risk; official `yt-dlp` behavior.
   - Assumption to test: users want duplicate protection across app restarts more than only filesystem overwrite protection.

2. Concurrent fragment downloads
   - Reason: tiny implementation surface; improves large segmented downloads without changing normal downloads.
   - Assumption to test: 4-8 workers improves enough without causing throttling for common sources.

3. Sidecar metadata files
   - Reason: useful for archive workflows, debugging, and future import/retry flows.
   - Assumption to test: archive-focused users want `.info.json` and description files near media files.

4. Clipboard watcher
   - Reason: strong native desktop convenience feature and competitor parity.
   - Assumption to test: automatic prompts are helpful rather than noisy.

5. Playlist/channel tracking
   - Reason: strong differentiator, but requires persistence, scheduling, and careful UX.
   - Assumption to test: users want subscriptions inside this app rather than using external RSS/automation.

## Implemented In This Pass

- Persistent download archive toggle and path.
- Sidecar metadata toggles for info JSON and description files.
- Embedded chapters toggle for video downloads.
- Fragment worker setting for `yt-dlp -N`.
