#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CodexSatellites"
BUNDLE_ID="io.github.ntlx.codexsatellites"
VERSION="0.1.0"
BUILD_NUMBER="1"
PROJECT_NAME="CodexSatellites.xcodeproj"
SCHEME="CodexSatellites"
NOTARY_PROFILE="${NOTARY_PROFILE:-CodexSatellites-notary}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
WORK_DIR="$DIST_DIR/work"
LOG_DIR="$DIST_DIR/logs"
ARCHIVE_PATH="$WORK_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$WORK_DIR/export"
EXPORT_OPTIONS="$WORK_DIR/ExportOptions.plist"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
APP_ZIP="$WORK_DIR/$APP_NAME-$VERSION-app.zip"
DMG_ROOT="$WORK_DIR/dmg-root"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
CHECKSUMS_PATH="$DIST_DIR/SHA256SUMS"

SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
TEAM_ID="${TEAM_ID:-}"

log() {
    printf '[release] %s\n' "$*"
}

die() {
    printf '[release] ERROR: %s\n' "$*" >&2
    exit 1
}

ensure_tools() {
    local tool
    for tool in xcodebuild security codesign spctl xcrun ditto hdiutil shasum plutil; do
        command -v "$tool" >/dev/null 2>&1 || die "required tool unavailable: $tool"
    done
}

resolve_signing_identity() {
    local identities developer_lines count team_from_identity
    identities="$(security find-identity -p codesigning -v 2>/dev/null || true)"
    developer_lines="$(printf '%s\n' "$identities" | awk -F '"' '/Developer ID Application:/ {print $2}')"
    count="$(printf '%s\n' "$developer_lines" | awk 'NF { count += 1 } END { print count + 0 }')"

    if [[ -n "$SIGNING_IDENTITY" ]]; then
        printf '%s\n' "$developer_lines" | awk -v wanted="$SIGNING_IDENTITY" '$0 == wanted { found = 1 } END { exit(found ? 0 : 1) }' \
            || die "SIGNING_IDENTITY is not an installed Developer ID Application identity"
    elif [[ "$count" -eq 1 ]]; then
        SIGNING_IDENTITY="$developer_lines"
    elif [[ "$count" -eq 0 ]]; then
        printf '[release] BLOCKED: Developer ID Application certificate unavailable\n' >&2
        return 1
    else
        if [[ -z "$TEAM_ID" ]]; then
            printf '[release] BLOCKED: multiple Developer ID Application identities; set TEAM_ID or SIGNING_IDENTITY\n' >&2
            return 1
        fi
        SIGNING_IDENTITY="$(printf '%s\n' "$developer_lines" | awk -v team="$TEAM_ID" 'index($0, "(" team ")") { print; exit }')"
        [[ -n "$SIGNING_IDENTITY" ]] || die "no Developer ID Application identity matches TEAM_ID=$TEAM_ID"
    fi

    if [[ "$SIGNING_IDENTITY" =~ \(([A-Z0-9]+)\)$ ]]; then
        team_from_identity="${BASH_REMATCH[1]}"
    else
        die "could not derive Team ID from signing identity"
    fi

    if [[ -n "$TEAM_ID" && "$TEAM_ID" != "$team_from_identity" ]]; then
        die "TEAM_ID does not match SIGNING_IDENTITY"
    fi
    TEAM_ID="$team_from_identity"
}

check_notary_profile() {
    local profile_check
    profile_check="$WORK_DIR/notary-profile.txt"
    mkdir -p "$WORK_DIR"
    if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >"$profile_check" 2>&1; then
        log "notary profile available: $NOTARY_PROFILE"
        return 0
    fi

    printf '[release] BLOCKED: notarization Keychain profile unavailable: %s\n' "$NOTARY_PROFILE" >&2
    printf '[release] Prepare it interactively (the password stays in Keychain):\n' >&2
    printf 'xcrun notarytool store-credentials "%s" --apple-id "<APPLE_ID>" --team-id "<TEAM_ID>"\n' "$NOTARY_PROFILE" >&2
    return 1
}

preflight() {
    local blocked=0
    ensure_tools
    mkdir -p "$WORK_DIR" "$LOG_DIR"

    log "project: $PROJECT_NAME"
    log "bundle: $BUNDLE_ID"
    log "version: $VERSION ($BUILD_NUMBER)"
    log "notary profile: $NOTARY_PROFILE"

    if resolve_signing_identity; then
        log "Developer ID identity: $SIGNING_IDENTITY"
        log "Team ID: $TEAM_ID"
    else
        blocked=1
    fi

    if check_notary_profile; then
        :
    else
        blocked=1
    fi

    [[ "$blocked" -eq 0 ]] || return 1
}

write_export_options() {
    mkdir -p "$WORK_DIR"
    cat >"$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>$TEAM_ID</string>
</dict>
</plist>
PLIST
    plutil -lint "$EXPORT_OPTIONS" >/dev/null
}

build() {
    [[ -n "$SIGNING_IDENTITY" && -n "$TEAM_ID" ]] || die "run preflight successfully before build"
    write_export_options
    mkdir -p "$WORK_DIR"
    rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

    log "archiving Release app"
    xcodebuild \
        -project "$ROOT_DIR/$PROJECT_NAME" \
        -scheme "$SCHEME" \
        -configuration Release \
        -destination 'generic/platform=macOS' \
        -archivePath "$ARCHIVE_PATH" \
        DEVELOPMENT_TEAM="$TEAM_ID" \
        CODE_SIGN_STYLE=Automatic \
        CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
        archive

    log "exporting Developer ID app"
    xcodebuild \
        -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS"

    [[ -d "$APP_PATH" ]] || die "export did not produce $APP_PATH"
    log "Release app exported: $APP_PATH"
}

