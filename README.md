# CodexSatellites

Minimal Codex quota satellites for the MacBook notch.

![CodexSatellites](Artwork/README/README-hero-1600x900.png)

Website: [ntlx.github.io/CodexSatellites](https://ntlx.github.io/CodexSatellites/)

Latest release: [v0.4.0](https://github.com/NTLx/CodexSatellites/releases/tag/v0.4.0)

## What it does

CodexSatellites is a native macOS ambient HUD for the built-in display of a notched MacBook. It keeps the hardware notch untouched and shows two small quota orbs beside it:

CodexSatellites is an independent community utility and is not affiliated with or endorsed by OpenAI.

- Left satellite → Codex 5h remaining
- Right satellite → Codex weekly remaining
- Desktop / Notification Center widget → quotas, available reset count, and live app Running/Stopped status

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

v0.4.0 is the current GitHub release. Its public DMG contains an ad-hoc signed app and widget extension and is **not notarized**. This is the project's current distribution policy because no Apple Developer identity is used for the release.

```bash
./script/release.sh preflight
./script/release.sh adhoc
```

`./script/release.sh adhoc` requires a clean tree, builds the exact HEAD revision, verifies the app/widget signatures and versions, creates `dist/CodexSatellites-0.4.0.dmg`, and writes `dist/SHA256SUMS`. `./script/release.sh preview` remains a local-only packaging check. The optional `./script/release.sh all` path is retained for a future Developer ID signed and notarized release if those credentials become available.

Because the public DMG is not notarized, macOS may require explicit approval the first time you open the app. The release notes and GitHub Release identify this trust model rather than implying Apple notarization.

## Known limitations

- Codex usage currently depends on an undocumented ChatGPT usage endpoint.
- Full-screen Space behavior has not been explicitly validated and should be treated as a known limitation.
- The app assumes an existing local Codex login and does not manage authentication.
- Notifications require a signed build and the app to be running.
- Notifications are English-only and have no in-app toggle — use macOS System Settings → Notifications.
- The widget requires a code-signed build to be registered by macOS. The v0.4.0 public release ad-hoc signs both the app and widget extension; it is not Developer ID signed or notarized.
- The widget extension is sandboxed (a macOS requirement) and never reads Codex auth or calls the usage endpoint. App-owned quota/settings snapshots stay separate from transient app-process state.
- WidgetKit stores **Edit Widget** configuration per widget instance, while Launch at Login and Frequency are app-global settings. CodexSatellites reconciles the field that changed, but WidgetKit provides no public API to rewrite the stored editor values in every other widget instance.
- On macOS, an already-running WidgetKit extension can temporarily keep the previous widget binary after an in-place app update. CodexSatellites requests a timeline reload after an app build change, but WidgetKit process recycling remains controlled by macOS and has no public force-recycle API.

## License

CodexSatellites is released under the [MIT License](LICENSE).
