#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
case "$MODE" in
  run|--build-only|--verify|--smoke|--previews|--validate-focus|--validate-snowman|--debug|--logs|--telemetry) ;;
  *) echo "Usage: $0 [--build-only|--verify|--smoke|--previews|--validate-focus|--validate-snowman|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
APP_NAME="WindowWeather"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
BUILD_ROOT="${WEATHER_BUILD_DIR:-$ROOT_DIR/.build}"
mkdir -p "$BUILD_ROOT/clang-cache" "$BUILD_ROOT/swift-cache" "$BUILD_ROOT/swiftpm-cache"
export CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_ROOT/swift-cache"

# Only stop this checkout's staged app, never another installation.
while IFS= read -r pid; do
  [[ -z "$pid" ]] && continue
  executable="$(ps -p "$pid" -o comm= 2>/dev/null || true)"
  if [[ "$executable" == "$APP_BINARY" ]]; then kill "$pid"; fi
done < <(pgrep -x "$APP_NAME" || true)

# SwiftPM's nested sandbox cannot run inside some agent sandboxes.
# Opt out explicitly with WEATHER_DISABLE_SWIFTPM_SANDBOX=1 in those environments.
BUILD_OPTIONS=(--scratch-path "$BUILD_ROOT" --cache-path "$BUILD_ROOT/swiftpm-cache")
if [[ "${WEATHER_DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]]; then BUILD_OPTIONS+=(--disable-sandbox); fi
swift build "${BUILD_OPTIONS[@]}" --product "$APP_NAME"
BUILD_DIR="$(swift build "${BUILD_OPTIONS[@]}" --show-bin-path)"
# Sign outside File Provider: it can restore FinderInfo between xattr removal
# and codesign when the generated bundle lives in Documents.
STAGE_ROOT="$(mktemp -d /private/tmp/window-weather-dev.XXXXXX)"
trap 'rm -rf "$STAGE_ROOT"' EXIT
STAGED_APP="$STAGE_ROOT/$APP_NAME.app"
mkdir -p "$STAGED_APP/Contents/MacOS"
cp -X "$BUILD_DIR/$APP_NAME" "$STAGED_APP/Contents/MacOS/$APP_NAME"
chmod +x "$STAGED_APP/Contents/MacOS/$APP_NAME"
cat > "$STAGED_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>WindowWeather</string>
<key>CFBundleDisplayName</key><string>WindowWeather</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleExecutable</key><string>WindowWeather</string>
<key>CFBundleIdentifier</key><string>org.windowweather.app</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.6.1</string>
<key>CFBundleVersion</key><string>8</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><false/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/bin/ditto --norsrc --noextattr "$ROOT_DIR/Resources" "$STAGED_APP/Contents/Resources"
/usr/bin/python3 "$ROOT_DIR/script/embed_sparkle.py" "$BUILD_ROOT" "$STAGED_APP" -
/usr/bin/codesign --force --sign - "$STAGED_APP"
mkdir -p "$ROOT_DIR/dist"
/usr/bin/ditto -c -k --keepParent --norsrc --noextattr "$STAGED_APP" "$ROOT_DIR/dist/WindowWeather-macOS.zip"
/usr/bin/ditto --norsrc --noextattr "$STAGED_APP" "$APP_BUNDLE"
# Best effort for the runnable Documents copy; the ZIP is made from clean staging.
/usr/bin/xattr -dr com.apple.FinderInfo "$APP_BUNDLE" 2>/dev/null || true
/usr/bin/xattr -dr com.apple.ResourceFork "$APP_BUNDLE" 2>/dev/null || true

case "$MODE" in
  --build-only) echo "$APP_BUNDLE" ;;
  --smoke)
    REPORT="$ROOT_DIR/docs/validation/smoke.json"
    rm -f "$REPORT"
    /usr/bin/open -n -W "$APP_BUNDLE" --args --smoke-test "$REPORT"
    /usr/bin/python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print(json.dumps(r,indent=2)); sys.exit(0 if r["passed"] else 1)' "$REPORT"
    ;;
  --previews)
    rm -f "$ROOT_DIR/docs/validation/corner-validation.json"
    /usr/bin/open -n -W "$APP_BUNDLE" --args --render-previews "$ROOT_DIR/docs/validation"
    test -s "$ROOT_DIR/docs/validation/snow-preview.png"
    test -s "$ROOT_DIR/docs/validation/rain-preview.png"
    test -s "$ROOT_DIR/docs/validation/autumn-preview.png"
    test -s "$ROOT_DIR/docs/validation/cherryBlossom-preview.png"
    test -s "$ROOT_DIR/docs/validation/bubbles-preview.png"
    test -s "$ROOT_DIR/docs/validation/confetti-preview.png"
    /usr/bin/python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print(json.dumps(r,indent=2)); sys.exit(0 if r["passed"] else 1)' "$ROOT_DIR/docs/validation/corner-validation.json"
    ;;
  --validate-focus|--validate-snowman)
    if [[ "$MODE" == "--validate-focus" ]]; then
      REPORT_DIR="$ROOT_DIR/docs/validation/focused-window"
      REPORT_NAME=focus-validation.json
    else
      REPORT_DIR="$ROOT_DIR/docs/validation/snowman"
      REPORT_NAME=snowman-validation.json
    fi
    mkdir -p "$REPORT_DIR"
    rm -f "$REPORT_DIR/$REPORT_NAME"
    /usr/bin/open -n -W "$APP_BUNDLE" --args "$MODE" "$REPORT_DIR"
    /usr/bin/python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print(json.dumps(r,indent=2)); sys.exit(0 if r["passed"] else 1)' "$REPORT_DIR/$REPORT_NAME"
    ;;
  --verify)
    /usr/bin/open -n "$APP_BUNDLE"
    sleep 2
    found=0
    while IFS= read -r pid; do
      if [[ "$(ps -p "$pid" -o comm= 2>/dev/null || true)" == "$APP_BINARY" ]]; then found=1; fi
    done < <(pgrep -x "$APP_NAME" || true)
    [[ "$found" == 1 ]] || { echo "App did not remain running" >&2; exit 1; }
    echo "Window Weather is running."
    ;;
  --debug) /usr/bin/lldb -- "$APP_BINARY" ;;
  --logs|--telemetry)
    /usr/bin/open -n "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate 'process == "WindowWeather"'
    ;;
  run) /usr/bin/open -n "$APP_BUNDLE" ;;
esac
