# Contributing

Thanks for helping improve SKD Downloader.

## Project Lanes

- Native macOS app: SwiftPM package under `Sources/`, released through the Homebrew cask.
- Legacy Electron app: `main.js`, `preload.js`, `src/`, `lib/`, and Electron build scripts.

Keep changes scoped to the lane you are working on unless the bug crosses both.

## Local Setup

```bash
brew install yt-dlp ffmpeg
npm install
npm test
swift test
```

For the native app:

```bash
npm run native:verify
```

For the legacy Electron app:

```bash
npm start
```

## Pull Requests

- Start from a feature branch.
- Include the user-visible behavior change in the PR description.
- Add or update tests for parser, command-builder, queue, media-library, or release workflow changes.
- Run the relevant checks before requesting review.

Recommended checks:

```bash
npm test
swift test
bash -n script/build_and_run.sh script/release_native.sh
```

For Homebrew cask changes, also run:

```bash
brew audit --cask --strict skd-downloader
brew install --cask --dry-run skd-downloader
```

## Release Changes

Release scripts may touch the local Homebrew tap if it exists at
`/usr/local/Homebrew/Library/Taps/bonchaloo/homebrew-tap`. Review that diff
before committing or pushing tap updates.

Private beta casks are explicit. Use `SKD_RELEASE_PRIVATE_ASSET=1` only when a
release asset intentionally requires `HOMEBREW_GITHUB_API_TOKEN`.
