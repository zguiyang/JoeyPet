import AppKit
import SpriteKit
import SwiftUI

// MARK: - SwiftUI bridge

/// Ambient layer for the Calm Space main window.
///
/// This is the hero background only: SwiftUI paints the gradient underneath and every
/// label/control above it. The layer is decorative, never intercepts mouse events, and its
/// render loop is paused whenever the window cannot show it.
struct CalmSpaceOrbView: NSViewRepresentable {
    let style: CalmSpaceOrbStyle
    let isActive: Bool

    func makeNSView(context: Context) -> CalmSpaceOrbNSView {
        let view = CalmSpaceOrbNSView(frame: .zero)
        view.apply(style: style)
        view.setActive(isActive)
        return view
    }

    func updateNSView(_ nsView: CalmSpaceOrbNSView, context: Context) {
        // Both calls are cheap + idempotent; the scene diffs the style internally so a
        // resize or an unrelated SwiftUI update never restarts an animation.
        nsView.apply(style: style)
        nsView.setActive(isActive)
    }
}

// MARK: - SKView host

/// `SKView` host for `CalmSpaceOrbScene`.
///
/// Lifecycle rules implemented here:
/// - transparent, 30 FPS (the slowest rate that still reads as smooth for 6–90 s cycles),
/// - render loop paused when the app is hidden, the window is gone/miniaturised/occluded,
///   or the SwiftUI shell reports `isActive == false`,
/// - live resize only forwards the new size to the scene (which reprojects stars and the
///   orb transform); it never presents a new scene or re-bakes textures.
@MainActor
final class CalmSpaceOrbNSView: SKView {
    private static let fallbackSize = CGSize(width: 960, height: 640)
    private static let renderFramesPerSecond = 30

    private let orbScene: CalmSpaceOrbScene

    private var lastStyle: CalmSpaceOrbStyle?

    /// Owns the window/occlusion/app-hidden pause rules shared with the Work Rhythm
    /// host. Created lazily so it can capture `self` after `super.init`.
    private lazy var renderLifecycle = CalmSpaceRenderLifecycle(name: "macCare", view: self, scene: orbScene)

    override init(frame frameRect: NSRect) {
        let hasUsableFrame = frameRect.width > 0 && frameRect.height > 0
        orbScene = CalmSpaceOrbScene(size: hasUsableFrame ? frameRect.size : Self.fallbackSize)

        super.init(frame: frameRect)

        // 30 FPS: the ambient layer's fastest cycle is 6.6 s, so 60 FPS would only double
        // the idle GPU cost without a perceptible gain.
        preferredFramesPerSecond = Self.renderFramesPerSecond
        allowsTransparency = true
        presentScene(orbScene)

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
    func apply(style: CalmSpaceOrbStyle) {
        guard style != lastStyle else { return }
        lastStyle = style
        orbScene.apply(style: style)
    }

    /// Forwards to the shared lifecycle; `false` pauses the scene instead of burning
    /// frames (e.g. another window is front, or this page is off-screen).
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
        if orbScene.size != newSize {
            // `didChangeSize` reprojects the starfield and the orb transform without
            // touching nodes, textures or running actions.
            orbScene.size = newSize
        }
        // Handles the first layout (the scene may have been created before this view had a
        // non-zero frame) and keeps background projection authoritative.
        orbScene.updateViewportLayout()
    }

    /// Decorative background: let clicks/hover reach the SwiftUI window below and above.
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
