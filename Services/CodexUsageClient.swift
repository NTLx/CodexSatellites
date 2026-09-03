import Foundation
import OSLog

struct CodexAuthCredentials: Sendable {
    let accessToken: String
    let accountID: String?
}

enum CodexAuthError: Error, Equatable {
    case unavailable
    case unreadable
    case malformed
    case accessTokenMissing
}

struct CodexAuthReader {
    private let environment: [String: String]
    private let homeDirectoryURL: URL
    private let fileManager: FileManager

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) {
        self.environment = environment
        self.homeDirectoryURL = homeDirectoryURL
        self.fileManager = fileManager
    }

    var authFileURL: URL {
        if let codexHome = environment["CODEX_HOME"], !codexHome.isEmpty {
            return URL(fileURLWithPath: codexHome, isDirectory: true)
                .appendingPathComponent("auth.json", isDirectory: false)
        }
        return homeDirectoryURL
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("auth.json", isDirectory: false)
    }

    func read() throws -> CodexAuthCredentials {
        guard fileManager.fileExists(atPath: authFileURL.path) else {
            throw CodexAuthError.unavailable
        }

        let data: Data
        do {
            data = try Data(contentsOf: authFileURL, options: [.mappedIfSafe])
        } catch {
            throw CodexAuthError.unreadable
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw CodexAuthError.malformed
        }

        guard let root = object as? [String: Any],
              let tokens = root["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              !accessToken.isEmpty else {
            throw CodexAuthError.accessTokenMissing
        }

        let accountID = (root["account_id"] as? String) ?? (tokens["account_id"] as? String)
        return CodexAuthCredentials(accessToken: accessToken, accountID: accountID)
    }
}

enum CodexUsageError: Error, Equatable {
    case invalidEndpoint
    case httpStatus(Int)
    case invalidResponse
    case invalidPayload
}

struct CodexUsageClient {
    typealias Transport = (URLRequest) async throws -> (Data, URLResponse)

    private static let loggerSubsystem = Bundle.main.bundleIdentifier ?? "io.github.ntlx.codexsatellites"
    private let authReader: CodexAuthReader
    private let endpoint: URL
    private let transport: Transport
    private let logger = Logger(subsystem: CodexUsageClient.loggerSubsystem, category: "usage")

    init(
        authReader: CodexAuthReader = CodexAuthReader(),
        endpoint: URL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!,
        transport: @escaping Transport = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.authReader = authReader
        self.endpoint = endpoint
        self.transport = transport
    }

    func fetch(now: Date = Date()) async throws -> CodexQuotaSnapshot {
        let credentials = try authReader.read()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        if let accountID = credentials.accountID, !accountID.isEmpty {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let (data, response) = try await transport(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CodexUsageError.invalidResponse
        }
        logger.info("usage fetch status=\(httpResponse.statusCode)")
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw CodexUsageError.httpStatus(httpResponse.statusCode)
        }

        let snapshot = try CodexUsageParser.parse(data: data, fetchedAt: now)
        logger.info("usage fetch succeeded")
        return snapshot
    }
}

enum CodexUsageParser {
    private struct RawWindow {
        let usedPercent: Double
        let durationSeconds: TimeInterval
        let resetsAt: Date?
    }

    static func parse(data: Data, fetchedAt: Date) throws -> CodexQuotaSnapshot {
        let rootObject: Any
        do {
            rootObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw CodexUsageError.invalidPayload
        }

        guard let root = rootObject as? [String: Any],
              let rateLimit = root["rate_limit"] as? [String: Any] else {
            throw CodexUsageError.invalidPayload
        }

        let candidateValues = [
            rateLimit["primary_window"],
            rateLimit["secondary_window"]
        ].compactMap { $0 }

        var shortWindows: [RawWindow] = []
        var weeklyWindows: [RawWindow] = []
        for value in candidateValues {
            guard let rawWindow = parseWindow(value) else { continue }
            if rawWindow.durationSeconds < 24 * 60 * 60 {
                shortWindows.append(rawWindow)
            } else {
                weeklyWindows.append(rawWindow)
            }
        }

        let fiveHour = selectFiveHour(from: shortWindows).map(makeQuotaWindow)
        let weekly = weeklyWindows.count == 1 ? makeQuotaWindow(weeklyWindows[0]) : nil

        guard fiveHour != nil || weekly != nil else {
            throw CodexUsageError.invalidPayload
        }

        return CodexQuotaSnapshot(fiveHour: fiveHour, weekly: weekly, fetchedAt: fetchedAt)
    }

    private static func parseWindow(_ value: Any) -> RawWindow? {
        guard let dictionary = value as? [String: Any],
              let usedNumber = number(dictionary["used_percent"]),
              let durationNumber = number(dictionary["limit_window_seconds"]) else {
            return nil
        }

        let usedPercent = usedNumber.doubleValue
        let durationSeconds = durationNumber.doubleValue
        guard usedPercent.isFinite, durationSeconds.isFinite, durationSeconds > 0 else {
            return nil
        }

        let resetsAt = number(dictionary["reset_at"]).map { Date(timeIntervalSince1970: $0.doubleValue) }
        return RawWindow(usedPercent: usedPercent, durationSeconds: durationSeconds, resetsAt: resetsAt)
    }

    private static func number(_ value: Any?) -> NSNumber? {
        guard let value, !(value is Bool) else { return nil }
        return value as? NSNumber
    }

    private static func selectFiveHour(from windows: [RawWindow]) -> RawWindow? {
        guard !windows.isEmpty else { return nil }
        let sorted = windows.sorted {
            abs($0.durationSeconds - 18_000) < abs($1.durationSeconds - 18_000)
        }
        guard sorted.count == 1 ||
                abs(sorted[0].durationSeconds - 18_000) < abs(sorted[1].durationSeconds - 18_000) else {
            return nil
        }
        return sorted[0]
    }

    private static func makeQuotaWindow(_ raw: RawWindow) -> QuotaWindow {
        let remainingPercent = min(max(100 - raw.usedPercent, 0), 100)
        return QuotaWindow(
            remainingPercent: remainingPercent,
            windowDurationSeconds: raw.durationSeconds,
            resetsAt: raw.resetsAt
        )
    }
}
