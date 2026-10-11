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

Widget quota-face reload:

- [ ] Clicking non-gear quota content — gauge, label, or empty content space — logs `intent operation=refresh result=noop` followed by a new `timeline build=<n>` line.
- [ ] The reload shows a snapshot the app cached after the widget was last rendered; it never triggers a Codex usage request.
- [ ] A quota-content reload does not launch or activate CodexSatellites.
- [ ] The gear wins hit testing and does not also run `RefreshCachedQuotaIntent`.
- [ ] A click in the system content margin may use WidgetKit's default app-launch behavior; no `widgetURL` or custom padding masks that platform behavior.
- [ ] The reload action adds no refresh affordance: no icon, spinner, label, timestamp, toast, or pressed overlay.
- [ ] With no quota snapshot on disk the widget keeps showing `—` after a reload.

Widget settings face (v0.4.0):

- [ ] Small and Medium each show a top-right gear and can switch `quota → settings → quota`.
- [ ] The normal transition is the Y-axis flip and completes in about 0.35 seconds; Reduce Motion uses the non-3D fallback.
- [ ] Small settings use a 2×2 control grid; Medium settings use one centered row; neither clips at 158×158 / 338×158 reference sizes.
- [ ] Launch at Login matches `SMAppService.mainApp`: enabled/disabled toggle, `requiresApproval` opens Login Items, unavailable is noninteractive.
- [ ] Frequency cycles exactly `1m → 5m → 15m → 1m`, persists through `QuotaRefreshPreference`, replaces the old loop once, and does not cause an immediate quota fetch solely because the interval changed.
- [ ] Reset count is read-only; fresh `0` renders as `0`, stale/unavailable renders `—`.
- [ ] Quit terminates the current app without unregistering Launch at Login.
- [ ] Settings actions execute through the existing main-app `QuotaOverlayController` path; no duplicate widget-side settings logic exists.
- [ ] Already-running app actions do not create a normal window or persistent Dock icon.
- [ ] Cold-launch widget action reaches the queued main-app handler and the intent returns so WidgetKit reloads the timeline.
- [ ] Small and Medium face state are independent; multiple instances of the same family may share that family's face state.
- [ ] No settings action makes the widget read Codex auth or call the usage endpoint.
- [ ] Widget logs continue using `transport=widgetContainer` with no TCC App Group denial.
- [ ] At least one usable-notch Mac and one no-notch Mac/VM-equivalent environment have been tested for settings reachability when such environments are available.

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

Known limitation (non-blocking): macOS does not guarantee hot replacement of an already-running WidgetKit extension process when the containing app is replaced in place, and no public WidgetKit API can force it. Developer ID upgrade behaviour remains `NOT TESTED`.

Observed 2026-10-11 for v0.4.0 release preparation:

- `PASS` — clean rebuild + full macOS test suite: 63/63 tests passed.
- `PASS` — `./script/build_and_run.sh --verify`; app and embedded widget both reported `0.4.0` with matching HEAD-derived build numbers and passed ad-hoc `codesign --verify`.
- `PASS` — `./script/release.sh preview` produced `CodexSatellites-0.4.0-preview-adhoc.dmg`; `hdiutil verify` and preview codesign validation passed; app/widget metadata inside the DMG matched `0.4.0` with the same HEAD-derived build number.
- `NOT TESTED` — v0.4.0 live widget clicks and visual flip/Reduce Motion observation: macOS Accessibility automation was unavailable (`AXIsProcessTrusted=false`) and screen-capture preflight was denied; system privacy settings were intentionally not changed for testing.
- `NOT TESTED` — no-notch Mac/VM-equivalent E2E; this Mac exposed only its built-in notched display and no no-notch environment was available.
- `NOT TESTED` — the complete 158×158 / 338×158 offscreen layout matrix was not completed before the live-E2E run was stopped.
- `BLOCKED` — formal Developer ID/notarized release artifact on this machine: release preflight reported Developer ID unavailable and `CodexSatellites-notary` unavailable. Preview capability remains ready.

## 14. Final install

- [ ] Install from final signed/notarized DMG.
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
- [ ] Preview artifacts from `./script/release.sh preview` are treated as local-validation artifacts; formal publication uses the signed/notarized `./script/release.sh all` output.
- [ ] MIT License present.
- [ ] Final DMG + `SHA256SUMS` ready.
- [ ] Owner approves publication.
- [ ] Tag `v0.4.0`.
- [ ] Publish GitHub Release.

## Final classification

Use exactly one:

- `RELEASE CANDIDATE READY`
- `BLOCKED`
- `NOT READY`

List every `FAIL`, `BLOCKED`, and `NOT TESTED` item explicitly.
