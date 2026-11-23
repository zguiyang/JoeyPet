import AppKit
import SpriteKit

/// Debug-only window hosting the twelve-pose atlas preview.
@MainActor
final class JoeyPosePreviewWindowController: NSWindowController {
    private static let sceneSize = CGSize(width: 1120, height: 1050)

    static func make() -> JoeyPosePreviewWindowController? {
        guard let package = JoeyAssetPackage.load() else {
            return nil
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Joey 姿态预览"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 840, height: 700)

        let controller = JoeyPosePreviewWindowController(window: window)

        let view = JoeyPreviewSKView(frame: NSRect(origin: .zero, size: window.contentLayoutRect.size))
        view.allowsTransparency = false
        view.ignoresSiblingOrder = true
        view.autoresizingMask = [.width, .height]

        let scene = JoeyPosePreviewScene(size: sceneSize, package: package)
        view.presentScene(scene)

        window.contentView = view
        window.center()
        window.makeFirstResponder(view)
        return controller
    }
}

private final class JoeyPreviewSKView: SKView {
    override var acceptsFirstResponder: Bool { true }
}
