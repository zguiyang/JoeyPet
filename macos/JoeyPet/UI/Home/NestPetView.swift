import AppKit
import SpriteKit
import SwiftUI

/// The pet that lives in the room's nest.
///
/// It does not own art of its own: it hosts the same layered SpriteKit scene
/// (`JoeyDesktopScene`) with the same `JoeyAssetPackage` the desktop pet uses,
/// and feeds it the pose `PetRuntime` resolved. Faces, props, breathing, blinks
/// and ear/tail motion therefore match the desktop pet exactly.
struct NestPetView: View {
    let pose: PetPose
    var daypart: RoomDaypart? = nil
    let onGreet: () -> Void

    @Environment(\.joeyChromeTone) private var chromeTone
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isWindowVisible = true

    var body: some View {
        LayeredPetSurface(
            pose: pose,
            tint: JoeyTheme(chromeTone: chromeTone, daypart: daypart).nestPetTint,
            reduceMotion: reduceMotion,
            isPaused: !isWindowVisible
        )
        .overlay(alignment: .top) {
            if pose == .wave {
                JoeyGreetingTipView()
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(reduceMotion ? nil : JoeyMotion.stateEnter, value: pose)
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
    }
}

// MARK: - Layered scene host

/// A read-only host for the desktop pet's scene. It only forwards a pose; the
/// schedule and behavior still live in `PetRuntime`.
private struct LayeredPetSurface: NSViewRepresentable {
    /// The scene is the same 320×400 design canvas; `.aspectFit` scales it to
    /// whatever frame the room gives the nest.
    private static let designSize = CGSize(width: 320, height: 400)

    let pose: PetPose
    let tint: JoeyPetTint
    let reduceMotion: Bool
    let isPaused: Bool

    func makeNSView(context: Context) -> SKView {
        let view = SKView()
        view.allowsTransparency = true
        view.preferredFramesPerSecond = 30

        defer { view.isPaused = isPaused }
        guard let package = JoeyAssetPackage.load() else {
            let empty = SKScene(size: Self.designSize)
            empty.scaleMode = .aspectFit
            empty.backgroundColor = .clear
            view.presentScene(empty)
            return view
        }

        let scene = JoeyDesktopScene(size: Self.designSize, package: package)
        scene.scaleMode = .aspectFit
        scene.backgroundColor = .clear
        scene.setTint(tint)
        scene.setReduceMotion(reduceMotion)
        scene.show(pose: pose)
        view.presentScene(scene)
        context.coordinator.scene = scene
        return view
    }

    func updateNSView(_ view: SKView, context: Context) {
        guard let scene = context.coordinator.scene else { return }
        scene.setTint(tint)
        scene.setReduceMotion(reduceMotion)
        scene.show(pose: pose)
        view.isPaused = isPaused
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var scene: JoeyDesktopScene?
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
