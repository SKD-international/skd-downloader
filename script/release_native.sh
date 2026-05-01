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
PREFLIGHT=0
SETUP_PROFILE=0
VERIFY_DIR=""
NOTARY_PROFILE="${SKD_NOTARY_PROFILE:-}"
NOTARY_APPLE_ID="${SKD_NOTARY_APPLE_ID:-}"
NOTARY_TEAM_ID="${SKD_NOTARY_TEAM_ID:-}"
NOTARY_PASSWORD="${SKD_NOTARY_PASSWORD:-}"
NOTARY_SYNC="${SKD_NOTARY_SYNC:-0}"

cleanup() {
  if [[ -n "$VERIFY_DIR" ]]; then
    rm -rf "$VERIFY_DIR"
  fi
}
trap cleanup EXIT

update_cask_metadata() {
  local checksum="$1"
  local cask_paths=(
    "$ROOT_DIR/homebrew/skd-downloader.rb"
    "/usr/local/Homebrew/Library/Taps/bonchaloo/homebrew-tap/Casks/skd-downloader.rb"
  )

  for cask_path in "${cask_paths[@]}"; do
    if [[ -f "$cask_path" ]]; then
      SKD_RELEASE_VERSION="$VERSION" SKD_RELEASE_SHA="$checksum" perl -0pi -e '
        s/version "[^"]+"/version "$ENV{SKD_RELEASE_VERSION}"/;
        s/sha256 (?::no_check|"[a-f0-9]{64}")/sha256 "$ENV{SKD_RELEASE_SHA}"/;
      ' "$cask_path"
    fi
  done
}

usage() {
  cat <<EOF
usage: $0 [--notarize] [--upload]
       $0 --preflight
       SKD_NOTARY_PROFILE=<profile> \\
         SKD_NOTARY_APPLE_ID=<apple-id> \\
         SKD_NOTARY_TEAM_ID=<team-id> \\
         $0 --setup-profile

Builds and verifies the native macOS release artifact.

Environment:
  SKD_GITHUB_REPO          GitHub repo for release uploads. Default: $REPO
  SKD_CODESIGN_IDENTITY   Codesign identity. Defaults to first Developer ID Application identity.
  SKD_NOTARY_PROFILE      notarytool keychain profile used by --notarize.
  SKD_NOTARY_APPLE_ID     Apple ID used by --setup-profile.
  SKD_NOTARY_TEAM_ID      Developer Team ID used by --setup-profile.
  SKD_NOTARY_PASSWORD     Optional app-specific password. Omit it for
                           notarytool's secure prompt in an interactive shell.
  SKD_NOTARY_SYNC=1       Store the notarytool profile in iCloud Keychain.
  SKD_ALLOW_UNNOTARIZED_UPLOAD=1
                           Allow --upload without --notarize.
  SKD_SKIP_CODESIGN=1     Skip codesigning for local debugging only.

Options:
  --notarize              Submit the zip to Apple notarization, staple the app, and rebuild the zip.
  --upload                Create or update GitHub release $TAG with $ASSET_NAME.
  --preflight             Validate signing/notarization tools and keychain profile.
  --setup-profile         Create and validate a notarytool keychain profile.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_tool() {
  local label="$1"
  local executable="$2"

  if ! command -v "$executable" >/dev/null 2>&1; then
    die "$label not found on PATH."
  fi
}

require_xcrun_tool() {
  local tool="$1"

  if ! xcrun --find "$tool" >/dev/null 2>&1; then
    die "xcrun could not find '$tool'. Select full Xcode with sudo xcode-select -s /Applications/Xcode.app/Contents/Developer."
  fi
}

require_full_xcode() {
  local developer_dir=""

  developer_dir="$(xcode-select -p 2>/dev/null || true)"
  if [[ -z "$developer_dir" ]]; then
    die "xcode-select has no active developer directory."
  fi

  if [[ "$developer_dir" != *"/Xcode.app/Contents/Developer" ]]; then
    die "full Xcode is required, but xcode-select points to '$developer_dir'."
  fi

  echo "  Xcode:      $developer_dir"
}

require_notary_profile() {
  if [[ -z "$NOTARY_PROFILE" ]]; then
    echo "ERROR: SKD_NOTARY_PROFILE is required." >&2
    echo "" >&2
    usage >&2
    exit 2
  fi
}

require_notary_setup_inputs() {
  require_notary_profile

  if [[ -z "$NOTARY_APPLE_ID" ]]; then
    die "SKD_NOTARY_APPLE_ID is required for --setup-profile."
  fi

  if [[ -z "$NOTARY_TEAM_ID" ]]; then
    die "SKD_NOTARY_TEAM_ID is required for --setup-profile."
  fi
}

run_notary_preflight() {
  require_notary_profile
  require_tool "codesign" "codesign"
  require_tool "spctl" "spctl"
  require_tool "xcode-select" "xcode-select"
  require_tool "xcrun" "xcrun"
  require_full_xcode
  require_xcrun_tool "notarytool"
  require_xcrun_tool "stapler"

  echo "  Profile:    $NOTARY_PROFILE"
  if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" --output-format json --no-progress >/dev/null; then
    echo "" >&2
    echo "ERROR: notarytool profile '$NOTARY_PROFILE' is not usable." >&2
    echo "       Create it with '$0 --setup-profile', then rerun." >&2
    exit 1
  fi
  echo "  notarytool: profile accepted"
}

run_notary_profile_setup() {
  require_notary_setup_inputs
  require_tool "xcode-select" "xcode-select"
  require_tool "xcrun" "xcrun"
  require_full_xcode
  require_xcrun_tool "notarytool"

  local command=(
    xcrun notarytool store-credentials "$NOTARY_PROFILE"
    --apple-id "$NOTARY_APPLE_ID"
    --team-id "$NOTARY_TEAM_ID"
    --validate
  )

  if [[ "$NOTARY_SYNC" == "1" ]]; then
    command+=(--sync)
  fi

  if [[ -n "$NOTARY_PASSWORD" ]]; then
    command+=(--password "$NOTARY_PASSWORD")
  else
    if [[ ! -t 0 ]]; then
      die "SKD_NOTARY_PASSWORD is required for non-interactive --setup-profile. Run from a terminal for notarytool's secure prompt, or provide an app-specific password through the environment."
    fi
    echo "  Password:   not set; notarytool will prompt securely."
  fi

  echo "Creating notarytool keychain profile:"
  echo "  Profile:    $NOTARY_PROFILE"
  echo "  Apple ID:   $NOTARY_APPLE_ID"
  echo "  Team ID:    $NOTARY_TEAM_ID"
  if [[ "$NOTARY_SYNC" == "1" ]]; then
    echo "  Keychain:   iCloud sync"
  else
    echo "  Keychain:   default local keychain"
  fi

  "${command[@]}"

  echo ""
  echo "Validating saved notarytool profile..."
  run_notary_preflight
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
    --preflight)
      PREFLIGHT=1
      shift
      ;;
    --setup-profile)
      SETUP_PROFILE=1
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

