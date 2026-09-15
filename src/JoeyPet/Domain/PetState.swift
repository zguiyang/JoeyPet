import Foundation

enum PetState: String, Equatable, Sendable, CaseIterable, Codable {
    case idle
    case sweating
    case tired
    case carryingTrash
}
