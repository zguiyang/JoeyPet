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
    /// Leaf + happy pose already mark completion; toast only names the nest change.
    private static let completionToast = "窝里多了一片叶子。"

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
    private let greetingTipPanel = SurfacePanel(interactive: false)

    private let chipHost = NSHostingView(rootView: AnyView(EmptyView()))
    private let invitationHost = NSHostingView(rootView: AnyView(EmptyView()))
    private let recoveryHost = NSHostingView(rootView: AnyView(EmptyView()))
    private let toastHost = NSHostingView(rootView: AnyView(EmptyView()))
    private let greetingTipHost = NSHostingView(rootView: AnyView(EmptyView()))

    private var isGreetingTipVisible = false

    init(petPanel: NSPanel, appearance: JoeyAppearance) {
        self.petPanel = petPanel
        self.appearance = appearance

        for panel in panels {
            panel.appearance = appearance.nsAppearance()
            panel.hasShadow = true
        }
        invitationHost.translatesAutoresizingMaskIntoConstraints = true
        chipHost.translatesAutoresizingMaskIntoConstraints = true
        recoveryHost.translatesAutoresizingMaskIntoConstraints = true
        toastHost.translatesAutoresizingMaskIntoConstraints = true
        greetingTipHost.translatesAutoresizingMaskIntoConstraints = true

        chipPanel.contentView = chipHost
        invitationPanel.contentView = invitationHost
        recoveryPanel.contentView = recoveryHost
        toastPanel.contentView = toastHost
        toastPanel.ignoresMouseEvents = true
        greetingTipPanel.contentView = greetingTipHost
        greetingTipPanel.ignoresMouseEvents = true

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
            let placement = invitationPlacement(size: NSSize(width: 236, height: 120))
            setRoot(
                invitationHost,
                InvitationCardView(
                    onAccept: { [weak self] in self?.onAcceptInvitation?() },
                    onSnooze: { [weak self] in self?.onSnooze?() },
                    onDoNotDisturb: { [weak self] in self?.onEnterDoNotDisturb?() },
                    caretEdge: placement.caret
                )
            )
            present(
                invitationPanel,
                host: invitationHost,
                fallback: NSSize(width: 236, height: 120),
                origin: { size in
                    self.invitationPlacement(size: size).origin
                },
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
                fallback: NSSize(width: 300, height: 320),
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
            panel.appearance = appearance.nsAppearance()
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
        isGreetingTipVisible = false
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

    /// Same object-label tip as the nest: appears above Joey while `wave` plays.
    func setGreetingTipVisible(_ visible: Bool) {
        guard visible != isGreetingTipVisible else {
            if visible { repositionGreetingTip() }
            return
        }
        isGreetingTipVisible = visible
        if visible {
            setRoot(greetingTipHost, JoeyGreetingTipView())
            present(
                greetingTipPanel,
                host: greetingTipHost,
                fallback: NSSize(width: 64, height: 28),
                origin: chipOrigin,
                duration: 0.24,
                rise: 4
            )
        } else {
            dismiss(greetingTipPanel, entrance: 0.24)
        }
    }

    // MARK: - Panels

    private var panels: [SurfacePanel] {
        [chipPanel, invitationPanel, recoveryPanel, toastPanel, greetingTipPanel]
    }

    private func setRoot(_ host: NSHostingView<AnyView>, _ view: some View) {
        let tone = appearance.resolveChromeTone()
        host.rootView = AnyView(
            view
                .environment(\.joeyAppearance, appearance)
                .environment(\.joeyChromeTone, tone)
        )
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

    private struct InvitationPlacement {
        let origin: NSPoint
        let caret: InvitationCaretEdge
    }

    /// Places the invite note beside Joey and aims the caret toward him.
    private func invitationPlacement(size: NSSize) -> InvitationPlacement {
        let visible = activeVisibleFrame
        let pet = petPanel.frame
        let gap: CGFloat = 10
        let margin: CGFloat = 8
        let left = pet.minX - size.width - gap
        let right = pet.maxX + gap

        let fitsLeft = left >= visible.minX + margin
        let fitsRight = right + size.width <= visible.maxX - margin

        let x: CGFloat
        let caret: InvitationCaretEdge
        if fitsLeft, fitsRight {
            if pet.midX >= visible.midX {
                x = left
                caret = .trailing
            } else {
                x = right
                caret = .leading
            }
        } else if fitsLeft {
            x = left
            caret = .trailing
        } else if fitsRight {
            x = right
            caret = .leading
        } else {
            x = pet.midX - size.width / 2
            caret = .none
        }

        return InvitationPlacement(
            origin: clamped(
                NSPoint(x: x, y: pet.midY - size.height / 2),
                size: size
            ),
            caret: caret
        )
    }

    /// Dead-centre on Joey’s screen — never `NSScreen.main` (key-window screen).
    private func recoveryOrigin(size: NSSize) -> NSPoint {
        let visible = activeVisibleFrame
        let margin: CGFloat = 8
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
        return NSPoint(
            x: min(max(origin.x, visible.minX + margin), visible.maxX - size.width - margin),
            y: min(max(origin.y, visible.minY + margin), visible.maxY - size.height - margin)
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
            let placement = invitationPlacement(size: size)
            invitationPanel.setFrameOrigin(placement.origin)
        }
        if recoveryPanel.isVisible {
            let size = recoveryPanel.frame.size
            recoveryPanel.setFrameOrigin(recoveryOrigin(size: size))
        }
        repositionGreetingTip()
        chipPanel.invalidateShadow()
        invitationPanel.invalidateShadow()
        recoveryPanel.invalidateShadow()
        greetingTipPanel.invalidateShadow()
    }

    private func repositionGreetingTip() {
        guard greetingTipPanel.isVisible else { return }
        let size = greetingTipPanel.frame.size
        greetingTipPanel.setFrameOrigin(chipOrigin(size: size))
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