if [[ "$PREFLIGHT" -eq 1 && $((UPLOAD + NOTARIZE + SETUP_PROFILE)) -ne 0 ]]; then
  echo "--preflight must be run by itself." >&2
  exit 2
fi

if [[ "$SETUP_PROFILE" -eq 1 && $((UPLOAD + NOTARIZE + PREFLIGHT)) -ne 0 ]]; then
  echo "--setup-profile must be run by itself." >&2
  exit 2
fi

if [[ "$PREFLIGHT" -eq 1 ]]; then
  echo "Checking SKD Downloader notarization prerequisites..."
  run_notary_preflight
  echo "Notarization preflight passed."
  exit 0
fi

if [[ "$SETUP_PROFILE" -eq 1 ]]; then
  run_notary_profile_setup
  echo "Notary profile setup passed."
  exit 0
fi

if [[ "$UPLOAD" -eq 1 && "$NOTARIZE" -ne 1 && "${SKD_ALLOW_UNNOTARIZED_UPLOAD:-0}" != "1" ]]; then
  echo "--upload requires --notarize for release builds." >&2
  echo "Set SKD_ALLOW_UNNOTARIZED_UPLOAD=1 only for a deliberate unnotarized beta." >&2
  exit 1
fi

if [[ "$NOTARIZE" -eq 1 && -z "${SKD_NOTARY_PROFILE:-}" ]]; then
  echo "SKD_NOTARY_PROFILE is required for --notarize" >&2
  exit 1
fi

if [[ "$NOTARIZE" -eq 1 ]]; then
  echo "Checking SKD Downloader notarization prerequisites..."
  run_notary_preflight
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

update_cask_metadata "$FINAL_SHA"

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
- Adds native queue stop controls, format inspection, manual yt-dlp format selection, copyable command previews, and per-job activity logs.
- Adds download archive duplicate protection, info/description sidecar metadata, embedded chapters, and fragment worker tuning.
- Adds an Engine Health panel for yt-dlp, ffmpeg, ffprobe, and Homebrew diagnostics.
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
