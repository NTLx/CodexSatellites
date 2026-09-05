import AppKit
import OSLog
import QuartzCore
import ServiceManagement
import SwiftUI

@MainActor
final class QuotaOverlayController {
    private enum OverlayMetrics {
        static let orbDiameter: CGFloat = 14
        static let orbLineWidth: CGFloat = 2.5
        static let panelHeight: CGFloat = 24
        static let collapsedWidth: CGFloat = 24
        static let expandedWidth: CGFloat = 60
        static let horizontalGap: CGFloat = 10
        static let hoverPadding: CGFloat = 10
        static let settingsWidth: CGFloat = 176
        static let settingsHeight: CGFloat = 44
        static let settingsNotchGap: CGFloat = 6
        static let expandAnimationDuration: TimeInterval = 0.2
        static let collapseAnimationDuration: TimeInterval = 0.18
        static let settingsShowDuration: TimeInterval = 0.18
        static let settingsHideDuration: TimeInterval = 0.15
        static let settingsAnimationOffset: CGFloat = 6
    }

    private static let loggerSubsystem = Bundle.main.bundleIdentifier ?? "io.github.ntlx.codexsatellites"
    static let settingsAutoHideDelay: Duration = .seconds(3)
    private let logger = Logger(subsystem: QuotaOverlayController.loggerSubsystem, category: "window")
    private let usageClient = CodexUsageClient()
    private let launchAtLoginService: LaunchAtLoginService
    private let refreshPreference: QuotaRefreshPreference
    private let leftPanel: NSPanel
    private let rightPanel: NSPanel
    private let settingsPanel: NSPanel
    private let leftHostingView: NSHostingView<QuotaOrbView>
    private let rightHostingView: NSHostingView<QuotaOrbView>
    private var settingsHostingView: NSHostingView<SettingsBarView>

    private var state = SnapshotStateMachine()
    private var expanded = false
    private var settingsVisible = false
    private var currentGeometry: NotchGeometry?
    private var refreshTask: Task<Void, Never>?
    private var refreshInterval: QuotaRefreshInterval
    private var refreshLoopGeneration = 0
    private var refreshInFlight = false
    private var refreshPending = false
    private var refreshFollowUpTask: Task<Void, Never>?
    private var collapseTask: Task<Void, Never>?
    private var settingsAutoHideTask: Task<Void, Never>?
    private var screenChangeObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var started = false

    init(refreshPreference: QuotaRefreshPreference = QuotaRefreshPreference()) {
        launchAtLoginService = LaunchAtLoginService()
        self.refreshPreference = refreshPreference
        refreshInterval = refreshPreference.interval
        leftHostingView = NSHostingView(rootView: QuotaOrbView(
            remainingPercent: nil,
            freshness: .unavailable,
            expanded: false,
            side: .left,
            onActivate: {}
        ))
        rightHostingView = NSHostingView(rootView: QuotaOrbView(
            remainingPercent: nil,
            freshness: .unavailable,
            expanded: false,
            side: .right,
            onActivate: {}
        ))
        settingsHostingView = NSHostingView(rootView: SettingsBarView(
            launchAtLoginState: .unavailable,
            refreshInterval: refreshInterval,
            availableResetCount: nil,
            onSetLaunchAtLogin: { _ in },
            onReviewLoginItems: {},
            onAdvanceRefreshInterval: {},
            onQuit: {}
        ))
        leftPanel = Self.makePanel(contentView: leftHostingView)
        rightPanel = Self.makePanel(contentView: rightHostingView)
        settingsPanel = Self.makeSettingsPanel(contentView: settingsHostingView)
        settingsHostingView.rootView = makeSettingsBarView()
    }

    func start() {
        guard !started else { return }
        started = true
        observeSystemChanges()
        observeMouseMovement()
        updateGeometry()
        updateHoverState(at: NSEvent.mouseLocation)
        startRefreshLoop(immediately: true)
    }

    func stop() {
        cancelSettingsAutoHide()
        guard started else { return }
        started = false
        refreshLoopGeneration += 1
        refreshTask?.cancel()
        refreshTask = nil
        refreshPending = false
        refreshFollowUpTask?.cancel()
        refreshFollowUpTask = nil
        collapseTask?.cancel()
        collapseTask = nil
        removeObservers()
        settingsVisible = false
        settingsPanel.alphaValue = 1
        settingsPanel.orderOut(nil)
        leftPanel.orderOut(nil)
        rightPanel.orderOut(nil)
    }

