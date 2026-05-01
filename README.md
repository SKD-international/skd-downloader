# SKD Downloader

A free, open-source, premium-looking yt-dlp GUI for Mac and Windows. Drop-in replacement for MediaHuman YouTube Downloader.

## Features

- **1000+ sites** — YouTube, TikTok, Instagram, Reddit, Twitter, Vimeo, and more
- **Video & Audio** — Download video or extract audio with one toggle
- **Quality control** — Pick resolution (4K to 360p) or bitrate (320 to 128 Kbps)
- **Playlist support** — Auto-detects and downloads entire playlists
- **Batch downloads** — Paste multiple URLs at once
- **SponsorBlock** — Auto-remove sponsor segments
- **Subtitles** — Download and embed subtitles
- **Download history** — Searchable log of past downloads
- **Dark theme** — Premium dark cinematic UI
- **Cross-platform** — Mac and Windows

## Install

### macOS (Homebrew)

```bash
brew tap bonchaloo/tap
brew install --cask skd-downloader
```

### From source

```bash
git clone https://github.com/SKD-international/skd-downloader.git
cd skd-downloader
npm install
npm start
```

### Prerequisites

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) must be installed: `brew install yt-dlp`
- [ffmpeg](https://ffmpeg.org/) recommended for format conversion: `brew install ffmpeg`

## Build

```bash
# Mac
npm run dist:mac

# Windows
npm run dist:win
```

## Native macOS Release

The Swift native app is packaged separately for the Homebrew cask:

```bash
npm run native:release
```

This runs the Node and Swift test suites, builds `SKD Downloader.app`, signs it with the first available Developer ID Application certificate, creates `dist/native/SKD.Downloader.Native-<version>-mac.zip`, and writes release notes under `dist/native/`. The Homebrew cask installs `yt-dlp` and `ffmpeg`; the native app resolves those Homebrew-managed tools directly.

To upload the native artifact to GitHub:

```bash
export SKD_NOTARY_PROFILE=skd-downloader-notary
npm run native:notary:preflight
npm run native:release:upload
```

If the notarytool profile does not exist yet, create it from an interactive
terminal so macOS can prompt securely for the app-specific Apple ID password:

```bash
export SKD_NOTARY_PROFILE=<notarytool-keychain-profile>
export SKD_NOTARY_APPLE_ID=<apple-id>
export SKD_NOTARY_TEAM_ID=<developer-team-id>
npm run native:notary:setup
```

## License

MIT
