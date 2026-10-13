import SwiftUI
import WidgetKit
import AppIntents

@main
struct CodexSatellitesWidgetBundle: WidgetBundle {
    var body: some Widget {
        CodexQuotaWidget()
    }
}

struct CodexQuotaWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetSnapshotStore.widgetKind,
            intent: CodexWidgetConfigurationIntent.self,
            provider: CodexWidgetProvider()
        ) { entry in
            CodexWidgetView(entry: entry)
        }
        .configurationDisplayName("Codex Usage")
        .description("View Codex quota, reset count, and CodexSatellites app status at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
