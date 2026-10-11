import Foundation

enum WidgetSettingsAction: String, Codable, CaseIterable, Sendable {
    case toggleLaunchAtLogin
    case advanceRefreshInterval
    case reviewLoginItems
    case quit
}

/// Main-process handoff for settings actions invoked from WidgetKit.
/// If intents arrive during cold launch, keep them pending and drain them
/// as soon as the app installs its controller-backed handler.
@MainActor
final class WidgetSettingsActionRouter {
    static let shared = WidgetSettingsActionRouter()

    typealias Handler = (WidgetSettingsAction) -> Void

    private struct PendingAction {
        let action: WidgetSettingsAction
        let continuation: CheckedContinuation<Void, Never>
    }

    private var handler: Handler?
    private var pendingActions: [PendingAction] = []

    var pendingActionCount: Int {
        pendingActions.count
    }

    func install(handler newHandler: @escaping Handler) {
        handler = newHandler
        let actions = pendingActions
        pendingActions.removeAll()
        for pendingAction in actions {
            newHandler(pendingAction.action)
            pendingAction.continuation.resume()
        }
    }

    func dispatch(_ action: WidgetSettingsAction) async {
        if let handler {
            handler(action)
            return
        }

        await withCheckedContinuation { continuation in
            pendingActions.append(PendingAction(action: action, continuation: continuation))
        }
    }

    func reset() {
        handler = nil
        let actions = pendingActions
        pendingActions.removeAll()
        for pendingAction in actions {
            pendingAction.continuation.resume()
        }
    }
}
