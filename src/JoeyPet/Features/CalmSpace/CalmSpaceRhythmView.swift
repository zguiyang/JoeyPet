import AppKit
import SpriteKit
import SwiftUI

// MARK: - SwiftUI bridge

/// Work Rhythm's central dial layer.
///
/// Mirrors `CalmSpaceOrbView`: a decorative, non-interactive `SKView` layer that shares
/// the window/occlusion pause rules through `CalmSpaceRenderLifecycle` instead of
/// duplicating them. SwiftUI paints everything else; this layer only draws the dial.
struct CalmSpaceRhythmView: NSViewRepresentable {
    let style: CalmSpaceRhythmStyle
    let isActive: Bool

    func makeNSView(context: Context) -> CalmSpaceRhythmNSView {
        let view = CalmSpaceRhythmNSView(frame: .zero)
        view.apply(style: style)
        view.setActive(isActive)
        return view
    }

    func updateNSView(_ nsView: CalmSpaceRhythmNSView, context: Context) {
        // Both calls are cheap + idempotent; the scene diffs the style internally so a
        // resize or an unrelated SwiftUI update never restarts an animation.
        nsView.apply(style: style)
        nsView.setActive(isActive)
    }
}

// MARK: - SKView host

/// `SKView` host for `CalmSpaceRhythmScene`.
///
/// Same lifecycle contract as the orb host: transparent, 30 FPS, `hitTest` nil, and the
/// render loop paused (via the shared `CalmSpaceRenderLifecycle`) when the app is hidden,
/// the window is gone/miniaturised/occluded, or the SwiftUI shell reports
/// `isActive == false`. Live resize only forwards the new size to the scene.
@MainActor
final class CalmSpaceRhythmNSView: SKView {
    private static let fallbackSize = CGSize(width: 960, height: 640)
    private static let renderFramesPerSecond = 30

    private let rhythmScene: CalmSpaceRhythmScene
    private var lastStyle: CalmSpaceRhythmStyle?

    /// Owns the window/occlusion/app-hidden pause rules for both scene hosts. Created
    /// lazily so it can capture `self` after `super.init`.
    private lazy var renderLifecycle = CalmSpaceRenderLifecycle(name: "workRhythm", view: self, scene: rhythmScene)

    override init(frame frameRect: NSRect) {
        let hasUsableFrame = frameRect.width > 0 && frameRect.height > 0
        rhythmScene = CalmSpaceRhythmScene(size: hasUsableFrame ? frameRect.size : Self.fallbackSize)

        super.init(frame: frameRect)

        // The dial's fastest cycle is 8 s; 30 FPS is more than enough and keeps the
        // idle GPU cost as low as the orb layer's.
        preferredFramesPerSecond = Self.renderFramesPerSecond
        allowsTransparency = true
        presentScene(rhythmScene)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setAccessibilityElement(false)

        // Instantiating the lifecycle installs the window observers and applies the
        // initial pause state (a not-yet-attached view starts paused).
        _ = renderLifecycle
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    // MARK: SwiftUI inputs

    /// Safe to call on every SwiftUI update: an equal style is a no-op.
    func apply(style: CalmSpaceRhythmStyle) {
        guard style != lastStyle else { return }
        lastStyle = style
        rhythmScene.apply(style: style)
    }

    /// Forwards to the shared lifecycle; `false` pauses the scene immediately (the
    /// off-screen page case).
    func setActive(_ active: Bool) {
        renderLifecycle.setActive(active)
    }

    // MARK: NSView

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        renderLifecycle.didMoveToWindow()
    }

    override func layout() {
        super.layout()
        let newSize = bounds.size
        guard newSize.width > 0, newSize.height > 0 else { return }
        if rhythmScene.size != newSize {
            // Reprojects the dial transform only; never touches textures or actions.
            rhythmScene.size = newSize
        }
        // Handles the first layout (the scene may predate this view's non-zero frame).
        rhythmScene.updateViewportLayout()
    }

    /// Decorative layer: let clicks/hover reach the SwiftUI controls below and above.
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
