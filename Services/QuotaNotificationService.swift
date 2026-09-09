import Foundation
import OSLog
import UserNotifications

@MainActor
protocol QuotaNotificationDelivering {
    func requestAuthorizationIfNeeded() async
    func deliver(_ event: QuotaChangeEvent, at date: Date) async
}

@MainActor
final class QuotaNotificationService: QuotaNotificationDelivering {
    private static let loggerSubsystem = Bundle.main.bundleIdentifier ?? "io.github.ntlx.codexsatellites"
    private let logger = Logger(subsystem: QuotaNotificationService.loggerSubsystem, category: "notifications")
    private let center: UNUserNotificationCenter
    private let presentationDelegate: NotificationPresentationDelegate

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        presentationDelegate = NotificationPresentationDelegate()
        center.delegate = presentationDelegate
    }

    func requestAuthorizationIfNeeded() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            logger.info("notification authorization granted=\(granted, privacy: .public)")
        } catch {
            logger.error("notification authorization failed error=\(String(describing: error), privacy: .public)")
        }
    }

    func deliver(_ event: QuotaChangeEvent, at date: Date) async {
        let eventID = identifier(for: event)
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            break
        default:
            logger.info("notification skipped reason=notAuthorized event=\(eventID, privacy: .public)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(eventID)-\(date.timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        do {
            try await center.add(request)
            logger.info("notification delivered event=\(eventID, privacy: .public)")
        } catch {
            logger.error("notification delivery failed event=\(eventID, privacy: .public) error=\(String(describing: error), privacy: .public)")
        }
    }

    private func identifier(for event: QuotaChangeEvent) -> String {
        switch event {
        case .fiveHourReset:
            return "fiveHourReset"
        case .weeklyReset:
            return "weeklyReset"
        case .fiveHourLow:
            return "fiveHourLow"
        case .weeklyLow:
            return "weeklyLow"
        case .resetCreditsIncreased:
            return "resetCreditsIncreased"
        case .resetCreditsDecreased:
            return "resetCreditsDecreased"
        }
    }
}

private final class NotificationPresentationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
