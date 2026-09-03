import ServiceManagement
import XCTest
@testable import CodexSatellites

@MainActor
final class LaunchAtLoginServiceTests: XCTestCase {
    func testMapsSystemStatuses() {
        let mock = MockLoginItemService(status: .notRegistered)
        let service = LaunchAtLoginService(appService: mock)

        mock.status = .notRegistered
        XCTAssertEqual(service.state(), .disabled)
        mock.status = .enabled
        XCTAssertEqual(service.state(), .enabled)
        mock.status = .requiresApproval
        XCTAssertEqual(service.state(), .requiresApproval)
        mock.status = .notFound
        XCTAssertEqual(service.state(), .unavailable)
    }

    func testSetEnabledIsIdempotentAndReadsSystemState() throws {
        let mock = MockLoginItemService(status: .notRegistered)
        let service = LaunchAtLoginService(appService: mock)

        try service.setEnabled(false)
        XCTAssertEqual(mock.unregisterCallCount, 0)

        try service.setEnabled(true)
        XCTAssertEqual(mock.registerCallCount, 1)
        XCTAssertEqual(service.state(), .enabled)

        try service.setEnabled(true)
        XCTAssertEqual(mock.registerCallCount, 1)

        try service.setEnabled(false)
        XCTAssertEqual(mock.unregisterCallCount, 1)
        XCTAssertEqual(service.state(), .disabled)

        try service.setEnabled(false)
        XCTAssertEqual(mock.unregisterCallCount, 1)
    }

    func testRequiresApprovalDoesNotRegisterAgainButCanBeDisabled() throws {
        let mock = MockLoginItemService(status: .requiresApproval)
        let service = LaunchAtLoginService(appService: mock)

        try service.setEnabled(true)
        XCTAssertEqual(mock.registerCallCount, 0)

        try service.setEnabled(false)
        XCTAssertEqual(mock.unregisterCallCount, 1)
        XCTAssertEqual(service.state(), .disabled)
    }

    func testUnavailableDoesNotAttemptToRegisterOrUnregister() throws {
        let mock = MockLoginItemService(status: .notFound)
        let service = LaunchAtLoginService(appService: mock)

        try service.setEnabled(true)
        try service.setEnabled(false)

        XCTAssertEqual(mock.registerCallCount, 0)
        XCTAssertEqual(mock.unregisterCallCount, 0)
    }

    func testRegisterAndUnregisterErrorsArePropagated() {
        let mock = MockLoginItemService(status: .notRegistered)
        let service = LaunchAtLoginService(appService: mock)

        mock.registerError = MockError.register
        XCTAssertThrowsError(try service.setEnabled(true)) { error in
            XCTAssertEqual(error as? MockError, .register)
        }

        mock.status = .enabled
        mock.unregisterError = MockError.unregister
        XCTAssertThrowsError(try service.setEnabled(false)) { error in
            XCTAssertEqual(error as? MockError, .unregister)
        }
    }

    private enum MockError: Error, Equatable {
        case register
        case unregister
    }

    private final class MockLoginItemService: LoginItemServicing {
        var status: SMAppService.Status
        var registerError: Error?
        var unregisterError: Error?
        private(set) var registerCallCount = 0
        private(set) var unregisterCallCount = 0

        init(status: SMAppService.Status) {
            self.status = status
        }

        func register() throws {
            registerCallCount += 1
            if let registerError {
                throw registerError
            }
            status = .enabled
        }

        func unregister() throws {
            unregisterCallCount += 1
            if let unregisterError {
                throw unregisterError
            }
            status = .notRegistered
        }
    }
}
