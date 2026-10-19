#!/usr/bin/env bash
# Write the cask for a published release to mpdreamz/homebrew-tap: packaging/homebrew/yabar.rb with the version and
# the sha256 the release carries. Run by the release workflow after publishing, and by the tap workflow to redo it.
#
#   TAP_TOKEN=… scripts/bump-tap.sh 0.1.0
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
version="${1:?usage: scripts/bump-tap.sh <version>}"
version="${version#v}"
token="${TAP_TOKEN:?set TAP_TOKEN (the HOMEBREW_TAP_TOKEN secret)}"
release="https://github.com/mpdreamz/yabar/releases/download/v$version"

# The published checksum, so the cask matches what users download.
sha="$(curl -fsSL "$release/Yabar-arm64.zip.sha256" | awk '{print $1}')"
[[ "$sha" =~ ^[0-9a-f]{64}$ ]] || { echo "bump-tap: no sha256 published for v$version" >&2; exit 1; }

tap="$(mktemp -d)"
trap 'rm -rf "$tap"' EXIT
git clone --quiet --depth 1 "https://x-access-token:$token@github.com/mpdreamz/homebrew-tap.git" "$tap"
mkdir -p "$tap/Casks"
# The template's header is about the template; the tap's copy says where it comes from instead.
{
  echo "# Written by yabar's release workflow from packaging/homebrew/yabar.rb in https://github.com/mpdreamz/yabar;"
  echo "# change it there, not here."
  sed -e '/^# TEMPLATE:/,/^[^#]/{/^#/d;}' -e "s/__VERSION__/$version/" -e "s/__SHA256__/$sha/" \
    "$root/packaging/homebrew/yabar.rb"
} >"$tap/Casks/yabar.rb"
rm -f "$tap/Casks/.gitkeep"

cd "$tap"
git add -A
if git diff --cached --quiet; then
  echo "bump-tap: the tap already has yabar $version"
  exit 0
fi
git -c user.name="yabar release" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit --quiet -m "yabar $version"
git push --quiet origin HEAD:main
echo "bump-tap: mpdreamz/homebrew-tap now installs yabar $version ($sha)"
