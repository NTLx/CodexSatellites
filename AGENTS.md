# AGENTS.md

## Project

CodexSatellites is a native macOS ambient HUD for notched MacBooks.

It shows:

- left satellite → Codex 5-hour remaining quota;
- right satellite → Codex weekly remaining quota;
- hover → remaining percentages;
- click → compact icon-only Settings Bar.

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
- notifications;
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

Current v0.1 visual design uses high-contrast white remaining arcs and percentage text.

Do not change colors/geometry/animation as incidental cleanup.

## Freshness invariant

States:

- fresh;
- stale(last good);
- unavailable.

Quota percentages may display last-good data in stale state with reduced opacity.

Reset count displays `—` when not fresh.

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
- version: `0.1.0`
- build: `1`
- license: MIT
- minimum macOS: 15+
- App Sandbox: OFF
- Hardened Runtime: ON

Do not change release identity casually.

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
