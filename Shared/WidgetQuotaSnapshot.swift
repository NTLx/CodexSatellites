import Foundation
import OSLog

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

/// How the snapshot travels from the app to the widget extension.
enum WidgetSnapshotTransport: String, CaseIterable, Sendable {
    case widgetContainer
    case appGroup
}

enum WidgetSnapshotError: Error {
    case decodeFailed
    case encodeFailed
}

/// Hand-off between the non-sandboxed app and the sandboxed widget extension.
///
/// On macOS 15+ App Group containers are protected and membership must be
/// authorized by the code-signing/provisioning model. An ad-hoc build has
/// neither a provisioning profile authorizing a registered `group.*` App Group
/// nor a Developer Team ID usable with a team-prefixed macOS App Group, so the
/// widget extension's read of the group container is denied by TCC
/// (`kTCCServiceSystemPolicyAppData`).
///
/// Ad-hoc preview builds therefore hand the snapshot off through the widget
/// extension's own sandbox container: the non-sandboxed app writes into
/// `~/Library/Containers/<widget-id>/Data/Documents`, and the widget reads it
/// as its own data. This is a development compatibility workaround, not the
/// production sharing architecture; a Developer ID build with a provisioned
/// `group.io.github.ntlx.codexsatellites` switches `activeTransport` to
/// `.appGroup`.
enum WidgetSnapshotStore {
    static let appGroupIdentifier = "group.io.github.ntlx.codexsatellites"
    static let widgetBundleIdentifier = "io.github.ntlx.codexsatellites.widget"
    static let widgetKind = "CodexSatellitesWidget"

    /// Preview / ad-hoc builds use the widget extension's own container. Switch
    /// this to `.appGroup` once a Developer ID build provisions the App Group.
    static let activeTransport: WidgetSnapshotTransport = .widgetContainer

    private static let fileName = "quota-snapshot.json"
    private static let logger = Logger(
        subsystem: "io.github.ntlx.codexsatellites.widget",
        category: "snapshot"
    )

    /// Writer side (non-sandboxed app): its home directory is the real home, so
    /// the widget extension's container is addressed explicitly.
    private static func writeURL(for transport: WidgetSnapshotTransport) -> URL? {
        switch transport {
        case .widgetContainer:
            return FileManager.default
                .homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers", isDirectory: true)
                .appendingPathComponent(widgetBundleIdentifier, isDirectory: true)
                .appendingPathComponent("Data/Documents", isDirectory: true)
                .appendingPathComponent(fileName, isDirectory: false)
        case .appGroup:
            return FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
                .appendingPathComponent(fileName, isDirectory: false)
        }
    }

    /// Reader side (sandboxed widget): its home directory already is its own
    /// sandbox container, so `.widgetContainer` resolves to its own Documents.
    private static func readURL(for transport: WidgetSnapshotTransport) -> URL? {
        switch transport {
        case .widgetContainer:
            return FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent(fileName, isDirectory: false)
        case .appGroup:
            return FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
                .appendingPathComponent(fileName, isDirectory: false)
        }
    }

    static func load() -> WidgetQuotaSnapshot? {
        var snapshots: [WidgetQuotaSnapshot] = []
        for transport in WidgetSnapshotTransport.allCases {
            guard let url = readURL(for: transport) else {
                log("load", transport, "unavailable")
                continue
            }
            switch decode(at: url) {
            case let .success(snapshot):
                log("load", transport, "success")
                snapshots.append(snapshot)
            case let .failure(error):
                if isMissingFile(error) {
                    log("load", transport, "missing")
                } else {
                    logError("load", transport, error)
                }
            }
        }
        return newestSnapshot(from: snapshots)
    }

    static func save(_ snapshot: WidgetQuotaSnapshot) {
        guard let url = writeURL(for: activeTransport) else {
            logError("save", activeTransport, CocoaError(.fileNoSuchFile))
            return
        }
        switch encode(snapshot, to: url) {
        case .success:
            log("save", activeTransport, "success")
        case let .failure(error):
            logError("save", activeTransport, error)
        }
    }

    static func clear() {
        for transport in WidgetSnapshotTransport.allCases {
            guard let url = writeURL(for: transport) else { continue }
            try? FileManager.default.removeItem(at: url)
            log("clear", transport, "done")
        }
    }

    /// When more than one transport holds a snapshot, the newest `fetchedAt`
    /// wins so a stale file can never shadow fresh data during a migration.
    static func newestSnapshot(from snapshots: [WidgetQuotaSnapshot]) -> WidgetQuotaSnapshot? {
        snapshots.max { $0.fetchedAt < $1.fetchedAt }
    }

    private static func decode(at url: URL) -> Result<WidgetQuotaSnapshot, Error> {
        do {
            let data = try Data(contentsOf: url)
            guard let snapshot = decodeSnapshot(from: data) else {
                return .failure(WidgetSnapshotError.decodeFailed)
            }
            return .success(snapshot)
        } catch {
            return .failure(error)
        }
    }

    private static func encode(_ snapshot: WidgetQuotaSnapshot, to url: URL) -> Result<Void, Error> {
        do {
            guard let data = encodeSnapshot(snapshot) else {
                return .failure(WidgetSnapshotError.encodeFailed)
            }
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    static func decodeSnapshot(from data: Data) -> WidgetQuotaSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetQuotaSnapshot.self, from: data)
    }

    static func encodeSnapshot(_ snapshot: WidgetQuotaSnapshot) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(snapshot)
    }

    private static func isMissingFile(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoSuchFileError
    }

    private static func log(
        _ operation: String,
        _ transport: WidgetSnapshotTransport,
        _ result: String
    ) {
        logger.info("snapshot operation=\(operation, privacy: .public) transport=\(transport.rawValue, privacy: .public) result=\(result, privacy: .public)")
    }

    private static func logError(
        _ operation: String,
        _ transport: WidgetSnapshotTransport,
        _ error: Error
    ) {
        let nsError = error as NSError
        logger.error("snapshot operation=\(operation, privacy: .public) transport=\(transport.rawValue, privacy: .public) result=failure error=\(nsError.domain, privacy: .public)#\(nsError.code, privacy: .public)")
    }
}
