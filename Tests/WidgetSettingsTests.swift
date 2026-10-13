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

final class WidgetConfigurationReconcilerTests: XCTestCase {
    func testEqualConfigurationsProduceNoDeltaRegardlessOfOrder() {
        let small = fingerprint(.small, launchAtLogin: true, minutes: 5)
        let medium = fingerprint(.medium, launchAtLogin: false, minutes: 15)

        XCTAssertNil(
            WidgetConfigurationReconciler.delta(
                previous: [small, medium],
                current: [medium, small]
            )
        )
    }

    func testSingleLaunchEditChangesOnlyLaunchAtLogin() {
        let old = fingerprint(.small, launchAtLogin: false, minutes: 5)
        let new = fingerprint(.small, launchAtLogin: true, minutes: 5)

        XCTAssertEqual(
            WidgetConfigurationReconciler.delta(previous: [old], current: [new]),
            WidgetConfigurationDelta(launchAtLogin: true, refreshIntervalMinutes: nil)
        )
    }

    func testSingleFrequencyEditChangesOnlyFrequency() {
        let old = fingerprint(.medium, launchAtLogin: true, minutes: 1)
        let new = fingerprint(.medium, launchAtLogin: true, minutes: 15)

        XCTAssertEqual(
            WidgetConfigurationReconciler.delta(previous: [old], current: [new]),
            WidgetConfigurationDelta(launchAtLogin: nil, refreshIntervalMinutes: 15)
        )
    }

    func testUnchangedStaleFieldDoesNotOverwriteOtherGlobalSetting() {
        let old = fingerprint(.small, launchAtLogin: false, minutes: 1)
        let new = fingerprint(.small, launchAtLogin: false, minutes: 5)

        let delta = WidgetConfigurationReconciler.delta(previous: [old], current: [new])
        XCTAssertNil(delta?.launchAtLogin)
        XCTAssertEqual(delta?.refreshIntervalMinutes, 5)
    }

    func testAddOrRemoveOnlyDoesNotChangeGlobalSettings() {
        let small = fingerprint(.small, launchAtLogin: false, minutes: 1)
        let medium = fingerprint(.medium, launchAtLogin: false, minutes: 1)

        XCTAssertNil(WidgetConfigurationReconciler.delta(previous: [small], current: [small, medium]))
        XCTAssertNil(WidgetConfigurationReconciler.delta(previous: [small, medium], current: [small]))
    }

    func testFamilyResizeDoesNotChangeGlobalSettings() {
        let old = fingerprint(.small, launchAtLogin: false, minutes: 1)
        let resized = fingerprint(.medium, launchAtLogin: true, minutes: 5)

        XCTAssertNil(WidgetConfigurationReconciler.delta(previous: [old], current: [resized]))
    }

    func testAmbiguousMultipleEditsDoNotChangeGlobalSettings() {
        let previous = [
            fingerprint(.small, launchAtLogin: false, minutes: 1),
            fingerprint(.medium, launchAtLogin: false, minutes: 1)
        ]
        let current = [
            fingerprint(.small, launchAtLogin: true, minutes: 1),
            fingerprint(.medium, launchAtLogin: false, minutes: 15)
        ]

        XCTAssertNil(WidgetConfigurationReconciler.delta(previous: previous, current: current))
    }

    func testRefreshIntervalOptionMapsSupportedMinutesExactly() {
        XCTAssertEqual(WidgetRefreshIntervalOption(minutes: 1), .oneMinute)
        XCTAssertEqual(WidgetRefreshIntervalOption(minutes: 5), .fiveMinutes)
        XCTAssertEqual(WidgetRefreshIntervalOption(minutes: 15), .fifteenMinutes)
        XCTAssertNil(WidgetRefreshIntervalOption(minutes: 2))
        XCTAssertEqual(WidgetRefreshIntervalOption.fiveMinutes.minutes, 5)
    }

    private func fingerprint(
        _ family: WidgetConfigurationFingerprint.Family,
        launchAtLogin: Bool,
        minutes: Int
    ) -> WidgetConfigurationFingerprint {
        WidgetConfigurationFingerprint(
            family: family,
            launchAtLogin: launchAtLogin,
            refreshIntervalMinutes: minutes
        )
    }
}
