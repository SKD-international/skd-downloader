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
cd /Users/bonchaloo/Desktop/Projects/skd-downloader
./script/build_and_run.sh --verify
```

Build the uploadable zip and release notes:

```bash
npm run native:release
```

If the app still shows `Binary Missing`, open Settings and use the setup section to confirm the detected binary path.
