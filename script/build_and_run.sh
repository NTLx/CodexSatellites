#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="CodexSatellites"
BUNDLE_ID="io.github.ntlx.codexsatellites"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Keep the debug widget's identity trackable: same build number as release.sh.
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || echo 1)}"
PROJECT="$ROOT_DIR/CodexSatellites.xcodeproj"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
APPEX_BUNDLE="$APP_BUNDLE/Contents/PlugIns/CodexSatellitesWidget.appex"
APPEX_BUNDLE_ID="$BUNDLE_ID.widget"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -project "$PROJECT" \
  -scheme "$APP_NAME" \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  build

# Debug builds are linker-signed only, which makes UNUserNotificationCenter
# refuse authorization. Ad-hoc sign the bundle so the Info.plist is sealed
# under the real bundle identifier and notifications can be tested locally.
# The widget extension is signed first with its own identifier and App Group
# entitlement so it can read the shared snapshot; signing the app afterwards
# seals the already-signed appex by reference.
if [[ -d "$APPEX_BUNDLE" ]]; then
  if ! codesign --force --sign - \
    --identifier "$APPEX_BUNDLE_ID" \
    --entitlements "$ROOT_DIR/CodexSatellitesWidget/CodexSatellitesWidget.entitlements" \
    "$APPEX_BUNDLE"; then
    printf 'warning: ad-hoc signing of the widget extension failed; the widget will be unavailable\n' >&2
  fi
fi

if ! codesign --force --sign - \
  --identifier "$BUNDLE_ID" \
  --entitlements "$ROOT_DIR/CodexSatellites.entitlements" \
  "$APP_BUNDLE"; then
  printf 'warning: ad-hoc signing failed; notifications will be unavailable\n' >&2
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
