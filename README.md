# CodexSatellites

Minimal Codex quota satellites for the MacBook notch.

![CodexSatellites](Artwork/README/README-hero-1600x900.png)

Website: [ntlx.github.io/CodexSatellites](https://ntlx.github.io/CodexSatellites/)

## What it does

CodexSatellites is a native macOS ambient HUD for the built-in display of a notched MacBook. It keeps the hardware notch untouched and shows two small quota orbs beside it:

CodexSatellites is an independent community utility and is not affiliated with or endorsed by OpenAI.

- Left satellite → Codex 5h remaining
- Right satellite → Codex weekly remaining
- Desktop / Notification Center widget → the same two quotas at a glance

## Widget

CodexSatellites ships a WidgetKit widget in two sizes:

- **Small** → 5-hour and weekly remaining gauges, available reset count, and current app status.
- **Medium** → the same information with reset times for both quota windows.

Add it from the desktop: right-click the desktop → **Edit Widgets…** → **CodexSatellites**. macOS does not allow an app to place a widget for you.

The app remains the only component that reads Codex authentication and requests usage. It publishes quota and settings snapshots for the widget; the widget only reads those caches and independently checks whether the main app is currently running. The `1m` / `5m` / `15m` setting controls quota polling by the app, not widget rendering. The widget performs no scheduled background refresh and its timeline policy remains `.never`.

Use macOS **Edit Widget** to configure **Launch at Login** and **Frequency**. Those settings are global to CodexSatellites even though WidgetKit stores editor values per widget instance: the running app detects the field that changed and applies only that field globally, so an unchanged stale value from another widget does not overwrite newer app state. WidgetKit does not provide a public API for rewriting the stored editor values of every other widget instance. If a widget is edited while CodexSatellites is stopped, the edit does not wake the app; it is reconciled the next time the app launches. This native editor is also the settings path on Macs without a usable hardware notch.

Clicking the normal widget content performs a local-only refresh. WidgetKit reloads the timeline, re-reads the latest quota/settings caches, and checks whether `CodexSatellites.app` is currently running. The click never fetches from OpenAI, reads Codex auth, starts or activates the app, or writes either snapshot. The system content margin around the content may still use WidgetKit's default tap behavior and open CodexSatellites. If the app has never run and no snapshot exists, the widget keeps showing `—`.

## Interaction

- Hover → both satellites expand and show remaining percentages.
- Click either satellite → a compact icon-only Settings Bar appears.
- Click normal widget content → re-reads cached quota/settings information and refreshes the live app Running/Stopped state, with no network request and no app launch.
- Edit Widget → Launch at Login and refresh frequency (`1m`, `5m`, `15m`).
- Notch Settings Bar → Launch at Login, refresh frequency, read-only available reset count, and Quit.
- Quota check interval → `1m`, `5m`, or `15m`.
- Notifications → native macOS alerts when a quota window resets to 100%, crosses below 10%, or the available reset count changes.

## Requirements

- macOS 15+
- MacBook with a hardware notch (notch satellites only; the widget works on any Mac)
- Existing local Codex CLI authentication

## How it works

The app reads the existing local Codex authentication state and requests the current quota windows. It classifies the 5-hour and weekly windows by their server-provided duration, then positions two non-activating panels using the display's camera-housing geometry.

## Privacy & authentication

CodexSatellites does not perform login or OAuth. It reads the existing local Codex authentication state. It does not refresh tokens or write Codex auth files.

## Development

Build and run the app with:

```bash
./script/build_and_run.sh
```

Use `./script/build_and_run.sh --verify` to build, launch, and verify the process.

## Documentation

- [Agent Engineering Contract](AGENTS.md)
- [Release Checklist](RELEASE_CHECKLIST.md)

## Release engineering

The outside-Mac-App-Store release workflow uses Developer ID signing, Hardened Runtime, notarization, stapling, and a DMG:

```bash
./script/release.sh preflight
./script/release.sh preview
./script/release.sh all
```

The release script reads signing and notarization identity from the local environment and Keychain. It never stores credentials in the repository. Generated artifacts and release evidence live under the ignored `dist/` directory. `./script/release.sh preview` produces an ad-hoc signed, unnotarized artifact for local validation only; the formal distribution path is `./script/release.sh all`.

## Known limitations

- Codex usage currently depends on an undocumented ChatGPT usage endpoint.
- Full-screen Space behavior has not been explicitly validated and should be treated as a known limitation.
- The app assumes an existing local Codex login and does not manage authentication.
- Notifications require a signed build and the app to be running.
- Notifications are English-only and have no in-app toggle — use macOS System Settings → Notifications.
- The widget requires a code-signed build to be registered by macOS; both `./script/build_and_run.sh` and `./script/release.sh preview` ad-hoc sign locally, so the widget can be tested without a Developer ID.
- The widget extension is sandboxed (a macOS requirement) and never reads Codex auth or calls the usage endpoint. App-owned quota/settings snapshots stay separate from widget-local presentation state.
- Widget face state is stored per family, so multiple Small widgets share one face selection and multiple Medium widgets share one face selection.
- On macOS, an already-running widget extension may keep using the previous widget code after CodexSatellites is updated, even though the installed app and widget extension report a newer build number. This was observed during local ad-hoc upgrade testing: widget data kept refreshing, but presentation changes did not appear until macOS recycled the widget extension process. There is no public API that guarantees recycling; restarting the WidgetKit host or logging out may create a fresh process. Developer ID upgrade behaviour remains to be verified.

## License

CodexSatellites is released under the [MIT License](LICENSE).
