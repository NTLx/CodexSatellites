import AppKit
import OSLog
import WidgetKit

@MainActor
@main
final class CodexSatellitesApp: NSObject, NSApplicationDelegate {
    private static let loggerSubsystem = Bundle.main.bundleIdentifier ?? "io.github.ntlx.codexsatellites"
    private static let widgetReloadBuildKey = "widgetTimelineLastReloadedBuild"
    private let logger = Logger(subsystem: CodexSatellitesApp.loggerSubsystem, category: "app")
    private var overlayController: QuotaOverlayController?
    private var widgetConfigurationSyncService: WidgetConfigurationSyncService?

    static func main() {
        let application = NSApplication.shared
        let delegate = CodexSatellitesApp()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("application launched")
        NSApp.setActivationPolicy(.accessory)
        let controller = QuotaOverlayController()
        overlayController = controller
        controller.start()

        let widgetConfigurationSyncService = WidgetConfigurationSyncService { [weak controller] launchAtLogin, refreshInterval in
            controller?.applyWidgetConfigurationChange(
                launchAtLogin: launchAtLogin,
                refreshInterval: refreshInterval
            )
        }
        self.widgetConfigurationSyncService = widgetConfigurationSyncService
        widgetConfigurationSyncService.start()

        reloadWidgetTimelineAfterUpgradeIfNeeded()
    }

    private func reloadWidgetTimelineAfterUpgradeIfNeeded() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let buildToken = "\(version)-\(build)"
        let defaults = UserDefaults.standard

        guard defaults.string(forKey: Self.widgetReloadBuildKey) != buildToken else {
            return
        }

        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshotStore.widgetKind)
        defaults.set(buildToken, forKey: Self.widgetReloadBuildKey)
        logger.info(
            "widget timeline reload reason=appBuildChanged version=\(version, privacy: .public) build=\(build, privacy: .public)"
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        widgetConfigurationSyncService?.stop()
        widgetConfigurationSyncService = nil
        overlayController?.stop()
        overlayController = nil
    }
}
