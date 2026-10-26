import AppKit
import OSLog
import SpriteKit

/// Shared render lifecycle for the Calm Space SpriteKit hosts.
///
/// The Mac Care orb and the Work Rhythm dial are both decorative `SKView` layers that
/// must never burn frames while they cannot be seen. This object owns the AppKit-side
/// pause rules once, so each host only reports its SwiftUI input (`isActive`) and its
/// window moves:
///
/// - the SwiftUI shell reports `isActive == false` (the page is off-screen, or the
///   window is not presenting this layer),
/// - the app is hidden, or the host's window is gone, miniaturised, or occluded.
///
/// The effective pause is `!isActive || !windowVisible`. Both the view (stop asking for
/// frames) and the scene (stop actions while preserving cycle positions) are paused
/// together, so resuming is seamless and free of jumps.
@MainActor
final class CalmSpaceRenderLifecycle: NSObject {
    /// Short host name ("macCare" / "workRhythm") used only in DEBUG pause logging.
    private let name: String
    private weak var view: SKView?
    private weak var scene: SKScene?

    private var isActive = true
    private var observersInstalled = false

    init(name: String, view: SKView, scene: SKScene) {
        self.name = name
        self.view = view
        self.scene = scene
        super.init()
        installObservers()
        updateRenderState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - SwiftUI inputs

    /// `false` means the shell is not presenting this layer (e.g. another page is
    /// on-screen or the window is not front); the scene then stops ticking instead of
    /// burning frames. Safe to call on every SwiftUI update.
    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        updateRenderState()
    }

    /// Call from the host's `viewDidMoveToWindow()`.
    func didMoveToWindow() {
        if view?.window == nil {
            removeObservers()
        } else {
            installObservers()
        }
        updateRenderState()
    }

    // MARK: - Notifications

    private func installObservers() {
        guard !observersInstalled else { return }
        observersInstalled = true

        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSApplication.didHideNotification,
            NSApplication.didUnhideNotification,
            NSApplication.didBecomeActiveNotification,
            NSWindow.didChangeOcclusionStateNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSWindow.didBecomeKeyNotification
        ]
        for name in names {
            center.addObserver(
                self,
                selector: #selector(handleLifecycleNotification(_:)),
                name: name,
                object: nil
            )
        }
    }

    private func removeObservers() {
        guard observersInstalled else { return }
        observersInstalled = false
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleLifecycleNotification(_ notification: Notification) {
        // Window notifications arrive for every window; only react to our own.
        if let notifiedWindow = notification.object as? NSWindow,
            notifiedWindow !== view?.window
        {
            return
        }
        updateRenderState()
    }

    // MARK: - Render state

    private func updateRenderState() {
        let shouldRender = isActive && canRenderInCurrentWindow
        let paused = !shouldRender
        // Pause both: the view stops asking for frames and the scene stops its actions,
        // so an occluded window costs nothing while the cycle position is preserved for
        // a clean resume.
        if let view, view.isPaused != paused {
            view.isPaused = paused
        }
        if let scene, scene.isPaused != paused {
            scene.isPaused = paused
        }

        #if DEBUG
        // QA observability (`-JoeyPetQADebugRenderState`): log effective pause changes
        // per host. Silent otherwise — no logging unless the flag is present.
        if lastLoggedPaused != paused {
            lastLoggedPaused = paused
            if DebugStateInjector.qaLogsCalmSpaceRenderState() {
                Self.qaLogger.info(
                    "render \(self.name, privacy: .public): \(paused ? "paused" : "running", privacy: .public)"
                )
            }
        }
        #endif
    }

    #if DEBUG
    private static let qaLogger = Logger(
        subsystem: "com.zguiyang.JoeyPet",
        category: "CalmSpaceQA"
    )

    /// Last pause value reported to the QA log (dedupes repeated log lines).
    private var lastLoggedPaused: Bool?
    #endif

    private var canRenderInCurrentWindow: Bool {
        guard !NSApp.isHidden, let window = view?.window else { return false }
        guard window.isVisible, !window.isMiniaturized else { return false }
        return window.occlusionState.contains(.visible)
    }
}
