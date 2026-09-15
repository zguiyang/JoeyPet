import Foundation

struct PetBehavior: Equatable, Sendable {
    let state: PetState
    let priority: Int
    let triggeringSignal: SystemSignalKind
    let decidedAt: Date
}
