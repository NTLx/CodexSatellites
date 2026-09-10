import AppKit
import SwiftUI
import WidgetKit

struct CodexWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: CodexWidgetEntry

    var body: some View {
        Button(intent: RefreshCachedQuotaIntent()) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "Refresh Codex quota"))
        .accessibilityHint(Text(verbatim: "Reloads the quota snapshot cached by the CodexSatellites app."))
        .containerBackground(for: .widget) {
            Color(nsColor: .windowBackgroundColor)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium:
            MediumCodexWidgetView(entry: entry)
        default:
            SmallCodexWidgetView(entry: entry)
        }
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
