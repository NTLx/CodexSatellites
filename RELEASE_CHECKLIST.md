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

## 12. v0.4.0 ad-hoc public release

Developer ID signing and Apple notarization are intentionally outside the v0.4.0 release gate. The owner does not currently use an Apple Developer identity; the public trust model must be disclosed as ad-hoc signed and unnotarized.

- [ ] `./script/release.sh preflight` reports `Ad-hoc public release capability: READY`.
- [ ] `./script/release.sh adhoc` succeeds from a clean exact HEAD.
- [ ] App and widget versions are `0.4.0` and share the exact HEAD-derived `CFBundleVersion`.
- [ ] App passes `codesign --verify --deep --strict` with its ad-hoc signature.
- [ ] Widget extension passes strict signature verification and remains sandboxed.
- [ ] App remains non-sandboxed.
- [ ] Final `CodexSatellites-0.4.0.dmg` passes `hdiutil verify`.
- [ ] Mounted DMG contains `CodexSatellites.app`, `Applications`, `LICENSE.txt`, and the widget extension.
- [ ] `SHA256SUMS` verifies and contains only the final DMG basename.
- [ ] README, release notes, website, and GitHub Release explicitly state that the public artifact is ad-hoc signed and not notarized.

Optional future Developer ID/notarized distribution remains available through `./script/release.sh all` when credentials exist, but it is not required for v0.4.0.

## 13. Widget

Ad-hoc widget transport (`widgetContainer`):

- [ ] `CodexSatellites.app/Contents/PlugIns/CodexSatellitesWidget.appex` exists.
- [ ] `pluginkit -m -p com.apple.widgetkit-extension -v` lists `io.github.ntlx.codexsatellites.widget`.
- [ ] App writes `quota-snapshot.json` and `settings-snapshot.json` to the widget extension's container.
- [ ] Widget process loads both snapshots from `widgetContainer`.
- [ ] Both Small and Medium added together; opening and closing Notification Center repeatedly stays responsive.
- [ ] Runtime logs contain no `transport=appGroup` and no `kTCCServiceSystemPolicyAppData`.
- [ ] Small widget shows the 5-hour and weekly gauges.
- [ ] Medium widget shows both gauges plus reset times.
- [ ] Widget follows Light/Dark automatically.
- [ ] Stale data shows reduced emphasis without an error state.
- [ ] Unavailable data shows `—` instead of stale numbers.
- [ ] Widget never reads Codex auth or calls the usage endpoint.
- [ ] No Codex credentials are copied into the snapshot.
- [ ] No TCC prompt appears and no `SystemPolicyAppData` denial is logged for the primary transport.
- [ ] App Sandbox absent on the app; App Sandbox present on the widget extension.

Widget refresh model:

- [ ] App `1m`/`5m`/`15m` polling continues updating `quota-snapshot.json`.
- [ ] Widget Provider returns one entry with `.never`.
- [ ] Normal app quota refresh does not call `WidgetCenter.reloadTimelines`.
- [ ] Widget performs no direct network request.
- [ ] Widget performs no Timer or background refresh.
- [ ] When WidgetKit requests a new timeline, it reads the latest available snapshot.

Widget local refresh (v0.4.0):

- [ ] Clicking normal widget content — gauge, label, status row, or empty content space inside the interactive content region — logs `intent operation=refresh result=reloadRequested` followed by a new `timeline build=<n>` line.
- [ ] The reload re-reads quota/settings snapshots the app already cached and re-probes the main app's current Running/Stopped process state.
- [ ] The reload never triggers a Codex usage request, reads Codex auth, launches/activates CodexSatellites, or writes either snapshot.
- [ ] With the app running, click refresh and confirm the status row reports `Running`.
- [ ] Quit the app, click refresh again, confirm the status row reports `Stopped`, and confirm the app remains stopped.
- [ ] Reset count is read-only on the normal face; fresh `0` renders as `0`, stale/unavailable renders `—`.
- [ ] A click in the system content margin may use WidgetKit's default app-launch behavior; no `widgetURL` or custom padding masks that platform behavior.
- [ ] The reload action adds no refresh affordance: no icon, spinner, timestamp, toast, or pressed overlay.
- [ ] With no quota snapshot on disk the widget keeps showing `—` after a reload.

