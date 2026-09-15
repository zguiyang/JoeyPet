import Foundation

enum ThermalPressureLevel: String, Equatable, Sendable, Codable {
    case nominal
    case fair
    case serious
    case critical
}

enum MemoryPressureLevel: String, Equatable, Sendable, Codable {
    case normal
    case warning
    case critical
}

enum SystemSignalKind: Equatable, Sendable, Hashable {
    case thermalPressure(level: ThermalPressureLevel)
    case memoryPressure(level: MemoryPressureLevel)
    case storageLow(availableBytes: Int64, thresholdBytes: Int64)
}

struct SystemSignal: Equatable, Sendable {
    let sensorID: String
    let kind: SystemSignalKind
    let severity: SignalSeverity
    let timestamp: Date

    var behaviorPriority: Int {
        switch kind {
        case .thermalPressure(let level):
            switch level {
            case .critical: return 100
            case .serious: return 70
            case .fair: return 20
            case .nominal: return 0
            }
        case .memoryPressure(let level):
            switch level {
            case .critical: return 90
            case .warning: return 60
            case .normal: return 0
            }
        case .storageLow:
            switch severity {
            case .critical: return 80
            case .warning: return 50
            case .notice: return 40
            case .info: return 0
            }
        }
    }

    var proposedPetState: PetState? {
        switch kind {
        case .thermalPressure(let level):
            switch level {
            case .serious, .critical:
                return .sweating
            case .fair, .nominal:
                return nil
            }
        case .memoryPressure(let level):
            switch level {
            case .warning, .critical:
                return .tired
            case .normal:
                return nil
            }
        case .storageLow:
            switch severity {
            case .notice, .warning, .critical:
                return .carryingTrash
            case .info:
                return nil
            }
        }
    }
}
