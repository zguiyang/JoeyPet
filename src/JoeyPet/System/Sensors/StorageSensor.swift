import Foundation
import OSLog

final class StorageSensor: SystemSensor {
    let sensorID = "storage"
    var onSignal: ((SystemSignal) -> Void)?

    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "StorageSensor")
    private nonisolated(unsafe) var pollTask: Task<Void, Never>?
    private let volumeURL: URL

    init(volumeURL: URL = URL(fileURLWithPath: NSHomeDirectory())) {
        self.volumeURL = volumeURL
    }

    func start() {
        guard pollTask == nil else { return }

        emitCurrentCapacity()

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(SensorThresholds.storagePollInterval))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self?.emitCurrentCapacity()
                }
            }
        }

        Self.logger.info("StorageSensor started")
    }

    func stop() {
        releaseResources()
        Self.logger.info("StorageSensor stopped")
    }

    deinit {
        releaseResources()
    }

    nonisolated func releaseResources() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func emitCurrentCapacity() {
        onSignal?(Self.makeSignal(for: volumeURL))
    }

    static func makeSignal(for volumeURL: URL, now: Date = Date()) -> SystemSignal {
        let availableBytes = availableCapacityBytes(for: volumeURL)

        if availableBytes <= SensorThresholds.storageCriticalBytes {
            return SystemSignal(
                sensorID: "storage",
                kind: .storageLow(
                    availableBytes: availableBytes,
                    thresholdBytes: SensorThresholds.storageCriticalBytes
                ),
                severity: .critical,
                timestamp: now
            )
        }

        if availableBytes <= SensorThresholds.storageWarningBytes {
            return SystemSignal(
                sensorID: "storage",
                kind: .storageLow(
                    availableBytes: availableBytes,
                    thresholdBytes: SensorThresholds.storageWarningBytes
                ),
                severity: .warning,
                timestamp: now
            )
        }

        return SystemSignal(
            sensorID: "storage",
            kind: .storageLow(availableBytes: availableBytes, thresholdBytes: SensorThresholds.storageWarningBytes),
            severity: .info,
            timestamp: now
        )
    }

    private static func availableCapacityBytes(for volumeURL: URL) -> Int64 {
        do {
            let values = try volumeURL.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ])

            if let important = values.volumeAvailableCapacityForImportantUsage {
                return important
            }
            if let available = values.volumeAvailableCapacity {
                return Int64(available)
            }
        } catch {
            logger.error("Failed to read storage capacity: \(error.localizedDescription, privacy: .public)")
        }

        return Int64.max
    }
}
