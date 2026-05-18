# SKD Downloader Native Setup

`SKD Downloader` depends on two command-line tools:

- `yt-dlp`
- `ffmpeg`

## Fast Path

If Homebrew is already installed:

```bash
brew install yt-dlp ffmpeg
```

Then verify:

```bash
yt-dlp --version
ffmpeg -version
```

## If Homebrew Is Missing

Install Homebrew first:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then run:

```bash
brew install yt-dlp ffmpeg
```

## Homebrew Cask

The native macOS app is distributed through the SKD tap:

```bash
brew tap bonchaloo/tap
brew install --cask skd-downloader
```

The cask installs the Homebrew `yt-dlp` and `ffmpeg` formula dependencies. The native app resolves those Homebrew-managed tools through absolute `/opt/homebrew` and `/usr/local` paths so GUI launches work even when macOS starts the app with a minimal `PATH`.

If the project is shipping a deliberately private beta artifact, use the private
cask mode from the release script and set `HOMEBREW_GITHUB_API_TOKEN` before
installing. Public casks should not require a token just to audit or load.

The native cask supports macOS 14 Sonoma and newer, including macOS 15 Sequoia.
Release artifacts are universal `arm64` + `x86_64` app bundles for Apple
Silicon and Intel Macs.

## What The App Expects

- `yt-dlp` must be available through Homebrew
- `ffmpeg` and `ffprobe` should be available through Homebrew for merge and probe workflows
- the app writes config and history under:

```text
~/Library/Application Support/skd-downloader-native/
```

## Native App Verification

Run the staged macOS bundle:

```bash
cd /path/to/skd-downloader
./script/build_and_run.sh --verify
```

Build the uploadable zip and release notes:

```bash
npm run native:release
```

If the app still shows `Binary Missing`, open Settings and use the setup section to confirm the detected binary path.

## Release And Tap Checks

```bash
export SKD_NOTARY_PROFILE=skd-downloader-notary
npm run native:notary:preflight
npm run native:release:upload
brew audit --cask --strict skd-downloader
brew install --cask --dry-run skd-downloader
```

The public cask should point at the normal GitHub release download URL. Use
`SKD_RELEASE_PRIVATE_ASSET=1` only for a closed beta asset that intentionally
requires `HOMEBREW_GITHUB_API_TOKEN`.
