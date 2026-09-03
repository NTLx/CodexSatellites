import Foundation
import XCTest
@testable import CodexNotch

final class CodexUsageClientTests: XCTestCase {
    private let fetchedAt = Date(timeIntervalSince1970: 1_700_000_000)

    func testClassifiesStandardWindowsByDuration() throws {
        let snapshot = try parse("""
        {"rate_limit":{"primary_window":{"used_percent":28,"limit_window_seconds":18000,"reset_at":1700001000},"secondary_window":{"used_percent":59,"limit_window_seconds":604800,"reset_at":1700500000}}}
        """)

        XCTAssertEqual(snapshot.fiveHour?.remainingPercent, 72)
        XCTAssertEqual(snapshot.fiveHour?.windowDurationSeconds, 18000)
        XCTAssertEqual(snapshot.weekly?.remainingPercent, 41)
        XCTAssertEqual(snapshot.weekly?.windowDurationSeconds, 604800)
    }

    func testClassifiesWeeklyWhenItIsPrimary() throws {
        let snapshot = try parse("""
        {"rate_limit":{"primary_window":{"used_percent":47,"limit_window_seconds":604800},"secondary_window":null}}
        """)

        XCTAssertNil(snapshot.fiveHour)
        XCTAssertEqual(snapshot.weekly?.remainingPercent, 53)
    }

    func testClassifiesFiveHourWhenItIsTheOnlyWindow() throws {
        let snapshot = try parse("""
        {"rate_limit":{"primary_window":null,"secondary_window":{"used_percent":20,"limit_window_seconds":18000}}}
        """)

        XCTAssertEqual(snapshot.fiveHour?.remainingPercent, 80)
        XCTAssertNil(snapshot.weekly)
    }

    func testClampsPercentageBoundaries() throws {
        let snapshot = try parse("""
        {"rate_limit":{"primary_window":{"used_percent":-1,"limit_window_seconds":18000},"secondary_window":{"used_percent":101,"limit_window_seconds":604800}}}
        """)

        XCTAssertEqual(snapshot.fiveHour?.remainingPercent, 100)
        XCTAssertEqual(snapshot.weekly?.remainingPercent, 0)
    }

    func testMissingOrMalformedWindowsFailClosedWithoutCrashing() {
        XCTAssertThrowsError(try parse("not json"))
        XCTAssertThrowsError(try parse("{" + "\"rate_limit\":{\"primary_window\":{\"used_percent\":20}}}"))
        XCTAssertThrowsError(try parse("{" + "\"rate_limit\":{\"primary_window\":null,\"secondary_window\":null}}"))
    }

    func testAdditionalLimitsAreIgnored() throws {
        let snapshot = try parse("""
        {"rate_limit":{"primary_window":{"used_percent":10,"limit_window_seconds":18000},"secondary_window":{"used_percent":20,"limit_window_seconds":604800}},"model_specific_limit":{"used_percent":99,"limit_window_seconds":60}}
        """)

        XCTAssertEqual(snapshot.fiveHour?.remainingPercent, 90)
        XCTAssertEqual(snapshot.weekly?.remainingPercent, 80)
    }

    func testAuthPathPrefersEnvironmentDirectory() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let codexHome = root.appendingPathComponent("custom", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try writeAuth(to: codexHome.appendingPathComponent("auth.json"), token: "env-token")

        let reader = CodexAuthReader(
            environment: ["CODEX_HOME": codexHome.path],
            homeDirectoryURL: root.appendingPathComponent("other", isDirectory: true)
        )
        let credentials = try reader.read()

        XCTAssertEqual(credentials.accessToken, "env-token")
        XCTAssertEqual(reader.authFileURL, codexHome.appendingPathComponent("auth.json"))
    }

    func testAuthPathFallsBackToHomeCodexDirectory() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let codexHome = root.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try writeAuth(to: codexHome.appendingPathComponent("auth.json"), token: "home-token")

        let reader = CodexAuthReader(environment: [:], homeDirectoryURL: root)
        XCTAssertEqual(try reader.read().accessToken, "home-token")
    }

    func testAuthReaderAcceptsAccountIDAlongsideTokens() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let codexHome = root.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try Data("{\"tokens\":{\"access_token\":\"token\",\"account_id\":\"nested-account\"}}".utf8)
            .write(to: codexHome.appendingPathComponent("auth.json"))

        let reader = CodexAuthReader(environment: [:], homeDirectoryURL: root)
        let credentials = try reader.read()

        XCTAssertEqual(credentials.accountID, "nested-account")
    }

    func testAuthErrorsAreExplicit() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let reader = CodexAuthReader(environment: [:], homeDirectoryURL: root)
        XCTAssertThrowsError(try reader.read()) { error in
            XCTAssertEqual(error as? CodexAuthError, .unavailable)
        }

        let codexHome = root.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: codexHome.appendingPathComponent("auth.json"))
        XCTAssertThrowsError(try reader.read()) { error in
            XCTAssertEqual(error as? CodexAuthError, .accessTokenMissing)
        }
    }

    func testSnapshotFreshnessStateMachineKeepsLastGoodSnapshot() {
        let snapshot = CodexQuotaSnapshot(fiveHour: nil, weekly: nil, fetchedAt: fetchedAt)
        var state = SnapshotStateMachine()

        state.applyFailure()
        XCTAssertEqual(state.freshness, .unavailable)
        state.applySuccess(snapshot)
        state.applyFailure()
        XCTAssertEqual(state.freshness, .stale(snapshot))
        state.applyFailure()
        XCTAssertEqual(state.freshness, .stale(snapshot))
    }

    func testUsageClientBuildsExpectedRequestAndParsesResponse() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let codexHome = root.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try Data("{\"tokens\":{\"access_token\":\"test-token\"},\"account_id\":\"account-123\"}".utf8)
            .write(to: codexHome.appendingPathComponent("auth.json"))

        let response = HTTPURLResponse(
            url: URL(string: "https://example.test/usage")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let client = CodexUsageClient(
            authReader: CodexAuthReader(environment: [:], homeDirectoryURL: root),
            endpoint: response.url!,
            transport: { request in
                XCTAssertEqual(request.httpMethod, "GET")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "account-123")
                return (Data("{\"rate_limit\":{\"primary_window\":{\"used_percent\":28,\"limit_window_seconds\":18000}}}".utf8), response)
            }
        )

        let snapshot = try await client.fetch(now: fetchedAt)
        XCTAssertEqual(snapshot.fiveHour?.remainingPercent, 72)
    }

    func testUsageClientFailsClosedOnUnauthorizedResponse() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let codexHome = root.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try writeAuth(to: codexHome.appendingPathComponent("auth.json"), token: "test-token")

        let response = HTTPURLResponse(
            url: URL(string: "https://example.test/usage")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        let client = CodexUsageClient(
            authReader: CodexAuthReader(environment: [:], homeDirectoryURL: root),
            endpoint: response.url!,
            transport: { _ in (Data(), response) }
        )

        do {
            _ = try await client.fetch(now: fetchedAt)
            XCTFail("Expected unauthorized response to fail")
        } catch {
            XCTAssertEqual(error as? CodexUsageError, .httpStatus(401))
        }
    }

    private func parse(_ json: String) throws -> CodexQuotaSnapshot {
        try CodexUsageParser.parse(data: Data(json.utf8), fetchedAt: fetchedAt)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeAuth(to url: URL, token: String) throws {
        try Data("{\"tokens\":{\"access_token\":\"\(token)\"}}".utf8).write(to: url)
    }
}