notary_submit() {
    local label="$1"
    local artifact="$2"
    local result_path="$WORK_DIR/notary-$label.json"
    local status submission_id

    log "submitting $label to notarytool"
    if ! xcrun notarytool submit "$artifact" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait \
        --output-format json >"$result_path"; then
        submission_id="$(plutil -extract id raw -o - "$result_path" 2>/dev/null || true)"
        if [[ -n "$submission_id" ]]; then
            xcrun notarytool log "$submission_id" --keychain-profile "$NOTARY_PROFILE" >"$LOG_DIR/notary-$label-$submission_id.json" 2>&1 || true
        fi
        die "$label notarization submission failed; inspect $result_path"
    fi

    status="$(plutil -extract status raw -o - "$result_path" 2>/dev/null || true)"
    submission_id="$(plutil -extract id raw -o - "$result_path" 2>/dev/null || true)"
    log "$label notarization status: ${status:-UNKNOWN}"
    log "$label submission ID: ${submission_id:-UNKNOWN}"

    if [[ "$status" != "Accepted" ]]; then
        if [[ -n "$submission_id" ]]; then
            xcrun notarytool log "$submission_id" --keychain-profile "$NOTARY_PROFILE" >"$LOG_DIR/notary-$label-$submission_id.json" 2>&1 || true
        fi
        die "$label notarization was not Accepted; inspect $result_path and $LOG_DIR"
    fi
}

notarize_app() {
    [[ -d "$APP_PATH" ]] || die "exported app missing; run build first"
    rm -f "$APP_ZIP"
    ditto -c -k --keepParent "$APP_PATH" "$APP_ZIP"
    notary_submit app "$APP_ZIP"
    xcrun stapler staple "$APP_PATH"
    xcrun stapler validate "$APP_PATH"
    spctl -a -vv --type execute "$APP_PATH"
    log "stapled and Gatekeeper-verified app"
}

package_dmg() {
    [[ -d "$APP_PATH" ]] || die "exported app missing; run build first"
    [[ -n "$SIGNING_IDENTITY" ]] || die "run preflight successfully before package"
    xcrun stapler validate "$APP_PATH"
    rm -rf "$DMG_ROOT"
    rm -f "$DMG_PATH"
    mkdir -p "$DMG_ROOT"
    ditto "$APP_PATH" "$DMG_ROOT/$APP_NAME.app"
    ln -s /Applications "$DMG_ROOT/Applications"

    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$DMG_ROOT" \
        -ov \
        -format UDZO \
        "$DMG_PATH"
    codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
    codesign --verify --verbose=4 "$DMG_PATH"
    codesign -dvv "$DMG_PATH" >"$LOG_DIR/dmg-codesign.txt" 2>&1
    log "signed DMG created: $DMG_PATH"
}

notarize_dmg() {
    [[ -f "$DMG_PATH" ]] || die "DMG missing; run package first"
    notary_submit dmg "$DMG_PATH"
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
    log "stapled DMG"
}

verify_app() {
    [[ -d "$APP_PATH" ]] || die "exported app missing"
    codesign --verify --deep --strict --verbose=4 "$APP_PATH"
    codesign -dvvv "$APP_PATH" >"$LOG_DIR/app-codesign.txt" 2>&1
    codesign -d --entitlements :- "$APP_PATH" >"$LOG_DIR/app-entitlements.plist" 2>&1
    if codesign -d --entitlements :- "$APP_PATH" 2>&1 | grep -q 'com.apple.security.app-sandbox'; then
        die "App Sandbox entitlement is present"
    fi
    spctl -a -vv --type execute "$APP_PATH"
    [[ "$(lipo -archs "$APP_PATH/Contents/MacOS/$APP_NAME")" == *arm64* ]] || die "app binary does not contain arm64"
    log "app signature, entitlements, architecture, and Gatekeeper checks passed"
}

verify_dmg() {
    [[ -f "$DMG_PATH" ]] || die "DMG missing"
    codesign --verify --verbose=4 "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
    spctl -a -vv -t open --context context:primary-signature "$DMG_PATH"
    log "DMG signature, staple, and Gatekeeper checks passed"
}

verify() {
    mkdir -p "$DIST_DIR" "$WORK_DIR" "$LOG_DIR"
    verify_app
    xcrun stapler validate "$APP_PATH"
    verify_dmg
    shasum -a 256 "$DMG_PATH" >"$CHECKSUMS_PATH"
    shasum -a 256 -c "$CHECKSUMS_PATH"
    log "checksum verified: $CHECKSUMS_PATH"
}

usage() {
    printf 'usage: %s {preflight|build|notarize|package|verify|all}\n' "$0" >&2
}

main() {
    local mode="${1:-}"
    case "$mode" in
        preflight)
            preflight
            ;;
        build)
            preflight
            build
            verify_app
            ;;
        notarize)
            preflight
            notarize_app
            ;;
        package)
            preflight
            package_dmg
            ;;
        verify)
            verify
            ;;
        all)
            preflight
            build
            verify_app
            notarize_app
            package_dmg
            notarize_dmg
            verify
            ;;
        *)
            usage
            exit 2
            ;;
    esac
}

main "$@"
