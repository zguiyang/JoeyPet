import AppKit
import SwiftUI

@MainActor
final class MainWindowController {
    private let model: AppModel
    private let shellState: AppShellState
    private let stageState: JoeyStageState
    private var window: NSWindow?

    init(model: AppModel, shellState: AppShellState, stageState: JoeyStageState) {
        self.model = model
        self.shellState = shellState
        self.stageState = stageState
    }

    func present(intent: MainWindowIntent = .default) {
        shellState.apply(intent: intent)
        if window == nil {
            let root = AppShellView(
                model: model,
                shellState: shellState,
                permissionService: PermissionService.shared
            )
            let hosting = NSHostingController(rootView: root)
            let initialSize = DebugStateInjector.qaWindowSize()
                ?? CGSize(width: ShellMetrics.defaultWindowWidth, height: ShellMetrics.defaultWindowHeight)
            let minimumSize = CGSize(
                width: ShellMetrics.minimumWindowWidth,
                height: ShellMetrics.minimumWindowHeight
            )
            let window = JoeyPetMainWindow(
                contentRect: NSRect(origin: .zero, size: initialSize),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "JoeyPet"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.isMovableByWindowBackground = true
            window.toolbar = nil
            window.backgroundColor = .windowBackgroundColor
            window.contentMinSize = NSSize(
                width: minimumSize.width,
                height: ShellMetrics.minimumWindowContentHeight
            )
            window.minSize = NSSize(width: minimumSize.width, height: minimumSize.height)
            window.contentViewController = hosting
            window.setContentSize(initialSize)
            #if DEBUG
            if let qaSize = DebugStateInjector.qaWindowSize() {
                window.setFrame(
                    NSRect(x: 0, y: 0, width: qaSize.width, height: qaSize.height),
                    display: false
                )
            }
            #endif
            window.center()
            window.isReleasedWhenClosed = false
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
