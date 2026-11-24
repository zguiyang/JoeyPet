import Foundation

enum PetTransientBehavior: String, Equatable, Sendable, CaseIterable {
    case blink
    case carrying
    case sleeping
    case celebrating
    case notifying
    /// One short response when the user taps the nest.
    case greeting

    var animationID: String {
        rawValue
    }

    /// Looping transient clips need a finite session so they can return to the
    /// underlying state. This is behavior cadence, not clip frame rate.
    var sessionDuration: TimeInterval? {
        switch self {
        case .carrying:
            return 3.6
        case .greeting:
            return 2.8
        case .sleeping:
            return 18
        case .blink, .celebrating, .notifying:
            return nil
        }
    }
}
