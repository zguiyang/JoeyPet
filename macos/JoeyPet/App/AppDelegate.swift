import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static var retainedDelegate: AppDelegate?

    private let settings = AppSettings()
    private let companionStatus = CompanionStatus()
    private let audioController = JoeyAudioController()
    private var panelController: PetPanelController?
    private var coordinator: PetCoordinator?
    private var statusItem: NSStatusItem?
    private var togglePetItem: NSMenuItem?
    private var doNotDisturbItem: NSMenuItem?
    private var homeWindowController: MainWindowController?
    #if DEBUG
    private var posePreviewWindowController: JoeyPosePreviewWindowController?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // Do not assign NSApp.applicationIconImage — a raw square PNG bypasses
        // the system squircle mask and shows sharp corners in the Dock.
        configureMainMenu()

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-JoeyPetDebugPoses") {
            showPosePreview()
            return
        }
        #endif

        settings.onShowsDesktopPetChanged = { [weak self] isVisible in
            self?.panelController?.setVisible(isVisible)
            self?.coordinator?.setVisible(isVisible)
        }
        settings.onAppearanceChanged = { [weak self] _ in
            self?.applyAppearanceToWindows()
        }
        settings.onPetCornerChanged = { [weak self] corner in
            self?.panelController?.applyCorner(corner)
        }
        settings.onScheduleChanged = { [weak self] quietWindow, rhythmMinutes in
            self?.coordinator?.applyConfiguration(
                quietWindow: quietWindow,
                rhythmMinutes: rhythmMinutes
            )
        }
        settings.onDoNotDisturbChanged = { [weak self] enabled in
            self?.coordinator?.setDoNotDisturb(enabled)
        }
        settings.onSoundSelectionChanged = { [weak self] ambientID, cueID in
            guard let self else { return }
            self.audioController.applySelection(ambientID: ambientID, cueID: cueID)
            self.audioController.sync(situation: self.companionStatus.situation)
        }

        let panel = PetPanelController(corner: settings.petCorner)
        let coordinator = PetCoordinator(panelController: panel)
        coordinator.onSituationChanged = { [weak self] situation, summary in
            guard let self else { return }
            self.companionStatus.update(situation: situation, summary: summary)
            if self.settings.isDoNotDisturb != situation.isDoNotDisturb {
                self.settings.isDoNotDisturb = situation.isDoNotDisturb
            }
            self.audioController.sync(situation: situation)
        }
        coordinator.onPoseChanged = { [weak self] pose in
            self?.companionStatus.update(pose: pose)
        }
        panel.onHideRequested = { [weak self] in
            self?.settings.showsDesktopPet = false
        }
        panelController = panel
        self.coordinator = coordinator
        audioController.applySelection(
            ambientID: settings.ambientSoundID,
            cueID: settings.cueSoundID
        )
        panel.applyAppearance(settings.appearance)
        panel.setVisible(settings.showsDesktopPet)
        coordinator.start()
        coordinator.applyConfiguration(
            quietWindow: settings.quietWindow,
            rhythmMinutes: settings.rhythmMinutes
        )
        audioController.sync(situation: panel.petRuntime.situation)

        configureStatusItem()
        showHome()
    }

    func applicationWillTerminate(_ notification: Notification) {
        audioController.stop()
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

        let doNotDisturb = menuItem(
            settings.isDoNotDisturb ? "关闭勿扰模式" : "勿扰模式",
            #selector(toggleDoNotDisturb)
        )
        doNotDisturb.state = settings.isDoNotDisturb ? .on : .off
        doNotDisturbItem = doNotDisturb
        menu.addItem(doNotDisturb)

        menu.addItem(.separator())
        menu.addItem(menuItem("退出 JoeyPet", #selector(quit)))

        item.menu = menu
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        togglePetItem?.state = settings.showsDesktopPet ? .on : .off
        doNotDisturbItem?.state = settings.isDoNotDisturb ? .on : .off
        doNotDisturbItem?.title = settings.isDoNotDisturb ? "关闭勿扰模式" : "勿扰模式"
    }

    // MARK: - Windows

    @objc private func showHome() {
        if homeWindowController == nil {
            homeWindowController = MainWindowController(
                settings: settings,
                status: companionStatus,
                onPrimaryAction: { [weak self] in self?.toggleCompanionship() },
                onGreetPet: { [weak self] in self?.coordinator?.greetPet() },
                onInviteAccept: { [weak self] in
                    self?.panelController?.acceptInvitationFromNest()
                },
                onInviteSnooze: { [weak self] in
                    self?.panelController?.snoozeInvitationFromNest()
                },
                onInviteDoNotDisturb: { [weak self] in
                    self?.settings.isDoNotDisturb = true
                    self?.panelController?.enterDoNotDisturbFromNest()
                },
                onDebugAction: { [weak self] action in
                    self?.handleDebugPetAction(action)
                }
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

    @objc private func toggleDoNotDisturb() {
        settings.isDoNotDisturb.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    /// Starts companionship only from an explicit user action, and ends it the same way.
    /// Showing the desktop pet stays a separate manual choice in Settings or the menu bar.
    private func toggleCompanionship() {
        guard let coordinator else { return }
        if panelController?.petRuntime.situation.session != nil {
            coordinator.endSession()
        } else {
            coordinator.startSession()
        }
    }

    private func applyAppearanceToWindows() {
        homeWindowController?.applyAppearance()
        panelController?.applyAppearance(settings.appearance)
    }

    private func handleDebugPetAction(_ action: DebugPetAction) {
        #if DEBUG
        switch action {
        case .showDesktopPet:
            settings.showsDesktopPet = true
        case .posePreview:
            showPosePreview()
        case .greeting, .notifying, .recovering, .celebrating, .sleeping,
             .quietSleep, .yawning, .grooming, .startSession, .endSession:
            if action == .notifying || action == .recovering || action == .celebrating
                || action == .sleeping || action == .quietSleep
                || action == .yawning || action == .grooming || action == .greeting {
                settings.showsDesktopPet = true
                panelController?.setVisible(true)
                coordinator?.setVisible(true)
            }
            DispatchQueue.main.async { [weak self] in
                _ = self?.coordinator?.debugTrigger(action)
            }
        }
        #else
        _ = action
        #endif
    }

    #if DEBUG
    private func showPosePreview() {
        guard let controller = JoeyPosePreviewWindowController.make() else {
            return
        }
        posePreviewWindowController = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
    #endif
}
