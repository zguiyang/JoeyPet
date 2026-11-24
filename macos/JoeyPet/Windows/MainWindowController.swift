import AppKit
import SwiftUI

/// AppKit owns the main window; SwiftUI owns its content.
@MainActor
final class MainWindowController: NSWindowController {
    private static let frameAutosaveName = "JoeyPet.HomeWindow"
    private static let defaultSize = NSSize(width: 1080, height: 720)

    private let settings: AppSettings
    private let navigation = NestNavigation()
    private var chromeButton: NSButton?

    init(
        settings: AppSettings,
        status: CompanionStatus,
        onPrimaryAction: @escaping () -> Void,
        onGreetPet: @escaping () -> Void,
        onInviteAccept: (() -> Void)? = nil,
        onInviteSnooze: (() -> Void)? = nil,
        onInviteDoNotDisturb: (() -> Void)? = nil,
        onDebugAction: ((DebugPetAction) -> Void)? = nil
    ) {
        self.settings = settings

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
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
            onInviteAccept: onInviteAccept,
            onInviteSnooze: onInviteSnooze,
            onInviteDoNotDisturb: onInviteDoNotDisturb,
            onDebugAction: onDebugAction,
            onRouteChange: { [weak self] route in
                self?.updateChrome(for: route)
            }
        )
        let hostingView = NSHostingView(rootView: root)
        hostingView.safeAreaRegions = []
        window.contentView = hostingView

        placeHomeWindow(window)
        installChromeButton()
        applyAppearance()
    }

    /// Restores the last frame when possible; otherwise centres on the
    /// system primary display (`screens[0]` / menu-bar screen) — never
    /// `NSScreen.main`, which follows the key window across monitors.
    private func placeHomeWindow(_ window: NSWindow) {
        let restored = window.setFrameUsingName(Self.frameAutosaveName)
        window.setFrameAutosaveName(Self.frameAutosaveName)

        if restored, Self.frameIntersectsAnyScreen(window.frame) {
            return
        }

        Self.centerOnPrimaryDisplay(window)
    }

    private static func primaryScreen() -> NSScreen? {
        NSScreen.screens.first
    }

    private static func centerOnPrimaryDisplay(_ window: NSWindow) {
        guard let screen = primaryScreen() else {
            window.center()
            return
        }
        let visible = screen.visibleFrame
        let size = window.frame.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
        window.setFrame(NSRect(origin: origin, size: size), display: false)
    }

    private static func frameIntersectsAnyScreen(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
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