Native Edit Widget configuration (v0.4.0):

- [ ] Small and Medium always render one information face; there is no custom gear, settings face, flip transition, Percentage option, reset action, or widget-side Quit.
- [ ] **Edit Widget** exposes exactly Launch at Login and Frequency (`1m`, `5m`, `15m`).
- [ ] Changing only Launch at Login applies that field through the main app's `SMAppService.mainApp` path and does not overwrite Frequency from a stale per-instance editor value.
- [ ] Changing only Frequency persists through `QuotaRefreshPreference`, replaces the old refresh loop once, does not cause an immediate quota fetch solely because the interval changed, and does not overwrite Launch at Login from a stale per-instance editor value.
- [ ] Adding, removing, or resizing a widget does not mutate either global setting.
- [ ] An ambiguous multi-widget configuration change does not mutate global settings.
- [ ] Editing native configuration while CodexSatellites is stopped does not launch/wake the app; after the next app launch the persisted configuration baseline is reconciled.
- [ ] WidgetKit's per-instance editor values are not claimed to be rewritten across other installed instances; no private API or polling workaround is used.
- [ ] Widget logs continue using `transport=widgetContainer` with no TCC App Group denial.
- [ ] At least one usable-notch Mac and one no-notch Mac/VM-equivalent environment have been tested for native settings reachability when such environments are available.

Observed 2026-09-10 (ad-hoc, built-in display, Small + Medium, builds 27 and 28):

- `PASS` — `intent operation=refresh result=noop`, then `snapshot operation=load transport=widgetContainer result=success`, then `timeline build=<n>`, about 30ms apart in one widget process; seen on build 27 and on build 28, for both families.
- `PASS` — cached snapshot swapped to 55/66 with the weekly reset moved to 3 days while the app was not running: both widgets kept their previous 98/86 until clicked, then rendered 55/66 and the new reset time in the Medium's reset label, and `CodexSatellites` was still not running afterwards.
- `PASS` — render latency after a click is not deterministic: Medium showed the new values within ~2.5s, Small within ~1s on one click and only by ~25s on another, so treat the `timeline build=` line as the evidence, not a screenshot deadline.
- `PASS` — clicks on the empty top-left content area do not reload: probing a 180pt Small widget puts the intent's hit boundary about 24pt in from the visual edge.
- `PASS` — a click in that margin band launched `CodexSatellites`; the 0.3.0 build with no intent did the same from a centre click, so the app-launch band is the platform's default widget tap, not a regression.
- `NOT TESTED` — Light appearance, other display configurations, Developer ID builds.

App Group transport (implemented but inactive in the current source):

- [ ] `BLOCKED` — `WidgetSnapshotStore.activeTransport` is currently fixed to `.widgetContainer`. Developer ID signing does not switch the transport. Re-test App Group only after source code explicitly selects `.appGroup` and the build is provisioned for the App Group.

Widget upgrade (build N → N+1):

- [ ] Install build N, launch the app, add Small + Medium, and confirm `timeline build=N`.
- [ ] Install build N+1 over it without removing the widgets, killing chronod, or rebooting.
- [ ] Launch the app and confirm both widgets report `timeline build=N+1`.

Observed 2026-09-09 (ad-hoc, build 20 → 21):

- `PASS` — build 21 app and appex installed; both reported `CFBundleVersion 21`.
- `FAIL` — after launching build 21, chronod kept the pre-upgrade widget extension process; the timeline still ran the build 20 binary, and re-adding the widgets did not recycle it.
- `PASS` — after the old extension process was terminated, chronod launched a new process reporting `timeline build=21`.

