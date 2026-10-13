import AppKit
import OSLog
import SwiftUI
import WidgetKit

struct CodexWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetQuotaSnapshot?
    let settingsSnapshot: WidgetSettingsSnapshot?
    let isAppRunning: Bool?
}

struct CodexWidgetProvider: AppIntentTimelineProvider {
    typealias Intent = CodexWidgetConfigurationIntent
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
            isAppRunning: nil
        )
    }

    func snapshot(for configuration: Intent, in context: Context) async -> CodexWidgetEntry {
        makeEntry(configuration: configuration, quotaFallback: .placeholder, settingsFallback: .placeholder)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<CodexWidgetEntry> {
        let entry = makeEntry(configuration: configuration)
        logger.info("timeline build=\(Self.buildNumber, privacy: .public) snapshot=\(entry.snapshot == nil ? "missing" : "loaded", privacy: .public) freshness=\(entry.snapshot?.freshness.rawValue ?? "none", privacy: .public) app=\(entry.isAppRunning == true ? "running" : "stopped", privacy: .public)")
        if !context.isPreview {
            WidgetConfigurationSignal.post()
        }
        return Timeline(entries: [entry], policy: .never)
    }

    private func makeEntry(
        configuration: Intent,
        quotaFallback: WidgetQuotaSnapshot? = nil,
        settingsFallback: WidgetSettingsSnapshot? = nil
    ) -> CodexWidgetEntry {
        return CodexWidgetEntry(
            date: Date(),
            snapshot: WidgetSnapshotStore.load() ?? quotaFallback,
            settingsSnapshot: WidgetSettingsSnapshotStore.load() ?? settingsFallback,
            isAppRunning: Self.isMainAppRunning
        )
    }

    private static var isMainAppRunning: Bool {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: WidgetSnapshotStore.appBundleIdentifier)
            .contains { !$0.isTerminated }
    }
}
