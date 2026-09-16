import Foundation

enum SignalSeverity: Int, Comparable, Sendable, Codable {
    case normal = 0
    case notice = 1
    case warning = 2
    case critical = 3

    /// Compatibility spelling for existing sensor fixtures. Product UI uses
    /// `normal` so system status and pet status share one vocabulary.
    static let info = SignalSeverity.normal

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .notice: return "Notice"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }

    var isActionable: Bool { self >= .notice }


    static func < (lhs: SignalSeverity, rhs: SignalSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
