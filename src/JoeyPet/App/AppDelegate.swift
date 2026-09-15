import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "AppDelegate")

    private var panelController: PetPanelController?
    private var coordinator: PetCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        let panelController = PetPanelController()
        let coordinator = PetCoordinator(panelController: panelController)

        self.panelController = panelController
        self.coordinator = coordinator

        panelController.show()
        coordinator.start()

        Self.logger.info("JoeyPet desktop spike launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }
}
