#!/bin/sh
# Install or update Yabar: curl -fsSL https://raw.githubusercontent.com/mpdreamz/yabar/main/install.sh | sh
#
# Downloads the latest release (or YABAR_VERSION=0.1.0), checks its sha256, and puts Yabar.app in /Applications, or
# ~/Applications when /Applications is not writable (YABAR_APP_DIR overrides both; YABAR_DOWNLOAD_BASE downloads from
# elsewhere). Downloaded with curl, the app
# carries no quarantine flag, so it opens without a Gatekeeper prompt.
set -eu

repo="mpdreamz/yabar"
asset="Yabar-arm64.zip"

fail() {
  echo "yabar: $*" >&2
  exit 1
}

[ "$(uname -s)" = "Darwin" ] || fail "Yabar is a macOS app."
[ "$(uname -m)" = "arm64" ] || fail "Yabar builds for Apple Silicon only, for now."

if [ -n "${YABAR_DOWNLOAD_BASE:-}" ]; then
  # A mirror, or a local server when testing this script.
  base="$YABAR_DOWNLOAD_BASE"
elif [ -n "${YABAR_VERSION:-}" ]; then
  base="https://github.com/$repo/releases/download/v${YABAR_VERSION#v}"
else
  base="https://github.com/$repo/releases/latest/download"
fi

if [ -n "${YABAR_APP_DIR:-}" ]; then
  dir="$YABAR_APP_DIR"
elif [ -w /Applications ]; then
  dir="/Applications"
else
  dir="$HOME/Applications"
fi
mkdir -p "$dir"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "yabar: downloading $base/$asset"
curl -fsSL -o "$tmp/$asset" "$base/$asset" || fail "download failed (is there a release yet?)"
curl -fsSL -o "$tmp/$asset.sha256" "$base/$asset.sha256" || fail "checksum download failed"
(cd "$tmp" && shasum -a 256 -c "$asset.sha256" >/dev/null) || fail "checksum does not match; nothing installed"

ditto -x -k "$tmp/$asset" "$tmp/app"
[ -x "$tmp/app/Yabar.app/Contents/MacOS/Yabar" ] || fail "the download holds no Yabar.app; nothing installed"

if pgrep -xq Yabar; then
  echo "yabar: Yabar is running; quit it to finish, or it keeps the old version until it restarts."
fi
rm -rf "$dir/Yabar.app"
mv "$tmp/app/Yabar.app" "$dir/Yabar.app"

version="$(plutil -extract CFBundleShortVersionString raw "$dir/Yabar.app/Contents/Info.plist" 2>/dev/null || echo "?")"
echo "yabar: Yabar $version is in $dir. Open it with: open -a Yabar"
