import Foundation
import OSLog

final class StorageSensor: SystemSensor {
    let sensorID = "storage"
    var onSignal: ((SystemSignal) -> Void)?

    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "StorageSensor")
    private nonisolated(unsafe) var pollTask: Task<Void, Never>?
    private let volumeURL: URL
    private(set) var currentCapacity: (available: Int64, total: Int64)?

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
        currentCapacity = Self.capacity(for: volumeURL)
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
        capacity(for: volumeURL)?.available ?? Int64.max
    }

    private static func capacity(for volumeURL: URL) -> (available: Int64, total: Int64)? {
        do {
            let values = try volumeURL.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey,
                .volumeTotalCapacityKey
            ])
            let available = values.volumeAvailableCapacityForImportantUsage
                ?? values.volumeAvailableCapacity.map(Int64.init)
            guard let available, let total = values.volumeTotalCapacity else { return nil }
            return (available, Int64(total))
        } catch {
            logger.error("Failed to read storage capacity: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
