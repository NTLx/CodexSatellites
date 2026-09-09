# AGENTS.md

## Project

CodexSatellites is a native macOS ambient HUD for notched MacBooks.

It shows:

- left satellite → Codex 5-hour remaining quota;
- right satellite → Codex weekly remaining quota;
- hover → remaining percentages;
- click → compact icon-only Settings Bar;
- WidgetKit widget (Small/Medium) → the same two quotas on the desktop and in Notification Center.

Current Settings Bar controls:

1. Launch at Login;
2. quota check frequency (`1m → 5m → 15m → 1m`);
3. read-only available reset count;
4. Quit.

## Source of truth

Use this priority order:

1. production code;
2. automated tests;
3. `script/release.sh`;
4. this file;
5. `RELEASE_CHECKLIST.md`;
6. `README.md`.

Do not recreate large Product / Architecture / Test specification documents unless explicitly requested.

## Product boundaries

Do not add without explicit owner request:

- ordinary Settings window;
- menu bar item;
- quota history;
- cost/token dashboard;
- reset countdown;
- reset-credit consumption;
- provider abstraction;
- Claude/Gemini/OpenRouter support;
- OAuth/device-code login;
- automatic updater;
- analytics/telemetry;
- cloud sync.

## Authentication invariant

Codex owns authentication.

CodexSatellites only observes existing local Codex authentication.

Allowed:

- read `$CODEX_HOME/auth.json`;
- otherwise read `~/.codex/auth.json`;
- use the existing access token/account ID for the usage request.

Forbidden:

- OAuth login;
- device-code login;
- browser auth;
- refresh-token exchange;
- writing `auth.json`;
- storing Codex credentials;
- logging access tokens or Authorization headers.

## Usage API invariant

Current usage source:

`GET https://chatgpt.com/backend-api/wham/usage`

Treat this undocumented endpoint defensively.

Quota-window classification is duration-based:

- short window closest to 18,000 seconds → 5-hour quota;
- long weekly window → weekly quota.

Do not classify by primary/secondary position alone.

## Reset-credit invariant

CodexSatellites may display only the read-only current available reset count.

Canonical field:

`rate_limit_reset_credits.available_count`

Rules:

- `0` is valid;
- missing/malformed → unknown (`nil` / `—`);
- stale/unavailable snapshot → UI displays `—`;
- reset parsing failure must not invalidate valid quota windows.

Never:

- consume a reset credit;
- call a reset-consume endpoint;
- expose a Reset action;
- manage reset-credit lifecycle.

## Refresh invariant

Supported intervals:

`1m → 5m → 15m → 1m`

Default: `1m`.

Only this preference may be persisted in `UserDefaults`.

Changing frequency must replace the old scheduled loop and must not create duplicate concurrent requests.

Wake from sleep triggers an immediate refresh regardless of interval.

## Launch at Login invariant

Use `SMAppService.mainApp`.

System status is the only source of truth.

Never mirror Launch at Login state into `UserDefaults`.

Quit terminates the current app instance and must not unregister the Login Item.

## Settings Bar invariant

Current structure:

`(Launch) (1m/5m/15m) (reset count) (Quit)`

Rules:

- no persistent explanatory labels;
- circular visual treatment;
- Launch/Quit use SF Symbols;
- reset count is read-only;
- native `.help(...)` tooltips;
- English + Simplified Chinese localization;
- localized accessibility labels;
- 3 seconds of Settings-Bar inactivity auto-dismisses it;
- re-clicking a satellite closes it immediately;
- clicking outside closes it without swallowing the original click.

## Orb invariant

Two non-activating panels are anchored around the built-in MacBook notch.

Do not:

- cover the camera housing;
- create external-display fallback UI;
- steal keyboard focus;
- activate the app during hover;
- expand toward the center of the notch.

Current visual design uses high-contrast white remaining arcs and percentage text.

Do not change colors/geometry/animation as incidental cleanup.

The panel frame animation and the SwiftUI orb content animation must share the single `OverlayMetrics.orbAnimationDuration` value. Mismatched durations let the content grow wider than the panel and clip the orb at the panel's fixed edge.

The percentage text deliberately slides in and out from the notch edge (`.move(edge: .trailing)` for the left orb, `.move(edge: .leading)` for the right), so it is transiently clipped at the panel edge during the ~0.2s transition. That is intended and is not the duration-mismatch clipping above.

Hover exit collapses the orbs immediately. Orb expansion is coupled to Settings Bar visibility through `effectiveExpanded`, so hiding the bar — including its 3-second auto-dismiss — also retracts the orbs whenever the cursor is not over them. That coupling is intended; do not decouple it.

## Freshness invariant

States:

- fresh;
- stale(last good);
- unavailable.

Quota percentages may display last-good data in stale state with reduced opacity.

Reset count displays `—` when not fresh.

## Widget invariant

The app embeds one WidgetKit extension (`CodexSatellitesWidget`, bundle ID `io.github.ntlx.codexsatellites.widget`) exposing `.systemSmall` and `.systemMedium`.

Data flow is one-way:

