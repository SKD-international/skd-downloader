# Third-Party Notices

SKD Downloader uses external tools and platforms. This repository vendors no
binaries.

## Runtime Tools

- `yt-dlp` (Unlicense): downloaded by the app from the official
  `yt-dlp/yt-dlp` GitHub release (`yt-dlp_macos`) and verified against the
  release's `SHA2-256SUMS`.
- `deno` (MIT): downloaded by the app from the official `denoland/deno` GitHub
  release and verified against the asset's `.sha256sum`.
- `ffmpeg` and `ffprobe`: installed by Homebrew for merging, probing, and
  conversion workflows.

Review each upstream project for its current license terms and security
advisories before redistributing binaries.

## Build And Release Tools

- Homebrew casks are used for native macOS installation.
- Apple Developer ID signing and notarization are used for public macOS
  distribution.
- GitHub Releases are used for release artifacts.