Known limitation (non-blocking): macOS does not guarantee hot replacement of an already-running WidgetKit extension process when the containing app is replaced in place, and no public WidgetKit API can force process recycling.

Observed 2026-10-13 for the revised v0.4.0 widget design:

- `PASS` — `git diff --check` and the full macOS `xcodebuild test` workflow passed after the native Edit Widget / runtime-status implementation.
- `PASS` — `BUILD_NUMBER=41 ./script/build_and_run.sh --verify`; app and embedded widget both reported `0.4.0 (41)` and the app bundle passed strict/deep code-signature verification.
- `PASS` — compiled AppIntents metadata exposes Launch at Login + Frequency on `CodexWidgetConfigurationIntent`; Percentage and the superseded custom gear/settings-face intents are absent.
- `PASS` — exact validated build 41 was installed rollback-safely to `/Applications`; installed app/widget versions and strict/deep signatures were re-verified, and the prior CodexSatellites widget-extension process was recycled without touching chronod or unrelated processes.
- `PASS` — owner manually validated the installed build 41: Small/Medium no longer expose the custom gear; normal-content refresh reports `Running` while the app is active, reports `Stopped` after Quit without relaunching the app, and native **Edit Widget** exposes only Launch at Login + Frequency.
- `PASS` — owner subsequently installed the final exact-HEAD preview from `dist/` and confirmed the tested behavior is good enough to approve v0.4.0 publication.
- `PASS` — revised implementation is committed as `0899ccc2f062c98ce60ef261699c6e4326b24cec`. Release builds derive `CFBundleVersion` from the final release commit count; final exact-HEAD validation must run without a `BUILD_NUMBER` override.
- `NOT TESTED` — changing Launch at Login or Frequency in the native editor and observing end-to-end reconciliation into app-global settings remains a separate manual E2E check. System privacy settings were intentionally not changed for UI automation.
- `NOT TESTED` — no-notch Mac/VM-equivalent E2E; this Mac exposes only its built-in notched display and no no-notch environment is currently available.
- `PASS` — owner explicitly chose ad-hoc signed, unnotarized distribution for v0.4.0 because no Apple Developer account is currently used or planned in the short term. Developer ID/notary availability is therefore not a v0.4.0 blocker; the release must disclose the resulting Gatekeeper trust model.

## 14. Final install

- [ ] Install from final ad-hoc signed, unnotarized DMG.
- [ ] Complete any explicit macOS first-launch approval required by Gatekeeper.
- [ ] Launch from `/Applications`.
- [ ] Quota display works.
- [ ] Settings Bar works.
- [ ] Reset count works.
- [ ] Refresh preference works.
- [ ] Launch at Login E2E passes.

## 15. Publication

- [ ] Source tree is final.
- [ ] Version `0.4.0`; app and widget `CFBundleVersion` match the release build number.
- [ ] `ReleaseNotes/v0.4.0.md` accurate.
- [ ] README and website describe the runtime transport exactly as implemented; they do not claim Developer ID signing automatically activates App Group transport.
- [ ] README and website keep Full-screen Space behavior marked unvalidated unless it was actually tested.
- [ ] Preview artifacts from `./script/release.sh preview` remain local-validation artifacts; v0.4.0 publication uses the clean-HEAD `./script/release.sh adhoc` output.
- [ ] Public release copy clearly states that v0.4.0 is ad-hoc signed and unnotarized; it does not claim Developer ID, notarization, stapling, or Gatekeeper acceptance.
- [ ] MIT License present.
- [ ] Final `CodexSatellites-0.4.0.dmg` + `SHA256SUMS` ready.
- [x] Owner approves publication.
- [ ] Tag `v0.4.0`.
- [ ] Publish GitHub Release.

## Final classification

Use exactly one:

- `RELEASE CANDIDATE READY`
- `BLOCKED`
- `NOT READY`

List every `FAIL`, `BLOCKED`, and `NOT TESTED` item explicitly.
