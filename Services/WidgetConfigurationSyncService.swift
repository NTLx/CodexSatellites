import CoreFoundation
import Foundation
import OSLog
import WidgetKit

struct WidgetConfigurationFingerprint: Codable, Equatable, Hashable, Sendable {
    enum Family: String, Codable, Sendable {
        case small
        case medium
    }

    let family: Family
    let launchAtLogin: Bool
    let refreshIntervalMinutes: Int
}

struct WidgetConfigurationDelta: Equatable, Sendable {
    let launchAtLogin: Bool?
    let refreshIntervalMinutes: Int?

    var isEmpty: Bool {
        launchAtLogin == nil && refreshIntervalMinutes == nil
    }
}

enum WidgetConfigurationReconciler {
    /// WidgetKit configuration is stored per widget instance, while these two
    /// settings are app-global. Treat one same-family replacement as one edited
    /// widget and apply only fields that actually changed on that instance.
    /// Add/remove/resize or otherwise ambiguous changes update the baseline only.
    static func delta(
        previous: [WidgetConfigurationFingerprint],
        current: [WidgetConfigurationFingerprint]
    ) -> WidgetConfigurationDelta? {
        var unmatchedPrevious = previous
        var added: [WidgetConfigurationFingerprint] = []

        for item in current {
            if let index = unmatchedPrevious.firstIndex(of: item) {
                unmatchedPrevious.remove(at: index)
            } else {
                added.append(item)
            }
        }

        guard unmatchedPrevious.count == 1,
              added.count == 1,
              let old = unmatchedPrevious.first,
              let new = added.first,
              old.family == new.family else {
            return nil
        }

        let delta = WidgetConfigurationDelta(
            launchAtLogin: old.launchAtLogin == new.launchAtLogin ? nil : new.launchAtLogin,
            refreshIntervalMinutes: old.refreshIntervalMinutes == new.refreshIntervalMinutes
                ? nil
                : new.refreshIntervalMinutes
        )
        return delta.isEmpty ? nil : delta
    }
}

private enum WidgetConfigurationBaselineStore {
    private static let fileName = "widget-configuration-baseline.json"

    static func load(fileManager: FileManager = .default) -> [WidgetConfigurationFingerprint]? {
        guard let url = url(fileManager: fileManager),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode([WidgetConfigurationFingerprint].self, from: data)
    }

    static func save(
        _ baseline: [WidgetConfigurationFingerprint],
        fileManager: FileManager = .default
    ) throws {
        guard let url = url(fileManager: fileManager) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(baseline)
        try data.write(to: url, options: .atomic)
    }

    private static func url(fileManager: FileManager) -> URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("CodexSatellites", isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }
}

private func widgetConfigurationSignalCallback(
    _ center: CFNotificationCenter?,
    _ observer: UnsafeMutableRawPointer?,
    _ name: CFNotificationName?,
    _ object: UnsafeRawPointer?,
    _ userInfo: CFDictionary?
) {
    guard let observer else { return }
    let service = Unmanaged<WidgetConfigurationSyncService>
        .fromOpaque(observer)
        .takeUnretainedValue()
    Task { @MainActor in
        service.configurationSignalReceived()
    }
}

@MainActor
final class WidgetConfigurationSyncService {
    typealias ApplyChange = (_ launchAtLogin: Bool?, _ refreshInterval: QuotaRefreshInterval?) -> Void

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.github.ntlx.codexsatellites",
        category: "widget-configuration"
    )
    private let applyChange: ApplyChange
    private var baseline: [WidgetConfigurationFingerprint]?
    private var started = false
    private var scanInFlight = false
    private var scanPending = false
    private var debounceTask: Task<Void, Never>?

    init(applyChange: @escaping ApplyChange) {
        self.applyChange = applyChange
        baseline = WidgetConfigurationBaselineStore.load()
    }

    deinit {
        debounceTask?.cancel()
    }

    func start() {
        guard !started else { return }
        started = true
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            widgetConfigurationSignalCallback,
            WidgetConfigurationSignal.name.rawValue,
            nil,
            .deliverImmediately
        )
        requestScan()
    }

    func stop() {
        guard started else { return }
        started = false
        debounceTask?.cancel()
        debounceTask = nil
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            WidgetConfigurationSignal.name,
            nil
        )
    }

    fileprivate func configurationSignalReceived() {
        guard started else { return }
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(150))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.requestScan()
        }
    }

    private func requestScan() {
        guard started else { return }
        if scanInFlight {
            scanPending = true
            return
        }
        scanInFlight = true

        WidgetCenter.shared.getCurrentConfigurations { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.scanInFlight = false
                self.process(result)
                if self.scanPending {
                    self.scanPending = false
                    self.requestScan()
                }
            }
        }
    }

    private func process(_ result: Result<[WidgetInfo], Error>) {
        switch result {
        case let .failure(error):
            let nsError = error as NSError
            logger.error(
                "widget configuration scan result=failure error=\(nsError.domain, privacy: .public)#\(nsError.code, privacy: .public)"
            )
        case let .success(infos):
            let current = infos.compactMap(Self.fingerprint)
            guard let previous = baseline else {
                baseline = current
                saveBaseline(current)
                logger.info("widget configuration scan result=baselineInitialized count=\(current.count, privacy: .public)")
                return
            }

            let delta = WidgetConfigurationReconciler.delta(previous: previous, current: current)
            baseline = current
            saveBaseline(current)

            guard let delta else {
                logger.info("widget configuration scan result=noGlobalChange count=\(current.count, privacy: .public)")
                return
            }

            let interval = delta.refreshIntervalMinutes.flatMap(QuotaRefreshInterval.init(rawValue:))
            applyChange(delta.launchAtLogin, interval)
            logger.info(
                "widget configuration scan result=applied launchChanged=\(delta.launchAtLogin != nil, privacy: .public) frequencyChanged=\(delta.refreshIntervalMinutes != nil, privacy: .public)"
            )
        }
    }

    private func saveBaseline(_ current: [WidgetConfigurationFingerprint]) {
        do {
            try WidgetConfigurationBaselineStore.save(current)
        } catch {
            let nsError = error as NSError
            logger.error(
                "widget configuration baseline save result=failure error=\(nsError.domain, privacy: .public)#\(nsError.code, privacy: .public)"
            )
        }
    }

    private static func fingerprint(_ info: WidgetInfo) -> WidgetConfigurationFingerprint? {
        guard info.kind == WidgetSnapshotStore.widgetKind,
              let intent = info.widgetConfigurationIntent(of: CodexWidgetConfigurationIntent.self) else {
            return nil
        }

        let family: WidgetConfigurationFingerprint.Family
        switch info.family {
        case .systemSmall:
            family = .small
        case .systemMedium:
            family = .medium
        default:
            return nil
        }

        return WidgetConfigurationFingerprint(
            family: family,
            launchAtLogin: intent.launchAtLogin,
            refreshIntervalMinutes: intent.refreshInterval.minutes
        )
    }
}
