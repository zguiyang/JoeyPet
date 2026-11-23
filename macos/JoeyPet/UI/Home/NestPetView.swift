import AppKit
import SwiftUI

/// The pet that lives in the room's nest.
///
/// It does not own a day schedule: it renders the exact pose that `PetRuntime`
/// resolved for the desktop pet, so the nest and the desktop always show the
/// same state. Tapping the nest asks the runtime for a short greeting.
struct NestPetView: View {
    let pose: PetPose
    let onGreet: () -> Void

    @Environment(\.joeyAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var poseStartedAt = Date()
    @State private var previousPose: PetPose?
    @State private var transitionStartedAt = Date()
    @State private var isWindowVisible = true

    private static let transitionDuration: TimeInterval = 0.32

    private var theme: JoeyTheme { JoeyTheme(appearance: appearance) }

    var body: some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 30.0,
            paused: reduceMotion || !isWindowVisible
        )) { timeline in
            Canvas { context, size in
                context.scaleBy(x: size.width / 320, y: size.height / 400)

                let elapsed = reduceMotion
                    ? 0
                    : max(0, timeline.date.timeIntervalSince(poseStartedAt))
                let transition: (from: PetPose, progress: Double)? = {
                    guard !reduceMotion, let previousPose else { return nil }
                    let value = timeline.date.timeIntervalSince(transitionStartedAt)
                    guard value < Self.transitionDuration else { return nil }
                    return (previousPose, value / Self.transitionDuration)
                }()

                let painter = NestPetPainter(theme: theme)
                if let transition {
                    painter.draw(
                        pose: transition.from,
                        elapsed: elapsed,
                        reduceMotion: reduceMotion,
                        opacity: 1 - transition.progress,
                        in: &context
                    )
                    painter.draw(
                        pose: pose,
                        elapsed: elapsed,
                        reduceMotion: reduceMotion,
                        opacity: transition.progress,
                        in: &context
                    )
                } else {
                    painter.draw(
                        pose: pose,
                        elapsed: elapsed,
                        reduceMotion: reduceMotion,
                        in: &context
                    )
                }
            }
        }
        .overlay(alignment: .bottom) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 250)
                .contentShape(Rectangle())
                .onTapGesture(perform: onGreet)
        }
        .background(WindowVisibilityObserver(isVisible: $isWindowVisible))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Joey")
        .accessibilityHint("点一下它会回应你")
        .onChange(of: pose) { oldValue, _ in
            previousPose = oldValue
            transitionStartedAt = Date()
            poseStartedAt = Date()
        }
        .onChange(of: reduceMotion) { _, _ in
            previousPose = nil
            poseStartedAt = Date()
        }
    }
}

// MARK: - Painting

private struct NestPetPainter {
    let theme: JoeyTheme

    private var art: NestPetArt { NestPetArt(theme: theme) }

    /// Renders one runtime pose. Every pose keeps the same upright silhouette;
    /// only ears, arms, face, settle and breathing change.
    func draw(
        pose: PetPose,
        elapsed: TimeInterval,
        reduceMotion: Bool,
        opacity: Double = 1,
        in context: inout GraphicsContext
    ) {
        switch pose {
        case .sit:
            drawStanding(
                elapsed: elapsed,
                face: .calm,
                arms: .rest,
                opacity: opacity,
                in: &context
            )

        case .look:
            drawStanding(
                elapsed: elapsed,
                face: .look,
                arms: .rest,
                opacity: opacity,
                in: &context
            )

        case .sign:
            drawStanding(
                elapsed: elapsed,
                face: .calm,
                arms: .wave,
                opacity: opacity,
                in: &context
            )

        case .stretch:
            drawStanding(
                elapsed: elapsed,
                face: .stretch,
                arms: .up,
                opacity: opacity,
                in: &context
            )

        case .happy:
            drawStanding(
                elapsed: elapsed,
                face: .happy,
                arms: .rest,
                bodyOffsetY: -5,
                opacity: opacity,
                in: &context
            )

        case .sleep:
            art.drawSitting(
                in: &context,
                face: .sleep,
                arms: .rest,
                earTilt: 12,
                bodyOffset: CGSize(width: 0, height: 8),
                breath: breath(elapsed, period: 6),
                tailAngle: 0,
                opacity: opacity
            )
            if opacity > 0.99 {
                art.drawZ(
                    in: &context,
                    elapsed: elapsed,
                    count: 3,
                    period: 6,
                    reduceMotion: reduceMotion
                )
            }

        case .doze:
            art.drawSitting(
                in: &context,
                face: .doze,
                arms: .rest,
                earTilt: 6,
                bodyRotation: -2,
                bodyOffset: CGSize(width: 0, height: 5),
                breath: breath(elapsed, period: 5.4),
                tailAngle: 0,
                opacity: opacity
            )
            if opacity > 0.99 {
                art.drawZ(
                    in: &context,
                    elapsed: elapsed,
                    count: 2,
                    period: 5.4,
                    reduceMotion: reduceMotion
                )
            }

        case .groom:
            art.drawSitting(
                in: &context,
                face: .groom,
                arms: .groom,
                waveAngle: groomingStroke(elapsed),
                breath: breath(elapsed, period: 4.8),
                tailAngle: tailAngle(elapsed, period: 4.8, lag: 0.1),
                opacity: opacity
            )

        case .yawn:
            drawStanding(
                elapsed: elapsed,
                face: .yawn,
                arms: .rest,
                opacity: opacity,
                in: &context
            )

        case .step:
            drawStanding(
                elapsed: elapsed,
                face: .look,
                arms: .rest,
                opacity: opacity,
                in: &context
            )

        case .carry:
            drawStanding(
                elapsed: elapsed,
                face: .calm,
                arms: .rest,
                opacity: opacity,
                in: &context
            )

        case .peek:
            drawStanding(
                elapsed: elapsed,
                face: .look,
                arms: .rest,
                opacity: opacity,
                in: &context
            )
        }
    }

