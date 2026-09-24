import AppKit
import SwiftUI

@MainActor
final class MainWindowController {
    private let model: AppModel
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func show(section: MainSection = .overview) {
        if window == nil {
            let content = NSHostingView(rootView: ContentView(model: model))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "JoeyPet"
            window.minSize = NSSize(width: 720, height: 480)
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = content
            self.window = window
        }
        model.selectedSection = section
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