- the app is the only writer of quota state; the widget is a read-only presentation layer;
- sharing is implemented in `Shared/WidgetQuotaSnapshot.swift` with an explicit `WidgetSnapshotTransport`; `activeTransport` is `widgetContainer` for ad-hoc/preview builds and switches to `appGroup` once a Developer ID build provisions the App Group;
- on macOS 15+ App Group containers are protected and membership must be authorized by the code-signing/provisioning model; an ad-hoc build has neither a provisioning profile authorizing the registered `group.*` App Group nor a Developer Team ID for a team-prefixed macOS group, so the widget's group-container read is denied by TCC (`kTCCServiceSystemPolicyAppData`);
- for ad-hoc builds the non-sandboxed app writes `~/Library/Containers/io.github.ntlx.codexsatellites.widget/Data/Documents/quota-snapshot.json` and the widget reads its own container; this is a development compatibility workaround, not the production sharing architecture;
- `activeTransport` is the single source of truth: `.widgetContainer` resolves, reads, and deletes only the widget's own container and must never touch the App Group; only a provisioned `.appGroup` build may fall back to `.widgetContainer` for legacy migration;
- the snapshot payload is a rolling-upgrade IPC contract: after an app update an older widget build may still be reading while the newer app writes, so new fields stay optional and existing fields are never removed, retyped, or repurposed; bump `WidgetQuotaSnapshot.currentSchemaVersion` only for a breaking change;
- macOS may keep an already-running widget extension process on the previous binary after the app is replaced in place; no public WidgetKit API can force a reload. Treat this as a known platform limitation — do not add `killall chronod`, `pluginkit`, or `lsregister` workarounds to product code;
- snapshot reads/writes log `operation`/`transport`/`result` only — never quota values, tokens, or paths;
- app polling frequency and WidgetKit rendering are deliberately decoupled;
- the app writes the latest `WidgetQuotaSnapshot` after every quota fetch, including a `stale` snapshot when a failed fetch retains last-good data;
- the widget has no scheduled refresh and its timeline policy is `.never`;
- normal quota changes and snapshot clearing do not call `WidgetCenter.reloadTimelines`;
- the widget never polls Codex directly; WidgetKit is the sole owner of when the next widget timeline is requested;
- do not implement visibility/`onAppear`-based refresh hacks, timers, background tasks, push refresh, or private lifecycle workarounds;
- the widget must never read Codex auth, call the usage endpoint, or perform OAuth.

Signing/entitlements:

- the widget extension is sandboxed (`com.apple.security.app-sandbox`); macOS rejects unsandboxed extensions in PlugInKit;
- the containing app stays non-sandboxed because it must read `~/.codex/auth.json`; this asymmetry is intended;
- both targets carry the App Group entitlement; `script/build_and_run.sh` and `script/release.sh preview` ad-hoc sign the appex first (own identifier + entitlements) and the app second — do not collapse this into `--deep`;
- formal Developer ID signing requires the App Group to be registered in the developer account; local ad-hoc signing does not;
- every installable DMG must carry a new `CFBundleVersion`; the app and appex share one build number, and `script/release.sh` derives it from the git commit count and verifies it on both bundles;
- `script/release.sh preview` must never launch the app from the mounted image — that registers a widget-extension path that disappears on detach; install to `/Applications` before launching.

Presentation:

- the widget keeps its own presentation layer; do not port `QuotaOrbView`'s fixed-white notch styling;
- use system `Gauge` (`.accessoryCircularCapacity`), SF Pro text styles, and semantic `.primary`/`.secondary`/`.tertiary` foreground styles;
- use `containerBackground(for: .widget)` and system content margins; do not hand-draw corners, glass, shadows, or gradients;
- no quota threshold colors and no continuous animation; animate only data changes;
- the fresh state shows no metadata; stale lowers the gauge opacity and adds a `Stale` label instead of a live timestamp;
- widget strings are English-only and are not localized; relative dates use a pinned `en_US` locale so they never follow the system language;
- each quota metric sits in an equal-width, center-aligned column so the small and medium layouts stay symmetric.

## Notifications invariant

Native macOS notifications are delivered by `QuotaNotificationService`, driven by `QuotaChangeDetector` transitions between the previous and current snapshot inside the existing refresh loop.

Triggers:

- 5-hour quota reset to 100%;
- weekly quota reset to 100%;
- 5-hour quota crossing below 10%;
- weekly quota crossing below 10%;
- available reset count increased;
- available reset count decreased.

Rules:

- detection is transition-based, never state-based; a first fetch is a silent baseline;
- the previous snapshot is in-memory only (see the Persistence invariant);
- notification text is English-only;
- missing/unknown reset count never produces a notification;
- denied or unavailable authorization is a silent no-op;
- no in-app notification toggle — macOS System Settings owns that;
- notification delivery requires a signed build and a running app;
- authorization requires the sealed code-signing identifier to match `CFBundleIdentifier`; a linker-signed build seals `Identifier=CodexSatellites` (mismatch), so `UNUserNotificationCenter` refuses authorization on every launch (`UNErrorDomain Code=1`) and delivery is a silent no-op;
- `script/build_and_run.sh` and `script/release.sh preview` both ad-hoc re-sign with `--identifier "$BUNDLE_ID"`, which is what makes local notification and widget testing possible; those steps must stay;
- notifications cannot be verified on an un-re-signed build — only on a locally ad-hoc signed or Developer ID–signed build;
- real quota changes cannot force every trigger, so verify delivery by temporarily forcing a detector event and reverting it.

