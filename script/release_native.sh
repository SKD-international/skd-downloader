#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${SKD_GITHUB_REPO:-SKD-international/skd-downloader}"
VERSION="$(cd "$ROOT_DIR" && node -p "require('./package.json').version")"
TAG="v$VERSION"
ASSET_NAME="SKD.Downloader.Native-$VERSION-mac.zip"
ASSET_PATH="$ROOT_DIR/dist/native/$ASSET_NAME"
NOTES_PATH="$ROOT_DIR/dist/native/release-notes-$VERSION.md"
UPLOAD=0
NOTARIZE=0
VERIFY_DIR=""

cleanup() {
  if [[ -n "$VERIFY_DIR" ]]; then
    rm -rf "$VERIFY_DIR"
  fi
}
trap cleanup EXIT

update_cask_sha() {
  local checksum="$1"
  local cask_paths=(
    "$ROOT_DIR/homebrew/skd-downloader.rb"
    "/usr/local/Homebrew/Library/Taps/bonchaloo/homebrew-tap/Casks/skd-downloader.rb"
  )

  for cask_path in "${cask_paths[@]}"; do
    if [[ -f "$cask_path" ]]; then
      SKD_RELEASE_SHA="$checksum" perl -0pi -e 's/sha256 (?::no_check|"[a-f0-9]{64}")/sha256 "$ENV{SKD_RELEASE_SHA}"/' "$cask_path"
    fi
  done
}

usage() {
  cat <<EOF
usage: $0 [--notarize] [--upload]

Builds and verifies the native macOS release artifact.

Environment:
  SKD_GITHUB_REPO          GitHub repo for release uploads. Default: $REPO
  SKD_CODESIGN_IDENTITY   Codesign identity. Defaults to first Developer ID Application identity.
  SKD_NOTARY_PROFILE      notarytool keychain profile used by --notarize.
  SKD_ALLOW_UNNOTARIZED_UPLOAD=1
                           Allow --upload without --notarize.
  SKD_SKIP_CODESIGN=1     Skip codesigning for local debugging only.

Options:
  --notarize              Submit the zip to Apple notarization, staple the app, and rebuild the zip.
  --upload                Create or update GitHub release $TAG with $ASSET_NAME.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notarize)
      NOTARIZE=1
      shift
      ;;
    --upload)
      UPLOAD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

cd "$ROOT_DIR"

if [[ "$UPLOAD" -eq 1 && "$NOTARIZE" -ne 1 && "${SKD_ALLOW_UNNOTARIZED_UPLOAD:-0}" != "1" ]]; then
  echo "--upload requires --notarize for release builds." >&2
  echo "Set SKD_ALLOW_UNNOTARIZED_UPLOAD=1 only for a deliberate unnotarized beta." >&2
  exit 1
fi

if [[ "$NOTARIZE" -eq 1 && -z "${SKD_NOTARY_PROFILE:-}" ]]; then
  echo "SKD_NOTARY_PROFILE is required for --notarize" >&2
  exit 1
fi

npm test
swift test

PACKAGE_PATH="$(./script/build_and_run.sh --package | tail -n 1)"
if [[ "$PACKAGE_PATH" != "$ASSET_PATH" ]]; then
  echo "unexpected package path: $PACKAGE_PATH" >&2
  echo "expected: $ASSET_PATH" >&2
  exit 1
fi

test -f "$ASSET_PATH"
shasum -a 256 "$ASSET_PATH"

ZIP_CONTENTS="$(zipinfo -1 "$ASSET_PATH")"
if [[ "$ZIP_CONTENTS" != *"SKD Downloader.app/Contents/MacOS/SKDDownloaderNative"* ]]; then
  echo "archive is missing SKDDownloaderNative" >&2
  exit 1
fi
if [[ "$ZIP_CONTENTS" == *"SKD Downloader.app/Contents/Resources/bin/"* ]]; then
  echo "archive must not bundle mutable tool wrappers under Resources/bin" >&2
  exit 1
fi
if [[ "$ZIP_CONTENTS" == *"__MACOSX/"* || "$ZIP_CONTENTS" == *"/._"* || "$ZIP_CONTENTS" == *$'\n''._'* ]]; then
  echo "archive contains macOS sidecar files" >&2
  exit 1
fi

VERIFY_DIR="$(mktemp -d /tmp/skd-downloader-native-verify.XXXXXX)"
ditto -x -k "$ASSET_PATH" "$VERIFY_DIR"
APP_PATH="$VERIFY_DIR/SKD Downloader.app"

test -d "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
SIGNATURE_DETAILS="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)"
if [[ "$SIGNATURE_DETAILS" != *"Authority=Developer ID Application"* ]]; then
  echo "release artifact must be signed with a Developer ID Application certificate" >&2
  exit 1
fi

if [[ "$NOTARIZE" -eq 1 ]]; then
  xcrun notarytool submit "$ASSET_PATH" --keychain-profile "$SKD_NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_PATH"
  xcrun stapler validate "$APP_PATH"

  rm -f "$ASSET_PATH"
  (
    cd "$VERIFY_DIR"
    COPYFILE_DISABLE=1 /usr/bin/zip -qry -X "$ASSET_NAME" "SKD Downloader.app"
  )
  mv "$VERIFY_DIR/$ASSET_NAME" "$ASSET_PATH"
fi

FINAL_SHA="$(shasum -a 256 "$ASSET_PATH" | awk '{ print $1 }')"

if [[ "$NOTARIZE" -eq 1 ]]; then
  update_cask_sha "$FINAL_SHA"
fi

if [[ "$NOTARIZE" -eq 1 ]]; then
  spctl --assess --type execute --verbose=2 "$APP_PATH"
else
  spctl --assess --type execute --verbose=2 "$APP_PATH" || {
    echo "warning: app is signed but not notarized; run with --notarize before --upload" >&2
  }
fi

cat >"$NOTES_PATH" <<EOF
SKD Downloader Native $VERSION

- Native Swift macOS app bundle for Homebrew cask distribution.
- Uses Homebrew-managed yt-dlp/ffmpeg/ffprobe through the cask dependencies.
- Adds resilient cookie handling with fallback when browser cookie access is denied.
- Adds native queue stop controls, format inspection, manual yt-dlp format selection, and copyable command previews.
- Signed with Developer ID$(if [[ "$NOTARIZE" -eq 1 ]]; then echo " and notarized"; else echo ""; fi).

Artifact:
- $ASSET_NAME

SHA-256:
- $FINAL_SHA
EOF

if [[ "$UPLOAD" -eq 1 ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI is required for --upload" >&2
    exit 1
  fi

  if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    gh release upload "$TAG" "$ASSET_PATH" --repo "$REPO" --clobber
  else
    gh release create "$TAG" "$ASSET_PATH" \
      --repo "$REPO" \
      --title "$TAG - Native Homebrew beta" \
      --notes-file "$NOTES_PATH" \
      --prerelease \
      --target "$(git rev-parse HEAD)"
  fi
fi

echo "$NOTES_PATH"
