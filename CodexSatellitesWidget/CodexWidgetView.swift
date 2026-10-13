import AppKit
import SwiftUI
import WidgetKit

struct CodexWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: CodexWidgetEntry

    var body: some View {
        quotaFace
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(for: .widget) {
                Color(nsColor: .windowBackgroundColor)
            }
    }

    private var quotaFace: some View {
        Button(intent: RefreshCachedQuotaIntent()) {
            quotaContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "Refresh Codex widget information"))
        .accessibilityHint(Text(verbatim: "Reloads cached quota information and checks whether CodexSatellites is currently running."))
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
}

struct WidgetStatusRow: View {
    let availableResetCount: Int?
    let isAppRunning: Bool?

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                Text(verbatim: "Reset")
                Text(verbatim: availableResetCount.map(String.init) ?? "—")
                    .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "Available Reset Count"))
            .accessibilityValue(Text(verbatim: availableResetCount.map(String.init) ?? "Unavailable"))

            Spacer(minLength: 4)

            HStack(spacing: 3) {
                Image(systemName: appStatusSymbol)
                    .imageScale(.small)
                Text(verbatim: appStatusText)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "CodexSatellites App Status"))
            .accessibilityValue(Text(verbatim: appStatusAccessibilityValue))
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var appStatusSymbol: String {
        switch isAppRunning {
        case true: "circle.fill"
        case false: "circle"
        case nil: "questionmark.circle"
        }
    }

    private var appStatusText: String {
        switch isAppRunning {
        case true: "Running"
        case false: "Stopped"
        case nil: "—"
        }
    }

    private var appStatusAccessibilityValue: String {
        switch isAppRunning {
        case true: "Running"
        case false: "Not Running"
        case nil: "Unavailable"
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
