import OSLog
import SwiftUI
import WidgetKit

struct CodexWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetQuotaSnapshot?
}

struct CodexWidgetProvider: TimelineProvider {
    private static let buildNumber = Bundle.main.object(
        forInfoDictionaryKey: "CFBundleVersion"
    ) as? String ?? "unknown"

    private let logger = Logger(
        subsystem: "io.github.ntlx.codexsatellites.widget",
        category: "timeline"
    )

    func placeholder(in context: Context) -> CodexWidgetEntry {
        CodexWidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CodexWidgetEntry) -> Void) {
        let snapshot = WidgetSnapshotStore.load() ?? .placeholder
        completion(CodexWidgetEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CodexWidgetEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.load()
        logger.info("timeline build=\(Self.buildNumber, privacy: .public) snapshot=\(snapshot == nil ? "missing" : "loaded", privacy: .public) freshness=\(snapshot?.freshness.rawValue ?? "none", privacy: .public)")
        let entry = CodexWidgetEntry(date: Date(), snapshot: snapshot)
        let next = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}
