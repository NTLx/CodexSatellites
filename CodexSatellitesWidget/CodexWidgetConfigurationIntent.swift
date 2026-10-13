import AppIntents

enum WidgetRefreshIntervalOption: String, AppEnum, CaseIterable, Codable, Sendable {
    case oneMinute
    case fiveMinutes
    case fifteenMinutes

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Frequency")
    static let caseDisplayRepresentations: [WidgetRefreshIntervalOption: DisplayRepresentation] = [
        .oneMinute: DisplayRepresentation(title: "1 minute"),
        .fiveMinutes: DisplayRepresentation(title: "5 minutes"),
        .fifteenMinutes: DisplayRepresentation(title: "15 minutes")
    ]

    var minutes: Int {
        switch self {
        case .oneMinute: 1
        case .fiveMinutes: 5
        case .fifteenMinutes: 15
        }
    }

    init?(minutes: Int) {
        switch minutes {
        case 1: self = .oneMinute
        case 5: self = .fiveMinutes
        case 15: self = .fifteenMinutes
        default: return nil
        }
    }
}

struct CodexWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Codex Usage"
    static let description = IntentDescription("Configure CodexSatellites app settings from this widget.")
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Launch at Login", default: false)
    var launchAtLogin: Bool

    @Parameter(title: "Frequency", default: .oneMinute)
    var refreshInterval: WidgetRefreshIntervalOption

    init() {
        let snapshot = WidgetSettingsSnapshotStore.load()
        launchAtLogin = snapshot?.launchAtLoginState == .enabled
        refreshInterval = snapshot
            .flatMap { WidgetRefreshIntervalOption(minutes: $0.refreshIntervalMinutes) }
            ?? .oneMinute
    }

    init(launchAtLogin: Bool, refreshInterval: WidgetRefreshIntervalOption) {
        self.launchAtLogin = launchAtLogin
        self.refreshInterval = refreshInterval
    }
}
