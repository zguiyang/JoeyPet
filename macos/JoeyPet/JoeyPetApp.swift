import AppKit

/// AppKit owns the application lifecycle, windows and status item.
/// SwiftUI only provides the content hosted inside those AppKit windows.
@main
enum JoeyPetMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        AppDelegate.retainedDelegate = delegate
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.run()
    }
}
