import AppKit
import OSLog
import SpriteKit

@MainActor
final class PetPanelController {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "PetPanelController")

    static let panelSize = NSSize(
        width: PetPanelGeometry.defaultSize.x,
        height: PetPanelGeometry.defaultSize.y
    )

    private let panel: PetPanel
    private let spriteView: PetSpriteView
    private let positionStore: PetPositionStore
    private let menuController = PetMenuController()
    private let sessionSurfaces: SessionSurfacesController
    private(set) var petRuntime: PetRuntime

    /// Invoked when the user hides Joey from the desktop menu.
    var onHideRequested: (() -> Void)?

    /// Mirrors every reduced situation so the host can follow session state.
    var onSituationChanged: ((PetSituation) -> Void)?

    private var corner: PetCorner

    convenience init(corner: PetCorner = .bottomRight) {
        self.init(positionStore: PetPositionStore(), corner: corner)
    }

    init(
        positionStore: PetPositionStore,
        corner: PetCorner = .bottomRight
    ) {
        self.positionStore = positionStore
        self.corner = corner

        let frame = Self.restoredFrame(
            size: Self.panelSize,
            savedPosition: positionStore.load(),
            corner: corner
        )
        panel = PetPanel(contentRect: NSRect(origin: frame.origin, size: Self.panelSize))

        spriteView = PetSpriteView(frame: NSRect(origin: .zero, size: Self.panelSize))
        spriteView.allowsTransparency = true
        spriteView.wantsLayer = true
        spriteView.layer?.backgroundColor = NSColor.clear.cgColor

        petRuntime = PetRuntime(sceneSize: Self.panelSize)
        spriteView.presentScene(petRuntime.scene)
        sessionSurfaces = SessionSurfacesController(petPanel: panel, appearance: .system)

        panel.contentView = spriteView
        configureInteractions()
    }

    // MARK: - Runtime wiring

    private func configureInteractions() {
        spriteView.onLeftClick = { [weak self] in self?.showMenu() }
        spriteView.onMenuRequested = { [weak self] in self?.showMenu() }
        spriteView.onDragBegan = { [weak self] in self?.dragBegan() }
        spriteView.onDragEnded = { [weak self] origin in self?.dragEnded(origin: origin) }

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
            self?.petRuntime.send(.snoozeRequested)
        }
        sessionSurfaces.onEnterDoNotDisturb = { [weak self] in
            self?.petRuntime.send(.doNotDisturbChanged(true))
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

    /// Keeps the shared greeting tip in step with the rendered pose.
    func syncGreetingTip(for pose: PetPose) {
        sessionSurfaces.setGreetingTipVisible(pose == .wave)
    }

    /// Nest invite card mirrors the desktop invitation actions.
    func acceptInvitationFromNest() {
        petRuntime.send(.inviteAccepted)
    }

    func snoozeInvitationFromNest() {
        petRuntime.send(.snoozeRequested)
    }

    func enterDoNotDisturbFromNest() {
        petRuntime.send(.doNotDisturbChanged(true))
    }

    private(set) var isVisible = false

    /// Hidden mode still surfaces briefly for an invitation; this keeps the
    /// panel in step with the situation instead of the settings switch alone.
    private func syncPanelVisibility(with situation: PetSituation) {
        let shouldShow = situation.shouldShowPanel(at: Date())
        guard shouldShow != isVisible else { return }
        setVisible(shouldShow)
    }

    /// System sleep / lock freeze from `PetRuntime` effects. Keeps SpriteKit
    /// paused even while the panel remains ordered in (hidden panels stay paused).
    private var isRenderFrozen = false

    /// Shows or hides the desktop pet. Hidden mode also pauses SpriteKit so a hidden pet costs no CPU.
    func setVisible(_ visible: Bool) {
        isVisible = visible
        if visible {
            applySpritePausedState()
            panel.orderFrontRegardless()
            sessionSurfaces.update(situation: petRuntime.situation)
            Self.logger.info("Pet panel shown")
        } else {
            panel.orderOut(nil)
            sessionSurfaces.hideAll()
            spriteView.isPaused = true
            petRuntime.scene.isPaused = true
            Self.logger.info("Pet panel hidden")
        }
    }

    /// Mirrors domain `.freeze` / `.resume` so sleep and screen lock stop the GPU.
    func setRenderFrozen(_ frozen: Bool) {
        guard isRenderFrozen != frozen else { return }
        isRenderFrozen = frozen
        applySpritePausedState()
        Self.logger.info("Pet render \(frozen ? "frozen" : "resumed", privacy: .public)")
    }

    private func applySpritePausedState() {
        let paused = !isVisible || isRenderFrozen
        spriteView.isPaused = paused
        petRuntime.scene.isPaused = paused
    }

    func currentFrame() -> NSRect { panel.frame }

    func resetPosition() {
        positionStore.clear()
        let frame = Self.initialFrame(size: Self.panelSize, corner: corner)
        panel.setFrameOrigin(frame.origin)
    }

    /// Moves Joey to the chosen corner and forgets any dragged position so the
    /// choice also applies on the next launch.
    func applyCorner(_ corner: PetCorner) {
        self.corner = corner
        positionStore.clear()

        guard let screen = screenForPanel() ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = PetPanelGeometry.initialOrigin(
            in: PetPositionRect(
                minX: visible.minX,
                minY: visible.minY,
                width: visible.width,
                height: visible.height
            ),
            windowSize: Self.panelSizePoint,
            corner: corner
        )
        panel.setFrameOrigin(NSPoint(x: origin.x, y: origin.y))
        sessionSurfaces.update(situation: petRuntime.situation)
    }

    // MARK: - Drag

    private func dragBegan() {
        petRuntime.send(.dragBegan)
    }

    private func dragEnded(origin: NSPoint) {
        petRuntime.send(.dragEnded)
        saveUserPosition(origin: origin)
    }

    // MARK: - Menu

    private func showMenu() {
        spriteView.toolTip = nil
        menuController.popUp(
            in: spriteView,
            at: NSPoint(x: spriteView.bounds.midX, y: spriteView.bounds.midY)
        )
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
            return "勿扰中"
        case .snoozed:
            return "过一阵再问你"
        case .companion:
            switch situation.companion {
            case .invite:
                return "想请你休息一下"
            case .recover:
                return situation.activeRecipe?.accessibilityRecovering ?? "正在休息"
            case .complete:
                return "好了"
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
            return "在旁边"
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

    private static func initialFrame(
        size: NSSize,
        corner: PetCorner = .bottomRight
    ) -> NSRect {
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
            windowSize: PetPositionPoint(x: size.width, y: size.height),
            corner: corner
        )
        return NSRect(origin: NSPoint(x: origin.x, y: origin.y), size: size)
    }

    private static func restoredFrame(
        size: NSSize,
        savedPosition: PetPositionRecord?,
        corner: PetCorner
    ) -> NSRect {
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
        let origin = PetPositionGeometry.restore(
            savedPosition,
            on: screens,
            windowSize: sizePoint,
            corner: corner
        )
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
        doNotDisturbItem.title = isOn ? "关闭勿扰模式" : "勿扰模式"
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
