import Foundation
import OSLog

@MainActor
final class SensorHub {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "SensorHub")

    var onSignal: ((SystemSignal) -> Void)?

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

        Self.logger.info("SensorHub stopped")
    }

    deinit {
        thermalSensor.releaseResources()
        memorySensor.releaseResources()
        storageSensor.releaseResources()
    }

    private func wire(sensor: SystemSensor) {
        sensor.onSignal = { [weak self] signal in
            self?.onSignal?(signal)
        }
    }
}
