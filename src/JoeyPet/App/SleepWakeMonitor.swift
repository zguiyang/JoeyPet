import AppKit
import OSLog

@MainActor
final class SleepWakeMonitor {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "SleepWakeMonitor")

    var onSleep: (() -> Void)?
    var onWake: (() -> Void)?

    private var observers: [NSObjectProtocol] = []
    private var isSleeping = false

    func start() {
        guard observers.isEmpty else { return }

        let center = NSWorkspace.shared.notificationCenter
        observers.append(
            center.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleSleep()
            }
        )
        observers.append(
            center.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleWake()
            }
        )

        Self.logger.info("SleepWakeMonitor started")
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
        Self.logger.info("SleepWakeMonitor stopped")
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers {
            center.removeObserver(observer)
        }
    }

    private func handleSleep() {
        guard !isSleeping else { return }
        isSleeping = true
        Self.logger.info("System sleep detected")
        onSleep?()
    }

    private func handleWake() {
        guard isSleeping else { return }
        isSleeping = false
        Self.logger.info("System wake detected")
        onWake?()
    }
}
