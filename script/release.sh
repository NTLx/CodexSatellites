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
RW_DMG="$WORK_DIR/$APP_NAME-$VERSION-rw.dmg"
MOUNT_POINT="/Volumes/$APP_NAME"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
CHECKSUMS_PATH="$DIST_DIR/SHA256SUMS"
PREVIEW_DERIVED="$WORK_DIR/preview-derived"
PREVIEW_APP="$PREVIEW_DERIVED/Build/Products/Release/$APP_NAME.app"
PREVIEW_RW_DMG="$WORK_DIR/$APP_NAME-$VERSION-preview-rw.dmg"
PREVIEW_MOUNT_POINT="$WORK_DIR/preview-dmg-mount"
PREVIEW_DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION-preview-unsigned.dmg"
DMG_BACKGROUND="$ROOT_DIR/Artwork/Release/DMG/dmg-background.png"

SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
TEAM_ID="${TEAM_ID:-}"

log() {
    printf '[release] %s\n' "$*"
}

warn() {
    printf '[release] WARNING: %s\n' "$*" >&2
}

die() {
    printf '[release] ERROR: %s\n' "$*" >&2
    exit 1
}

ensure_tools() {
    local tool
    for tool in xcodebuild security codesign spctl xcrun ditto hdiutil shasum plutil osascript lipo; do
        command -v "$tool" >/dev/null 2>&1 || die "required tool unavailable: $tool"
    done
}

check_artwork() {
    local icon_count
    [[ -f "$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json" ]] || return 1
    icon_count="$(find "$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')"
    [[ "$icon_count" -eq 10 ]] || return 1
    [[ -f "$DMG_BACKGROUND" ]] || return 1
    [[ -f "$ROOT_DIR/Artwork/Brand/mark.svg" ]] || return 1
    [[ -f "$ROOT_DIR/Artwork/Brand/mark-1024.png" ]] || return 1
    [[ -f "$ROOT_DIR/Artwork/Brand/wordmark-horizontal.svg" ]] || return 1
    [[ -f "$ROOT_DIR/Artwork/Brand/wordmark-horizontal.png" ]] || return 1
    [[ -f "$ROOT_DIR/Artwork/README/README-hero-1600x900.png" ]] || return 1
    [[ -f "$ROOT_DIR/Artwork/GitHub/github-social-preview-1280x640.png" ]] || return 1
}

resolve_signing_identity() {
    local identities developer_lines count team_from_identity
    identities="$(security find-identity -p codesigning -v 2>/dev/null || true)"
    developer_lines="$(printf '%s\n' "$identities" | awk -F '"' '/Developer ID Application:/ {print $2}')"
    count="$(printf '%s\n' "$developer_lines" | awk 'NF { count += 1 } END { print count + 0 }')"

    if [[ -n "$SIGNING_IDENTITY" ]]; then
        printf '%s\n' "$developer_lines" | awk -v wanted="$SIGNING_IDENTITY" '$0 == wanted { found = 1 } END { exit(found ? 0 : 1) }' || return 1
    elif [[ "$count" -eq 1 ]]; then
        SIGNING_IDENTITY="$developer_lines"
    elif [[ "$count" -eq 0 ]]; then
        return 1
    else
        [[ -n "$TEAM_ID" ]] || return 1
        SIGNING_IDENTITY="$(printf '%s\n' "$developer_lines" | awk -v team="$TEAM_ID" 'index($0, "(" team ")") { print; exit }')"
        [[ -n "$SIGNING_IDENTITY" ]] || return 1
    fi

    if [[ "$SIGNING_IDENTITY" =~ \(([A-Z0-9]+)\)$ ]]; then
        team_from_identity="${BASH_REMATCH[1]}"
    else
        return 1
    fi
    [[ -z "$TEAM_ID" || "$TEAM_ID" == "$team_from_identity" ]] || return 1
    TEAM_ID="$team_from_identity"
}

check_signing_prerequisites() {
    resolve_signing_identity
}

check_notary_prerequisites() {
    local profile_check="$WORK_DIR/notary-profile.txt"
    mkdir -p "$WORK_DIR"
    xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >"$profile_check" 2>&1
}

require_signing() {
    ensure_tools
    check_signing_prerequisites || die "BLOCKED: Developer ID Application certificate unavailable or ambiguous"
}

require_notary() {
    ensure_tools
    check_notary_prerequisites || {
        printf '[release] BLOCKED: notarization Keychain profile unavailable: %s\n' "$NOTARY_PROFILE" >&2
        printf '[release] Prepare it interactively (the password stays in Keychain):\n' >&2
        printf 'xcrun notarytool store-credentials "%s" --apple-id "<APPLE_ID>" --team-id "<TEAM_ID>"\n' "$NOTARY_PROFILE" >&2
        return 1
    }
}

