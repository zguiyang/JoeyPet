import AppKit
import OSLog
import SpriteKit

@MainActor
final class PetPanelController {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "PetPanelController")

    private let panel: PetPanel
    private let spriteView: PetSpriteView
    private(set) var petRuntime: PetRuntime
    var onLeftClick: (() -> Void)?
    var onRightClick: ((NSEvent) -> Void)?
    private var movementTask: Task<Void, Never>?

    private let panelSize = NSSize(width: 160, height: 160)

    init() {
        let frame = Self.initialFrame(size: panelSize)
        panel = PetPanel(contentRect: NSRect(origin: frame.origin, size: panelSize))

        spriteView = PetSpriteView(frame: NSRect(origin: .zero, size: panelSize))
        spriteView.allowsTransparency = true
        spriteView.wantsLayer = true
        spriteView.layer?.backgroundColor = NSColor.clear.cgColor

        petRuntime = PetRuntime(sceneSize: panelSize, package: Self.debugOverridePackage())
        spriteView.presentScene(petRuntime.scene)

        panel.contentView = spriteView
        spriteView.onLeftClick = { [weak self] in self?.onLeftClick?() }
        spriteView.onRightClick = { [weak self] event in self?.onRightClick?(event) }
    }

    /// Loads a Debug launch-argument package when present and valid; otherwise `nil` (default JoeyRobot).
    private static func debugOverridePackage() -> LoadedPetPackage? {
        guard let packageID = DebugStateInjector.injectedPackageID() else {
            return nil
        }

        if let package = PetAssetLoader.loadBundledPackage(packageID: packageID) {
            logger.info("Using debug pet package \(packageID, privacy: .public)")
            return package
        }

        logger.error("Debug pet package \(packageID, privacy: .public) failed to load; falling back to default")
        return nil
    }

    func show() {
        panel.makeKeyAndOrderFront(nil)
        Self.logger.info("Pet panel shown")
    }

    func currentFrame() -> NSRect { panel.frame }

    func moveShortDistance() {
        guard movementTask == nil,
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

    func showContextMenu(_ menu: NSMenu, for event: NSEvent) {
        menu.popUp(positioning: nil, at: event.locationInWindow, in: spriteView)
    }

    private func screenForPanel() -> NSScreen? {
        NSScreen.screens.first { $0.visibleFrame.intersects(panel.frame) } ?? NSScreen.main
    }

    deinit {
        movementTask?.cancel()
    }

    private static func initialFrame(size: NSSize) -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 120, y: 120, width: size.width, height: size.height)
        }

        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.maxX - size.width - 24,
            y: visible.minY + 24
        )
        return NSRect(origin: origin, size: size)
    }
}
