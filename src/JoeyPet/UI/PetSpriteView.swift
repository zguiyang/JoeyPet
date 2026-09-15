import AppKit
import SpriteKit

final class PetSpriteView: SKView {
    var interactiveRadius: CGFloat = PetScene.interactiveRadius

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        preferredFramesPerSecond = 30
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        preferredFramesPerSecond = 30
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }

        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = hypot(dx, dy)

        if distance <= interactiveRadius {
            return self
        }

        return nil
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
