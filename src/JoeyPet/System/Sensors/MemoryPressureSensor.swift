import Foundation
import OSLog

final class MemoryPressureSensor: SystemSensor {
    let sensorID = "memory"
    var onSignal: ((SystemSignal) -> Void)?

    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "MemoryPressureSensor")
    private nonisolated(unsafe) var source: DispatchSourceMemoryPressure?

    func start() {
        guard source == nil else { return }

        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.normal, .warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            self?.emit(level: source.data)
        }
        source.resume()
        self.source = source
        emit(level: source.data)

        Self.logger.info("MemoryPressureSensor started")
    }

    func stop() {
        releaseResources()
        Self.logger.info("MemoryPressureSensor stopped")
    }

    deinit {
        releaseResources()
    }

    nonisolated func releaseResources() {
        source?.cancel()
        source = nil
    }

    private func emit(level: DispatchSource.MemoryPressureEvent) {
        onSignal?(Self.makeSignal(from: level))
    }

    static func makeSignal(from event: DispatchSource.MemoryPressureEvent, now: Date = Date()) -> SystemSignal {
        let level: MemoryPressureLevel
        let severity: SignalSeverity

        switch event {
        case .normal:
            level = .normal
            severity = .normal
        case .warning:
            level = .warning
            severity = .warning
        case .critical:
            level = .critical
            severity = .critical
        default:
            level = .normal
            severity = .normal
        }

        return SystemSignal(
            sensorID: "memory",
            kind: .memoryPressure(level: level),
            severity: severity,
            timestamp: now
        )
    }
}
