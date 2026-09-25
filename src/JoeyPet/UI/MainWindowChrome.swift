import AppKit
import SwiftUI

/// Main window whose title stays available as metadata, but is never drawn in the titlebar.
/// SwiftUI's unified toolbar resets `titleVisibility` to `.visible` after a one-shot AppKit write,
/// which is why the window title ("JoeyPet") kept appearing next to the real navigation items.
final class JoeyPetMainWindow: NSWindow {
    override var titleVisibility: TitleVisibility {
        get { super.titleVisibility }
        set { super.titleVisibility = .hidden }
    }
}

/// Keeps one unified toolbar and strips system items that Navigation containers inject.
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
        private var pending = false

        func attach(to view: NSView) {
            guard !pending else { return }
            pending = true
            DispatchQueue.main.async { [weak self, weak view] in
                guard let window = view?.window else {
                    self?.pending = false
                    return
                }
                Self.enforce(window)
                // SwiftUI installs default toolbar items after the first layout pass.
                DispatchQueue.main.async {
                    Self.enforce(window)
                    self?.pending = false
                }
            }
        }

        private static func enforce(_ window: NSWindow) {
            window.title = "JoeyPet"
            window.titleVisibility = .hidden
            window.toolbarStyle = .unified
            window.titlebarSeparatorStyle = .line
            stripInjectedToolbarItems(from: window.toolbar)
        }

        /// System items a navigation container adds beside `UnifiedWindowNavigation`.
        /// `titleVisibility` does not remove these; they are real `NSToolbarItem`s.
        private static func stripInjectedToolbarItems(from toolbar: NSToolbar?) {
            guard let toolbar else { return }
            let forbidden: Set<NSToolbarItem.Identifier> = [
                .toggleSidebar,
                .sidebarTrackingSeparator,
            ]
            var index = toolbar.items.count - 1
            while index >= 0 {
                let item = toolbar.items[index]
                let showsBrand = item.label == "JoeyPet" || item.paletteLabel == "JoeyPet"
                if forbidden.contains(item.itemIdentifier) || showsBrand {
                    toolbar.removeItem(at: index)
                }
                index -= 1
            }
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
