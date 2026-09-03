import SwiftUI

enum QuotaOrbSide: Sendable {
    case left
    case right
}

enum OrbFreshness: Sendable {
    case fresh
    case stale
    case unavailable
}

struct QuotaOrbView: View {
    let remainingPercent: Double?
    let freshness: OrbFreshness
    let expanded: Bool
    let side: QuotaOrbSide

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let diameter: CGFloat = 14
    private let lineWidth: CGFloat = 2.25

    var body: some View {
        HStack(spacing: 4) {
            if side == .left {
                orb
                if expanded {
                    percentageText
                }
            } else {
                if expanded {
                    percentageText
                }
                orb
            }
        }
        .padding(.horizontal, lineWidth / 2)
        .frame(width: expanded ? 60 : diameter + lineWidth, height: 24, alignment: .leading)
        .opacity(opacity)
        .animation(reduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: 0.2), value: expanded)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(side == .left ? "Codex five hour remaining" : "Codex weekly remaining")
        .accessibilityValue(displayValue)
    }

    private var orb: some View {
        ZStack {
            if freshness == .unavailable {
                Circle()
                    .stroke(Color.primary.opacity(0.55), lineWidth: lineWidth)
            } else if let remainingPercent {
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(remainingPercent / 100, 0), 1)))
                    .stroke(Color.primary.opacity(0.9), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private var percentageText: some View {
        Text(displayValue)
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.primary)
            .monospacedDigit()
            .fixedSize()
    }

    private var displayValue: String {
        guard let remainingPercent else { return "—" }
        return "\(Int(remainingPercent.rounded()))%"
    }

    private var opacity: Double {
        switch freshness {
        case .fresh:
            return 0.9
        case .stale:
            return 0.5
        case .unavailable:
            return 0.6
        }
    }
}
