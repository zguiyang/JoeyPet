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
    private static let pauseToast = "先安静一会儿。"

    var onAcceptInvitation: (() -> Void)?
    var onSnooze: (() -> Void)?
    var onPause: (() -> Void)?
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
                origin: chipOrigin
            )
        } else {
            dismiss(chipPanel)
        }

        if presentation.showsInvitation {
            setRoot(
                invitationHost,
                InvitationCardView(
                    onAccept: { [weak self] in self?.onAcceptInvitation?() },
                    onSnooze: { [weak self] in self?.onSnooze?() },
                    onPause: { [weak self] in self?.onPause?() }
                )
            )
            present(
                invitationPanel,
                host: invitationHost,
                fallback: NSSize(width: 400, height: 292),
                origin: invitationOrigin
            )
        } else {
            dismiss(invitationPanel)
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
                origin: recoveryOrigin
            )
        } else {
            dismiss(recoveryPanel)
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
            origin: toastOrigin
        )

        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            self?.dismiss(self?.toastPanel)
        }
    }

    func showSnoozeToast() {
        showToast(Self.snoozeToast)
    }

    func showPauseToast() {
        showToast(Self.pauseToast)
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
        origin: (NSSize) -> NSPoint
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
        panel.setFrameOrigin(NSPoint(x: target.x, y: target.y - 8))
        panel.orderFrontRegardless()
        panel.invalidateShadow()

        guard !reduceMotion else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.36
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.61, 0.36, 1)
            panel.animator().alphaValue = 1
            panel.animator().setFrameOrigin(target)
        }
    }

    private func dismiss(_ panel: SurfacePanel?) {
        guard let panel, panel.isVisible else { return }

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.orderOut(nil)
            panel.alphaValue = 1
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
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
        clamped(
            NSPoint(x: petPanel.frame.midX - size.width / 2, y: petPanel.frame.maxY + 4),
            size: size
        )
    }

    private func invitationOrigin(size: NSSize) -> NSPoint {
        clamped(
            NSPoint(
                x: petPanel.frame.minX - size.width - 12,
                y: petPanel.frame.midY - size.height / 2
            ),
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
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { interactive }
    override var canBecomeMain: Bool { false }
}
