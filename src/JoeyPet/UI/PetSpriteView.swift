import AppKit
import OSLog
import SpriteKit

final class PetSpriteView: SKView {
    var interactiveRadius: CGFloat = PetScene.interactiveRadius

    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowOrigin: NSPoint?

#if DEBUG
    private static let interactionLogger = Logger(
        subsystem: "com.zguiyang.JoeyPet",
        category: "PetSpriteView"
    )
#endif

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
        guard let window else { return }

        dragStartMouseLocation = window.convertPoint(toScreen: event.locationInWindow)
        dragStartWindowOrigin = window.frame.origin

#if DEBUG
        Self.interactionLogger.debug("drag began")
#endif
    }

    override func mouseDragged(with event: NSEvent) {
        guard
            let window,
            let dragStartMouseLocation,
            let dragStartWindowOrigin
        else { return }

        let currentMouseLocation = window.convertPoint(toScreen: event.locationInWindow)
        let delta = NSPoint(
            x: currentMouseLocation.x - dragStartMouseLocation.x,
            y: currentMouseLocation.y - dragStartMouseLocation.y
        )

        guard delta.x.isFinite, delta.y.isFinite else { return }

        window.setFrameOrigin(NSPoint(
            x: dragStartWindowOrigin.x + delta.x,
            y: dragStartWindowOrigin.y + delta.y
        ))
    }

    override func mouseUp(with event: NSEvent) {
#if DEBUG
        if dragStartMouseLocation != nil {
            Self.interactionLogger.debug("drag ended")
        }
#endif
        dragStartMouseLocation = nil
        dragStartWindowOrigin = nil
    }
}