    private static func makePanel(contentView: NSView) -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: OverlayMetrics.collapsedWidth, height: OverlayMetrics.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = contentView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isExcludedFromWindowsMenu = true
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = false
        return panel
    }

    private static func makeSettingsPanel(contentView: NSView) -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: OverlayMetrics.settingsWidth, height: OverlayMetrics.settingsHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = contentView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isExcludedFromWindowsMenu = true
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = false
        return panel
    }

    private func observeSystemChanges() {
        let center = NotificationCenter.default
        screenChangeObserver = center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateGeometry()
            }
        }
        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: NSWorkspace.shared,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateGeometry()
                await self?.requestRefresh()
            }
        }
    }

    private func observeMouseMovement() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            let location = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                self?.updateHoverState(at: location)
            }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            let location = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                self?.updateHoverState(at: location)
            }
            return event
        }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            let location = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                self?.handleClick(at: location)
            }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            let location = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                self?.handleClick(at: location)
            }
            return event
        }
    }

    private func removeObservers() {
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
        if let wakeObserver {
            NotificationCenter.default.removeObserver(wakeObserver)
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
        }
        screenChangeObserver = nil
        wakeObserver = nil
        globalMouseMonitor = nil
        localMouseMonitor = nil
        globalClickMonitor = nil
        localClickMonitor = nil
    }

    private func updateGeometry() {
        currentGeometry = Self.targetGeometry()
        guard let geometry = currentGeometry else {
            hideSettingsBar(animated: false)
            leftPanel.orderOut(nil)
            rightPanel.orderOut(nil)
            logger.info("geometry screen=none visible=false")
            return
        }
        logger.info("geometry screen=builtIn valid=true")
        updatePanelFrames(animated: false)
        if settingsVisible {
            settingsPanel.setFrame(settingsFrame(for: geometry), display: true, animate: false)
        }
        leftPanel.orderFrontRegardless()
        rightPanel.orderFrontRegardless()
    }

    private static func targetGeometry() -> NotchGeometry? {
        let candidates = NSScreen.screens.compactMap { screen -> (NSScreen, NotchGeometry, Bool)? in
            guard let geometry = NotchGeometry.from(screen: screen, horizontalGap: OverlayMetrics.horizontalGap) else {
                return nil
            }
            return (screen, geometry, isBuiltIn(screen))
        }

        return candidates
            .sorted { lhs, rhs in
                if lhs.2 != rhs.2 { return lhs.2 && !rhs.2 }
                if lhs.0 == NSScreen.main { return true }
                return false
            }
            .first?.1
    }

    private static func isBuiltIn(_ screen: NSScreen) -> Bool {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return false
        }
        return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0
    }

    private func updatePanelFrames(animated: Bool) {
        guard let geometry = currentGeometry else { return }
        let width = effectiveExpanded ? OverlayMetrics.expandedWidth : OverlayMetrics.collapsedWidth
        let height = OverlayMetrics.panelHeight
        let y = geometry.verticalCenter - height / 2
        let leftX = geometry.leftAnchor(gap: OverlayMetrics.horizontalGap) - width
        let rightX = geometry.rightAnchor(gap: OverlayMetrics.horizontalGap)
        let leftFrame = CGRect(x: leftX, y: y, width: width, height: height)
        let rightFrame = CGRect(x: rightX, y: y, width: width, height: height)

        guard animated else {
            leftPanel.setFrame(leftFrame, display: true, animate: false)
            rightPanel.setFrame(rightFrame, display: true, animate: false)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = effectiveExpanded
                ? OverlayMetrics.expandAnimationDuration
                : OverlayMetrics.collapseAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            leftPanel.animator().setFrame(leftFrame, display: true)
            rightPanel.animator().setFrame(rightFrame, display: true)
        }
    }

    private func updateHoverState(at location: NSPoint) {
        guard currentGeometry != nil else { return }
        if settingsVisible, settingsPanel.frame.contains(location) {
            scheduleSettingsAutoHide()
        }
        if interactionRegion.contains(location) {
            collapseTask?.cancel()
            collapseTask = nil
            setExpanded(true)
        } else if expanded && !settingsVisible {
            scheduleCollapse()
        }
    }

    private var effectiveExpanded: Bool {
        expanded || settingsVisible
    }

    private var interactionRegion: CGRect {
        let left = leftPanel.frame.insetBy(dx: -OverlayMetrics.hoverPadding, dy: -OverlayMetrics.hoverPadding)
        let right = rightPanel.frame.insetBy(dx: -OverlayMetrics.hoverPadding, dy: -OverlayMetrics.hoverPadding)
        return left.union(right)
    }

    private func scheduleCollapse() {
        collapseTask?.cancel()
        collapseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.settingsAutoHideDelay)
            guard !Task.isCancelled else { return }
            self?.collapseIfCursorOutside()
        }
    }

    private func collapseIfCursorOutside() {
        guard !interactionRegion.contains(NSEvent.mouseLocation) else { return }
        setExpanded(false)
    }

    private func setExpanded(_ value: Bool) {
        guard expanded != value else { return }
        expanded = value
        render()
        updatePanelFrames(animated: true)
        logger.info("window expanded=\(value)")
    }

    func toggleSettingsBar() {
        guard started else { return }
        if settingsVisible {
            hideSettingsBar(animated: true)
        } else {
            showSettingsBar()
        }
    }

    private func showSettingsBar() {
        guard let geometry = currentGeometry else {
            logger.info("settings visible=false reason=geometryUnavailable")
            return
        }

        if launchAtLoginService.state() == .unavailable {
            logger.info("launchAtLogin state=unavailable")
        }
        settingsVisible = true
        render()
        updatePanelFrames(animated: true)

        let finalFrame = settingsFrame(for: geometry)
        let initialFrame = finalFrame.offsetBy(dx: 0, dy: OverlayMetrics.settingsAnimationOffset)
        settingsPanel.alphaValue = 0
        settingsPanel.setFrame(initialFrame, display: false, animate: false)
        settingsPanel.orderFrontRegardless()

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduceMotion {
            settingsPanel.alphaValue = 1
            settingsPanel.setFrame(finalFrame, display: true, animate: false)
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = OverlayMetrics.settingsShowDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                settingsPanel.animator().alphaValue = 1
                settingsPanel.animator().setFrame(finalFrame, display: true)
            }
        }
        scheduleSettingsAutoHide()
        logger.info("settings visible=true")
    }

    private func hideSettingsBar(animated: Bool) {
        cancelSettingsAutoHide()
        guard settingsVisible else {
            settingsPanel.orderOut(nil)
            return
        }

        settingsVisible = false
        render()
        updatePanelFrames(animated: true)
        updateHoverState(at: NSEvent.mouseLocation)

        guard animated, let geometry = currentGeometry else {
            settingsPanel.alphaValue = 1
            settingsPanel.orderOut(nil)
            logger.info("settings visible=false")
            return
        }

        let finalFrame = settingsFrame(for: geometry)
        let hiddenFrame = finalFrame.offsetBy(dx: 0, dy: OverlayMetrics.settingsAnimationOffset)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = reduceMotion ? 0.01 : OverlayMetrics.settingsHideDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            settingsPanel.animator().alphaValue = 0
            settingsPanel.animator().setFrame(hiddenFrame, display: true)
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, !self.settingsVisible else { return }
                self.settingsPanel.orderOut(nil)
                self.settingsPanel.alphaValue = 1
                self.logger.info("settings visible=false")
            }
        })
    }

    private func scheduleSettingsAutoHide() {
        guard settingsVisible else { return }
        settingsAutoHideTask?.cancel()
        settingsAutoHideTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.settingsAutoHideDelay)
            } catch {
                return
            }
            guard let self, !Task.isCancelled, self.settingsVisible else { return }
            self.hideSettingsBar(animated: true)
        }
    }

    private func cancelSettingsAutoHide() {
        settingsAutoHideTask?.cancel()
        settingsAutoHideTask = nil
    }

    private func settingsFrame(for geometry: NotchGeometry) -> CGRect {
        CGRect(
            x: geometry.notchCenterX - OverlayMetrics.settingsWidth / 2,
            y: geometry.notchBottomEdge - OverlayMetrics.settingsNotchGap - OverlayMetrics.settingsHeight,
            width: OverlayMetrics.settingsWidth,
            height: OverlayMetrics.settingsHeight
        )
    }

    private func handleClick(at location: NSPoint) {
        guard settingsVisible else { return }
        let isInside = leftPanel.frame.contains(location)
            || rightPanel.frame.contains(location)
            || settingsPanel.frame.contains(location)
        if !isInside {
            hideSettingsBar(animated: true)
        } else if settingsPanel.frame.contains(location) {
            scheduleSettingsAutoHide()
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginService.setEnabled(enabled)
        } catch {
            logger.error("login item update failed error=\(String(describing: error), privacy: .public)")
        }
        render()
        scheduleSettingsAutoHide()
    }

    private func reviewLoginItems() {
        hideSettingsBar(animated: true)
        SMAppService.openSystemSettingsLoginItems()
    }

    private func advanceRefreshInterval() {
        let nextInterval = refreshInterval.next
        refreshPreference.interval = nextInterval
        refreshInterval = nextInterval
        startRefreshLoop(immediately: false)
        render()
        scheduleSettingsAutoHide()
    }

    private func quit() {
        NSApp.terminate(nil)
    }

    private func render() {
        let snapshot = state.freshness.snapshot
        let overallFreshness: OrbFreshness
        switch state.freshness {
        case .unavailable:
            overallFreshness = .unavailable
        case .fresh:
            overallFreshness = .fresh
        case .stale:
            overallFreshness = .stale
        }

        func freshness(for window: QuotaWindow?) -> OrbFreshness {
            window == nil ? .unavailable : overallFreshness
        }

        leftHostingView.rootView = QuotaOrbView(
            remainingPercent: snapshot?.fiveHour?.remainingPercent,
            freshness: freshness(for: snapshot?.fiveHour),
            expanded: effectiveExpanded,
            side: .left,
            onActivate: { [weak self] in
                self?.toggleSettingsBar()
            }
        )
        rightHostingView.rootView = QuotaOrbView(
            remainingPercent: snapshot?.weekly?.remainingPercent,
            freshness: freshness(for: snapshot?.weekly),
            expanded: effectiveExpanded,
            side: .right,
            onActivate: { [weak self] in
                self?.toggleSettingsBar()
            }
        )
        settingsHostingView.rootView = makeSettingsBarView()
    }

    private func makeSettingsBarView() -> SettingsBarView {
        let availableResetCount: Int?
        if case let .fresh(snapshot) = state.freshness {
            availableResetCount = snapshot.availableResetCount
        } else {
            availableResetCount = nil
        }

        return SettingsBarView(
            launchAtLoginState: launchAtLoginService.state(),
            refreshInterval: refreshInterval,
            availableResetCount: availableResetCount,
            onSetLaunchAtLogin: { [weak self] enabled in
                self?.setLaunchAtLogin(enabled)
            },
            onReviewLoginItems: { [weak self] in
                self?.reviewLoginItems()
            },
            onAdvanceRefreshInterval: { [weak self] in
                self?.advanceRefreshInterval()
            },
            onQuit: { [weak self] in
                self?.quit()
            }
        )
    }

    private func startRefreshLoop(immediately: Bool) {
        refreshLoopGeneration += 1
        let generation = refreshLoopGeneration
        let interval = refreshInterval
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            await self?.refreshLoop(
                interval: interval,
                generation: generation,
                immediately: immediately
            )
        }
    }

    private func refreshLoop(
        interval: QuotaRefreshInterval,
        generation: Int,
        immediately: Bool
    ) async {
        guard isCurrentRefreshLoop(generation) else { return }
        if immediately {
            await requestRefresh()
        }
        guard isCurrentRefreshLoop(generation) else { return }
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: interval.duration)
            } catch {
                return
            }
            guard isCurrentRefreshLoop(generation) else { return }
            await requestRefresh()
        }
    }

    private func isCurrentRefreshLoop(_ generation: Int) -> Bool {
        started && refreshLoopGeneration == generation && !Task.isCancelled
    }

    private func requestRefresh() async {
        guard started, !Task.isCancelled else { return }
        if refreshInFlight {
            refreshPending = true
            return
        }
        refreshInFlight = true
        await refreshOnce()
        refreshInFlight = false

        guard refreshPending else { return }
        refreshPending = false
        guard started else { return }
        refreshFollowUpTask?.cancel()
        refreshFollowUpTask = Task { @MainActor [weak self] in
            await self?.requestRefresh()
        }
    }

    private func refreshOnce() async {
        guard !Task.isCancelled else { return }
        do {
            let snapshot = try await usageClient.fetch()
            guard started, !Task.isCancelled else { return }
            state.applySuccess(snapshot)
            render()
            logger.info("usage state=fresh")
        } catch {
            guard started, !Task.isCancelled else { return }
            state.applyFailure()
            render()
            switch state.freshness {
            case .unavailable:
                logger.info("usage state=unavailable")
            case .stale:
                logger.info("usage state=stale")
            case .fresh:
                break
            }
        }
    }
}
