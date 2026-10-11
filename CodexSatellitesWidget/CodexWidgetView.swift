import AppKit
import SwiftUI
import WidgetKit

struct CodexWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let entry: CodexWidgetEntry

    var body: some View {
        face
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: reduceMotion ? 0.18 : 0.35), value: entry.face)
            .containerBackground(for: .widget) {
                Color(nsColor: .windowBackgroundColor)
            }
    }

    @ViewBuilder
    private var face: some View {
        switch entry.face {
        case .quota:
            quotaFace
                .transition(quotaTransition)
        case .settings:
            WidgetSettingsFaceView(entry: entry, family: presentationFamily)
                .transition(settingsTransition)
        }
    }

    private var quotaFace: some View {
        ZStack(alignment: .topTrailing) {
            Button(intent: RefreshCachedQuotaIntent()) {
                quotaContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: "Refresh Codex quota"))
            .accessibilityHint(Text(verbatim: "Reloads the quota snapshot cached by the CodexSatellites app."))

            Button(intent: SetWidgetFaceIntent(family: presentationFamily, face: .settings)) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .background(Circle().fill(Color.primary.opacity(0.08)))
            .overlay {
                Circle().stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
            }
            .accessibilityLabel(Text(verbatim: "Settings"))
            .accessibilityHint(Text(verbatim: "Shows CodexSatellites settings in this widget."))
        }
    }

    @ViewBuilder
    private var quotaContent: some View {
        switch family {
        case .systemMedium:
            MediumCodexWidgetView(entry: entry)
        default:
            SmallCodexWidgetView(entry: entry)
        }
    }

    private var presentationFamily: WidgetPresentationFamily {
        family == .systemMedium ? .medium : .small
    }

    private var quotaTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .modifier(
                active: WidgetFlipModifier(angle: 90),
                identity: WidgetFlipModifier(angle: 0)
            ),
            removal: .modifier(
                active: WidgetFlipModifier(angle: -90),
                identity: WidgetFlipModifier(angle: 0)
            )
        )
    }

    private var settingsTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .modifier(
                active: WidgetFlipModifier(angle: -90),
                identity: WidgetFlipModifier(angle: 0)
            ),
            removal: .modifier(
                active: WidgetFlipModifier(angle: 90),
                identity: WidgetFlipModifier(angle: 0)
            )
        )
    }
}

private struct WidgetFlipModifier: ViewModifier {
    let angle: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.7
            )
            .opacity(max(0, 1 - abs(angle) / 90))
    }
}

struct WidgetStaleLabel: View {
    let freshness: WidgetSnapshotFreshness?

    var body: some View {
        if freshness == .stale {
            Text(verbatim: "Stale")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }
}

extension Date.RelativeFormatStyle {
    /// Abbreviated English relative time (`2 min ago`, `in 2 hr`). The widget is
    /// English-only, so the locale is pinned instead of following the system.
    static var widgetRelative: Date.RelativeFormatStyle {
        Date.RelativeFormatStyle(
            presentation: .numeric,
            unitsStyle: .abbreviated,
            locale: Locale(identifier: "en_US")
        )
    }
}
