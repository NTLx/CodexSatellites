import CoreFoundation

/// Payload-free cross-process wake-up used only to tell the running main app
/// that WidgetKit may have persisted a new widget configuration.
///
/// The main app always re-reads WidgetCenter state before applying anything;
/// the notification itself is never treated as configuration data.
enum WidgetConfigurationSignal {
    static let name = CFNotificationName(
        rawValue: "io.github.ntlx.codexsatellites.widget.configuration-changed" as CFString
    )

    static func post() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            name,
            nil,
            nil,
            true
        )
    }
}
