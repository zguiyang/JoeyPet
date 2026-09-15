import Foundation

enum SensorThresholds {
    static let storageWarningBytes: Int64 = 10 * 1_024 * 1_024 * 1_024
    static let storageCriticalBytes: Int64 = 5 * 1_024 * 1_024 * 1_024
    static let storagePollInterval: TimeInterval = 60
}
