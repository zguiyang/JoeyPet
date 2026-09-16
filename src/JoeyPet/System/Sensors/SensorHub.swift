import Foundation
import OSLog

@MainActor
final class SensorHub {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "SensorHub")

    var onSignal: ((SystemSignal) -> Void)?
    var onSnapshot: ((SystemStatusSnapshot) -> Void)?

    private(set) var currentSnapshot = SystemStatusSnapshot.initial
    private var latestSignals: [String: SystemSignal] = [:]

    private let thermalSensor = ThermalSensor()
    private let memorySensor = MemoryPressureSensor()
    private let storageSensor = StorageSensor()
    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        isRunning = true

        wire(sensor: thermalSensor)
        wire(sensor: memorySensor)
        wire(sensor: storageSensor)

        thermalSensor.start()
        memorySensor.start()
        storageSensor.start()

        Self.logger.info("SensorHub started")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        thermalSensor.stop()
        memorySensor.stop()
        storageSensor.stop()

        thermalSensor.onSignal = nil
        memorySensor.onSignal = nil
        storageSensor.onSignal = nil
        onSnapshot = nil
        latestSignals.removeAll()
        currentSnapshot = .initial

        Self.logger.info("SensorHub stopped")
    }

    deinit {
        thermalSensor.releaseResources()
        memorySensor.releaseResources()
        storageSensor.releaseResources()
    }

    private func wire(sensor: SystemSensor) {
        sensor.onSignal = { [weak self] signal in
            guard let self else { return }
            if signal.proposedPetState == nil {
                self.latestSignals.removeValue(forKey: signal.sensorID)
            } else {
                self.latestSignals[signal.sensorID] = signal
            }
            self.currentSnapshot = self.makeSnapshot()
            self.onSnapshot?(self.currentSnapshot)
            self.onSignal?(signal)
        }
    }

    private func makeSnapshot() -> SystemStatusSnapshot {
        let thermal: ThermalPressureLevel = {
            guard let signal = latestSignals["thermal"],
                  case .thermalPressure(let level) = signal.kind else { return .nominal }
            return level
        }()
        let memory: MemoryPressureLevel = {
            guard let signal = latestSignals["memory"],
                  case .memoryPressure(let level) = signal.kind else { return .normal }
            return level
        }()
        let storage: (available: Int64, total: Int64)? = storageSensor.currentCapacity
        let storageSeverity = latestSignals["storage"]?.severity ?? .normal
        return SystemStatusSnapshot(
            thermal: thermal,
            memory: memory,
            storageAvailableBytes: storage?.available,
            storageTotalBytes: storage?.total,
            storageSeverity: storageSeverity
        )
    }
}
