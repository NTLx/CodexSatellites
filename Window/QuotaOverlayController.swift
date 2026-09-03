import AppKit
import OSLog
import QuartzCore
import SwiftUI

@MainActor
final class QuotaOverlayController {
    private enum OverlayMetrics {
        static let orbDiameter: CGFloat = 14
        static let orbLineWidth: CGFloat = 2.25
        static let panelHeight: CGFloat = 24
        static let collapsedWidth: CGFloat = orbDiameter + orbLineWidth
        static let expandedWidth: CGFloat = 60
        static let horizontalGap: CGFloat = 10
        static let hoverPadding: CGFloat = 10
        static let collapseDelay: Duration = .seconds(3)
        static let expandAnimationDuration: TimeInterval = 0.2
        static let collapseAnimationDuration: TimeInterval = 0.18
    }

    private let logger = Logger(subsystem: "com.codexsatellites.app", category: "window")
    private let usageClient = CodexUsageClient()
    private let leftPanel: NSPanel
    private let rightPanel: NSPanel
    private let leftHostingView: NSHostingView<QuotaOrbView>
    private let rightHostingView: NSHostingView<QuotaOrbView>

    private var state = SnapshotStateMachine()
    private var expanded = false
    private var currentGeometry: NotchGeometry?
    private var refreshTask: Task<Void, Never>?
    private var collapseTask: Task<Void, Never>?
    private var screenChangeObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var started = false

    init() {
        leftHostingView = NSHostingView(rootView: QuotaOrbView(
            remainingPercent: nil,
            freshness: .unavailable,
            expanded: false,
            side: .left
        ))
        rightHostingView = NSHostingView(rootView: QuotaOrbView(
            remainingPercent: nil,
            freshness: .unavailable,
            expanded: false,
            side: .right
        ))
        leftPanel = Self.makePanel(contentView: leftHostingView)
        rightPanel = Self.makePanel(contentView: rightHostingView)
    }

    func start() {
        guard !started else { return }
        started = true
        observeSystemChanges()
        observeMouseMovement()
        updateGeometry()
        updateHoverState(at: NSEvent.mouseLocation)
        refreshTask = Task { [weak self] in
            await self?.refreshLoop()
        }
    }

    func stop() {
        guard started else { return }
        started = false
        refreshTask?.cancel()
        refreshTask = nil
        collapseTask?.cancel()
        collapseTask = nil
        removeObservers()
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
        panel.ignoresMouseEvents = true
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
                await self?.refreshOnce()
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
        screenChangeObserver = nil
        wakeObserver = nil
        globalMouseMonitor = nil
        localMouseMonitor = nil
    }

    private func updateGeometry() {
        currentGeometry = Self.targetGeometry()
        guard currentGeometry != nil else {
            leftPanel.orderOut(nil)
            rightPanel.orderOut(nil)
            logger.info("geometry screen=none visible=false")
            return
        }
        logger.info("geometry screen=builtIn valid=true")
        updatePanelFrames(animated: false)
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
        let width = expanded ? OverlayMetrics.expandedWidth : OverlayMetrics.collapsedWidth
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
            context.duration = expanded
                ? OverlayMetrics.expandAnimationDuration
                : OverlayMetrics.collapseAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            leftPanel.animator().setFrame(leftFrame, display: true)
            rightPanel.animator().setFrame(rightFrame, display: true)
        }
    }

    private func updateHoverState(at location: NSPoint) {
        guard currentGeometry != nil else { return }
        if interactionRegion.contains(location) {
            collapseTask?.cancel()
            collapseTask = nil
            setExpanded(true)
        } else if expanded {
            scheduleCollapse()
        }
    }

    private var interactionRegion: CGRect {
        let left = leftPanel.frame.insetBy(dx: -OverlayMetrics.hoverPadding, dy: -OverlayMetrics.hoverPadding)
        let right = rightPanel.frame.insetBy(dx: -OverlayMetrics.hoverPadding, dy: -OverlayMetrics.hoverPadding)
        return left.union(right)
    }

    private func scheduleCollapse() {
        collapseTask?.cancel()
        collapseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: OverlayMetrics.collapseDelay)
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
            expanded: expanded,
            side: .left
        )
        rightHostingView.rootView = QuotaOrbView(
            remainingPercent: snapshot?.weekly?.remainingPercent,
            freshness: freshness(for: snapshot?.weekly),
            expanded: expanded,
            side: .right
        )
    }

    private func refreshLoop() async {
        await refreshOnce()
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                return
            }
            await refreshOnce()
        }
    }

    private func refreshOnce() async {
        do {
            let snapshot = try await usageClient.fetch()
            state.applySuccess(snapshot)
            render()
            logger.info("usage state=fresh")
        } catch {
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
