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
            let window = JoeyPetMainWindow(
                contentRect: NSRect(x: 0, y: 0, width: ShellMetrics.defaultWindowWidth, height: ShellMetrics.defaultWindowHeight),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "JoeyPet"
            window.titleVisibility = .hidden
            window.toolbarStyle = .unified
            window.titlebarSeparatorStyle = .line
            window.minSize = NSSize(width: ShellMetrics.minimumWindowWidth, height: ShellMetrics.minimumWindowHeight)
            window.contentViewController = hosting
            window.setContentSize(NSSize(width: ShellMetrics.defaultWindowWidth, height: ShellMetrics.defaultWindowHeight))
            window.center()
            window.isReleasedWhenClosed = false
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
