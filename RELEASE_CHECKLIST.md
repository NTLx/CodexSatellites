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
- [ ] App writes `quota-snapshot.json` to the widget extension's container after a successful fetch.
- [ ] Widget process loads the same snapshot (`snapshot operation=load transport=widgetContainer result=success`).
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

Widget click to reload:

- [ ] Clicking anywhere inside the widget's content area — gauge, label, or the empty space between them — logs `intent operation=refresh result=noop` followed by a new `timeline build=<n>` line.
- [ ] The reload shows a snapshot the app cached after the widget was last rendered; a click never triggers a Codex usage request.
- [ ] A content-area click does not launch or activate CodexSatellites.
- [ ] A click in the content margin does not reload; the platform's default widget tap opens the app there, which is how a tap anywhere on the widget behaved before this intent existed.
- [ ] The click adds no visible affordance: no icon, spinner, label, timestamp, toast, or pressed overlay.
- [ ] With no snapshot on disk the widget keeps showing `—` after a click.

Observed 2026-09-10 (ad-hoc, built-in display, Small + Medium, builds 27 and 28):

- `PASS` — `intent operation=refresh result=noop`, then `snapshot operation=load transport=widgetContainer result=success`, then `timeline build=<n>`, about 30ms apart in one widget process; seen on build 27 and on build 28, for both families.
- `PASS` — cached snapshot swapped to 55/66 with the weekly reset moved to 3 days while the app was not running: both widgets kept their previous 98/86 until clicked, then rendered 55/66 and the new reset time in the Medium's reset label, and `CodexSatellites` was still not running afterwards.
- `PASS` — render latency after a click is not deterministic: Medium showed the new values within ~2.5s, Small within ~1s on one click and only by ~25s on another, so treat the `timeline build=` line as the evidence, not a screenshot deadline.
- `PASS` — clicks on the empty top-left content area do not reload: probing a 180pt Small widget puts the intent's hit boundary about 24pt in from the visual edge.
- `PASS` — a click in that margin band launched `CodexSatellites`; the 0.3.0 build with no intent did the same from a centre click, so the app-launch band is the platform's default widget tap, not a regression.
- `NOT TESTED` — Light appearance, other display configurations, Developer ID builds.

App Group transport (Developer ID builds only):

- [ ] `BLOCKED` — ad-hoc signing has no authorized App Group identity or provisioning. Re-test after switching `WidgetSnapshotStore.activeTransport` to `.appGroup` on a provisioned build.

Widget upgrade (build N → N+1):

- [ ] Install build N, launch the app, add Small + Medium, and confirm `timeline build=N`.
- [ ] Install build N+1 over it without removing the widgets, killing chronod, or rebooting.
- [ ] Launch the app and confirm both widgets report `timeline build=N+1`.

Observed 2026-09-09 (ad-hoc, build 20 → 21):

- `PASS` — build 21 app and appex installed; both reported `CFBundleVersion 21`.
- `FAIL` — after launching build 21, chronod kept the pre-upgrade widget extension process; the timeline still ran the build 20 binary, and re-adding the widgets did not recycle it.
- `PASS` — after the old extension process was terminated, chronod launched a new process reporting `timeline build=21`.

Known limitation (non-blocking): macOS does not guarantee hot replacement of an already-running WidgetKit extension process when the containing app is replaced in place, and no public WidgetKit API can force it. Developer ID upgrade behaviour remains `NOT TESTED`.

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
- [ ] Version `0.3.1`; app and widget `CFBundleVersion` match the release build number.
- [ ] `ReleaseNotes/v0.3.1.md` accurate.
- [ ] MIT License present.
- [ ] Final DMG + `SHA256SUMS` ready.
- [ ] Owner approves publication.
- [ ] Tag `v0.3.1`.
- [ ] Publish GitHub Release.

## Final classification

Use exactly one:

- `RELEASE CANDIDATE READY`
- `BLOCKED`
- `NOT READY`

List every `FAIL`, `BLOCKED`, and `NOT TESTED` item explicitly.
