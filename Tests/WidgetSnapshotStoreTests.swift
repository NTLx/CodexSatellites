import XCTest
@testable import CodexSatellites

final class WidgetSnapshotStoreTests: XCTestCase {
    private func snapshot(
        fiveHour: Double?,
        weekly: Double?,
        fetchedAt: Date,
        freshness: WidgetSnapshotFreshness = .fresh
    ) -> WidgetQuotaSnapshot {
        WidgetQuotaSnapshot(
            fiveHourRemainingPercent: fiveHour,
            weeklyRemainingPercent: weekly,
            fiveHourResetsAt: nil,
            weeklyResetsAt: nil,
            fetchedAt: fetchedAt,
            freshness: freshness
        )
    }

    func testCodableRoundTripPreservesValues() {
        let original = snapshot(
            fiveHour: 73,
            weekly: 42,
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000),
            freshness: .stale
        )
        guard let data = WidgetSnapshotStore.encodeSnapshot(original) else {
            return XCTFail("encode failed")
        }
        XCTAssertEqual(WidgetSnapshotStore.decodeSnapshot(from: data), original)
    }

    func testDecodeRejectsCorruptedData() {
        XCTAssertNil(WidgetSnapshotStore.decodeSnapshot(from: Data("{ not json".utf8)))
    }

    func testActiveTransportIsWidgetContainerForAdHocBuilds() {
        XCTAssertEqual(WidgetSnapshotStore.activeTransport, .widgetContainer)
    }

    func testWidgetContainerModeReadsOnlyItsOwnContainer() {
        XCTAssertEqual(WidgetSnapshotStore.readableTransports(for: .widgetContainer), [.widgetContainer])
    }

    /// Regression: an ad-hoc widget must never resolve or read the App Group
    /// container, whose access is denied by TCC.
    func testWidgetContainerModeNeverReadsAppGroup() {
        let transports = WidgetSnapshotStore.readableTransports(for: .widgetContainer)
        XCTAssertFalse(transports.contains(.appGroup))
    }

    func testAppGroupModeFallsBackToWidgetContainerForMigration() {
        XCTAssertEqual(
            WidgetSnapshotStore.readableTransports(for: .appGroup),
            [.appGroup, .widgetContainer]
        )
    }

    /// A refresh that only moves `fetchedAt` must not spend a timeline reload.
    func testDisplayedContentIgnoresFetchedAt() {
        let earlier = snapshot(fiveHour: 73, weekly: 42, fetchedAt: Date(timeIntervalSince1970: 100))
        let later = snapshot(fiveHour: 73, weekly: 42, fetchedAt: Date(timeIntervalSince1970: 200))
        XCTAssertTrue(earlier.hasSameDisplayedContent(as: later))
    }

    func testDisplayedContentDetectsQuotaChange() {
        let before = snapshot(fiveHour: 73, weekly: 42, fetchedAt: Date(timeIntervalSince1970: 100))
        let after = snapshot(fiveHour: 72, weekly: 42, fetchedAt: Date(timeIntervalSince1970: 100))
        XCTAssertFalse(before.hasSameDisplayedContent(as: after))
    }

    func testDisplayedContentDetectsFreshnessChange() {
        let fresh = snapshot(fiveHour: 73, weekly: 42, fetchedAt: Date(timeIntervalSince1970: 100))
        let stale = snapshot(fiveHour: 73, weekly: 42, fetchedAt: Date(timeIntervalSince1970: 100), freshness: .stale)
        XCTAssertFalse(fresh.hasSameDisplayedContent(as: stale))
    }

    func testEncodeCarriesSchemaVersion() {
        let original = snapshot(fiveHour: 73, weekly: 42, fetchedAt: Date(timeIntervalSince1970: 100))
        guard let data = WidgetSnapshotStore.encodeSnapshot(original),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return XCTFail("encode failed")
        }
        XCTAssertEqual(object["schemaVersion"] as? Int, WidgetQuotaSnapshot.currentSchemaVersion)
    }

    /// An older widget build reads a snapshot that predates the version field.
    func testDecodeDefaultsMissingSchemaVersion() {
        let json = """
        {"fiveHourRemainingPercent":73,"weeklyRemainingPercent":42,"fetchedAt":"2026-09-09T06:00:00Z","freshness":"fresh"}
        """
        let decoded = WidgetSnapshotStore.decodeSnapshot(from: Data(json.utf8))
        XCTAssertEqual(decoded?.schemaVersion, WidgetQuotaSnapshot.legacySchemaVersion)
        XCTAssertEqual(decoded?.fiveHourRemainingPercent, 73)
    }

    /// A newer writer must fail closed rather than misread the payload.
    func testDecodeRejectsFutureSchemaVersion() {
        let json = """
        {"schemaVersion":99,"fiveHourRemainingPercent":73,"fetchedAt":"2026-09-09T06:00:00Z","freshness":"fresh"}
        """
        XCTAssertNil(WidgetSnapshotStore.decodeSnapshot(from: Data(json.utf8)))
    }
}
