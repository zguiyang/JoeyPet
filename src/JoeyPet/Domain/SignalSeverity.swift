import Foundation

enum SignalSeverity: Int, Comparable, Sendable, Codable {
    case info = 0
    case notice = 1
    case warning = 2
    case critical = 3

    static func < (lhs: SignalSeverity, rhs: SignalSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
