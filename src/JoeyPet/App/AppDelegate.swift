import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: PetPanelController?
    private var coordinator: PetCoordinator?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let panel = PetPanelController()
        let coordinator = PetCoordinator(panelController: panel)
        panelController = panel
        self.coordinator = coordinator
        panel.setVisible(PetPreferences.showsDesktopPet())
        coordinator.start()
        configureStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) { coordinator?.stop() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(named: "JoeyPetMenuBarTemplate")
        let menu = NSMenu()
        menu.addItem(withTitle: "显示 Joey", action: #selector(showJoey), keyEquivalent: "")
        menu.addItem(withTitle: "隐藏 Joey", action: #selector(hideJoey), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 JoeyPet", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func showJoey() { panelController?.setVisible(true) }
    @objc private func hideJoey() { panelController?.setVisible(false) }
    @objc private func quit() { NSApp.terminate(nil) }
}
