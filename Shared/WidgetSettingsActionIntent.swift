import AppIntents

extension WidgetSettingsAction: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget Settings Action"

    static var caseDisplayRepresentations: [WidgetSettingsAction: DisplayRepresentation] = [
        .toggleLaunchAtLogin: "Toggle Launch at Login",
        .advanceRefreshInterval: "Advance Refresh Interval",
        .reviewLoginItems: "Review Login Items",
        .quit: "Quit CodexSatellites"
    ]
}

struct WidgetSettingsActionIntent: AppIntent {
    static var title: LocalizedStringResource { "Change CodexSatellites Setting" }
    static var isDiscoverable: Bool { false }
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Action")
    var action: WidgetSettingsAction

    init() {
        action = .toggleLaunchAtLogin
    }

    init(action: WidgetSettingsAction) {
        self.action = action
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        await WidgetSettingsActionRouter.shared.dispatch(action)
        return .result()
    }
}
