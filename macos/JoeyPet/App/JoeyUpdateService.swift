import Foundation
import Observation
import OSLog
import Sparkle

/// Owns Sparkle and exposes About-pane update state. Automatic checks stay off.
@Observable
@MainActor
final class JoeyUpdateService: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    private(set) var phase: JoeyUpdatePhase = .idle

    private let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "Update")
    private var updaterController: SPUStandardUpdaterController?

    override init() {
        super.init()
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: self
        )
        controller.updater.automaticallyChecksForUpdates = false
        controller.updater.automaticallyDownloadsUpdates = false
        updaterController = controller
    }

    /// Manual check / install from About.
    /// - Idle / upToDate / failed → background check (no “已是最新” system alert).
    /// - available → Sparkle install UI (download + restart).
    func checkForUpdates() {
        guard let updater = updaterController?.updater else {
            phase = .failed
            return
        }
        guard phase != .checking else { return }

        if case .available = phase {
            updater.checkForUpdates()
            return
        }

        phase = .checking
        updater.checkForUpdatesInBackground()
    }

    // MARK: - SPUUpdaterDelegate

    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        Task { @MainActor in
            self.phase = .available(version: version)
            self.logger.info("Update available: \(version, privacy: .public)")
        }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        Task { @MainActor in
            self.phase = .upToDate
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        Task { @MainActor in
            let nsError = error as NSError
            // User dismissed Sparkle’s sheet — keep `.available` so they can retry.
            if nsError.domain == SUSparkleErrorDomain,
               nsError.code == Int(SUError.installationCanceledError.rawValue) {
                return
            }
            self.logger.error("Update aborted: \(error.localizedDescription, privacy: .public)")
            if self.phase == .checking {
                self.phase = .failed
            }
        }
    }

    // MARK: - SPUStandardUserDriverDelegate

    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    /// Background discovery must not pop Sparkle UI; About owns the 「更新」 button.
    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediate: Bool
    ) -> Bool {
        false
    }
}
