import Foundation
import OSLog

enum WidgetSnapshotFreshness: String, Codable, Sendable {
    case fresh
    case stale
}

/// Codable projection of the app's quota state shared with the widget extension.
/// The main app is the only writer; the widget is a read-only presentation layer.
///
/// This payload is a rolling-upgrade IPC contract: after an app update, an older
/// widget build may still be reading while the newer app writes. New fields must
/// therefore stay optional, and existing fields must not be removed, retyped, or
/// repurposed. Bump `currentSchemaVersion` only for a breaking change.
struct WidgetQuotaSnapshot: Codable, Equatable, Sendable {
    /// Version implied by a payload that predates the `schemaVersion` field.
    /// It must stay fixed so a future `currentSchemaVersion` bump cannot make a
    /// legacy payload look newer than it is.
    static let legacySchemaVersion = 1
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let fiveHourRemainingPercent: Double?
    let weeklyRemainingPercent: Double?
    let fiveHourResetsAt: Date?
    let weeklyResetsAt: Date?
    let fetchedAt: Date
    let freshness: WidgetSnapshotFreshness

    init(
        schemaVersion: Int = WidgetQuotaSnapshot.currentSchemaVersion,
        fiveHourRemainingPercent: Double?,
        weeklyRemainingPercent: Double?,
        fiveHourResetsAt: Date?,
        weeklyResetsAt: Date?,
        fetchedAt: Date,
        freshness: WidgetSnapshotFreshness
    ) {
        self.schemaVersion = schemaVersion
        self.fiveHourRemainingPercent = fiveHourRemainingPercent
        self.weeklyRemainingPercent = weeklyRemainingPercent
        self.fiveHourResetsAt = fiveHourResetsAt
        self.weeklyResetsAt = weeklyResetsAt
        self.fetchedAt = fetchedAt
        self.freshness = freshness
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? Self.legacySchemaVersion
        guard version <= Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "unsupported snapshot schema version \(version)"
            )
        }
        self.init(
            schemaVersion: version,
            fiveHourRemainingPercent: try container.decodeIfPresent(Double.self, forKey: .fiveHourRemainingPercent),
            weeklyRemainingPercent: try container.decodeIfPresent(Double.self, forKey: .weeklyRemainingPercent),
            fiveHourResetsAt: try container.decodeIfPresent(Date.self, forKey: .fiveHourResetsAt),
            weeklyResetsAt: try container.decodeIfPresent(Date.self, forKey: .weeklyResetsAt),
            fetchedAt: try container.decode(Date.self, forKey: .fetchedAt),
            freshness: try container.decode(WidgetSnapshotFreshness.self, forKey: .freshness)
        )
    }
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

    /// Fields the widget actually renders. `fetchedAt` is excluded so a refresh
    /// that changes nothing visible does not spend a timeline reload.
    func hasSameDisplayedContent(as other: WidgetQuotaSnapshot) -> Bool {
        fiveHourRemainingPercent == other.fiveHourRemainingPercent
            && weeklyRemainingPercent == other.weeklyRemainingPercent
            && fiveHourResetsAt == other.fiveHourResetsAt
            && weeklyResetsAt == other.weeklyResetsAt
            && freshness == other.freshness
    }
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
/// neither a provisioning profile authorizing the registered `group.*` App Group
/// nor a Developer Team ID usable with a team-prefixed macOS App Group, so the
/// widget extension's read of the group container is denied by TCC
/// (`kTCCServiceSystemPolicyAppData`).
///
/// Ad-hoc preview builds therefore hand the snapshot off through the widget
/// extension's own sandbox container: the non-sandboxed app writes into
/// `~/Library/Containers/<widget-id>/Data/Documents`, and the widget reads it
/// as its own data. This is a development compatibility workaround, not the
/// production sharing architecture.
///
/// `activeTransport` is the single source of truth. In `.widgetContainer` mode
/// the App Group container is never resolved, read, or deleted, so the widget
/// hot path can never trigger the TCC denial. Only a provisioned `.appGroup`
/// build may fall back to the legacy preview snapshot for migration.
enum WidgetSnapshotStore {
    static let appGroupIdentifier = "group.io.github.ntlx.codexsatellites"
    static let widgetBundleIdentifier = "io.github.ntlx.codexsatellites.widget"
    static let widgetKind = "CodexSatellitesWidget"

    /// Preview / ad-hoc builds use the widget extension's own container. Switch
    /// this to `.appGroup` manually once a Developer ID build provisions the
    /// App Group.
    static let activeTransport: WidgetSnapshotTransport = .widgetContainer

    private static let fileName = "quota-snapshot.json"
    private static let logger = Logger(
        subsystem: "io.github.ntlx.codexsatellites.widget",
        category: "snapshot"
    )

    /// Transports the widget may read, in priority order.
    static func readableTransports(for transport: WidgetSnapshotTransport) -> [WidgetSnapshotTransport] {
        transport == .appGroup ? [.appGroup, .widgetContainer] : [.widgetContainer]
    }

    static func load() -> WidgetQuotaSnapshot? {
        for transport in readableTransports(for: activeTransport) {
            if let snapshot = load(from: transport) {
                return snapshot
            }
        }
        return nil
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
        guard let url = writeURL(for: activeTransport) else { return }
        try? FileManager.default.removeItem(at: url)
        log("clear", activeTransport, "done")
    }

    private static func load(from transport: WidgetSnapshotTransport) -> WidgetQuotaSnapshot? {
        guard let url = readURL(for: transport) else {
            log("load", transport, "unavailable")
            return nil
        }
        switch decode(at: url) {
        case let .success(snapshot):
            log("load", transport, "success")
            return snapshot
        case let .failure(error):
            if isMissingFile(error) {
                log("load", transport, "missing")
            } else {
                logError("load", transport, error)
            }
            return nil
        }
    }

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
