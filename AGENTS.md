# SKD Downloader — Shared Agent Context

## What This Is
Native macOS downloader built around `yt-dlp`, aimed at replacing MediaHuman with a simpler GUI.

- **GitHub:** `SKD-international/skd-downloader`
- **Release lane:** Swift 6 SwiftPM app, universal `arm64` + `x86_64`, macOS 14+, distributed through the Homebrew cask in `bonchaloo/tap`
- **Version:** single source of truth is the `VERSION` file (read by both scripts)

## Run
```bash
./script/build_and_run.sh --verify
```

## Build
```bash
./script/build_and_run.sh --build
./script/build_and_run.sh --package
./script/release_native.sh
```

## Test
```bash
swift test
bash -n script/build_and_run.sh script/release_native.sh
```

## Architecture
| Path | Purpose |
|------|---------|
| `Package.swift` | Swift package manifest |
| `VERSION` | App version used by build and release scripts |
| `Sources/DownloaderCore/` | Engine, yt-dlp command builder and output parser, managed toolchain (yt-dlp + Deno installer), failure classifier, presets, media probe, media library models |
| `Sources/DownloaderUI/` | SwiftUI app state, queue, media library, player, settings |
| `Sources/SKDDownloaderNativeApp/` | App entry point |
| `script/build_and_run.sh` | Build, package, launch, and local verification |
| `script/release_native.sh` | Release packaging, signing, notarization, upload, cask metadata |
| `homebrew/skd-downloader.rb` | Homebrew cask |
| `tests/DownloaderCoreTests/`, `tests/DownloaderUITests/` | Swift Testing suites |

## Config & Data
- `~/Library/Application Support/skd-downloader-native/` holds `config.json`, `workbench.json`, `history.json`, `queue/queue.json`, `library/`, and `tools/bin/` (app-managed yt-dlp and Deno)

## Download Flow
```text
Paste URL
  -> YTDLPEngine.fetchInfo (yt-dlp --dump-json --flat-playlist)
  -> queue items with a configuration snapshot

Start queue
  -> YTDLPCommandBuilder.build
  -> YTDLPEngine.startDownload streams stdout/stderr lines
  -> YTDLPOutputParser reads progress and destination
  -> history + media library entry on success
```

## Toolchain
- `ManagedToolchain` installs yt-dlp (`yt-dlp_macos`, universal) and Deno (per-arch zip) from official GitHub releases, verifying SHA-256 against the published manifest. Never bundle or fetch tools from anywhere else.
- `BinaryLocator` searches the managed `tools/bin` first, then Homebrew, `/usr/local/bin`, `~/.local/bin`, `~/.deno/bin`, `/opt/local/bin`, `/usr/bin`, and the login `PATH`.
- Every yt-dlp invocation passes `--ffmpeg-location` and `--js-runtimes deno:<dir>` explicitly; GUI launches have a bare `PATH`.
- `EngineHealth` marks yt-dlp `outdated` when behind the latest release or older than 60 days. Deno is a required tool.
- `DownloadFailure.classify` maps yt-dlp output to a title plus a remedy (`updateYTDLP`, `installDeno`, `installFFmpeg`, `useBrowserCookies`, `checkURL`); UI surfaces the remedy as a button.
- ffmpeg stays external: the FFmpeg project publishes no official macOS binary.

## Gotchas
- Public casks should use the stable GitHub release download URL and load without `HOMEBREW_GITHUB_API_TOKEN`.
- Private beta casks require explicit `SKD_RELEASE_PRIVATE_ASSET=1` release mode.
- `yt-dlp` path selection and cookie handling are the most failure-prone parts of the app.
- `ffmpeg` is required for merge and audio extraction flows.
- Browser cookie reads can hit macOS app-data privacy; the engine retries once without browser cookies when the cookie DB is unreadable.
