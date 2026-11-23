import AppKit
import OSLog
import QuartzCore
import SpriteKit

@MainActor
final class PetPanelController {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "PetPanelController")

    static let panelSize = NSSize(
        width: PetPanelGeometry.defaultSize.x,
        height: PetPanelGeometry.defaultSize.y
    )

    private enum DockState: Equatable {
        case free
        case docked(edge: PetDockEdge, expandedOrigin: NSPoint)
    }

    private let panel: PetPanel
    private let spriteView: PetSpriteView
    private let positionStore: PetPositionStore
    private let docking: PetDockingPolicy
    private let menuController = PetMenuController()
    private let sessionSurfaces: SessionSurfacesController
    private(set) var petRuntime: PetRuntime

    /// Invoked when the user hides Joey from the desktop menu.
    var onHideRequested: (() -> Void)?

    /// Mirrors every reduced situation so the host can follow session state.
    var onSituationChanged: ((PetSituation) -> Void)?

    private var movementTask: Task<Void, Never>?
    private var settleTask: Task<Void, Never>?
    private var collapseTask: Task<Void, Never>?
    private var dockState: DockState = .free
    private var isDockedCollapsed = false

    convenience init() {
        self.init(positionStore: PetPositionStore())
    }

    init(positionStore: PetPositionStore, docking: PetDockingPolicy? = nil) {
        self.positionStore = positionStore
        self.docking = docking ?? Self.manifestDockingPolicy()

        let frame = Self.restoredFrame(size: Self.panelSize, savedPosition: positionStore.load())
        panel = PetPanel(contentRect: NSRect(origin: frame.origin, size: Self.panelSize))

        spriteView = PetSpriteView(frame: NSRect(origin: .zero, size: Self.panelSize))
        spriteView.allowsTransparency = true
        spriteView.wantsLayer = true
        spriteView.layer?.backgroundColor = NSColor.clear.cgColor

        petRuntime = PetRuntime(sceneSize: Self.panelSize)
        spriteView.presentScene(petRuntime.scene)
        sessionSurfaces = SessionSurfacesController(petPanel: panel, appearance: .light)

        panel.contentView = spriteView
        configureInteractions()
    }

    // MARK: - Runtime wiring

    private func configureInteractions() {
        spriteView.onLeftClick = { [weak self] in self?.showMenu() }
        spriteView.onMenuRequested = { [weak self] in self?.showMenu() }
        spriteView.onDragBegan = { [weak self] in self?.dragBegan() }
        spriteView.onDragEnded = { [weak self] origin in self?.dragEnded(origin: origin) }
        spriteView.onPointerEntered = { [weak self] in self?.pointerEntered() }
        spriteView.onPointerExited = { [weak self] in self?.pointerExited() }
        spriteView.onKeyboardMove = { [weak self] dx, dy in self?.movePanel(by: dx, dy: dy) }

        menuController.isSessionActive = { [weak self] in
            self?.petRuntime.situation.session != nil
        }
        menuController.onOpen = { [weak self] in self?.petRuntime.send(.menuOpened) }
        menuController.onClose = { [weak self] in self?.petRuntime.send(.menuClosed) }
        menuController.onEndSession = { [weak self] in self?.petRuntime.endSession() }
        menuController.onHidePet = { [weak self] in self?.onHideRequested?() }
        menuController.isDoNotDisturb = { [weak self] in
            self?.petRuntime.situation.isDoNotDisturb ?? false
        }
        menuController.onToggleDoNotDisturb = { [weak self] in
            guard let self else { return }
            self.petRuntime.send(
                .doNotDisturbChanged(!self.petRuntime.situation.isDoNotDisturb)
            )
        }

        sessionSurfaces.onAcceptInvitation = { [weak self] in
            self?.petRuntime.send(.inviteAccepted)
        }
        sessionSurfaces.onSnooze = { [weak self] in
            guard let self else { return }
            self.petRuntime.send(.snoozeRequested)
            self.sessionSurfaces.showSnoozeToast()
        }
        sessionSurfaces.onEnterDoNotDisturb = { [weak self] in
            guard let self else { return }
            self.petRuntime.send(.doNotDisturbChanged(true))
            self.sessionSurfaces.showDoNotDisturbToast()
        }
        sessionSurfaces.onFinishRecovery = { [weak self] in
            self?.petRuntime.send(.recoveryFinished)
        }
        sessionSurfaces.onSkipRecovery = { [weak self] in
            self?.petRuntime.send(.recoverySkipped)
        }

        petRuntime.onSituationChanged = { [weak self] situation in
            guard let self else { return }
            self.updateAccessibility(situation)
            self.syncPanelVisibility(with: situation)
            self.sessionSurfaces.update(situation: situation)
            self.onSituationChanged?(situation)
        }
        updateAccessibility(petRuntime.situation)
        syncPanelVisibility(with: petRuntime.situation)
        sessionSurfaces.update(situation: petRuntime.situation)
    }

    /// Follows the app appearance for the floating session surfaces.
    func applyAppearance(_ appearance: JoeyAppearance) {
        sessionSurfaces.applyAppearance(appearance)
    }

    private static func manifestDockingPolicy() -> PetDockingPolicy {
        guard let spec = JoeyAssetPackage.load()?.manifest.docking else {
            return PetDockingPolicy()
        }
        return PetDockingPolicy(spec: spec)
    }

    private(set) var isVisible = false

    /// Hidden mode still surfaces briefly for an invitation; this keeps the
    /// panel in step with the situation instead of the settings switch alone.
    private func syncPanelVisibility(with situation: PetSituation) {
        let shouldShow = situation.shouldShowPanel(at: Date())
        guard shouldShow != isVisible else { return }
        setVisible(shouldShow)
    }

    /// Shows or hides the desktop pet. Hidden mode also pauses SpriteKit so a hidden pet costs no CPU.
    func setVisible(_ visible: Bool) {
        isVisible = visible
        if visible {
            spriteView.isPaused = false
            petRuntime.scene.isPaused = false
            if case .docked = dockState {
                applyDockFrame(animated: false)
            }
            panel.orderFrontRegardless()
            sessionSurfaces.update(situation: petRuntime.situation)
            Self.logger.info("Pet panel shown")
        } else {
            stopMovement()
            cancelDockingTasks()
            panel.orderOut(nil)
            sessionSurfaces.hideAll()
            spriteView.isPaused = true
            petRuntime.scene.isPaused = true
            Self.logger.info("Pet panel hidden")
        }
    }

    func currentFrame() -> NSRect { panel.frame }

    func moveShortDistance() {
        guard isVisible,
              movementTask == nil,
              petRuntime.currentState == .idle,
              petRuntime.currentTransientBehavior == nil,
              petRuntime.perform(.walking) else { return }

        guard let screen = screenForPanel() else {
            petRuntime.finishTransientIfCurrent(.walking)
            return
        }
        let visible = screen.visibleFrame
        let margin: CGFloat = 20
        let direction: CGFloat = Bool.random() ? 1 : -1
        let distance = CGFloat(Int.random(in: 40...120)) * direction
        let minX = visible.minX + margin
        let maxX = visible.maxX - panel.frame.width - margin
        let targetX = min(max(panel.frame.origin.x + distance, minX), maxX)
        guard abs(targetX - panel.frame.origin.x) > 1 else {
            petRuntime.finishTransientIfCurrent(.walking)
            return
        }

        panel.animator().setFrameOrigin(NSPoint(x: targetX, y: panel.frame.origin.y))
        movementTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, let self else { return }
            if self.petRuntime.currentState == .idle {
                self.petRuntime.finishTransientIfCurrent(.walking)
            }
            self.movementTask = nil
        }
    }

    func stopMovement() {
        movementTask?.cancel()
        movementTask = nil
        if petRuntime.currentTransientBehavior == .walking {
            petRuntime.finishTransientIfCurrent(.walking)
        }
    }

    func resetPosition() {
        cancelDockingTasks()
        dockState = .free
        isDockedCollapsed = false
        positionStore.clear()
        let frame = Self.initialFrame(size: Self.panelSize)
        panel.setFrameOrigin(frame.origin)
    }

    // MARK: - Drag and docking

    private func dragBegan() {
        stopMovement()
        cancelDockingTasks()
        dockState = .free
        isDockedCollapsed = false
        petRuntime.send(.dragBegan)
    }

    private func dragEnded(origin: NSPoint) {
        petRuntime.send(.dragEnded)
        saveUserPosition(origin: origin)
        scheduleDockSettle()
    }

    private func pointerEntered() {
        guard case .docked = dockState, isDockedCollapsed else { return }
        collapseTask?.cancel()
        collapseTask = nil
        isDockedCollapsed = false
        applyDockFrame(animated: true)
    }

    private func pointerExited() {
        guard case .docked = dockState, !isDockedCollapsed else { return }
        let delay = docking.collapseDelay
        collapseTask?.cancel()
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, !self.isDockedCollapsed else { return }
            self.isDockedCollapsed = true
            self.applyDockFrame(animated: true)
            self.collapseTask = nil
        }
    }

    private func scheduleDockSettle() {
        let delay = docking.collapseDelay
        settleTask?.cancel()
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.settleDocking()
            self.settleTask = nil
        }
    }

    /// After release the panel re-evaluates whether it sits within 24 pt of a side edge.
    private func settleDocking() {
        guard let screen = screenForPanel() else { return }
        let visible = petVisibleFrame(screen)
        let origin = PetPositionPoint(x: panel.frame.origin.x, y: panel.frame.origin.y)

        guard let edge = PetPanelGeometry.dockEdge(
            for: origin,
            in: visible,
            windowSize: Self.panelSizePoint,
            edgePt: docking.edgePt
        ) else {
            dockState = .free
            isDockedCollapsed = false
            return
        }

        let expanded = PetPanelGeometry.clampedOrigin(
            origin,
            in: visible,
            windowSize: Self.panelSizePoint
        )
        dockState = .docked(
            edge: edge,
            expandedOrigin: NSPoint(x: expanded.x, y: expanded.y)
        )
        isDockedCollapsed = true
        applyDockFrame(animated: true)
        Self.logger.info("Pet docked to \(String(describing: edge), privacy: .public) edge")
    }

    private func applyDockFrame(animated: Bool) {
        guard case let .docked(edge, expandedOrigin) = dockState,
              let screen = screenForPanel() else { return }

        let origin: NSPoint
        if isDockedCollapsed {
            let collapsed = PetPanelGeometry.collapsedOrigin(
                edge: edge,
                expandedOrigin: PetPositionPoint(
                    x: expandedOrigin.x,
                    y: expandedOrigin.y
                ),
                in: petVisibleFrame(screen),
                windowSize: Self.panelSizePoint,
                exposeRatio: docking.exposeRatio,
                minExposePt: docking.minExposePt
            )
            origin = NSPoint(x: collapsed.x, y: collapsed.y)
        } else {
            origin = expandedOrigin
        }

        guard animated, isVisible else {
            panel.setFrameOrigin(origin)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = docking.slideDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrameOrigin(origin)
        }
    }

    private func cancelDockingTasks() {
        settleTask?.cancel()
        settleTask = nil
        collapseTask?.cancel()
        collapseTask = nil
    }

    // MARK: - Menu and keyboard

    private func showMenu() {
        spriteView.toolTip = nil
        menuController.popUp(
            in: spriteView,
            at: NSPoint(x: spriteView.bounds.midX, y: spriteView.bounds.midY)
        )
    }

    private func movePanel(by dx: CGFloat, dy: CGFloat) {
        guard isVisible else { return }
        cancelDockingTasks()
        dockState = .free
        isDockedCollapsed = false

        guard let screen = screenForPanel() else { return }
        let visible = petVisibleFrame(screen)
        let clamped = PetPanelGeometry.clampedOrigin(
            PetPositionPoint(
                x: panel.frame.origin.x + dx,
                y: panel.frame.origin.y + dy
            ),
            in: visible,
            windowSize: Self.panelSizePoint
        )
        let origin = NSPoint(x: clamped.x, y: clamped.y)
        panel.setFrameOrigin(origin)
        saveUserPosition(origin: origin)
    }

    // MARK: - Accessibility

    private func updateAccessibility(_ situation: PetSituation) {
        spriteView.accessibilityStatus = Self.accessibilityStatus(
            for: situation,
            at: Date()
        )
    }

    private static func accessibilityStatus(for situation: PetSituation, at date: Date) -> String {
        switch situation.resolvedDesktop(at: date) {
        case .hidden:
            return "已隐藏"
        case .dragging:
            return "正在换位置"
        case .quiet:
            return "安静时段，正在睡觉"
        case .doNotDisturb:
            return "勿扰模式，先不打扰你"
        case .snoozed:
            return "过一会儿提醒你休息"
        case .companion:
            switch situation.companion {
            case .invite:
                return "想请你休息一下"
            case .recover:
                return "一起伸个懒腰"
            case .complete:
                return "休息完成"
            case .approach, .idle, nil:
                return "在旁边陪着你"
            }
        case .alone:
            if situation.isYawnActive(at: date) {
                return "刚回到电脑前"
            }
            if situation.isDozing {
                return "在打盹"
            }
            return "安静地待着"
        }
    }

    // MARK: - Geometry

    private static var panelSizePoint: PetPositionPoint {
        PetPositionPoint(x: panelSize.width, y: panelSize.height)
    }

    private func petVisibleFrame(_ screen: NSScreen) -> PetPositionRect {
        let visible = screen.visibleFrame
        return PetPositionRect(
            minX: visible.minX,
            minY: visible.minY,
            width: visible.width,
            height: visible.height
        )
    }

    private func screenForPanel() -> NSScreen? {
        NSScreen.screens.first { $0.visibleFrame.intersects(panel.frame) } ?? NSScreen.main
    }

    private func saveUserPosition(origin: NSPoint) {
        guard let screen = screenForPanel() else { return }
        let visibleFrame = screen.visibleFrame
        let visibleGeometry = PetPositionRect(
            minX: visibleFrame.minX,
            minY: visibleFrame.minY,
            width: visibleFrame.width,
            height: visibleFrame.height
        )
        let point = PetPositionPoint(x: origin.x, y: origin.y)
        let size = PetPositionPoint(x: Self.panelSize.width, y: Self.panelSize.height)
        positionStore.save(PetPositionRecord(
            screenIdentifier: Self.screenIdentifier(for: screen),
            absoluteOrigin: point,
            normalizedOrigin: PetPositionGeometry.normalizedOrigin(point, in: visibleGeometry, windowSize: size),
            savedVisibleFrame: visibleGeometry
        ))
    }

    deinit {
        movementTask?.cancel()
        settleTask?.cancel()
        collapseTask?.cancel()
    }

    private static func initialFrame(size: NSSize) -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 120, y: 120, width: size.width, height: size.height)
        }

        let visible = screen.visibleFrame
        let origin = PetPanelGeometry.initialOrigin(
            in: PetPositionRect(
                minX: visible.minX,
                minY: visible.minY,
                width: visible.width,
                height: visible.height
            ),
            windowSize: PetPositionPoint(x: size.width, y: size.height)
        )
        return NSRect(origin: NSPoint(x: origin.x, y: origin.y), size: size)
    }

    private static func restoredFrame(size: NSSize, savedPosition: PetPositionRecord?) -> NSRect {
        let sizePoint = PetPositionPoint(x: size.width, y: size.height)
        let screens = NSScreen.screens.map { screen in
            PetScreenGeometry(
                identifier: screenIdentifier(for: screen),
                visibleFrame: PetPositionRect(
                    minX: screen.visibleFrame.minX,
                    minY: screen.visibleFrame.minY,
                    width: screen.visibleFrame.width,
                    height: screen.visibleFrame.height
                ),
                isMain: screen == NSScreen.main
            )
        }
        let origin = PetPositionGeometry.restore(savedPosition, on: screens, windowSize: sizePoint)
        return NSRect(origin: NSPoint(x: origin.x, y: origin.y), size: size)
    }

    private static func screenIdentifier(for screen: NSScreen) -> String {
        if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return "display-\(number.uint32Value)"
        }
        return "\(screen.localizedName)-\(screen.frame.origin.x)-\(screen.frame.origin.y)"
    }
}

