import AppKit
import SwiftUI

/// AppKit owns the main window; SwiftUI owns its content.
@MainActor
final class MainWindowController: NSWindowController {
    private let settings: AppSettings
    private let navigation = NestNavigation()
    private var chromeButton: NSButton?

    init(
        settings: AppSettings,
        status: CompanionStatus,
        onPrimaryAction: @escaping () -> Void,
        onGreetPet: @escaping () -> Void
    ) {
        self.settings = settings

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = JoeyCopy.homeTitle
        window.minSize = NSSize(width: 880, height: 560)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.isReleasedWhenClosed = false

        super.init(window: window)

        let root = NestRootView(
            settings: settings,
            navigation: navigation,
            status: status,
            onPrimaryAction: onPrimaryAction,
            onGreetPet: onGreetPet,
            onRouteChange: { [weak self] route in
                self?.updateChrome(for: route)
            }
        )
        let hostingView = NSHostingView(rootView: root)
        hostingView.safeAreaRegions = []
        window.contentView = hostingView

        window.center()
        installChromeButton()
        applyAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func openSettings() {
        navigation.openSettings()
    }

    func applyAppearance() {
        guard let window else { return }
        let theme = JoeyTheme(appearance: settings.appearance)
        window.appearance = settings.appearance.nsAppearance
        window.backgroundColor = NSColor(theme.windowChrome)
    }

    private func installChromeButton() {
        let button = NSButton(
            image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: "设置") ?? NSImage(),
            target: self,
            action: #selector(settingsPressed)
        )
        button.isBordered = false
        button.bezelStyle = .inline
        button.toolTip = "设置"
        button.setAccessibilityLabel("设置")

        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = button
        accessory.layoutAttribute = .trailing
        window?.addTitlebarAccessoryViewController(accessory)
        chromeButton = button
    }

    private func updateChrome(for route: NestRoute) {
        window?.title = title(for: route)

        let isSettings = route == .settings
        let label = isSettings ? "回到 Joey 的家" : "设置"
        let symbol = isSettings ? "house" : "gearshape"
        chromeButton?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        chromeButton?.toolTip = label
        chromeButton?.setAccessibilityLabel(label)
    }

    private func title(for route: NestRoute) -> String {
        switch route {
        case .home: return JoeyCopy.homeTitle
        case .reflection: return JoeyCopy.reflectionTitle
        case .settings: return JoeyCopy.settingsTitle
        }
    }

    @objc private func settingsPressed() {
        navigation.toggleSettings()
    }
}
