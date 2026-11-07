#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT_DIR/branding/window-weather-logo-v2.png"
STAGE="$(mktemp -d /private/tmp/window-weather-icon.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
mkdir "$STAGE/AppIcon.iconset"

# Resize the approved artwork without changing its composition or background.
for size in 16 32 128 256 512; do
  /usr/bin/sips -z "$size" "$size" "$SOURCE" --out "$STAGE/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  pixels=$((size * 2))
  /usr/bin/sips -z "$pixels" "$pixels" "$SOURCE" --out "$STAGE/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$STAGE/AppIcon.iconset" -o "$STAGE/AppIcon.icns"
/usr/bin/iconutil -c iconset "$STAGE/AppIcon.icns" -o "$STAGE/verified.iconset"
for source in "$STAGE/AppIcon.iconset/"*.png; do
  test -s "$STAGE/verified.iconset/$(basename "$source")"
done
cp "$STAGE/AppIcon.icns" "$ROOT_DIR/Resources/AppIcon.icns"
echo "$ROOT_DIR/Resources/AppIcon.icns"
