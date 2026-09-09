import SwiftUI

struct SmallCodexWidgetView: View {
    let entry: CodexWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "Codex")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                WidgetStaleLabel(freshness: snapshot?.freshness)
            }

            Spacer(minLength: 8)

            HStack(alignment: .top, spacing: 0) {
                quotaColumn(title: "5-hour", remainingPercent: snapshot?.fiveHourRemainingPercent)
                quotaColumn(title: "Weekly", remainingPercent: snapshot?.weeklyRemainingPercent)
            }
            .frame(maxWidth: .infinity)
            .opacity(quotaOpacity)

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func quotaColumn(title: String, remainingPercent: Double?) -> some View {
        VStack(spacing: 4) {
            WidgetQuotaGauge(title: title, remainingPercent: remainingPercent)
            Text(verbatim: title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var snapshot: WidgetQuotaSnapshot? { entry.snapshot }

    private var quotaOpacity: Double {
        snapshot?.freshness == .stale ? 0.8 : 1
    }
}
