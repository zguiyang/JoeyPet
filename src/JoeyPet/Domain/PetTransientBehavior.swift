import Foundation

enum PetTransientBehavior: String, Equatable, Sendable, CaseIterable {
    case blink
    case walking
    case sleeping
    case cleaning
    case celebrating
    case notifying

    var animationID: String {
        rawValue
    }

    var isAmbient: Bool {
        switch self {
        case .blink, .walking, .sleeping:
            return true
        case .cleaning, .celebrating, .notifying:
            return false
        }
    }

    /// Looping transient clips need a finite session so they can return to the
    /// underlying state. This is behavior cadence, not clip frame rate.
    var sessionDuration: TimeInterval? {
        switch self {
        case .walking:
            return 2
        case .cleaning:
            return 5
        case .sleeping:
            return 18
        case .blink, .celebrating, .notifying:
            return nil
        }
    }
}
