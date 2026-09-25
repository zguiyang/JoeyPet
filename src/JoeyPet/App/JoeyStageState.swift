import Combine
import Foundation
import SwiftUI

struct JoeyStageSnapshot: Equatable, Sendable {
    var petState: PetState
    var transientBehavior: PetTransientBehavior?
    var overallSeverity: SignalSeverity

    static let initial = JoeyStageSnapshot(petState: .idle, transientBehavior: nil, overallSeverity: .normal)
}

/// Read-only mirror of desktop pet state for the main-window Joey Stage (separate renderer).
@MainActor
final class JoeyStageState: ObservableObject {
    @Published private(set) var snapshot: JoeyStageSnapshot = .initial

    func apply(_ snapshot: JoeyStageSnapshot) {
        guard self.snapshot != snapshot else { return }
        self.snapshot = snapshot
    }
}
