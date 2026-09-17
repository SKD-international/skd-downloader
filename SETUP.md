# SKD Downloader Native Setup

`SKD Downloader` needs three command-line tools:

- `yt-dlp` — installed and updated by the app itself
- `deno` — JavaScript runtime YouTube now requires; installed by the app itself
- `ffmpeg` (with `ffprobe`) — install with Homebrew

## Fast Path

```bash
brew tap bonchaloo/tap
brew trust --cask bonchaloo/tap/skd-downloader
brew install --cask skd-downloader
```

Open the app. The Engine panel on the Overview shows every tool with an
**Install** or **Update** button. yt-dlp and Deno are downloaded from their
official GitHub releases, verified against the published SHA-256 sums, and kept
in `~/Library/Application Support/skd-downloader-native/tools/bin`. They take
precedence over any Homebrew or `/usr/local/bin` copies, so an in-app update is
always what the app runs.

`Downloads → Update yt-dlp` (⌘⇧U) refreshes yt-dlp at any time. The engine
check flags a yt-dlp build that is behind the latest release or older than
60 days, because YouTube changes break stale builds (typically `HTTP Error 403`).

Current Homebrew refuses casks from third-party taps until they are trusted,
which is why `brew trust` runs before the install.

## ffmpeg

Apple Silicon: the cask installs the `ffmpeg` formula.

Intel Macs: Homebrew stopped shipping Intel bottles in September 2026, so the
cask does not depend on `ffmpeg` there. Either keep an existing ffmpeg in
`/usr/local/bin`, or run `brew install ffmpeg` and let it build from source.
The app also looks in `~/.local/bin`, `/opt/local/bin` (MacPorts), and your
login `PATH`.

If Homebrew is missing entirely:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install ffmpeg
```

## Without Homebrew

Download `SKD.Downloader.Native-<version>-mac.zip` from the GitHub release,
unzip, and move `SKD Downloader.app` to `/Applications`. The bundle is signed
and notarized. Install yt-dlp and Deno from inside the app; provide ffmpeg
yourself.

## Cookies

In Settings → General → Network, `Cookies Browser` can read Firefox, Chrome, or
Safari cookies for sites that need a signed-in session. macOS may ask to let
SKD Downloader access data from other apps; if cookies cannot be read, the
download retries without them. Failures that need a login offer a
**Use Browser Cookies** button.

## Text Size

Settings → General → Accessibility → Text Size scales every label in the app
from 100% to 175%. ⌘+ / ⌘− / ⌘0 change it from anywhere.

## Where Things Live

```text
~/Library/Application Support/skd-downloader-native/
  config.json  workbench.json  history.json  queue/  library/  tools/bin/
```

## Native App Verification

```bash
cd /path/to/skd-downloader
./script/build_and_run.sh --verify
```

Build the uploadable zip and release notes:

```bash
./script/release_native.sh
```

## Release And Tap Checks

```bash
export SKD_NOTARY_PROFILE=skd-downloader-notary
./script/release_native.sh --preflight
./script/release_native.sh --notarize --upload
brew audit --cask --strict skd-downloader
brew install --cask --dry-run skd-downloader
```

The public cask should point at the normal GitHub release download URL. Use
`SKD_RELEASE_PRIVATE_ASSET=1` only for a closed beta asset that intentionally
requires `HOMEBREW_GITHUB_API_TOKEN`.
