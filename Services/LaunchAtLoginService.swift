import ServiceManagement

enum LaunchAtLoginState: Equatable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
}

@MainActor
protocol LoginItemServicing: AnyObject {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemServicing {}

@MainActor
final class LaunchAtLoginService {
    private let appService: LoginItemServicing

    init(appService: LoginItemServicing = SMAppService.mainApp) {
        self.appService = appService
    }

    func state() -> LaunchAtLoginState {
        switch appService.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        switch (state(), enabled) {
        case (.disabled, true):
            try appService.register()
        case (.enabled, false), (.requiresApproval, false):
            try appService.unregister()
        case (.enabled, true), (.disabled, false), (.requiresApproval, true), (.unavailable, _):
            break
        }
    }
}
