import AppKit
import QuartzCore
import SwiftUI

/// Owns the floating desktop surfaces that belong to a companionship session:
/// the companion chip, the rest invitation, the 30-second recovery panel and
/// short toasts.
///
/// The controller only renders situations and forwards button intent; product
/// state stays in `PetRuntime` / `PetStateMachine`.
@MainActor
final class SessionSurfacesController {
    private static let completionToast = "好了。Joey 的窝里多了一片叶子。"
    private static let snoozeToast = "好，过一阵再问你。"
    private static let doNotDisturbToast = "好，先不打扰你。"

    var onAcceptInvitation: (() -> Void)?
    var onSnooze: (() -> Void)?
    var onEnterDoNotDisturb: (() -> Void)?
    var onFinishRecovery: (() -> Void)?
    var onSkipRecovery: (() -> Void)?

    private let petPanel: NSPanel
    private var appearance: JoeyAppearance
    private var lastSituation: PetSituation?
    private var moveObserver: NSObjectProtocol?
    private var toastTask: Task<Void, Never>?

    private let chipPanel = SurfacePanel(interactive: false)
    private let invitationPanel = SurfacePanel(interactive: true)
    private let recoveryPanel = SurfacePanel(interactive: true)
    private let toastPanel = SurfacePanel(interactive: false)

    private let chipHost = NSHostingView(rootView: AnyView(EmptyView()))
    private let invitationHost = NSHostingView(rootView: AnyView(EmptyView()))
    private let recoveryHost = NSHostingView(rootView: AnyView(EmptyView()))
    private let toastHost = NSHostingView(rootView: AnyView(EmptyView()))

    init(petPanel: NSPanel, appearance: JoeyAppearance) {
        self.petPanel = petPanel
        self.appearance = appearance

        for panel in panels {
            panel.appearance = appearance.nsAppearance
            panel.hasShadow = true
        }
        invitationHost.translatesAutoresizingMaskIntoConstraints = true
        chipHost.translatesAutoresizingMaskIntoConstraints = true
        recoveryHost.translatesAutoresizingMaskIntoConstraints = true
        toastHost.translatesAutoresizingMaskIntoConstraints = true

        chipPanel.contentView = chipHost
        invitationPanel.contentView = invitationHost
        recoveryPanel.contentView = recoveryHost
        toastPanel.contentView = toastHost
        toastPanel.ignoresMouseEvents = true

        observePetPanelMoves()
    }

    // MARK: - Rendering

    /// Applies one situation snapshot to every surface.
    func update(situation: PetSituation, now: Date = Date()) {
        let previous = lastSituation
        lastSituation = situation

        let presentation = SessionSurfacePresentation(
            situation: situation,
            previous: previous,
            now: now
        )

        if presentation.showsCompanionChip, let session = situation.session {
            setRoot(chipHost, JoeyCompanionChipView(startedAt: session.startedAt))
            present(
                chipPanel,
                host: chipHost,
                fallback: NSSize(width: 150, height: 30),
                origin: chipOrigin,
                duration: 0.24,
                rise: 6
            )
        } else {
            dismiss(chipPanel, entrance: 0.24)
        }

        if presentation.showsInvitation {
            setRoot(
                invitationHost,
                InvitationCardView(
                    onAccept: { [weak self] in self?.onAcceptInvitation?() },
                    onSnooze: { [weak self] in self?.onSnooze?() },
                    onDoNotDisturb: { [weak self] in self?.onEnterDoNotDisturb?() }
                )
            )
            present(
                invitationPanel,
                host: invitationHost,
                fallback: NSSize(width: 400, height: 292),
                origin: invitationOrigin,
                duration: 0.38,
                rise: 10
            )
        } else {
            dismiss(invitationPanel, entrance: 0.38)
        }

        if presentation.showsRecovery, let endsAt = presentation.recoveryEndsAt {
            setRoot(
                recoveryHost,
                RecoveryPanelView(
                    endsAt: endsAt,
                    onDone: { [weak self] in self?.onFinishRecovery?() },
                    onSkip: { [weak self] in self?.onSkipRecovery?() }
                )
            )
            present(
                recoveryPanel,
                host: recoveryHost,
                fallback: NSSize(width: 420, height: 340),
                origin: recoveryOrigin,
                duration: 0.38,
                rise: 10
            )
        } else {
            dismiss(recoveryPanel, entrance: 0.38)
        }

        if presentation.newlyCompleted {
            showToast(Self.completionToast)
        }
    }

    func applyAppearance(_ appearance: JoeyAppearance) {
        guard appearance != self.appearance else { return }
        self.appearance = appearance
        for panel in panels {
            panel.appearance = appearance.nsAppearance
            panel.invalidateShadow()
        }
        if let lastSituation {
            update(situation: lastSituation)
        }
    }

    /// Hides every surface, e.g. when Joey leaves the desktop.
    func hideAll() {
        toastTask?.cancel()
        toastTask = nil
        for panel in panels {
            panel.orderOut(nil)
            panel.alphaValue = 1
        }
    }

    // MARK: - User feedback