    private func drawStanding(
        elapsed: TimeInterval,
        face: NestFace,
        arms: NestArms,
        bodyOffsetY: CGFloat = 0,
        opacity: Double,
        in context: inout GraphicsContext
    ) {
        art.drawSitting(
            in: &context,
            face: face,
            arms: arms,
            bodyOffset: CGSize(width: 0, height: bodyOffsetY),
            breath: breath(elapsed, period: 4.8),
            tailAngle: tailAngle(elapsed, period: 4.8, lag: 0.1),
            opacity: opacity
        )
    }

    private func groomingStroke(_ elapsed: TimeInterval) -> Double {
        let cycle = elapsed.truncatingRemainder(dividingBy: 1.6)
        let window: TimeInterval = 0.38
        guard cycle < window else { return 0 }
        return -15 * sin(Double.pi * cycle / window)
    }

    // MARK: - Ambient helpers

    private func breath(_ elapsed: TimeInterval, period: TimeInterval) -> CGFloat {
        let phase = elapsed.truncatingRemainder(dividingBy: period) / period
        return CGFloat(1 + 0.012 * (0.5 - 0.5 * cos(2 * .pi * phase)))
    }

    private func tailAngle(
        _ elapsed: TimeInterval,
        period: TimeInterval,
        lag: TimeInterval
    ) -> Double {
        let phase = (elapsed - lag).truncatingRemainder(dividingBy: period) / period
        return 8 * sin(2 * .pi * phase)
    }
}

// MARK: - Window visibility

private struct WindowVisibilityObserver: NSViewRepresentable {
    @Binding var isVisible: Bool

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onWindowChanged = { window in
            context.coordinator.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: ObserverView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isVisible: $isVisible)
    }

    final class ObserverView: NSView {
        var onWindowChanged: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChanged?(window)
        }
    }

    final class Coordinator {
        private let isVisible: Binding<Bool>
        private weak var window: NSWindow?
        private var tokens: [NSObjectProtocol] = []

        init(isVisible: Binding<Bool>) {
            self.isVisible = isVisible
        }

        func attach(to window: NSWindow?) {
            guard self.window !== window else { return }
            self.window = window

            for token in tokens {
                NotificationCenter.default.removeObserver(token)
            }
            tokens.removeAll()

            guard let window else {
                isVisible.wrappedValue = false
                return
            }

            let update = { [weak self, weak window] in
                guard let self, let window else { return }
                self.isVisible.wrappedValue = window.occlusionState.contains(.visible)
                    && !window.isMiniaturized
                    && !NSApp.isHidden
            }
            update()

            let center = NotificationCenter.default
            tokens.append(center.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification,
                object: window,
                queue: .main
            ) { _ in update() })
            tokens.append(center.addObserver(
                forName: NSWindow.didMiniaturizeNotification,
                object: window,
                queue: .main
            ) { _ in update() })
            tokens.append(center.addObserver(
                forName: NSWindow.didDeminiaturizeNotification,
                object: window,
                queue: .main
            ) { _ in update() })
            tokens.append(center.addObserver(
                forName: NSApplication.didHideNotification,
                object: nil,
                queue: .main
            ) { _ in update() })
            tokens.append(center.addObserver(
                forName: NSApplication.didUnhideNotification,
                object: nil,
                queue: .main
            ) { _ in update() })
        }

        deinit {
            for token in tokens {
                NotificationCenter.default.removeObserver(token)
            }
        }
    }
}
