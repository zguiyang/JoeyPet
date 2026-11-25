import Foundation

enum PetTransientBehavior: String, Equatable, Sendable, CaseIterable {
    case blink
    case sleeping
    case celebrating
    case notifying
    /// One short response when the user taps the nest.
    case greeting
    /// Quiet-room ear groom while alone on `sit`.
    case grooming

    var animationID: String {
        rawValue
    }

    /// Ambient clips yield immediately to higher-priority situation poses.
    /// Product moments (`greeting`, …) finish unless a hard interrupt hits.
    var isAmbient: Bool {
        switch self {
        case .grooming, .sleeping, .blink:
            return true
        case .greeting, .celebrating, .notifying:
            return false
        }
    }

    /// Looping transient clips need a finite session so they can return to the
    /// underlying state. This is behavior cadence, not clip frame rate.
    var sessionDuration: TimeInterval? {
        switch self {
        case .greeting:
            return 2.8
        case .grooming:
            return 2.8
        case .sleeping:
            return 18
        case .blink, .celebrating, .notifying:
            return nil
        }
    }
}