preflight() {
    local blocked=0
    ensure_tools
    mkdir -p "$WORK_DIR" "$LOG_DIR"
    log "project: $PROJECT_NAME"
    log "bundle: $BUNDLE_ID"
    log "version: $VERSION ($BUILD_NUMBER)"

    if check_artwork; then
        log "Artwork: AVAILABLE"
    else
        log "Artwork: BLOCKED"
        blocked=1
    fi
    if check_signing_prerequisites; then
        log "Developer ID: AVAILABLE"
        log "Team ID: $TEAM_ID"
    else
        log "Developer ID: BLOCKED"
        blocked=1
    fi
    if check_notary_prerequisites; then
        log "Notary profile: AVAILABLE"
    else
        log "Notary profile: BLOCKED ($NOTARY_PROFILE)"
        blocked=1
    fi
    if check_artwork; then
        log "Preview DMG capability: READY"
    else
        log "Preview DMG capability: BLOCKED"
    fi
    if [[ "$blocked" -eq 0 ]]; then
        log "Public release capability: READY"
    else
        log "Public release capability: BLOCKED"
        log "Preview remains available with: $0 preview"
    fi
    [[ "$blocked" -eq 0 ]]
}

write_export_options() {
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
    require_signing
    check_artwork || die "artwork is incomplete; build cannot continue"
    mkdir -p "$WORK_DIR" "$LOG_DIR"
    write_export_options
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
}

verify_signed_app() {
    [[ -d "$APP_PATH" ]] || die "signed app missing"
    mkdir -p "$LOG_DIR"
    codesign --verify --deep --strict --verbose=4 "$APP_PATH"
    codesign -dvvv "$APP_PATH" >"$LOG_DIR/app-codesign.txt" 2>&1
    codesign -d --entitlements :- "$APP_PATH" >"$LOG_DIR/app-entitlements.plist" 2>&1
    if codesign -d --entitlements :- "$APP_PATH" 2>&1 | grep -q 'com.apple.security.app-sandbox'; then
        die "App Sandbox entitlement is present"
    fi
    grep -q 'Authority=Developer ID Application:' "$LOG_DIR/app-codesign.txt" || die "app is not signed by Developer ID Application"
    grep -q 'Timestamp=' "$LOG_DIR/app-codesign.txt" || die "signed app has no trusted timestamp"
    grep -q 'Runtime Version=' "$LOG_DIR/app-codesign.txt" || die "Hardened Runtime is not present"
    [[ "$(lipo -archs "$APP_PATH/Contents/MacOS/$APP_NAME")" == *arm64* ]] || die "app binary does not contain arm64"
    log "signed app verification passed"
}

verify_notarized_app() {
    [[ -d "$APP_PATH" ]] || die "app missing"
    xcrun stapler validate "$APP_PATH"
    spctl -a -vv --type execute "$APP_PATH"
    log "notarized app verification passed"
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
    require_notary
    [[ -d "$APP_PATH" ]] || die "signed app missing; run build first"
    rm -f "$APP_ZIP"
    ditto -c -k --keepParent "$APP_PATH" "$APP_ZIP"
    notary_submit app "$APP_ZIP"
    xcrun stapler staple "$APP_PATH"
    verify_notarized_app
}

