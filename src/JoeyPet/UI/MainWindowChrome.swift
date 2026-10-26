import AppKit
import SwiftUI

/// Main window whose title stays available as metadata, but is never drawn in the
/// titlebar. The window is a single full-bleed canvas: background, orb and controls
/// share one visual space while the native traffic lights keep working.
final class JoeyPetMainWindow: NSWindow {
    override var titleVisibility: TitleVisibility {
        get { super.titleVisibility }
        set { super.titleVisibility = .hidden }
    }
}

/// Enforces the immersive window chrome after SwiftUI installs its own hosting view.
struct MainWindowChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(MainWindowChromeAccessor())
    }
}

private struct MainWindowChromeAccessor: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.attach(to: nsView)
    }

    final class Coordinator {
        private var applied = false

        func attach(to view: NSView) {
            guard !applied else { return }
            applied = true
            DispatchQueue.main.async { [weak self, weak view] in
                guard let window = view?.window else {
                    self?.applied = false
                    return
                }
                Self.enforce(window)
                // SwiftUI may re-install chrome after the first layout pass.
                DispatchQueue.main.async {
                    Self.enforce(window)
                }
            }
        }

        private static func enforce(_ window: NSWindow) {
            window.title = "JoeyPet"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.toolbar = nil
        }
    }
}

extension View {
    func mainWindowChrome() -> some View {
        modifier(MainWindowChromeModifier())
    }

    /// Drops the window-title item and the split-view sidebar toggle from the single global toolbar.
    /// `.title` is macOS 15+; the app still builds for 14.
    @ViewBuilder
    func removingDefaultWindowToolbarItems() -> some View {
        if #available(macOS 15.0, *) {
            self
                .toolbar(removing: .title)
                .toolbar(removing: .sidebarToggle)
        } else {
            self.toolbar(removing: .sidebarToggle)
        }
    }
}
