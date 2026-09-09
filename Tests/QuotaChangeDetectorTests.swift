import Foundation
import XCTest
@testable import CodexSatellites

final class QuotaChangeDetectorTests: XCTestCase {
    private let fetchedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func window(_ percent: Double) -> QuotaWindow {
        QuotaWindow(remainingPercent: percent, windowDurationSeconds: 18_000, resetsAt: nil)
    }

    private func snapshot(
        fiveHour: Double? = nil,
        weekly: Double? = nil,
        resetCount: Int? = nil
    ) -> CodexQuotaSnapshot {
        CodexQuotaSnapshot(
            fiveHour: fiveHour.map(window),
            weekly: weekly.map(window),
            availableResetCount: resetCount,
            fetchedAt: fetchedAt
        )
    }

    private func events(_ previous: CodexQuotaSnapshot?, _ current: CodexQuotaSnapshot) -> [QuotaChangeEvent] {
        QuotaChangeDetector.events(previous: previous, current: current)
    }

    func testFirstFetchIsSilent() {
        XCTAssertEqual(events(nil, snapshot(fiveHour: 100, weekly: 100, resetCount: 5)), [])
    }

    func testFiveHourResetFiresOnceThenStaysSilent() {
        XCTAssertEqual(events(snapshot(fiveHour: 50), snapshot(fiveHour: 100)), [.fiveHourReset])
        XCTAssertEqual(events(snapshot(fiveHour: 100), snapshot(fiveHour: 100)), [])
    }

    func testWeeklyResetIsIndependentOfFiveHour() {
        XCTAssertEqual(events(snapshot(weekly: 30), snapshot(weekly: 100)), [.weeklyReset])
        XCTAssertEqual(events(snapshot(fiveHour: 30), snapshot(fiveHour: 100)), [.fiveHourReset])
    }

    func testBothWindowsResettingProduceTwoEvents() {
        XCTAssertEqual(
            events(snapshot(fiveHour: 12, weekly: 8), snapshot(fiveHour: 100, weekly: 100)),
            [.fiveHourReset, .weeklyReset]
        )
    }

    func testUnchangedValuesProduceNothing() {
        XCTAssertEqual(events(snapshot(fiveHour: 42, weekly: 77, resetCount: 3), snapshot(fiveHour: 42, weekly: 77, resetCount: 3)), [])
    }

    func testLowQuotaFiresOncePerCrossing() {
        XCTAssertEqual(events(snapshot(fiveHour: 25), snapshot(fiveHour: 9.9)), [.fiveHourLow])
        XCTAssertEqual(events(snapshot(fiveHour: 9.9), snapshot(fiveHour: 8)), [])
    }

    func testExactlyTenPercentDoesNotFire() {
        XCTAssertEqual(events(snapshot(fiveHour: 25), snapshot(fiveHour: 10)), [])
        XCTAssertEqual(events(snapshot(fiveHour: 10), snapshot(fiveHour: 9.9)), [.fiveHourLow])
    }

    func testWeeklyLowIsIndependentOfFiveHour() {
        XCTAssertEqual(events(snapshot(weekly: 40), snapshot(weekly: 4)), [.weeklyLow])
    }

    func testLowQuotaRearmsAfterReset() {
        XCTAssertEqual(events(snapshot(fiveHour: 9.9), snapshot(fiveHour: 100)), [.fiveHourReset])
        XCTAssertEqual(events(snapshot(fiveHour: 100), snapshot(fiveHour: 9)), [.fiveHourLow])
    }

    func testWindowAppearingOrDisappearingIsSilent() {
        XCTAssertEqual(events(snapshot(fiveHour: nil), snapshot(fiveHour: 5)), [])
        XCTAssertEqual(events(snapshot(fiveHour: 5), snapshot(fiveHour: nil)), [])
        XCTAssertEqual(events(snapshot(weekly: nil), snapshot(weekly: 5)), [])
    }

    func testResetCountIncreaseAndDecrease() {
        XCTAssertEqual(
            events(snapshot(resetCount: 1), snapshot(resetCount: 2)),
            [.resetCreditsIncreased(from: 1, to: 2)]
        )
        XCTAssertEqual(
            events(snapshot(resetCount: 3), snapshot(resetCount: 0)),
            [.resetCreditsDecreased(from: 3, to: 0)]
        )
        XCTAssertEqual(events(snapshot(resetCount: 0), snapshot(resetCount: 0)), [])
        XCTAssertEqual(events(snapshot(resetCount: 0), snapshot(resetCount: 1)), [.resetCreditsIncreased(from: 0, to: 1)])
    }

    func testResetCountUnknownOnEitherSideIsSilent() {
        XCTAssertEqual(events(snapshot(resetCount: nil), snapshot(resetCount: 2)), [])
        XCTAssertEqual(events(snapshot(resetCount: 2), snapshot(resetCount: nil)), [])
    }

    func testMultipleEventKindsUseDeterministicOrder() {
        XCTAssertEqual(
            events(
                snapshot(fiveHour: 5, weekly: 5, resetCount: 1),
                snapshot(fiveHour: 100, weekly: 100, resetCount: 2)
            ),
            [.fiveHourReset, .weeklyReset, .resetCreditsIncreased(from: 1, to: 2)]
        )
    }

    func testEventTextIsNonEmptyAsciiEnglish() {
        let allEvents: [QuotaChangeEvent] = [
            .fiveHourReset,
            .weeklyReset,
            .fiveHourLow,
            .weeklyLow,
            .resetCreditsIncreased(from: 1, to: 2),
            .resetCreditsDecreased(from: 2, to: 1)
        ]
        for event in allEvents {
            XCTAssertFalse(event.title.isEmpty)
            XCTAssertFalse(event.body.isEmpty)
            XCTAssertTrue(event.title.allSatisfy(\.isASCII), event.title)
            XCTAssertTrue(event.body.allSatisfy(\.isASCII), event.body)
        }
        XCTAssertEqual(
            QuotaChangeEvent.resetCreditsIncreased(from: 1, to: 4).body,
            "You now have 4 available reset credits."
        )
    }
}
