import Foundation
import OSLog

enum WidgetLaunchAtLoginState: String, Codable, Sendable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
}

/// App-owned settings state projected to the widget extension.
/// The widget is a read-only consumer of this payload.
struct WidgetSettingsSnapshot: Codable, Equatable, Sendable {
    static let legacySchemaVersion = 1
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let launchAtLoginState: WidgetLaunchAtLoginState
    let refreshIntervalMinutes: Int
    let availableResetCount: Int?

    init(
        schemaVersion: Int = WidgetSettingsSnapshot.currentSchemaVersion,
        launchAtLoginState: WidgetLaunchAtLoginState,
        refreshIntervalMinutes: Int,
        availableResetCount: Int?
    ) {
        self.schemaVersion = schemaVersion
        self.launchAtLoginState = launchAtLoginState
        self.refreshIntervalMinutes = refreshIntervalMinutes
        self.availableResetCount = availableResetCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? Self.legacySchemaVersion
        guard version <= Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "unsupported settings snapshot schema version \(version)"
            )
        }
        self.init(
            schemaVersion: version,
            launchAtLoginState: try container.decode(WidgetLaunchAtLoginState.self, forKey: .launchAtLoginState),
            refreshIntervalMinutes: try container.decode(Int.self, forKey: .refreshIntervalMinutes),
            availableResetCount: try container.decodeIfPresent(Int.self, forKey: .availableResetCount)
        )
    }
}

extension WidgetSettingsSnapshot {
    static let placeholder = WidgetSettingsSnapshot(
        launchAtLoginState: .unavailable,
        refreshIntervalMinutes: 1,
        availableResetCount: nil
    )
}

/// Uses the same transport policy as `WidgetSnapshotStore`, but a separate file
/// so quota data and settings state remain independent contracts.
enum WidgetSettingsSnapshotStore {
    private static let fileName = "settings-snapshot.json"
    private static let logger = Logger(
        subsystem: "io.github.ntlx.codexsatellites.widget",
        category: "settings-snapshot"
    )

    static var activeTransport: WidgetSnapshotTransport {
        WidgetSnapshotStore.activeTransport
    }

    static func load() -> WidgetSettingsSnapshot? {
        for transport in WidgetSnapshotStore.readableTransports(for: activeTransport) {
            guard let url = readURL(for: transport) else {
                log("load", transport, "unavailable")
                continue
            }
            do {
                let data = try Data(contentsOf: url)
                guard let snapshot = decodeSnapshot(from: data) else {
                    log("load", transport, "decodeFailed")
                    continue
                }
                log("load", transport, "success")
                return snapshot
            } catch {
                if isMissingFile(error) {
                    log("load", transport, "missing")
                } else {
                    log("load", transport, "failed")
                }
            }
        }
        return nil
    }

    static func save(_ snapshot: WidgetSettingsSnapshot) {
        guard let url = writeURL(for: activeTransport),
              let data = encodeSnapshot(snapshot) else {
            log("save", activeTransport, "unavailable")
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            log("save", activeTransport, "success")
        } catch {
            log("save", activeTransport, "failed")
        }
    }

    static func decodeSnapshot(from data: Data) -> WidgetSettingsSnapshot? {
        try? JSONDecoder().decode(WidgetSettingsSnapshot.self, from: data)
    }

    static func encodeSnapshot(_ snapshot: WidgetSettingsSnapshot) -> Data? {
        try? JSONEncoder().encode(snapshot)
    }

    private static func writeURL(for transport: WidgetSnapshotTransport) -> URL? {
        switch transport {
        case .widgetContainer:
            return FileManager.default
                .homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers", isDirectory: true)
                .appendingPathComponent(WidgetSnapshotStore.widgetBundleIdentifier, isDirectory: true)
                .appendingPathComponent("Data/Documents", isDirectory: true)
                .appendingPathComponent(fileName, isDirectory: false)
        case .appGroup:
            return FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshotStore.appGroupIdentifier)?
                .appendingPathComponent(fileName, isDirectory: false)
        }
    }

    private static func readURL(for transport: WidgetSnapshotTransport) -> URL? {
        switch transport {
        case .widgetContainer:
            return FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent(fileName, isDirectory: false)
        case .appGroup:
            return FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshotStore.appGroupIdentifier)?
                .appendingPathComponent(fileName, isDirectory: false)
        }
    }

    private static func isMissingFile(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoSuchFileError
    }

    private static func log(_ operation: String, _ transport: WidgetSnapshotTransport, _ result: String) {
        logger.info("operation=\(operation, privacy: .public) transport=\(transport.rawValue, privacy: .public) result=\(result, privacy: .public)")
    }
}
