#!/usr/bin/env bash
# Renders Resources/AppIcon.svg into Resources/AppIcon.icns (sips + iconutil, no dependencies).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ICONSET="$WORK/AppIcon.iconset"
mkdir "$ICONSET"

sips -s format png "$ROOT/Resources/AppIcon.svg" --out "$WORK/1024.png" >/dev/null
for size in 16 32 128 256 512; do
  sips -z $size $size "$WORK/1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$WORK/1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"
echo "✓ Resources/AppIcon.icns"
