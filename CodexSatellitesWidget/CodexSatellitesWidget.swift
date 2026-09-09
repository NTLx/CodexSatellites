import SwiftUI
import WidgetKit

@main
struct CodexSatellitesWidgetBundle: WidgetBundle {
    var body: some Widget {
        CodexQuotaWidget()
    }
}

struct CodexQuotaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetSnapshotStore.widgetKind,
            provider: CodexWidgetProvider()
        ) { entry in
            CodexWidgetView(entry: entry)
        }
        .configurationDisplayName("Codex Usage")
        .description("View your Codex 5-hour and weekly quota at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
