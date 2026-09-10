# CodexSatellites

Minimal Codex quota satellites for the MacBook notch.

![CodexSatellites](Artwork/README/README-hero-1600x900.png)

## What it does

CodexSatellites is a native macOS ambient HUD for the built-in display of a notched MacBook. It keeps the hardware notch untouched and shows two small quota orbs beside it:

CodexSatellites is an independent community utility and is not affiliated with or endorsed by OpenAI.

- Left satellite → Codex 5h remaining
- Right satellite → Codex weekly remaining
- Desktop / Notification Center widget → the same two quotas at a glance

## Widget

CodexSatellites ships a WidgetKit widget in two sizes:

- **Small** → 5-hour and weekly remaining gauges.
- **Medium** → both gauges plus reset times.

Add it from the desktop: right-click the desktop → **Edit Widgets…** → **CodexSatellites**. macOS does not allow an app to place a widget for you.

The widget is a read-only presentation layer. The app remains the only component that reads Codex authentication and requests usage; it publishes a small snapshot that the widget reads. The `1m` / `5m` / `15m` setting controls quota polling by the app, not widget rendering. The widget performs no scheduled background refresh and reads the latest snapshot whenever WidgetKit requests a new timeline. WidgetKit decides when a widget timeline is requested. The widget works on any Mac — including Mac mini, Mac Studio, and external displays — even though the notch satellites require a built-in notched display.

Clicking the widget's content area reloads the latest snapshot the app has cached — useful after the app has polled, before macOS asks for a new widget timeline. The click never fetches from OpenAI, never starts or activates the app, and never writes the snapshot: it only asks WidgetKit for a fresh timeline, which re-reads the cache. The system content margin around the content (roughly the outer 24pt of a Small widget) is not part of that click area; tapping there uses the system's default widget tap, which opens CodexSatellites — the same thing a tap anywhere on the widget did before. If the app has never run and no snapshot exists, the widget keeps showing `—`.

## Interaction

- Hover → both satellites expand and show remaining percentages.
- Click either satellite → a compact icon-only Settings Bar appears.
- Click the widget's content area → reloads the latest quota snapshot the app cached, with no network request and no app launch.
- Settings Bar → icon-only Launch at Login, refresh frequency, available reset count, and Quit controls.
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

The release script reads signing and notarization identity from the local environment and Keychain. It never stores credentials in the repository. Generated artifacts and release evidence live under the ignored `dist/` directory.

## Known limitations

- Codex usage currently depends on an undocumented ChatGPT usage endpoint.
- Full-screen Space behavior is a v0.1 compatibility limitation unless explicitly validated.
- The app assumes an existing local Codex login and does not manage authentication.
- Notifications require a signed build and the app to be running.
- Notifications are English-only and have no in-app toggle — use macOS System Settings → Notifications.
- The widget requires a code-signed build to be registered by macOS; both `./script/build_and_run.sh` and `./script/release.sh preview` ad-hoc sign locally, so the widget can be tested without a Developer ID.
- The widget extension is sandboxed (a macOS requirement) and reads only the snapshot the app publishes; it never reads Codex auth or calls the usage endpoint.
- On macOS, an already-running widget extension may keep using the previous widget code after CodexSatellites is updated, even though the installed app and widget extension report a newer build number. This was observed during local ad-hoc upgrade testing: widget data kept refreshing, but presentation changes did not appear until macOS recycled the widget extension process. There is no public API that guarantees recycling; restarting the WidgetKit host or logging out may create a fresh process. Developer ID upgrade behaviour remains to be verified.

## License

CodexSatellites is released under the [MIT License](LICENSE).