    func showToast(_ text: String) {
        setRoot(toastHost, JoeyToastView(text: text))
        present(
            toastPanel,
            host: toastHost,
            fallback: NSSize(width: 220, height: 34),
            origin: toastOrigin,
            duration: 0.24,
            rise: 6
        )

        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            self?.dismiss(self?.toastPanel, entrance: 0.24)
        }
    }

    func showSnoozeToast() {
        showToast(Self.snoozeToast)
    }

    func showDoNotDisturbToast() {
        showToast(Self.doNotDisturbToast)
    }

    // MARK: - Panels

    private var panels: [SurfacePanel] {
        [chipPanel, invitationPanel, recoveryPanel, toastPanel]
    }

    private func setRoot(_ host: NSHostingView<AnyView>, _ view: some View) {
        host.rootView = AnyView(view.environment(\.joeyAppearance, appearance))
    }

    private func present(
        _ panel: SurfacePanel,
        host: NSView,
        fallback: NSSize,
        origin: (NSSize) -> NSPoint,
        duration: TimeInterval,
        rise: CGFloat
    ) {
        let size = fittedSize(host, fallback: fallback)
        let target = origin(size)

        panel.setContentSize(size)

        guard !panel.isVisible else {
            panel.setFrameOrigin(target)
            return
        }

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.alphaValue = reduceMotion ? 1 : 0
        panel.setFrameOrigin(NSPoint(x: target.x, y: target.y - rise))
        panel.orderFrontRegardless()
        panel.invalidateShadow()

        guard !reduceMotion else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.61, 0.36, 1)
            panel.animator().alphaValue = 1
            panel.animator().setFrameOrigin(target)
        }
    }

    private func dismiss(_ panel: SurfacePanel?, entrance: TimeInterval) {
        guard let panel, panel.isVisible else { return }

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.orderOut(nil)
            panel.alphaValue = 1
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = max(0.12, entrance * 0.65)
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
        }
    }

    private func fittedSize(_ host: NSView, fallback: NSSize) -> NSSize {
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        guard size.width > 1, size.height > 1 else { return fallback }
        return NSSize(width: ceil(size.width), height: ceil(size.height))
    }

    // MARK: - Placement

    private var activeVisibleFrame: NSRect {
        let screen = NSScreen.screens.first { $0.visibleFrame.intersects(petPanel.frame) }
            ?? NSScreen.main
        return screen?.visibleFrame ?? petPanel.frame
    }

    private func clamped(_ origin: NSPoint, size: NSSize) -> NSPoint {
        let visible = activeVisibleFrame
        let margin: CGFloat = 8
        return NSPoint(
            x: min(max(origin.x, visible.minX + margin), visible.maxX - size.width - margin),
            y: min(max(origin.y, visible.minY + margin), visible.maxY - size.height - margin)
        )
    }

    private func chipOrigin(size: NSSize) -> NSPoint {
        let visible = activeVisibleFrame
        let pet = petPanel.frame
        let margin: CGFloat = 8
        let above = pet.maxY + 4
        let below = pet.minY - size.height - 4

        // Prefer above Joey, but drop below when the top edge is too close.
        let y: CGFloat
        if above + size.height <= visible.maxY - margin {
            y = above
        } else if below >= visible.minY + margin {
            y = below
        } else {
            y = above
        }

        return clamped(
            NSPoint(x: pet.midX - size.width / 2, y: y),
            size: size
        )
    }

    private func invitationOrigin(size: NSSize) -> NSPoint {
        let visible = activeVisibleFrame
        let pet = petPanel.frame
        let gap: CGFloat = 12
        let margin: CGFloat = 8
        let left = pet.minX - size.width - gap
        let right = pet.maxX + gap

        // Keep the card next to Joey, on the side that has room. When both
        // sides fit, prefer the side facing the middle of the screen.
        let fitsLeft = left >= visible.minX + margin
        let fitsRight = right + size.width <= visible.maxX - margin

        let x: CGFloat
        if fitsLeft, fitsRight {
            x = pet.midX >= visible.midX ? left : right
        } else if fitsLeft {
            x = left
        } else if fitsRight {
            x = right
        } else {
            x = pet.midX - size.width / 2
        }

        return clamped(
            NSPoint(x: x, y: pet.midY - size.height / 2),
            size: size
        )
    }

    private func recoveryOrigin(size: NSSize) -> NSPoint {
        let visible = activeVisibleFrame
        return clamped(
            NSPoint(x: visible.midX - size.width / 2, y: visible.maxY - 100 - size.height),
            size: size
        )
    }

    private func toastOrigin(size: NSSize) -> NSPoint {
        let visible = activeVisibleFrame
        return clamped(
            NSPoint(x: visible.midX - size.width / 2, y: visible.maxY - 50 - size.height),
            size: size
        )
    }

    private func observePetPanelMoves() {
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: petPanel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.repositionPetAnchoredSurfaces()
            }
        }
    }

    private func repositionPetAnchoredSurfaces() {
        if chipPanel.isVisible {
            let size = chipPanel.frame.size
            chipPanel.setFrameOrigin(chipOrigin(size: size))
        }
        if invitationPanel.isVisible {
            let size = invitationPanel.frame.size
            invitationPanel.setFrameOrigin(invitationOrigin(size: size))
        }
        chipPanel.invalidateShadow()
        invitationPanel.invalidateShadow()
    }
}

/// Borderless floating surface. Interactive panels may become key so their
/// buttons work without activating the app; passive panels click through.
private final class SurfacePanel: NSPanel {
    private let interactive: Bool

    init(interactive: Bool) {
        self.interactive = interactive
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        ignoresMouseEvents = !interactive
        becomesKeyOnlyIfNeeded = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { interactive }
    override var canBecomeMain: Bool { false }
}
