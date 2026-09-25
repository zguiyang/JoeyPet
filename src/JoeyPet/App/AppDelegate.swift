import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "AppDelegate")

    private var panelController: PetPanelController?
    private var coordinator: PetCoordinator?
    private var appModel: AppModel?
    private var mainWindowController: MainWindowController?
    private let bubbleController = JoeyBubbleController()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        let panelController = PetPanelController()
        let coordinator = PetCoordinator(panelController: panelController)
        let appModel = AppModel()
        let mainWindowController = MainWindowController(model: appModel)

        self.panelController = panelController
        self.coordinator = coordinator
        self.appModel = appModel
        self.mainWindowController = mainWindowController

        panelController.onLeftClick = { [weak self] in self?.showStatusBubble() }
        panelController.onRightClick = { [weak self] event in self?.showContextMenu(for: event) }
        coordinator.onSystemSnapshot = { [weak appModel] snapshot in appModel?.update(systemStatus: snapshot) }
        coordinator.onBubble = { [weak self] message, frame, primary, secondary in
            self?.bubbleController.show(message, near: frame, onPrimary: primary, onSecondary: secondary)
        }
        coordinator.onQuickClean = { [weak appModel] in appModel?.quickClean() }
        coordinator.onScan = { [weak appModel, weak mainWindowController] in
            mainWindowController?.show(section: .cleanup)
            appModel?.scan()
        }
        appModel.onPreferencesChanged = { [weak coordinator] in coordinator?.refreshPreferences() }
        appModel.onResetPetPosition = { [weak panelController] in panelController?.resetPosition() }
        appModel.onCleanupStarted = { [weak panelController] in
            _ = panelController?.petRuntime.perform(.cleaning)
        }
        appModel.onCleanupFinished = { [weak self, weak mainWindowController] result in
            let behavior: PetTransientBehavior = result.failedCount == 0 ? .celebrating : .notifying
            _ = panelController.petRuntime.perform(behavior)
            let message = result.failedCount == 0
                ? "处理好了，\(result.succeededCount) 个项目已经移到废纸篓。"
                : "已处理 \(result.succeededCount) 个项目，\(result.failedCount) 个项目失败。"
            self?.bubbleController.show(
                JoeyBubbleMessage(text: message, severity: result.failedCount == 0 ? .normal : .warning, primaryTitle: "查看详情", secondaryTitle: nil),
                near: panelController.currentFrame(),
                onPrimary: { mainWindowController?.show(section: .cleanup) }
            )
        }
        appModel.onCleanupEmpty = { [weak self, weak panelController] in
            self?.bubbleController.show(
                JoeyBubbleMessage(text: "暂时没发现需要清理的内容。", severity: .normal, primaryTitle: nil, secondaryTitle: nil),
                near: panelController?.currentFrame() ?? .zero
            )
        }

        panelController.show()
        coordinator.start()

        configureMenuBarStatusItem()

        Self.logger.info("JoeyPet desktop MVP launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
        appModel?.cancelOperations()
        bubbleController.dismiss()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc private func openMainWindow() { mainWindowController?.show(section: .overview) }

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

        button.target = self
        button.action = #selector(openMainWindow)
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

        item.isVisible = true
        #if DEBUG
        print("[JoeyPet] statusItem configured visible=\(item.isVisible)")
        #endif
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

    @objc private func quickClean() { appModel?.quickClean() }
    @objc private func scanAndView() {
        mainWindowController?.show(section: .cleanup)
        appModel?.scan()
    }
    @objc private func openSettings() { mainWindowController?.show(section: .settings) }
    @objc private func quit() { NSApp.terminate(nil) }

    private func showContextMenu(for event: NSEvent) {
        guard let panelController else { return }
        let menu = NSMenu()
        menu.addItem(withTitle: "打开 JoeyPet", action: #selector(openMainWindow), keyEquivalent: "")
        menu.addItem(withTitle: "快速清理", action: #selector(quickClean), keyEquivalent: "")
        menu.addItem(withTitle: "扫描并查看", action: #selector(scanAndView), keyEquivalent: "")
        menu.addItem(withTitle: "设置", action: #selector(openSettings), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 JoeyPet", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        panelController.showContextMenu(menu, for: event)
    }

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
            self?.mainWindowController?.show(section: .overview)
        })
    }
}
