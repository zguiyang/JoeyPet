import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "AppDelegate")

    private var panelController: PetPanelController?
    private var coordinator: PetCoordinator?
    private var appModel: AppModel?
    private let shellState = AppShellState()
    private let stageState = JoeyStageState()
    private var mainWindowController: MainWindowController?
    private let bubbleController = JoeyBubbleController()
    private var statusItem: NSStatusItem?
    private var statusBarMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        let panelController = PetPanelController()
        let coordinator = PetCoordinator(panelController: panelController)
        let appModel = AppModel()
        let mainWindowController = MainWindowController(model: appModel, shellState: shellState, stageState: stageState)

        self.panelController = panelController
        self.coordinator = coordinator
        self.appModel = appModel
        self.mainWindowController = mainWindowController

        panelController.onLeftClick = { [weak self] in self?.showStatusBubble() }
        coordinator.onSystemSnapshot = { [weak appModel] snapshot in appModel?.update(systemStatus: snapshot) }
        coordinator.onStageSnapshot = { [weak stageState] snapshot in stageState?.apply(snapshot) }
        coordinator.onBubble = { [weak self] message, frame, primary, secondary in
            self?.bubbleController.show(message, near: frame, onPrimary: primary, onSecondary: secondary)
        }
        coordinator.onQuickClean = { [weak appModel] in appModel?.beginQuickClean() }
        coordinator.onScan = { [weak appModel, weak mainWindowController] in
            mainWindowController?.present(intent: .macCareCleanup)
            appModel?.scan()
        }
        appModel.onPreferencesChanged = { [weak coordinator] in coordinator?.refreshPreferences() }
        appModel.onResetPetPosition = { [weak panelController] in panelController?.resetPosition() }
        appModel.onCleanupStarted = { [weak panelController, weak coordinator] in
            _ = panelController?.petRuntime.perform(.cleaning)
            coordinator?.publishStageSnapshot()
        }
        appModel.onCleanupFinished = { [weak self, weak mainWindowController, weak panelController, weak coordinator] result in
            guard let panelController else { return }
            let behavior: PetTransientBehavior = result.failedCount == 0 ? .celebrating : .notifying
            _ = panelController.petRuntime.perform(behavior)
            coordinator?.publishStageSnapshot()
            let message = result.failedCount == 0
                ? "处理好了，\(result.succeededCount) 个项目已经移到废纸篓。"
                : "已处理 \(result.succeededCount) 个项目，\(result.failedCount) 个项目失败。"
            self?.bubbleController.show(
                JoeyBubbleMessage(text: message, severity: result.failedCount == 0 ? .normal : .warning, primaryTitle: "查看详情", secondaryTitle: nil),
                near: panelController.currentFrame(),
                onPrimary: { mainWindowController?.present(intent: .macCareCleanup) }
            )
        }
        appModel.onQuickCleanNeedsConfirmation = { [weak self] in
            self?.presentQuickCleanConfirmation()
        }
        appModel.onQuickCleanNothingToProcess = { [weak self, weak panelController] in
            self?.bubbleController.show(
                JoeyBubbleMessage(text: "当前没有需要快速处理的内容。", severity: .normal, primaryTitle: nil, secondaryTitle: nil),
                near: panelController?.currentFrame() ?? .zero
            )
        }

        panelController.show()
        coordinator.start()

        configureMenuBarStatusItem()

        #if DEBUG
        applyQALaunchOverrides()
        #endif

        Self.logger.info("JoeyPet desktop MVP launched")
    }

    #if DEBUG
    private func applyQALaunchOverrides() {
        if let intent = DebugStateInjector.qaMainWindowIntent() {
            mainWindowController?.present(intent: intent)
            if DebugStateInjector.qaTriggersScan() {
                appModel?.scan()
            }
        }
    }
    #endif

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
        appModel?.cancelOperations()
        bubbleController.dismiss()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc private func openMainWindow() { mainWindowController?.present(intent: .default) }

    private func configureMenuBarStatusItem() {
        #if DEBUG
        print("[JoeyPet] configureMenuBarStatusItem")
        #endif
        Self.logger.info("configureMenuBarStatusItem")

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item

        guard let button = item.button else {
            #if DEBUG
            print("[JoeyPet] NSStatusItem.button is nil")
            #endif
            Self.logger.error("NSStatusItem.button is nil")
            return
        }

        button.toolTip = "JoeyPet"

        if let image = Self.statusBarTemplateImage(named: "JoeyPetMenuBarTemplate") {
            #if DEBUG
            print("[JoeyPet] JoeyPetMenuBarTemplate asset loaded for status bar")
            #endif
            button.image = image
            button.title = ""
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
        } else {
            #if DEBUG
            print("[JoeyPet] JoeyPetMenuBarTemplate asset NOT FOUND — using title fallback JP")
            #endif
            Self.logger.error("JoeyPetMenuBarTemplate asset NOT FOUND")
            button.image = nil
            button.title = "JP"
        }

        let menu = makeStatusBarMenu()
        menu.delegate = self
        statusBarMenu = menu
        item.menu = menu

        item.isVisible = true
        #if DEBUG
        print("[JoeyPet] statusItem configured visible=\(item.isVisible)")
        #endif
    }

    private func makeStatusBarMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(menuItem(title: "打开 JoeyPet", action: #selector(openMainWindow), tag: 1))
        menu.addItem(menuItem(title: "快速清理", action: #selector(quickClean), tag: 2))
        menu.addItem(menuItem(title: "扫描并查看…", action: #selector(scanAndView), tag: 3))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "设置…", action: #selector(openSettings), tag: 4))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "退出 JoeyPet", action: #selector(quit), keyEquivalent: "q", tag: 5))

        return menu
    }

    private func menuItem(
        title: String,
        action: Selector,
        keyEquivalent: String = "",
        tag: Int
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.tag = tag
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let busy = appModel?.isBusy ?? false
        menu.item(withTag: 2)?.isEnabled = !busy // Quick Clean
        menu.item(withTag: 3)?.isEnabled = !busy // Scan and View
    }

    /// Rasterize asset-catalog template artwork for NSStatusItem (SVG often has no bitmap backing).
    private static func statusBarTemplateImage(named name: String, pointSize: CGFloat = 19) -> NSImage? {
        guard let source = NSImage(named: name) ?? Bundle.main.image(forResource: name) else {
            return nil
        }
        source.isTemplate = true
        let size = NSSize(width: pointSize, height: pointSize)
        let output = NSImage(size: size)
        output.isTemplate = true
        output.lockFocus()
        defer { output.unlockFocus() }
        NSColor.clear.set()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        source.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: source.size),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )
        return output
    }

    @objc private func quickClean() { appModel?.beginQuickClean() }

    private func presentQuickCleanConfirmation() {
        let alert = NSAlert()
        alert.messageText = "清理可安全处理的内容？"
        alert.informativeText = "这些缓存和临时文件会被移到废纸篓，不会永久删除。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "移到废纸篓")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        appModel?.confirmQuickClean()
    }
    @objc private func scanAndView() {
        mainWindowController?.present(intent: .macCareCleanup)
        appModel?.scan()
    }
    @objc private func openSettings() {
        mainWindowController?.present(intent: .settings)
    }
    @objc private func quit() { NSApp.terminate(nil) }

    private func showStatusBubble() {
        guard let panelController, let appModel else { return }
        let status = appModel.systemStatus
        let message: JoeyBubbleMessage
        switch status.overallSeverity {
        case .normal: message = JoeyBubbleMessage(text: "Joey 在这里陪你工作。", severity: .normal, primaryTitle: nil, secondaryTitle: nil)
        case .notice: message = JoeyBubbleMessage(text: "Mac 有一点小提醒。", severity: .notice, primaryTitle: "查看", secondaryTitle: nil)
        case .warning: message = JoeyBubbleMessage(text: "Mac 需要注意一下。", severity: .warning, primaryTitle: "查看", secondaryTitle: nil)
        case .critical: message = JoeyBubbleMessage(text: "Mac 状态比较紧张。", severity: .critical, primaryTitle: "查看", secondaryTitle: nil)
        }
        bubbleController.show(message, near: panelController.currentFrame(), onPrimary: { [weak self] in
            self?.mainWindowController?.present(intent: .default)
        })
    }
}
