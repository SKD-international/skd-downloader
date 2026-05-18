# Open Source Readiness

This document tracks the checks needed before making
`SKD-international/skd-downloader` public.

## Current Decision

The recommended public lane is open source under MIT, with public GitHub
release assets for the native Homebrew cask.

Keep these private:

- Apple Developer ID certificates
- notarytool credentials
- GitHub release tokens
- any private beta release assets

## Repository Hygiene

Required public-facing files:

- `LICENSE`
- `CONTRIBUTING.md`
- `SECURITY.md`
- `THIRD_PARTY_NOTICES.md`
- `.github/workflows/ci.yml`
- issue templates
- pull request template

## Pre-Public Checks

Run before changing repository visibility:

```bash
rg -n --hidden -g '!node_modules/**' -g '!dist/**' -g '!.build/**' -g '!.git/**' \
  '(AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|-----BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----|password\s*[:=]|secret\s*[:=]|token\s*[:=]|api[_-]?key\s*[:=])' .

git rev-list --all | xargs git grep -nI -E \
  '(AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|-----BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----|password\s*[:=]|secret\s*[:=]|token\s*[:=]|api[_-]?key\s*[:=])' -- . ':!package-lock.json'
```

Then verify:

```bash
npm test
swift test
bash -n script/build_and_run.sh script/release_native.sh
brew audit --cask --strict skd-downloader
```

## GitHub Visibility

After the public-readiness branch is merged:

```bash
gh repo edit SKD-international/skd-downloader --visibility public
gh repo view SKD-international/skd-downloader --json visibility,isPrivate,url
```

Do not flip visibility until the public-readiness changes are on the default
branch, because making a private repository public exposes the current default
branch and the repository history.

