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
}
