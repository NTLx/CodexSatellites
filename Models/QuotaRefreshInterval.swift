import Foundation

enum QuotaRefreshInterval: Int, CaseIterable, Sendable {
    case oneMinute = 1
    case fiveMinutes = 5
    case fifteenMinutes = 15

    var duration: Duration {
        .seconds(rawValue * 60)
    }

    var displayText: String {
        "\(rawValue)m"
    }

    var next: Self {
        switch self {
        case .oneMinute:
            return .fiveMinutes
        case .fiveMinutes:
            return .fifteenMinutes
        case .fifteenMinutes:
            return .oneMinute
        }
    }
}
