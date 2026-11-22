import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static var retainedDelegate: AppDelegate?

    private let settings = AppSettings()
    private var panelController: PetPanelController?
    private var coordinator: PetCoordinator?
    private var statusItem: NSStatusItem?
    private var togglePetItem: NSMenuItem?
    private var homeWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureMainMenu()

        settings.onShowsDesktopPetChanged = { [weak self] isVisible in
            self?.panelController?.setVisible(isVisible)
        }
        settings.onAppearanceChanged = { [weak self] _ in
            self?.applyAppearanceToWindows()
        }

        let panel = PetPanelController()
        let coordinator = PetCoordinator(panelController: panel)
        panelController = panel
        self.coordinator = coordinator
        panel.setVisible(settings.showsDesktopPet)
        coordinator.start()

        configureStatusItem()
        showHome()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showHome()
        return true
    }

    // MARK: - Main menu

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "JoeyPet")
        appMenuItem.submenu = appMenu

        appMenu.addItem(
            menuItem(
                "关于 JoeyPet",
                #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                target: NSApp
            )
        )
        appMenu.addItem(.separator())
        appMenu.addItem(menuItem("设置…", #selector(openSettings), key: ","))
        appMenu.addItem(.separator())

        let servicesItem = NSMenuItem(title: "服务", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "服务")
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu

        appMenu.addItem(.separator())
        appMenu.addItem(
            menuItem("隐藏 JoeyPet", #selector(NSApplication.hide(_:)), key: "h", target: NSApp)
        )
        let hideOthers = menuItem(
            "隐藏其他",
            #selector(NSApplication.hideOtherApplications(_:)),
            key: "h",
            target: NSApp
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(
            menuItem(
                "显示全部",
                #selector(NSApplication.unhideAllApplications(_:)),
                target: NSApp
            )
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            menuItem("退出 JoeyPet", #selector(NSApplication.terminate(_:)), key: "q", target: NSApp)
        )

        let windowMenuItem = NSMenuItem(title: "窗口", action: nil, keyEquivalent: "")
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "窗口")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(
            menuItem("最小化", #selector(NSWindow.performMiniaturize(_:)), key: "m")
        )
        windowMenu.addItem(menuItem("缩放", #selector(NSWindow.performZoom(_:))))
        windowMenu.items.forEach { $0.target = nil }
        windowMenu.addItem(.separator())
        windowMenu.addItem(
            menuItem("前置全部窗口", #selector(NSApplication.arrangeInFront(_:)), target: NSApp)
        )
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    private func menuItem(
        _ title: String,
        _ action: Selector?,
        key: String = "",
        target: AnyObject? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target ?? self
        return item
    }

    // MARK: - Status item

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(named: "JoeyPetMenuBarTemplate")

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(menuItem("打开 Joey 的家", #selector(showHome)))
        menu.addItem(menuItem("设置…", #selector(openSettings)))
        menu.addItem(.separator())

        let toggle = menuItem("显示 Joey", #selector(toggleDesktopPet))
        toggle.state = settings.showsDesktopPet ? .on : .off
        togglePetItem = toggle
        menu.addItem(toggle)

        menu.addItem(.separator())
        menu.addItem(menuItem("退出 JoeyPet", #selector(quit)))

        item.menu = menu
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        togglePetItem?.state = settings.showsDesktopPet ? .on : .off
    }

    // MARK: - Windows

    @objc private func showHome() {
        if homeWindowController == nil {
            homeWindowController = MainWindowController(
                settings: settings,
                onPrimaryAction: {}
            )
        }
        homeWindowController?.applyAppearance()
        homeWindowController?.showWindow(nil)
        homeWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    @objc private func openSettings() {
        showHome()
        homeWindowController?.openSettings()
    }

    @objc private func toggleDesktopPet() {
        settings.showsDesktopPet.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func applyAppearanceToWindows() {
        homeWindowController?.applyAppearance()
    }
}
