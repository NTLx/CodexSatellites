---
name: build-macos-apps
description: Build, run, test, debug, instrument, and ship native macOS apps and Swift packages with Xcode, SwiftUI, and AppKit. Use when a task involves a macOS app or package — build/launch/crash or linker failures, test triage, Logger telemetry, SwiftUI scenes and window chrome, AppKit bridges, code signing and entitlements, or archive/notarization readiness. Not for iOS/watchOS/tvOS, desktop UI automation, or App Store Connect release management.
metadata:
  short-description: Build, debug, and ship macOS apps
---

# Build macOS Apps

macOS-first development workflows for Xcode projects and Swift packages.
Read the router, then open only the references that match the current task.

## When to use

- The repo is a macOS app or Swift package, or the task is about desktop-only behavior.
- The failure is desktop-specific: build, launch, crash, linker, codesign, Gatekeeper, sandbox, hardened runtime.
- The work is UI structure: SwiftUI scenes, windows, toolbars, settings, menus, split views, inspectors, Liquid Glass.
- The task is shipping rather than merely running locally: archive, export, notarization.

## When not to use

- iOS / watchOS / tvOS targets or simulators.
- Desktop UI automation.
- App Store Connect release management.
- Generic Swift questions with no macOS or desktop angle.

## Routing

| Situation | Read |
|---|---|
| Discover the project, build/run it, or debug a build, startup, or runtime failure | `references/build-run-debug.md` |
| Create or fix the project-local `script/build_and_run.sh` and `.codex/environments/environment.toml` run button | `references/build-run-debug/run-button-bootstrap.md` |
| Run tests and explain failures by category | `references/test-triage.md` |
| Codesign, entitlements, sandbox, hardened runtime, Gatekeeper, trust failures | `references/signing-entitlements.md` |
| Archive, export, notarization, or distribution-only failures | `references/packaging-notarization.md` |
| `Package.swift`-first repos: build, run, and test SwiftPM products | `references/swiftpm-macos.md` |
| SwiftUI scenes, commands, toolbars, settings, split views, inspectors | `references/swiftui-patterns.md`, then `references/swiftui-patterns/components-index.md` |
| Adopt the modern macOS design system / Liquid Glass, remove fighting custom chrome | `references/liquid-glass.md` |
| Window chrome, drag regions, placement, restoration, borderless windows | `references/window-management.md`, plus `references/window-management/api-snippets.md` |
| Bridge into AppKit: representables, NSWindow/panels, menus, responder chain, drag/drop | `references/appkit-interop.md`, plus the files under `references/appkit-interop/` |
| Split oversized SwiftUI views, tighten scene state, narrow AppKit escapes | `references/view-refactor.md` |
| Add `Logger`/`os.Logger` instrumentation and verify events with Console or `log stream` | `references/telemetry.md` |

### Named workflows

Thin command-style workflows, useful when the task is exactly one of these:

- `references/commands/build-and-run-macos-app.md`
- `references/commands/test-macos-app.md`
- `references/commands/fix-codesign-error.md`

## Working rules

- Establish the real blocker before changing code: build output, `log stream`, crash report, `codesign -dv`, or the failing test — not a guess.
- Run the smallest meaningful scope first, then widen.
- Prefer native macOS frameworks. Do not add third-party runtime dependencies without explicit owner approval.
- Keep SwiftUI as the source of truth; reach for AppKit only at the narrow edges where desktop behavior requires it.
- Do not claim manual, signing, or notarization checks passed unless they were actually executed. Report `NOT TESTED` otherwise.
- For this repository, follow `AGENTS.md` for build/test commands, product boundaries, and release invariants; do not restate or override them here.
