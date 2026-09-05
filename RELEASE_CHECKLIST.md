# CodexSatellites Release Checklist

Do not mark an item PASS unless it was actually executed or observed.

Use:

- `PASS`
- `FAIL`
- `NOT TESTED`
- `BLOCKED`

## 1. Automated baseline

- [ ] `./script/build_and_run.sh --verify` passes.
- [ ] `xcodebuild ... test` passes with 0 failures.
- [ ] `./script/release.sh preview` succeeds.
- [ ] Preview DMG passes `hdiutil verify`.
- [ ] Preview DMG contains `CodexSatellites.app`, `Applications`, and `LICENSE.txt`.

## 2. Real notched MacBook

- [ ] No Dock icon.
- [ ] No ordinary main window.
- [ ] Left/right satellites align with the physical notch.
- [ ] Camera housing is not covered.
- [ ] Spacing is visually symmetric.
- [ ] External non-notched display gets no fallback pill.

## 3. Hover

- [ ] Hovering either satellite expands both.
- [ ] Left expands outward left.
- [ ] Right expands outward right.
- [ ] Percentage text is readable.
- [ ] Foreground app does not lose focus.
- [ ] Collapse timing is reliable.
- [ ] Reduce Motion behavior is acceptable.

## 4. Settings Bar

Expected:

`(Launch) (1m/5m/15m) (reset count) (Quit)`

- [ ] Four circular controls.
- [ ] No persistent explanatory text.
- [ ] Satellite re-click closes immediately.
- [ ] Outside click closes immediately.
- [ ] Outside click still reaches target app.
- [ ] 3 seconds inactivity auto-dismisses.
- [ ] Mouse movement inside resets timer.
- [ ] Frequency click keeps panel open and resets timer.
- [ ] Quit terminates only current instance.

## 5. Localization/accessibility

English:

- [ ] `Launch at Login`
- [ ] `Review Login Items`
- [ ] `Launch at Login Unavailable`
- [ ] `Quota Check Frequency`
- [ ] `Available Reset Count`
- [ ] `Quit`

Simplified Chinese:

- [ ] `登录时启动`
- [ ] `检查登录项`
- [ ] `登录时启动不可用`
- [ ] `额度检查频率`
- [ ] `可用重置次数`
- [ ] `退出`

- [ ] Native macOS tooltips.
- [ ] Accessibility labels/values are meaningful.

## 6. Refresh

- [ ] First launch refreshes immediately.
- [ ] Default interval is `1m`.
- [ ] Cycle is `1m → 5m → 15m → 1m`.
- [ ] Selection survives restart.
- [ ] Repeated changes do not create duplicate requests.
- [ ] `15m` still refreshes immediately after wake.

## 7. Quota/reset semantics

- [ ] 5-hour remaining quota is correct.
- [ ] Weekly remaining quota is correct.
- [ ] Reset indicator uses `rate_limit_reset_credits.available_count`.
- [ ] `available_count = 0` displays `0`.
- [ ] Missing/malformed reset count displays `—`.
- [ ] Stale/unavailable reset count displays `—`.
- [ ] No reset-credit consume action exists.

## 8. Fresh/stale/unavailable

- [ ] Fresh data displays normally.
- [ ] Network failure preserves last-good quota percentages.
- [ ] Stale quota remains readable with reduced emphasis.
- [ ] Recovery returns to fresh.
- [ ] No normal transient-failure toast.

## 9. Display lifecycle

- [ ] Scaling/resolution change repositions overlay.
- [ ] Sleep/wake preserves geometry.
- [ ] External display does not duplicate overlay.
- [ ] Internal-display unavailability hides overlay appropriately.
- [ ] Space switching does not duplicate/drift panels.
- [ ] Full-screen behavior recorded as PASS or known limitation.

## 10. Launch at Login

Use a stable installed app path such as `/Applications/CodexSatellites.app`.

### ON

- [ ] Enable Launch at Login.
- [ ] Logout/login or reboot.
- [ ] App starts automatically.
- [ ] Satellites appear.

### OFF

- [ ] Disable Launch at Login.
- [ ] Current instance remains running.
- [ ] Logout/login or reboot.
- [ ] App does not auto-start.

### Quit

- [ ] Launch at Login ON.
- [ ] Quit app.
- [ ] Login Item remains registered.
- [ ] Next login starts app.

## 11. Authentication safety

- [ ] No OAuth/device-code login.
- [ ] No refresh-token exchange.
- [ ] No `auth.json` write.
- [ ] No credential storage.
- [ ] Logs contain no access token.
- [ ] Logs contain no Authorization header.
- [ ] App creates/modifies no files under `~/.codex`.

## 12. Formal Developer ID release

- [ ] Developer ID Application identity available.
- [ ] `./script/release.sh preflight` reports public release capability READY.
- [ ] `./script/release.sh all` succeeds.
- [ ] Exported app passes `codesign --verify`.
- [ ] Hardened Runtime present.
- [ ] App Sandbox absent.
- [ ] App notarization `Accepted`.
- [ ] App staple validation passes.
- [ ] App Gatekeeper passes.
- [ ] Final DMG passes `hdiutil verify`.
- [ ] DMG signature verifies.
- [ ] DMG notarization `Accepted`.
- [ ] DMG staple validation passes.
- [ ] DMG Gatekeeper passes.
- [ ] `SHA256SUMS` verifies.
- [ ] `SHA256SUMS` contains only DMG basename.

## 13. Final install

- [ ] Install from final signed/notarized DMG.
- [ ] Launch from `/Applications`.
- [ ] Quota display works.
- [ ] Settings Bar works.
- [ ] Reset count works.
- [ ] Refresh preference works.
- [ ] Launch at Login E2E passes.

## 14. Publication

- [ ] Source tree is final.
- [ ] Version `0.1.0`, build `1`.
- [ ] `ReleaseNotes/v0.1.0.md` accurate.
- [ ] MIT License present.
- [ ] Final DMG + `SHA256SUMS` ready.
- [ ] Owner approves publication.
- [ ] Tag `v0.1.0`.
- [ ] Publish GitHub Release.

## Final classification

Use exactly one:

- `RELEASE CANDIDATE READY`
- `BLOCKED`
- `NOT READY`

List every `FAIL`, `BLOCKED`, and `NOT TESTED` item explicitly.
