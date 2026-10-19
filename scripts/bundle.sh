#!/usr/bin/env bash
# Assemble build/Yabar.app from the SwiftPM products: the app binary, the `yabar` command line tool (Contents/Helpers,
# linked onto the PATH by the cask), Sparkle (Contents/Frameworks, the updater), Info.plist, then an ad-hoc signature.
# It packages what `swift build` made; it does not build (mise run build does both).
#
#   scripts/bundle.sh debug|release
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
config="${1:-debug}"
products="$(cd "$root" && swift build -c "$config" --show-bin-path)"
app="${BUILD_DIR:-$root/build}/Yabar.app"
# YABAR_VERSION is set by the release workflow from the release's tag; local builds say dev. The build number is the
# commit count, which only grows on main (pull requests are squash-merged): the updater compares it to tell a newer
# release. YabarCommit names the commit, so any build can be traced back.
version="${YABAR_VERSION:-0.1.0-dev}"
build="$(git -C "$root" rev-list --count HEAD 2>/dev/null || echo 0)"
commit="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo dev)"

mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers" "$app/Contents/Resources" "$app/Contents/Frameworks"
cp "$products/YabarApp" "$app/Contents/MacOS/Yabar"
cp "$products/yabar" "$app/Contents/Helpers/yabar"
# Sparkle, symlinks kept. Its XPC services are for sandboxed apps; Yabar is not sandboxed, so they go.
rm -rf "$app/Contents/Frameworks/Sparkle.framework"
ditto "$products/Sparkle.framework" "$app/Contents/Frameworks/Sparkle.framework"
rm -rf "$app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" \
  "$app/Contents/Frameworks/Sparkle.framework/XPCServices"
if ! otool -l "$app/Contents/MacOS/Yabar" | grep -q "@executable_path/../Frameworks"; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$app/Contents/MacOS/Yabar"
fi
sed -e "s/__VERSION__/$version/g" -e "s/__BUILD__/$build/g" -e "s/__COMMIT__/$commit/g" \
  "$root/Resources/Info.plist" >"$app/Contents/Info.plist"
codesign --force --sign - "$app/Contents/Helpers/yabar"
codesign --force --deep --sign - "$app/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$app"
# The helper must be the command line tool, never the app: skhd runs it on every key press.
if ! "$app/Contents/Helpers/yabar" --help 2>/dev/null | grep -q '^usage: yabar'; then
  echo "bundle: Contents/Helpers/yabar is not the yabar command line tool" >&2
  exit 1
fi
echo "bundle: $app ($version, build $build, $commit)"
