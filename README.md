# SKD Downloader

[![CI](https://github.com/SKD-international/skd-downloader/actions/workflows/ci.yml/badge.svg)](https://github.com/SKD-international/skd-downloader/actions/workflows/ci.yml)

A native macOS downloader powered by yt-dlp. The Homebrew release is the main app for Mac users.

For a simple native Mac walkthrough, see the [large-print Mac guide](docs/native-macos-large-print-guide.md).

## Features

- **1000+ sites** — YouTube, TikTok, Instagram, Reddit, Twitter, Vimeo, and more
- **Video & Audio** — Download video or extract audio with one toggle
- **Quality control** — Pick resolution (4K to 360p) or bitrate (320 to 128 Kbps)
- **Playlist support** — Auto-detects and downloads entire playlists
- **Batch downloads** — Paste multiple URLs at once
- **SponsorBlock** — Auto-remove sponsor segments
- **Subtitles** — Download and embed subtitles
- **Download history** — Searchable log of past downloads
- **Native media library** — Browse, filter, and play downloaded media on macOS
- **Dark theme** — Premium dark cinematic UI
- **Legacy cross-platform source** — Older Mac/Windows source remains available for developers

## Install

### macOS (Homebrew)

```bash
brew tap bonchaloo/tap
brew install --cask skd-downloader
```

The native Homebrew beta targets macOS 14 Sonoma and newer, including macOS 15
Sequoia. Release packages are built as universal `arm64` + `x86_64` app bundles
so the same cask can run on Apple Silicon and Intel Macs.

Private beta casks are an explicit release mode. If a release asset must stay
private, generate the cask with `SKD_RELEASE_PRIVATE_ASSET=1` and install with
`HOMEBREW_GITHUB_API_TOKEN` set. The normal cask uses the public GitHub release
download URL so `brew audit --cask --strict skd-downloader` can load it without
private credentials.

### From source

Native macOS app:

```bash
git clone https://github.com/SKD-international/skd-downloader.git
cd skd-downloader
brew install yt-dlp ffmpeg
swift test
npm run native:verify
```

Older cross-platform app source:

```bash
git clone https://github.com/SKD-international/skd-downloader.git
cd skd-downloader
npm install
npm start
```

### Prerequisites

- Homebrew cask installs [yt-dlp](https://github.com/yt-dlp/yt-dlp) and [ffmpeg](https://ffmpeg.org/) automatically.
- Source builds should install them first: `brew install yt-dlp ffmpeg`

## Build

Native macOS:

```bash
npm run native:build
npm run native:package
```

Older cross-platform build:

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

This runs the Node and Swift test suites, builds a universal `SKD Downloader.app`, signs it with the first available Developer ID Application certificate, creates `dist/native/SKD.Downloader.Native-<version>-mac.zip`, and writes release notes under `dist/native/`. The Homebrew cask installs `yt-dlp` and `ffmpeg`; the native app resolves those Homebrew-managed tools directly.

To upload the native artifact to GitHub:

```bash
export SKD_NOTARY_PROFILE=skd-downloader-notary
npm run native:notary:preflight
npm run native:release:upload
brew audit --cask --strict skd-downloader
```

If the notarytool profile does not exist yet, create it from an interactive
terminal so macOS can prompt securely for the app-specific Apple ID password:

```bash
export SKD_NOTARY_PROFILE=<notarytool-keychain-profile>
export SKD_NOTARY_APPLE_ID=<apple-id>
export SKD_NOTARY_TEAM_ID=<developer-team-id>
npm run native:notary:setup
```

Private beta release assets can still be published when the repository or asset
must remain private:

```bash
export SKD_NOTARY_PROFILE=skd-downloader-notary
SKD_RELEASE_PRIVATE_ASSET=1 npm run native:release:upload
```

See `docs/homebrew-release.md` for the full upload, tap, audit, and rollback
workflow.

## Open Source

SKD Downloader is released under the MIT License. See:

- `LICENSE` for license terms
- `CONTRIBUTING.md` for local setup and pull request expectations
- `SECURITY.md` for vulnerability reporting
- `THIRD_PARTY_NOTICES.md` for runtime tool notes

## License

MIT
