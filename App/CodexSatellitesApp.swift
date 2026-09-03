import AppKit
import OSLog

@MainActor
@main
final class CodexSatellitesApp: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.codexsatellites.app", category: "app")
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
        overlayController = QuotaOverlayController()
        overlayController?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        overlayController?.stop()
        overlayController = nil
    }
}
