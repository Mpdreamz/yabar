#!/usr/bin/env bash
# Draw every picture in docs/images, and the app icon, from fixed fixtures (Sources/YabarApp/Shots.swift): a desktop
# drawn in code with Yabar's real menu bar image, indicators, launcher and settings over it. Nothing is read from this
# Mac's screen or windows. The settings the pictures show are passed on the command line (NSArgumentDomain), so they
# don't depend on this Mac's own.
#
#   mise run shots
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
app="${BUILD_DIR:-$root/build}/Yabar.app"
images="$root/docs/images"

rm -rf "$images/shots" "$images/png" "$images/Yabar.iconset"
YABAR_SHOTS="$images" "$app/Contents/MacOS/Yabar" \
  -indicatorStyle tabs -indicatorPlacement top -showLabels 1 -showAttention 1 -hideEmptySpaces 0 -itemPerDisplay 0
iconutil -c icns "$images/Yabar.iconset" -o "$root/Resources/Yabar.icns"
rm -rf "$images/Yabar.iconset"
echo "shots: $(du -sh "$images" | cut -f1) in docs/images, Resources/Yabar.icns"
