import AppKit
import OSLog

@MainActor
@main
final class CodexSatellitesApp: NSObject, NSApplicationDelegate {
    private static let loggerSubsystem = Bundle.main.bundleIdentifier ?? "io.github.ntlx.codexsatellites"
    private let logger = Logger(subsystem: CodexSatellitesApp.loggerSubsystem, category: "app")
    private var overlayController: QuotaOverlayController?

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
        WidgetSettingsActionRouter.shared.install { [weak controller] action in
            controller?.handleWidgetSettingsAction(action)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        WidgetSettingsActionRouter.shared.reset()
        overlayController?.stop()
        overlayController = nil
    }
}
