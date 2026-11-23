import AppKit
import OSLog
import QuartzCore
import SpriteKit
import SwiftUI

final class PetSpriteView: SKView {
    /// Pet clips are single-frame animations at 1–6 fps; 30 fps rendering burned ~15% CPU.
    private static let renderFramesPerSecond = 10
    private static let dragThreshold: CGFloat = 4
    private static let hintText = "拖动换位置 · 点击打开菜单"
    private static let hintDelay: TimeInterval = 0.6

    var interactiveRadius: CGFloat = 44 {
        didSet { window?.invalidateCursorRects(for: self) }
    }
    var onLeftClick: (() -> Void)?
    var onDragBegan: (() -> Void)?
    var onDragEnded: ((NSPoint) -> Void)?
    var onPointerEntered: (() -> Void)?
    var onPointerExited: (() -> Void)?
    var onKeyboardMove: ((CGFloat, CGFloat) -> Void)?
    var onMenuRequested: (() -> Void)?

    /// Mirrors the runtime situation for VoiceOver without the view reading state.
    var accessibilityStatus = "" {
        didSet { setAccessibilityValue(accessibilityStatus) }
    }

    private let focusRing = FocusRingView()
    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowOrigin: NSPoint?
    private var isDragging = false
    private var hintTask: Task<Void, Never>?
    private var hoverTrackingArea: NSTrackingArea?
    private var keyObservers: [NSObjectProtocol] = []

#if DEBUG
    private static let interactionLogger = Logger(
        subsystem: "com.zguiyang.JoeyPet",
        category: "PetSpriteView"
    )
#endif

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        preferredFramesPerSecond = Self.renderFramesPerSecond
        configureAccessibility()
        configureFocusRing()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        preferredFramesPerSecond = Self.renderFramesPerSecond
        configureAccessibility()
        configureFocusRing()
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

    override func resetCursorRects() {
        addCursorRect(interactiveRect, cursor: isDragging ? .closedHand : .openHand)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        let center = NotificationCenter.default
        for observer in keyObservers {
            center.removeObserver(observer)
        }
        keyObservers.removeAll()

        guard let window else {
            focusRing.isHidden = true
            return
        }

        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            keyObservers.append(
                center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.updateFocusRing()
                    }
                }
            )
        }
        updateFocusRing()
    }

    // MARK: - Pointer

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }

        window.makeKey()
        window.makeFirstResponder(self)

        dragStartMouseLocation = window.convertPoint(toScreen: event.locationInWindow)
        dragStartWindowOrigin = window.frame.origin
        isDragging = false

#if DEBUG
        Self.interactionLogger.debug("mouse down")
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
        guard isDragging || hypot(delta.x, delta.y) >= Self.dragThreshold else { return }

        if !isDragging {
            isDragging = true
            cancelHint()
            onDragBegan?()
            setDraggingScale(true)
            NSCursor.closedHand.set()
            window.invalidateCursorRects(for: self)
#if DEBUG
            Self.interactionLogger.debug("drag began")
#endif
        }

        window.setFrameOrigin(
            clampedOrigin(
                NSPoint(
                    x: dragStartWindowOrigin.x + delta.x,
                    y: dragStartWindowOrigin.y + delta.y
                )
            )
        )
    }

    override func mouseUp(with event: NSEvent) {
        let finalOrigin = window?.frame.origin
        let wasDragging = isDragging

        isDragging = false
        setDraggingScale(false)
        NSCursor.openHand.set()
        window?.invalidateCursorRects(for: self)

        dragStartMouseLocation = nil
        dragStartWindowOrigin = nil

        if wasDragging {
#if DEBUG
            Self.interactionLogger.debug("drag ended")
#endif
            if let finalOrigin { onDragEnded?(finalOrigin) }
        } else if Self.containsInteractivePoint(
            convert(event.locationInWindow, from: nil),
            center: NSPoint(x: bounds.midX, y: bounds.midY),
            radius: interactiveRadius
        ) {
            onLeftClick?()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        onPointerEntered?()

        hintTask?.cancel()
        hintTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.hintDelay))
            guard !Task.isCancelled, let self, !self.isDragging else { return }
            self.toolTip = Self.hintText
        }
    }

    override func mouseExited(with event: NSEvent) {
        cancelHint()
        onPointerExited?()
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1

        switch event.keyCode {
        case 123:
            onKeyboardMove?(-step, 0)
        case 124:
            onKeyboardMove?(step, 0)
        case 125:
            onKeyboardMove?(0, -step)
        case 126:
            onKeyboardMove?(0, step)
        case 36, 76:
            onMenuRequested?()
        default:
            super.keyDown(with: event)
        }
    }

    // MARK: - Helpers

    private var interactiveRect: NSRect {
        let inset = max(interactiveRadius, 22)
        return NSRect(
            x: bounds.midX - inset,
            y: bounds.midY - inset,
            width: inset * 2,
            height: inset * 2
        )
    }

    private static func containsInteractivePoint(
        _ point: NSPoint,
        center: NSPoint,
        radius: CGFloat
    ) -> Bool {
        hypot(point.x - center.x, point.y - center.y) <= radius
    }

    private func clampedOrigin(_ origin: NSPoint) -> NSPoint {
        guard let screen = window?.screen ?? NSScreen.main else { return origin }
        let visible = screen.visibleFrame
        let size = window?.frame.size ?? bounds.size
        let point = PetPanelGeometry.clampedOrigin(
            PetPositionPoint(x: origin.x, y: origin.y),
            in: PetPositionRect(
                minX: visible.minX,
                minY: visible.minY,
                width: visible.width,
                height: visible.height
            ),
            windowSize: PetPositionPoint(x: size.width, y: size.height)
        )
        return NSPoint(x: point.x, y: point.y)
    }

    private func setDraggingScale(_ dragging: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(dragging ? 0.12 : 0.18)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        layer?.setAffineTransform(
            dragging ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
        )
        CATransaction.commit()
    }

    private func cancelHint() {
        hintTask?.cancel()
        hintTask = nil
        toolTip = nil
    }

    private func configureAccessibility() {
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Joey")
        setAccessibilityHelp(Self.hintText)
        setAccessibilityValue(accessibilityStatus)
    }

    private func configureFocusRing() {
        focusRing.frame = bounds
        focusRing.autoresizingMask = [.width, .height]
        focusRing.isHidden = true
        addSubview(focusRing)
    }

    private func updateFocusRing() {
        focusRing.isHidden = !(window?.isKeyWindow ?? false)
        focusRing.ringColor = NSColor(
            JoeyTheme(
                appearance: effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                    ? .dusk
                    : .light
            ).focus
        )
        focusRing.needsDisplay = true
    }
}

/// Sage focus ring drawn above the SpriteKit content; pointer events pass through.
private final class FocusRingView: NSView {
    var ringColor: NSColor = NSColor(JoeyTheme(appearance: .light).focus) {
        didSet { needsDisplay = true }
    }

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        let ring = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 3, dy: 3),
            xRadius: 14,
            yRadius: 14
        )
        ring.lineWidth = 2
        ringColor.setStroke()
        ring.stroke()
    }
}
