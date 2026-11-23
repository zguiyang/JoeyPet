import AppKit
import OSLog

@MainActor
final class SleepWakeMonitor {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "SleepWakeMonitor")

    var onSleep: (() -> Void)?
    var onWake: (() -> Void)?
    var onScreenLocked: (() -> Void)?
    var onScreenUnlocked: (() -> Void)?

    private var observers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var isSleeping = false
    private var isScreenLocked = false

    func start() {
        guard observers.isEmpty else { return }

        let center = NSWorkspace.shared.notificationCenter
        observers.append(
            center.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleSleep()
                }
            }
        )
        observers.append(
            center.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleWake()
                }
            }
        )

        let distributedCenter = DistributedNotificationCenter.default()
        distributedObservers.append(
            distributedCenter.addObserver(
                forName: Notification.Name("com.apple.screenIsLocked"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleScreenLocked()
                }
            }
        )
        distributedObservers.append(
            distributedCenter.addObserver(
                forName: Notification.Name("com.apple.screenIsUnlocked"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleScreenUnlocked()
                }
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

        let distributedCenter = DistributedNotificationCenter.default()
        for observer in distributedObservers {
            distributedCenter.removeObserver(observer)
        }
        distributedObservers.removeAll()
        Self.logger.info("SleepWakeMonitor stopped")
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers {
            center.removeObserver(observer)
        }
        let distributedCenter = DistributedNotificationCenter.default()
        for observer in distributedObservers {
            distributedCenter.removeObserver(observer)
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

    private func handleScreenLocked() {
        guard !isScreenLocked else { return }
        isScreenLocked = true
        Self.logger.info("Screen locked")
        onScreenLocked?()
    }

    private func handleScreenUnlocked() {
        guard isScreenLocked else { return }
        isScreenLocked = false
        Self.logger.info("Screen unlocked")
        onScreenUnlocked?()
    }
}