/// Three-item desktop menu from DESIGN §10.1; it only forwards user intent.
@MainActor
private final class PetMenuController: NSObject, NSMenuDelegate {
    var isSessionActive: (() -> Bool)?
    var onOpen: (() -> Void)?
    var onClose: (() -> Void)?
    var onEndSession: (() -> Void)?
    var onHidePet: (() -> Void)?
    var isDoNotDisturb: (() -> Bool)?
    var onToggleDoNotDisturb: (() -> Void)?

    private let menu = NSMenu()
    private let endSessionItem = NSMenuItem(title: "结束陪伴", action: nil, keyEquivalent: "")
    private let hideItem = NSMenuItem(title: "隐藏 Joey", action: nil, keyEquivalent: "")
    private let doNotDisturbItem = NSMenuItem(title: "勿扰模式", action: nil, keyEquivalent: "")

    override init() {
        super.init()

        endSessionItem.target = self
        endSessionItem.action = #selector(endSessionTapped)
        hideItem.target = self
        hideItem.action = #selector(hideTapped)
        doNotDisturbItem.target = self
        doNotDisturbItem.action = #selector(doNotDisturbTapped)

        menu.addItem(endSessionItem)
        menu.addItem(hideItem)
        menu.addItem(.separator())
        menu.addItem(doNotDisturbItem)
        menu.delegate = self
    }

    func popUp(in view: NSView, at point: NSPoint) {
        menu.popUp(positioning: nil, at: point, in: view)
    }

    func menuWillOpen(_ menu: NSMenu) {
        endSessionItem.isEnabled = isSessionActive?() ?? false
        let isOn = isDoNotDisturb?() == true
        doNotDisturbItem.state = isOn ? .on : .off
        doNotDisturbItem.title = isOn ? "勿扰中 · 点击关闭" : "勿扰模式"
        onOpen?()
    }

    func menuDidClose(_ menu: NSMenu) {
        onClose?()
    }

    @objc private func endSessionTapped() {
        onEndSession?()
    }

    @objc private func hideTapped() {
        onHidePet?()
    }

    @objc private func doNotDisturbTapped() {
        onToggleDoNotDisturb?()
    }
}
