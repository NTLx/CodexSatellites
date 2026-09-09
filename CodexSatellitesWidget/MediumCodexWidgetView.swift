import SwiftUI

struct MediumCodexWidgetView: View {
    let entry: CodexWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "Codex")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                WidgetUpdateLabel(fetchedAt: snapshot?.fetchedAt)
            }

            Spacer(minLength: 10)

            HStack(alignment: .top, spacing: 0) {
                metricColumn(
                    title: "5-hour",
                    remainingPercent: snapshot?.fiveHourRemainingPercent,
                    resetsAt: snapshot?.fiveHourResetsAt
                )
                metricColumn(
                    title: "Weekly",
                    remainingPercent: snapshot?.weeklyRemainingPercent,
                    resetsAt: snapshot?.weeklyResetsAt
                )
            }
            .frame(maxWidth: .infinity)
            .opacity(quotaOpacity)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func metricColumn(
        title: String,
        remainingPercent: Double?,
        resetsAt: Date?
    ) -> some View {
        VStack(spacing: 6) {
            WidgetQuotaGauge(title: title, remainingPercent: remainingPercent)
            VStack(spacing: 2) {
                Text(verbatim: title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                resetLabel(resetsAt)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func resetLabel(_ resetsAt: Date?) -> some View {
        if let resetsAt {
            HStack(spacing: 3) {
                Text(verbatim: "Reset")
                Text(verbatim: Date.RelativeFormatStyle.widgetRelative.format(resetsAt))
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        } else {
            Text(verbatim: "—")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var snapshot: WidgetQuotaSnapshot? { entry.snapshot }

    private var quotaOpacity: Double {
        snapshot?.freshness == .stale ? 0.72 : 1
    }
}
