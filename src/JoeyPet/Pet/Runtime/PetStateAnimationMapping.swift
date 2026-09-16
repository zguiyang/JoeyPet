import Foundation

enum PetStateAnimationMapping {
    static func animationID(for state: PetState) -> String {
        switch state {
        case .idle:
            return "idle"
        case .sweating:
            return "sweating"
        case .tired:
            return "tired"
        case .carryingTrash:
            return "carryingTrash"
        }
    }
}
