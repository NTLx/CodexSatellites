import AppIntents
import OSLog
import WidgetKit

/// Clicking the widget performs a local-only refresh: no network request, no Codex
/// auth read, no app launch, and no snapshot write. The explicit timeline reload
/// re-runs `CodexWidgetProvider`, which re-reads the app-owned cache and probes the
/// main app's current process state.
struct RefreshCachedQuotaIntent: AppIntent {
    static var title: LocalizedStringResource { "Refresh Codex Quota" }

    /// Nothing to configure, so it stays out of the Shortcuts action list.
    static var isDiscoverable: Bool { false }

    private static let logger = Logger(
        subsystem: "io.github.ntlx.codexsatellites.widget",
        category: "intent"
    )

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshotStore.widgetKind)
        Self.logger.info("intent operation=refresh result=reloadRequested")
        return .result()
    }
}
