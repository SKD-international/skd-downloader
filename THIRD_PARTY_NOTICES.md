# Third-Party Notices

SKD Downloader uses external tools and platforms. This repository does not
vendor the Homebrew-provided `yt-dlp`, `ffmpeg`, or `ffprobe` binaries for the
native macOS cask.

## Runtime Tools

- `yt-dlp`: installed by Homebrew for media extraction.
- `ffmpeg` and `ffprobe`: installed by Homebrew for merging, probing, and
  conversion workflows.

Review each upstream project for its current license terms and security
advisories before redistributing binaries.

## Build And Release Tools

- Homebrew casks are used for native macOS installation.
- Apple Developer ID signing and notarization are used for public macOS
  distribution.
- GitHub Releases are used for release artifacts.

