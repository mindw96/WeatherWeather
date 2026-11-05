#!/usr/bin/env bash
set -euo pipefail

# Builds a universal Release app independently of the running development app.
# Developer ID signing requires WEATHER_SIGN_IDENTITY.
# For distribution use release.sh, which also notarizes, staples, and verifies.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
VERSION="0.5.0"
if [[ "${1:-}" == "--print-version" ]]; then printf '%s\n' "$VERSION"; exit 0; fi
[[ "$#" == 0 ]] || { echo "Usage: $0 [--print-version]" >&2; exit 2; }
/usr/bin/python3 "$ROOT_DIR/script/embed_sparkle.py" --validate-config "$ROOT_DIR/Config/Updates.plist"
SIGN_IDENTITY="${WEATHER_SIGN_IDENTITY:?Set WEATHER_SIGN_IDENTITY to a Developer ID Application identity}"
[[ "$SIGN_IDENTITY" == "Developer ID Application: "* ]] || {
  echo "Sharing requires a Developer ID Application identity." >&2
  exit 1
}
CACHE_ROOT="${WEATHER_SHARE_BUILD_ROOT:-/private/tmp/window-weather-share-universal}"
STAGE_ROOT="$(mktemp -d /private/tmp/window-weather-package.XXXXXX)"
PACKAGE_NAME="WindowWeather-$VERSION-macOS"
PACKAGE_DIR="$STAGE_ROOT/$PACKAGE_NAME"
APP_BUNDLE="$PACKAGE_DIR/WindowWeather.app"
OUTPUT_DIR="$ROOT_DIR/dist/releases/$VERSION"
ZIP_PATH="$OUTPUT_DIR/WindowWeather-$VERSION-macOS-universal.zip"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$OUTPUT_DIR" "$CACHE_ROOT-cache"

BUILD_OPTIONS=(--configuration release --cache-path "$CACHE_ROOT-cache")
if [[ "${WEATHER_DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]]; then BUILD_OPTIONS+=(--disable-sandbox); fi
BUILD_OPTIONS+=(--arch arm64 --arch x86_64 --scratch-path "$CACHE_ROOT")
swift build "${BUILD_OPTIONS[@]}" --product WindowWeather
BIN_DIR="$(swift build "${BUILD_OPTIONS[@]}" --show-bin-path)"
cp "$BIN_DIR/WindowWeather" "$APP_BUNDLE/Contents/MacOS/WindowWeather"
chmod +x "$APP_BUNDLE/Contents/MacOS/WindowWeather"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Window Weather</string>
<key>CFBundleDisplayName</key><string>Window Weather</string>
<key>CFBundleExecutable</key><string>WindowWeather</string>
<key>CFBundleIdentifier</key><string>org.windowweather.app</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.5.0</string>
<key>CFBundleVersion</key><string>5</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><false/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/bin/python3 "$ROOT_DIR/script/embed_sparkle.py" "$CACHE_ROOT" "$APP_BUNDLE" "$SIGN_IDENTITY"

cp "$ROOT_DIR/docs/releases/$VERSION/START_HERE.ko.txt" "$PACKAGE_DIR/START_HERE.ko.txt"
cp "$ROOT_DIR/docs/releases/$VERSION/RELEASE_NOTES.ko.md" "$PACKAGE_DIR/RELEASE_NOTES.ko.md"
cp "$ROOT_DIR/LICENSE" "$PACKAGE_DIR/LICENSE"
# A new binary does not inherit the published release's notarization. Restore
# the release guides only after this build is accepted and its app is stapled.
/usr/bin/python3 - "$PACKAGE_DIR" <<'PY'
import pathlib, re, sys
for name in ('START_HERE.ko.txt', 'RELEASE_NOTES.ko.md'):
    path = pathlib.Path(sys.argv[1]) / name
    text, count = re.subn(r'^배포 상태:.*$', '배포 상태: Developer ID 서명 완료, Apple 공증 전입니다.',
                          path.read_text(), flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(f'{name}: expected exactly one 배포 상태: line')
    path.write_text(text)
PY
/usr/bin/codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
ARCHITECTURES="$(/usr/bin/lipo -archs "$APP_BUNDLE/Contents/MacOS/WindowWeather")"
[[ " $ARCHITECTURES " == *" arm64 "* && " $ARCHITECTURES " == *" x86_64 "* ]]
/usr/bin/plutil -lint "$APP_BUNDLE/Contents/Info.plist"
/usr/bin/ditto -c -k --keepParent --norsrc --noextattr "$PACKAGE_DIR" "$ZIP_PATH"
/usr/bin/python3 - "$STAGE_ROOT" "$PACKAGE_DIR" "$APP_BUNDLE" "$ZIP_PATH" "$OUTPUT_DIR/package-state.json" <<'PY'
import json, pathlib, sys
state = dict(zip(('stage_root', 'package_dir', 'app_bundle', 'zip_path'), sys.argv[1:5]))
pathlib.Path(sys.argv[5]).write_text(json.dumps(state, indent=2) + '\n')
print(json.dumps(state, indent=2))
PY
