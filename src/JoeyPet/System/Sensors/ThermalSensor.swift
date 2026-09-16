import Foundation
import OSLog

final class ThermalSensor: SystemSensor {
    let sensorID = "thermal"
    var onSignal: ((SystemSignal) -> Void)?

    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "ThermalSensor")
    private nonisolated(unsafe) var observer: NSObjectProtocol?

    func start() {
        guard observer == nil else { return }
        emitCurrentState()

        observer = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.emitCurrentState()
        }

        Self.logger.info("ThermalSensor started")
    }

    func stop() {
        releaseResources()
        Self.logger.info("ThermalSensor stopped")
    }

    deinit {
        releaseResources()
    }

    nonisolated func releaseResources() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    private func emitCurrentState() {
        let thermalState = ProcessInfo.processInfo.thermalState
        let signal = Self.makeSignal(from: thermalState)
        onSignal?(signal)
    }

    static func makeSignal(from thermalState: ProcessInfo.ThermalState, now: Date = Date()) -> SystemSignal {
        let level: ThermalPressureLevel
        let severity: SignalSeverity

        switch thermalState {
        case .nominal:
            level = .nominal
            severity = .normal
        case .fair:
            level = .fair
            severity = .notice
        case .serious:
            level = .serious
            severity = .warning
        case .critical:
            level = .critical
            severity = .critical
        @unknown default:
            level = .nominal
            severity = .normal
        }

        return SystemSignal(
            sensorID: "thermal",
            kind: .thermalPressure(level: level),
            severity: severity,
            timestamp: now
        )
    }
}

extension ThermalPressureLevel {
    init(_ thermalState: ProcessInfo.ThermalState) {
        switch thermalState {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .nominal
        }
    }
}
