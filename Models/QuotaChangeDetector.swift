import Foundation

enum QuotaChangeEvent: Equatable, Sendable {
    case fiveHourReset
    case weeklyReset
    case fiveHourLow
    case weeklyLow
    case resetCreditsIncreased(from: Int, to: Int)
    case resetCreditsDecreased(from: Int, to: Int)

    var title: String {
        switch self {
        case .fiveHourReset:
            return "Codex 5-hour quota reset"
        case .weeklyReset:
            return "Codex weekly quota reset"
        case .fiveHourLow:
            return "Codex 5-hour quota is low"
        case .weeklyLow:
            return "Codex weekly quota is low"
        case .resetCreditsIncreased:
            return "Codex reset credit added"
        case .resetCreditsDecreased:
            return "Codex reset credit used"
        }
    }

    var body: String {
        switch self {
        case .fiveHourReset:
            return "Your 5-hour quota is back to 100%."
        case .weeklyReset:
            return "Your weekly quota is back to 100%."
        case .fiveHourLow:
            return "Less than 10% of the 5-hour quota remains."
        case .weeklyLow:
            return "Less than 10% of the weekly quota remains."
        case let .resetCreditsIncreased(_, to):
            return "You now have \(to) available reset credits."
        case let .resetCreditsDecreased(_, to):
            return "You now have \(to) available reset credits."
        }
    }
}

enum QuotaChangeDetector {
    static let lowThreshold: Double = 10

    static func events(
        previous: CodexQuotaSnapshot?,
        current: CodexQuotaSnapshot
    ) -> [QuotaChangeEvent] {
        guard let previous else { return [] }

        var events: [QuotaChangeEvent] = []

        if let previousWindow = previous.fiveHour,
           let currentWindow = current.fiveHour,
           previousWindow.remainingPercent < 100,
           currentWindow.remainingPercent >= 100 {
            events.append(.fiveHourReset)
        }
        if let previousWindow = previous.weekly,
           let currentWindow = current.weekly,
           previousWindow.remainingPercent < 100,
           currentWindow.remainingPercent >= 100 {
            events.append(.weeklyReset)
        }

        if let previousWindow = previous.fiveHour,
           let currentWindow = current.fiveHour,
           previousWindow.remainingPercent >= lowThreshold,
           currentWindow.remainingPercent < lowThreshold {
            events.append(.fiveHourLow)
        }
        if let previousWindow = previous.weekly,
           let currentWindow = current.weekly,
           previousWindow.remainingPercent >= lowThreshold,
           currentWindow.remainingPercent < lowThreshold {
            events.append(.weeklyLow)
        }

        if let previousCount = previous.availableResetCount,
           let currentCount = current.availableResetCount,
           previousCount != currentCount {
            if currentCount > previousCount {
                events.append(.resetCreditsIncreased(from: previousCount, to: currentCount))
            } else {
                events.append(.resetCreditsDecreased(from: previousCount, to: currentCount))
            }
        }

        return events
    }
}
