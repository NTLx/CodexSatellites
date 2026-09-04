import XCTest
@testable import CodexSatellites

final class QuotaRefreshIntervalTests: XCTestCase {
    func testCyclesThroughSupportedIntervals() {
        XCTAssertEqual(QuotaRefreshInterval.oneMinute.next, .fiveMinutes)
        XCTAssertEqual(QuotaRefreshInterval.fiveMinutes.next, .fifteenMinutes)
        XCTAssertEqual(QuotaRefreshInterval.fifteenMinutes.next, .oneMinute)
    }

    func testDisplayText() {
        XCTAssertEqual(QuotaRefreshInterval.oneMinute.displayText, "1m")
        XCTAssertEqual(QuotaRefreshInterval.fiveMinutes.displayText, "5m")
        XCTAssertEqual(QuotaRefreshInterval.fifteenMinutes.displayText, "15m")
    }

    func testDuration() {
        XCTAssertEqual(QuotaRefreshInterval.oneMinute.duration, .seconds(60))
        XCTAssertEqual(QuotaRefreshInterval.fiveMinutes.duration, .seconds(300))
        XCTAssertEqual(QuotaRefreshInterval.fifteenMinutes.duration, .seconds(900))
    }

    func testMissingPreferenceDefaultsToOneMinute() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(QuotaRefreshPreference(defaults: defaults).interval, .oneMinute)
    }

    func testInvalidPreferenceDefaultsToOneMinute() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(10, forKey: QuotaRefreshPreference.key)

        XCTAssertEqual(QuotaRefreshPreference(defaults: defaults).interval, .oneMinute)
    }

    func testSupportedIntervalsPersist() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preference = QuotaRefreshPreference(defaults: defaults)

        for interval in QuotaRefreshInterval.allCases {
            preference.interval = interval
            XCTAssertEqual(preference.interval, interval)
            XCTAssertEqual(defaults.object(forKey: QuotaRefreshPreference.key) as? Int, interval.rawValue)
        }
    }

    func testOnlyRefreshIntervalKeyIsPersisted() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preference = QuotaRefreshPreference(defaults: defaults)

        preference.interval = .fiveMinutes

        XCTAssertEqual(
            Set(defaults.persistentDomain(forName: suiteName).map { Array($0.keys) } ?? []),
            [QuotaRefreshPreference.key]
        )
    }

    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "CodexSatellites.QuotaRefreshIntervalTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
