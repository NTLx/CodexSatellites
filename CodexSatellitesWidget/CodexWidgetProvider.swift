import OSLog
import SwiftUI
import WidgetKit

struct CodexWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetQuotaSnapshot?
    let settingsSnapshot: WidgetSettingsSnapshot?
    let face: WidgetFace
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
        CodexWidgetEntry(
            date: Date(),
            snapshot: .placeholder,
            settingsSnapshot: .placeholder,
            face: .quota
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CodexWidgetEntry) -> Void) {
        completion(makeEntry(for: context, quotaFallback: .placeholder, settingsFallback: .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CodexWidgetEntry>) -> Void) {
        let entry = makeEntry(for: context)
        logger.info("timeline build=\(Self.buildNumber, privacy: .public) snapshot=\(entry.snapshot == nil ? "missing" : "loaded", privacy: .public) freshness=\(entry.snapshot?.freshness.rawValue ?? "none", privacy: .public) face=\(entry.face.rawValue, privacy: .public)")
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func makeEntry(
        for context: Context,
        quotaFallback: WidgetQuotaSnapshot? = nil,
        settingsFallback: WidgetSettingsSnapshot? = nil
    ) -> CodexWidgetEntry {
        let family = presentationFamily(for: context.family)
        return CodexWidgetEntry(
            date: Date(),
            snapshot: WidgetSnapshotStore.load() ?? quotaFallback,
            settingsSnapshot: WidgetSettingsSnapshotStore.load() ?? settingsFallback,
            face: WidgetPresentationStore.face(for: family)
        )
    }

    private func presentationFamily(for family: WidgetFamily) -> WidgetPresentationFamily {
        switch family {
        case .systemMedium:
            return .medium
        default:
            return .small
        }
    }
}
