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
brew trust --cask bonchaloo/tap/skd-downloader
brew install --cask skd-downloader
```

The cask installs the Homebrew `yt-dlp` and `ffmpeg` formula dependencies. The native app resolves those Homebrew-managed tools through absolute `/opt/homebrew` and `/usr/local` paths so GUI launches work even when macOS starts the app with a minimal `PATH`.

Current Homebrew refuses casks from third-party taps until they are trusted, which is
why `brew trust --cask bonchaloo/tap/skd-downloader` runs before the install.

In Settings → Network, `Cookies Browser` can read Firefox, Chrome, or Safari cookies
for sites that need a signed-in session. macOS may ask to let SKD Downloader access
data from other apps; if cookies cannot be read, the download retries without them.

If the project is shipping a deliberately private beta artifact, use the private
cask mode from the release script and set `HOMEBREW_GITHUB_API_TOKEN` before
installing. Public casks should not require a token just to audit or load.

The native cask supports macOS 14 Sonoma and newer, including macOS 15 Sequoia.
Release artifacts are universal `arm64` + `x86_64` app bundles for Apple
Silicon and Intel Macs.

## Intel Macs (Homebrew Tier 3)

Homebrew stopped building bottles for macOS on Intel in September 2026, so the
cask's `yt-dlp` and `ffmpeg` formula dependencies try to compile from source.
On Intel Macs install the notarized app zip from the GitHub release directly and
use the official standalone tools, which the app finds in `/usr/local/bin`:

```bash
curl -fsSL -o /usr/local/bin/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos
curl -fsSL -o /tmp/deno.zip https://github.com/denoland/deno/releases/latest/download/deno-x86_64-apple-darwin.zip
ditto -xk /tmp/deno.zip /usr/local/bin
chmod +x /usr/local/bin/yt-dlp /usr/local/bin/deno
```

Verify each download against the release checksums (`SHA2-256SUMS` for yt-dlp,
`.sha256sum` for Deno). YouTube needs a current `yt-dlp` plus the Deno JavaScript
runtime; older builds fail with `HTTP Error 403`. Existing Homebrew `ffmpeg` keeps
working.

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