write_finder_layout() {
    osascript <<'APPLESCRIPT'
tell application "Finder"
    tell disk "CodexSatellites"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set pathbar visible of container window to false
        set the bounds of container window to {100, 100, 760, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set text size of viewOptions to 13
        set position of item "CodexSatellites.app" of container window to {170, 220}
        set position of item "Applications" of container window to {490, 220}
        set background picture of viewOptions to file ".background:dmg-background.png"
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT
}

create_styled_dmg() {
    local source_app="$1"
    local final_dmg="$2"
    local rw_dmg="$3"
    local mount_point="$4"
    local mount_active=0
    local layout_status=0

    [[ -d "$source_app" ]] || die "source app missing: $source_app"
    [[ -f "$DMG_BACKGROUND" ]] || die "DMG background missing: $DMG_BACKGROUND"
    rm -rf "$DMG_ROOT"
    rm -f "$rw_dmg" "$final_dmg"
    mkdir -p "$DMG_ROOT"
    if mount | awk -v target="$mount_point" '$3 == target { found = 1 } END { exit(found ? 0 : 1) }'; then
        die "mount point already in use: $mount_point"
    fi
    if [[ -e "$mount_point" ]]; then
        [[ -d "$mount_point" ]] || die "mount point is not a directory: $mount_point"
        rmdir "$mount_point" 2>/dev/null || die "mount point is not empty: $mount_point"
    fi
    ditto "$source_app" "$DMG_ROOT/$APP_NAME.app"
    ln -s /Applications "$DMG_ROOT/Applications"
    hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_ROOT" -ov -format UDRW "$rw_dmg"

    cleanup_mount() {
        if [[ "$mount_active" -eq 1 ]]; then
            hdiutil detach "$mount_point" >/dev/null 2>&1 || true
        fi
    }
    trap cleanup_mount EXIT
    if hdiutil attach -readwrite -noverify -noautoopen -mountpoint "$mount_point" "$rw_dmg" >/dev/null; then
        mount_active=1
        mkdir -p "$mount_point/.background"
        cp "$DMG_BACKGROUND" "$mount_point/.background/dmg-background.png"
        if write_finder_layout; then
            layout_status=1
        else
            warn "Finder layout AppleScript failed; falling back to a functional DMG"
        fi
        sync
        sleep 2
        if hdiutil detach "$mount_point" >/dev/null; then
            mount_active=0
        else
            cleanup_mount
            die "could not detach styled DMG volume cleanly"
        fi
    else
        warn "could not mount RW DMG for Finder layout; creating functional DMG"
    fi
    trap - EXIT
    hdiutil convert "$rw_dmg" -format UDZO -o "$final_dmg"
    if [[ "$layout_status" -eq 1 ]]; then
        log "styled DMG layout applied"
    else
        warn "styled Finder layout not applied; DMG remains functional"
    fi
}

package_dmg() {
    require_signing
    [[ -d "$APP_PATH" ]] || die "signed app missing; run build first"
    xcrun stapler validate "$APP_PATH"
    mkdir -p "$DIST_DIR" "$WORK_DIR" "$LOG_DIR"
    create_styled_dmg "$APP_PATH" "$DMG_PATH" "$RW_DMG" "$MOUNT_POINT"
    codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
    codesign --verify --verbose=4 "$DMG_PATH"
    codesign -dvv "$DMG_PATH" >"$LOG_DIR/dmg-codesign.txt" 2>&1
    log "signed DMG created: $DMG_PATH"
}

notarize_dmg() {
    require_notary
    [[ -f "$DMG_PATH" ]] || die "DMG missing; run package first"
    notary_submit dmg "$DMG_PATH"
    xcrun stapler staple "$DMG_PATH"
}

verify_dmg() {
    [[ -f "$DMG_PATH" ]] || die "DMG missing"
    codesign --verify --verbose=4 "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
    spctl -a -vv -t open --context context:primary-signature "$DMG_PATH"
    log "DMG verification passed"
}

write_checksum() {
    mkdir -p "$DIST_DIR"
    shasum -a 256 "$DMG_PATH" >"$CHECKSUMS_PATH"
    shasum -a 256 -c "$CHECKSUMS_PATH"
}

preview_smoke_test() {
    local mount_active=0
    rm -rf "$PREVIEW_MOUNT_POINT"
    mkdir -p "$PREVIEW_MOUNT_POINT"
    cleanup_preview_mount() {
        if [[ "$mount_active" -eq 1 ]]; then
            hdiutil detach "$PREVIEW_MOUNT_POINT" >/dev/null 2>&1 || true
        fi
    }
    trap cleanup_preview_mount EXIT
    hdiutil attach -readonly -noverify -noautoopen -mountpoint "$PREVIEW_MOUNT_POINT" "$PREVIEW_DMG_PATH" >/dev/null
    mount_active=1
    [[ -d "$PREVIEW_MOUNT_POINT/$APP_NAME.app" ]] || die "preview DMG is missing the app"
    [[ -L "$PREVIEW_MOUNT_POINT/Applications" ]] || die "preview DMG is missing Applications alias"
    /usr/bin/open -n "$PREVIEW_MOUNT_POINT/$APP_NAME.app"
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null || die "preview app launch smoke test failed"
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    hdiutil detach "$PREVIEW_MOUNT_POINT" >/dev/null
    mount_active=0
    trap - EXIT
    log "preview app launch smoke test passed"
}

preview() {
    ensure_tools
    check_artwork || die "artwork is incomplete; preview cannot be built"
    mkdir -p "$DIST_DIR" "$WORK_DIR" "$LOG_DIR"
    rm -rf "$PREVIEW_DERIVED"
    log "building unsigned Release preview app"
    xcodebuild \
        -project "$ROOT_DIR/$PROJECT_NAME" \
        -scheme "$SCHEME" \
        -configuration Release \
        -derivedDataPath "$PREVIEW_DERIVED" \
        CODE_SIGNING_ALLOWED=NO \
        build
    [[ -d "$PREVIEW_APP" ]] || die "preview build did not produce $PREVIEW_APP"
    create_styled_dmg "$PREVIEW_APP" "$PREVIEW_DMG_PATH" "$PREVIEW_RW_DMG" "$MOUNT_POINT"
    hdiutil verify "$PREVIEW_DMG_PATH"
    preview_smoke_test
    log "preview DMG: $PREVIEW_DMG_PATH"
    printf '%s\n' 'WARNING: This is an unsigned, unnotarized preview DMG.'
    printf '%s\n' 'It is for local packaging/artwork validation only.'
    printf '%s\n' 'Do not publish it.'
}

verify() {
    verify_notarized_app
    verify_dmg
    write_checksum
    log "checksum verified: $CHECKSUMS_PATH"
}

usage() {
    printf 'usage: %s {preflight|preview|build|notarize|package|verify|all}\n' "$0" >&2
}

main() {
    local mode="${1:-}"
    case "$mode" in
        preflight) preflight ;;
        preview) preview ;;
        build) build; verify_signed_app ;;
        notarize) notarize_app ;;
        package) package_dmg ;;
        verify) verify ;;
        all)
            require_signing
            require_notary
            build
            verify_signed_app
            notarize_app
            package_dmg
            notarize_dmg
            verify
            ;;
        *) usage; exit 2 ;;
    esac
}

main "$@"
