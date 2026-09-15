import AppKit
import OSLog
import SpriteKit

@MainActor
final class PetPanelController {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "PetPanelController")

    private let panel: PetPanel
    private let spriteView: PetSpriteView
    private(set) var petRuntime: PetRuntime

    private let panelSize = NSSize(width: 160, height: 160)

    init() {
        let frame = Self.initialFrame(size: panelSize)
        panel = PetPanel(contentRect: NSRect(origin: frame.origin, size: panelSize))

        spriteView = PetSpriteView(frame: NSRect(origin: .zero, size: panelSize))
        spriteView.allowsTransparency = true
        spriteView.wantsLayer = true
        spriteView.layer?.backgroundColor = NSColor.clear.cgColor

        petRuntime = PetRuntime(sceneSize: panelSize)
        spriteView.presentScene(petRuntime.scene)

        panel.contentView = spriteView
    }

    func show() {
        panel.makeKeyAndOrderFront(nil)
        Self.logger.info("Pet panel shown")
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
