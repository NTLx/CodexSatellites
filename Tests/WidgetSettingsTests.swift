import Foundation
import XCTest
@testable import CodexSatellites

@MainActor
final class WidgetSettingsSnapshotTests: XCTestCase {
    func testCodableRoundTripPreservesValuesIncludingZeroResetCount() {
        let original = WidgetSettingsSnapshot(
            launchAtLoginState: .enabled,
            refreshIntervalMinutes: 5,
            availableResetCount: 0
        )
        guard let data = WidgetSettingsSnapshotStore.encodeSnapshot(original) else {
            return XCTFail("encode failed")
        }
        XCTAssertEqual(WidgetSettingsSnapshotStore.decodeSnapshot(from: data), original)
    }

    func testDecodeAcceptsMissingOptionalResetCountAndUnknownFields() {
        let json = """
        {"schemaVersion":1,"launchAtLoginState":"disabled","refreshIntervalMinutes":15,"futureField":"ignored"}
        """
        let decoded = WidgetSettingsSnapshotStore.decodeSnapshot(from: Data(json.utf8))
        XCTAssertEqual(decoded?.launchAtLoginState, .disabled)
        XCTAssertEqual(decoded?.refreshIntervalMinutes, 15)
        XCTAssertNil(decoded?.availableResetCount)
    }

    func testDecodeRejectsFutureSchemaVersion() {
        let json = """
        {"schemaVersion":99,"launchAtLoginState":"disabled","refreshIntervalMinutes":1}
        """
        XCTAssertNil(WidgetSettingsSnapshotStore.decodeSnapshot(from: Data(json.utf8)))
    }

    func testSettingsSnapshotUsesSameActiveTransportAsQuotaSnapshot() {
        XCTAssertEqual(WidgetSettingsSnapshotStore.activeTransport, WidgetSnapshotStore.activeTransport)
        XCTAssertEqual(WidgetSettingsSnapshotStore.activeTransport, .widgetContainer)
    }

    func testResetCountProjectionRequiresFreshQuotaState() {
        let snapshot = CodexQuotaSnapshot(
            fiveHour: nil,
            weekly: nil,
            availableResetCount: 0,
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(QuotaOverlayController.widgetResetCount(for: .fresh(snapshot)), 0)
        XCTAssertNil(QuotaOverlayController.widgetResetCount(for: .stale(snapshot)))
        XCTAssertNil(QuotaOverlayController.widgetResetCount(for: .unavailable))
    }
}

final class WidgetPresentationStoreTests: XCTestCase {
    func testDefaultFaceIsQuota() {
        withDefaults { defaults in
            XCTAssertEqual(WidgetPresentationStore.face(for: .small, defaults: defaults), .quota)
            XCTAssertEqual(WidgetPresentationStore.face(for: .medium, defaults: defaults), .quota)
        }
    }

    func testSmallAndMediumFacesAreIndependent() {
        withDefaults { defaults in
            WidgetPresentationStore.setFace(.settings, for: .small, defaults: defaults)
            XCTAssertEqual(WidgetPresentationStore.face(for: .small, defaults: defaults), .settings)
            XCTAssertEqual(WidgetPresentationStore.face(for: .medium, defaults: defaults), .quota)

            WidgetPresentationStore.setFace(.settings, for: .medium, defaults: defaults)
            WidgetPresentationStore.setFace(.quota, for: .small, defaults: defaults)
            XCTAssertEqual(WidgetPresentationStore.face(for: .small, defaults: defaults), .quota)
            XCTAssertEqual(WidgetPresentationStore.face(for: .medium, defaults: defaults), .settings)
        }
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "WidgetPresentationStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            return XCTFail("failed to create UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }
}

@MainActor
private final class WidgetSettingsActionRecorder {
    var actions: [WidgetSettingsAction] = []
}

@MainActor
final class WidgetSettingsActionRouterTests: XCTestCase {
    func testInstalledHandlerReceivesExactAction() async {
        let router = WidgetSettingsActionRouter()
        let recorder = WidgetSettingsActionRecorder()
        router.install { recorder.actions.append($0) }

        await router.dispatch(.advanceRefreshInterval)

        XCTAssertEqual(recorder.actions, [.advanceRefreshInterval])
    }

    func testColdLaunchPendingActionDrainsExactlyOnce() async {
        let router = WidgetSettingsActionRouter()
        let dispatchTask = Task { @MainActor in
            await router.dispatch(.toggleLaunchAtLogin)
        }
        try? await Task.sleep(for: .milliseconds(10))
        XCTAssertEqual(router.pendingActionCount, 1)

        let firstRecorder = WidgetSettingsActionRecorder()
        router.install { firstRecorder.actions.append($0) }
        await dispatchTask.value
        XCTAssertEqual(firstRecorder.actions, [.toggleLaunchAtLogin])

        let secondRecorder = WidgetSettingsActionRecorder()
        router.install { secondRecorder.actions.append($0) }
        XCTAssertTrue(secondRecorder.actions.isEmpty)
    }
}
