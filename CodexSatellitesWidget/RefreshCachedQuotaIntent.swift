import AppIntents
import OSLog

/// Clicking the widget performs no work on purpose: no network request, no Codex
/// auth read, no app launch, no snapshot write. WidgetKit reloads the timeline
/// after a button interaction, and that reload re-runs `CodexWidgetProvider`,
/// which re-reads the snapshot the app cached.
struct RefreshCachedQuotaIntent: AppIntent {
    static var title: LocalizedStringResource { "Refresh Codex Quota" }

    /// Nothing to configure, so it stays out of the Shortcuts action list.
    static var isDiscoverable: Bool { false }

    private static let logger = Logger(
        subsystem: "io.github.ntlx.codexsatellites.widget",
        category: "intent"
    )

    func perform() async throws -> some IntentResult {
        Self.logger.info("intent operation=refresh result=noop")
        return .result()
    }
}
