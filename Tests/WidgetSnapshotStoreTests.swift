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

    func testNewestSnapshotWinsWhenWidgetContainerIsOlder() {
        let older = snapshot(fiveHour: 10, weekly: 20, fetchedAt: Date(timeIntervalSince1970: 100))
        let newer = snapshot(fiveHour: 90, weekly: 80, fetchedAt: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(WidgetSnapshotStore.newestSnapshot(from: [older, newer]), newer)
    }

    func testNewestSnapshotWinsWhenAppGroupIsOlder() {
        let older = snapshot(fiveHour: 10, weekly: 20, fetchedAt: Date(timeIntervalSince1970: 100))
        let newer = snapshot(fiveHour: 90, weekly: 80, fetchedAt: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(WidgetSnapshotStore.newestSnapshot(from: [newer, older]), newer)
    }

    func testNewestSnapshotReturnsNilWhenEmpty() {
        XCTAssertNil(WidgetSnapshotStore.newestSnapshot(from: []))
    }

    func testNewestSnapshotReturnsOnlySnapshot() {
        let only = snapshot(fiveHour: 55, weekly: 66, fetchedAt: Date(timeIntervalSince1970: 300))
        XCTAssertEqual(WidgetSnapshotStore.newestSnapshot(from: [only]), only)
    }

    func testActiveTransportIsWidgetContainerForAdHocBuilds() {
        XCTAssertEqual(WidgetSnapshotStore.activeTransport, .widgetContainer)
    }
}
