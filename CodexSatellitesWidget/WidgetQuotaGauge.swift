import SwiftUI

struct WidgetQuotaGauge: View {
    let title: String
    let remainingPercent: Double?

    private let diameter: CGFloat = 52

    var body: some View {
        Group {
            if let remainingPercent {
                Gauge(
                    value: min(max(remainingPercent, 0), 100),
                    in: 0...100
                ) {
                    Text(verbatim: title)
                } currentValueLabel: {
                    Text("\(Int(remainingPercent.rounded()))%")
                        .monospacedDigit()
                        .contentTransition(.numericText(value: remainingPercent))
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(.primary)
                .widgetAccentable()
            } else {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.22), lineWidth: 4)
                    Text(verbatim: "—")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        guard let remainingPercent else {
            return "Unavailable"
        }
        return "\(Int(remainingPercent.rounded()))%"
    }
}
