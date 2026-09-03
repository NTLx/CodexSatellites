import Foundation

struct QuotaWindow: Equatable, Sendable {
    let remainingPercent: Double
    let windowDurationSeconds: TimeInterval
    let resetsAt: Date?
}

struct CodexQuotaSnapshot: Equatable, Sendable {
    let fiveHour: QuotaWindow?
    let weekly: QuotaWindow?
    let fetchedAt: Date
}

enum SnapshotFreshness: Equatable, Sendable {
    case unavailable
    case fresh(CodexQuotaSnapshot)
    case stale(CodexQuotaSnapshot)

    var snapshot: CodexQuotaSnapshot? {
        switch self {
        case .unavailable:
            return nil
        case let .fresh(snapshot), let .stale(snapshot):
            return snapshot
        }
    }

    var isStale: Bool {
        if case .stale = self { return true }
        return false
    }
}

struct SnapshotStateMachine: Equatable, Sendable {
    private(set) var freshness: SnapshotFreshness = .unavailable

    mutating func applySuccess(_ snapshot: CodexQuotaSnapshot) {
        freshness = .fresh(snapshot)
    }

    mutating func applyFailure() {
        guard let snapshot = freshness.snapshot else {
            freshness = .unavailable
            return
        }
        freshness = .stale(snapshot)
    }
}

