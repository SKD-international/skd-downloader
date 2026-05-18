# Native Homebrew Release Workflow

This workflow is for the native Swift macOS app. The old Electron app still has
its own `npm start`, `dist:mac`, and `dist:win` path, but it is not the current
Homebrew artifact.

## Recommendation

Use a public or open source release lane for the Homebrew cask. Homebrew casks
are easiest to audit, install, and trust when `url` points at a stable public
release asset and the cask can load without credentials.

Keep only these private:

- Apple signing and notarization credentials
- GitHub release tokens
- private beta release assets, when needed
- internal release automation notes

If SKD Downloader must stay closed for now, use the private beta mode below and
expect token-based installs. For a broader public launch, publish the repo or at
least the release assets before calling the cask stable.

## Prerequisites

```bash
brew --version
xcrun --find notarytool
xcrun --find stapler
security find-identity -v -p codesigning
```

Validate the notarization profile before a release:

```bash
export SKD_NOTARY_PROFILE=skd-downloader-notary
npm run native:notary:preflight
```

Create the profile if it is missing:

```bash
export SKD_NOTARY_PROFILE=skd-downloader-notary
export SKD_NOTARY_APPLE_ID=<apple-id>
export SKD_NOTARY_TEAM_ID=<developer-team-id>
npm run native:notary:setup
```

## Public Release

```bash
export SKD_NOTARY_PROFILE=skd-downloader-notary
npm run native:release:upload
brew audit --cask --strict skd-downloader
brew install --cask --dry-run skd-downloader
```

The release script updates:

- `homebrew/skd-downloader.rb`
- `/usr/local/Homebrew/Library/Taps/bonchaloo/homebrew-tap/Casks/skd-downloader.rb`, when that local tap exists

The public cask should look like:

```ruby
url "https://github.com/SKD-international/skd-downloader/releases/download/v#{version}/SKD.Downloader.Native-#{version}-mac.zip"
depends_on formula: "yt-dlp"
depends_on formula: "ffmpeg"
```

Do not clear quarantine in the cask as a substitute for signing and
notarization. The release artifact should be signed and notarized before a
public upload.

## Private Beta Release

Use this only when the GitHub release asset intentionally remains private:

```bash
export SKD_NOTARY_PROFILE=skd-downloader-notary
SKD_RELEASE_PRIVATE_ASSET=1 npm run native:release:upload
```

Users of the private cask need a token:

```bash
brew tap bonchaloo/tap
export HOMEBREW_GITHUB_API_TOKEN="$(gh auth token)"
brew install --cask skd-downloader
```

Private beta mode rewrites the cask to GitHub's release asset API URL. Do not
use that as the default public install path.

## Tap Management

Inspect the tap before committing:

```bash
git -C /usr/local/Homebrew/Library/Taps/bonchaloo/homebrew-tap status --short --branch
git -C /usr/local/Homebrew/Library/Taps/bonchaloo/homebrew-tap diff -- Casks/skd-downloader.rb
```

Commit and push only when the release artifact, checksum, and cask audit are
fresh.

## Rollback

To return the cask to an earlier release, restore the older `version`, `sha256`,
and `url` from tap history:

```bash
git -C /usr/local/Homebrew/Library/Taps/bonchaloo/homebrew-tap log -- Casks/skd-downloader.rb
git -C /usr/local/Homebrew/Library/Taps/bonchaloo/homebrew-tap show <commit>:Casks/skd-downloader.rb
```

Then reinstall:

```bash
brew uninstall --cask skd-downloader
brew install --cask skd-downloader
```

## Verification Bar

Before calling a Homebrew release done, run:

```bash
npm test
swift test
bash -n script/build_and_run.sh script/release_native.sh
brew audit --cask --strict skd-downloader
```

For Sequoia compatibility, keep the package target at macOS 14 or newer and
verify a macOS 15 build:

```bash
swift build -c debug \
  --scratch-path .build/skd-sequoia-x86_64-debug \
  --triple x86_64-apple-macosx15.0 \
  --product SKDDownloaderNative
```

