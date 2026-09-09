import AppKit
import SwiftUI
import WidgetKit

struct CodexWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: CodexWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                MediumCodexWidgetView(entry: entry)
            default:
                SmallCodexWidgetView(entry: entry)
            }
        }
        .containerBackground(for: .widget) {
            Color(nsColor: .windowBackgroundColor)
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
