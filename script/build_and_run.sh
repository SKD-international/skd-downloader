#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PROCESS_NAME="SKDDownloaderNative"
APP_DISPLAY_NAME="SKD Downloader"
BUNDLE_ID="com.skd.downloader.native"
MIN_SYSTEM_VERSION="14.0"
DEFAULT_GITHUB_REPO="SKD-international/skd-downloader"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist/native"
VERSION="${SKD_DOWNLOADER_VERSION:-$(cd "$ROOT_DIR" && node -p "require('./package.json').version" 2>/dev/null || echo "0.0.0")}"
STAGING_DIR="${SKD_NATIVE_STAGING_DIR:-/tmp/skd-downloader-native-$VERSION}"
APP_BUNDLE="$STAGING_DIR/$APP_DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$PROCESS_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="assets/icon.icns"
ZIP_NAME="SKD.Downloader.Native-$VERSION-mac.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

pkill -x "$PROCESS_NAME" >/dev/null 2>&1 || true

swift build --product "$PROCESS_NAME"
BUILD_BINARY="$(swift build --show-bin-path)/$PROCESS_NAME"

mkdir -p "$DIST_DIR" "$STAGING_DIR"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -f "$ROOT_DIR/$ICON_SOURCE" ]]; then
  cp "$ROOT_DIR/$ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"
  ICON_KEYS=$'  <key>CFBundleIconFile</key>\n  <string>AppIcon</string>'
else
  ICON_KEYS=""
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$PROCESS_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
$ICON_KEYS
</dict>
</plist>
PLIST

detect_codesign_identity() {
  if [[ -n "${SKD_CODESIGN_IDENTITY:-}" ]]; then
    echo "$SKD_CODESIGN_IDENTITY"
    return
  fi

  if command -v security >/dev/null 2>&1; then
    security find-identity -v -p codesigning 2>/dev/null \
      | awk -F'"' '/Developer ID Application/ { print $2; exit }'
  fi
}

sign_app() {
  if [[ "${SKD_SKIP_CODESIGN:-0}" == "1" ]]; then
    return
  fi

  if ! command -v codesign >/dev/null 2>&1; then
    return
  fi

  local identity
  identity="$(detect_codesign_identity)"

  for attempt in 1 2 3; do
    xattr -c "$APP_BUNDLE" 2>/dev/null || true
    xattr -cr "$APP_BUNDLE" 2>/dev/null || true
    xattr -d com.apple.FinderInfo "$APP_BUNDLE" 2>/dev/null || true
    xattr -d "com.apple.fileprovider.fpfs#P" "$APP_BUNDLE" 2>/dev/null || true

    if [[ -n "$identity" ]]; then
      if /usr/bin/codesign --force --deep --options runtime --timestamp --sign "$identity" "$APP_BUNDLE"; then
        break
      fi
    else
      if /usr/bin/codesign --force --deep --sign - "$APP_BUNDLE"; then
        break
      fi
    fi

    if [[ "$attempt" == "3" ]]; then
      return 1
    fi

    sleep 0.5
  done

  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" >/dev/null
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

resolve_tool() {
  local name="$1"

  for candidate in "/opt/homebrew/bin/$name" "/usr/local/bin/$name" "/usr/bin/$name"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return
    fi
  done

  return 1
}

verify_required_tools() {
  local yt_dlp ffmpeg ffprobe
  yt_dlp="$(resolve_tool yt-dlp)"
  ffmpeg="$(resolve_tool ffmpeg)"
  ffprobe="$(resolve_tool ffprobe)"

  "$yt_dlp" --version >/dev/null
  "$ffmpeg" -version >/dev/null 2>&1
  "$ffprobe" -version >/dev/null 2>&1
}

package_app() {
  rm -f "$ZIP_PATH"
  (
    cd "$STAGING_DIR"
    COPYFILE_DISABLE=1 /usr/bin/zip -qry -X "$ZIP_PATH" "$APP_DISPLAY_NAME.app"
  )
  echo "$ZIP_PATH"
}

print_release_metadata() {
  local checksum
  checksum="$(shasum -a 256 "$ZIP_PATH" | awk '{ print $1 }')"

  cat <<EOF
version=$VERSION
tag=v$VERSION
repo=${SKD_GITHUB_REPO:-$DEFAULT_GITHUB_REPO}
asset=$ZIP_PATH
sha256=$checksum
EOF
}

sign_app

case "$MODE" in
  --build|build)
    verify_required_tools
    echo "$APP_BUNDLE"
    ;;
  --package|package)
    verify_required_tools
    package_app
    ;;
  --metadata|metadata)
    verify_required_tools
    package_app >/dev/null
    print_release_metadata
    ;;
  run)
    verify_required_tools
    open_app
    ;;
  --debug|debug)
    verify_required_tools
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    verify_required_tools
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$PROCESS_NAME\""
    ;;
  --telemetry|telemetry)
    verify_required_tools
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    verify_required_tools
    open_app
    sleep 1
    pgrep -x "$PROCESS_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--build|--package|--metadata|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
