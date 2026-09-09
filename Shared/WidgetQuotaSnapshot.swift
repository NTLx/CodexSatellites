import Foundation

enum WidgetSnapshotFreshness: String, Codable, Sendable {
    case fresh
    case stale
}

/// Codable projection of the app's quota state shared with the widget extension.
/// The main app is the only writer; the widget is a read-only presentation layer.
struct WidgetQuotaSnapshot: Codable, Equatable, Sendable {
    let fiveHourRemainingPercent: Double?
    let weeklyRemainingPercent: Double?
    let fiveHourResetsAt: Date?
    let weeklyResetsAt: Date?
    let fetchedAt: Date
    let freshness: WidgetSnapshotFreshness
}

extension WidgetQuotaSnapshot {
    static let placeholder = WidgetQuotaSnapshot(
        fiveHourRemainingPercent: 73,
        weeklyRemainingPercent: 42,
        fiveHourResetsAt: nil,
        weeklyResetsAt: nil,
        fetchedAt: Date(),
        freshness: .fresh
    )
}

/// Hand-off between the non-sandboxed app and the sandboxed widget extension.
///
/// App Group containers are TCC-protected unless the group ID carries the
/// signing team ID prefix, which an ad-hoc signed build cannot provide: on this
/// platform the widget's read of the group container is denied by
/// `kTCCServiceSystemPolicyAppData`. The snapshot is therefore handed off
/// through the widget extension's own sandbox container — the non-sandboxed app
/// writes into `~/Library/Containers/<widget-id>/Data/Documents`, and the
/// sandboxed widget reads it as its own data.
///
/// The App Group path is still written and read as a fallback so a future
/// Developer ID build with a team-prefixed group keeps working unchanged.
enum WidgetSnapshotStore {
    static let appGroupIdentifier = "group.io.github.ntlx.codexsatellites"
    static let widgetBundleIdentifier = "io.github.ntlx.codexsatellites.widget"
    static let widgetKind = "CodexSatellitesWidget"

    private static let fileName = "quota-snapshot.json"

    /// Writer side (non-sandboxed app): the widget extension's own container.
    private static var widgetContainerFileURL: URL? {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers", isDirectory: true)
            .appendingPathComponent(widgetBundleIdentifier, isDirectory: true)
            .appendingPathComponent("Data/Documents", isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    /// Reader side (sandboxed widget): its own Documents directory.
    private static var ownContainerFileURL: URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(fileName, isDirectory: false)
    }

    private static var appGroupFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(fileName, isDirectory: false)
    }

    static func load() -> WidgetQuotaSnapshot? {
        for url in [ownContainerFileURL, appGroupFileURL].compactMap({ $0 }) {
            if let snapshot = decode(at: url) {
                return snapshot
            }
        }
        return nil
    }

    static func save(_ snapshot: WidgetQuotaSnapshot) {
        for url in [widgetContainerFileURL, appGroupFileURL].compactMap({ $0 }) {
            encode(snapshot, to: url)
        }
    }

    static func clear() {
        for url in [widgetContainerFileURL, appGroupFileURL].compactMap({ $0 }) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func decode(at url: URL) -> WidgetQuotaSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetQuotaSnapshot.self, from: data)
    }

    private static func encode(_ snapshot: WidgetQuotaSnapshot, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
    }
}