## Persistence invariant

`UserDefaults` is allowed only for quota refresh frequency.

Do not use it for:

- Launch at Login;
- auth;
- quota snapshots;
- reset credits.

## Dependencies

Prefer native macOS frameworks.

Do not add third-party runtime dependencies without explicit owner approval.

## Release identity

Current release identity:

- Bundle ID: `io.github.ntlx.codexsatellites`
- build: derived from `git rev-list --count HEAD` and passed as `CURRENT_PROJECT_VERSION`
- license: MIT
- minimum macOS: 15+
- App Sandbox: OFF (the widget extension is sandboxed — WidgetKit requires it)
- Hardened Runtime: ON
- widget extension bundle ID: `io.github.ntlx.codexsatellites.widget`
- App Group: `group.io.github.ntlx.codexsatellites`

Do not change release identity casually.

## Agent skills

`.agents/skills/build-macos-apps/` packages macOS/Xcode guidance (build/run/debug, SwiftUI patterns, AppKit interop, signing, notarization, telemetry). Consult it explicitly for non-trivial macOS or Xcode work.

## Build and test

```bash
./script/build_and_run.sh --verify
```

```bash
xcodebuild \
  -project CodexSatellites.xcodeproj \
  -scheme CodexSatellites \
  -destination 'platform=macOS' \
  test
```

### Verifying the overlay manually

CodexSatellites is an accessory app with non-activating panels, so the computer-use plugin cannot list or drive it. Use raw APIs instead:

- drive: `CGEvent(mouseEventSource:mouseType:mouseCursorPosition:mouseButton:)` posted to `.cghidEventTap` (needs Accessibility permission); `CGWarpMouseCursorPosition` alone moves the cursor but emits no `mouseMoved`, so it cannot trigger hover;
- measure: poll `CGWindowListCopyWindowInfo` for panel bounds/alpha — no Screen Recording needed, and accurate enough to time the animation frame by frame;
- capture: `screencapture -R` or `SCScreenshotManager.captureImage`; `CGWindowListCreateImage` is obsoleted on macOS 15+.

Reference measurements (built-in display): hover enter → first frame change ≈40ms, hover exit ≈54ms (no debounce timer); orb 24→60pt ≈200ms with ~27 distinct intermediate widths; Settings Bar show ≈0.15s, hide ≈0.12s, auto-dismiss ≈3.2–3.4s. Both panels must change with identical timestamps.

### Verifying the widget manually

The widget extension is a separate process; the widget gallery is not scriptable.

- registration: `pluginkit -m -p com.apple.widgetkit-extension -v | grep codex` after launching the app;
- shared data (ad-hoc): the app writes `~/Library/Containers/io.github.ntlx.codexsatellites.widget/Data/Documents/quota-snapshot.json`; a Developer ID build uses the App Group container;
- logs: `log show --info --predicate 'subsystem == "io.github.ntlx.codexsatellites.widget"'` must show only `transport=widgetContainer` for ad-hoc builds, with no App Group load and no `kTCCServiceSystemPolicyAppData` denial;
- layout: render the real views offscreen with `ImageRenderer` at `.systemSmall` 158×158 and `.systemMedium` 338×158, including ~16pt content margins;
- if PlugInKit rejects the appex, `log show --predicate 'process == "pkd"'` reports `plug-ins must be sandboxed`;
- placing the widget on the desktop/gallery is a manual user action; report `NOT TESTED` unless actually observed.

Preview DMG:

```bash
./script/release.sh preview
```

Formal release:

```bash
./script/release.sh preflight
./script/release.sh all
```

Never claim manual/signing/notarization checks passed unless actually executed.

## Release engineering invariant

Do not modify `script/release.sh` as incidental cleanup.

Formal distribution uses:

Developer ID
→ Hardened Runtime
→ notarization
→ staple
→ Gatekeeper
→ signed/notarized DMG
→ SHA256SUMS.

Secrets/certificates must never be committed.

## Scope discipline

Before changing code:

1. identify the smallest necessary file set;
2. preserve current product boundaries;
3. avoid speculative refactoring;
4. run relevant tests;
5. report `NOT TESTED` for unexecuted manual validation.

After changes:

```bash
git status --short
git diff --stat
git diff
```

Audit the final diff for scope creep.

## Documentation discipline

Keep durable documentation small.

Update:

- `README.md` for user-facing behavior;
- `AGENTS.md` only when a long-lived engineering invariant changes;
- `RELEASE_CHECKLIST.md` only when a real release gate changes;
- `ReleaseNotes/*` for release-specific changes.

Do not recreate large canonical Product/Architecture/Test specs by default.
