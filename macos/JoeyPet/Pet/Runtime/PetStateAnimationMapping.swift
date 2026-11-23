import Foundation

/// Compatibility mapping for the legacy spritesheet fallback only.
///
/// The layered renderer consumes `PetPose` ids directly; this enum exists so a
/// missing V0.1 asset package can still render the closest old clip.
enum PetStateAnimationMapping {
    static func animationID(for state: PetState) -> String {
        "idle"
    }

    static func animationID(for pose: PetPose) -> String {
        switch pose {
        case .sign:
            return "notifying"
        case .happy:
            return "celebrating"
        case .sleep, .doze:
            return "sleeping"
        case .step:
            return "walking"
        case .sit, .look, .stretch, .groom, .yawn, .peek, .carry:
            return "idle"
        }
    }
}
