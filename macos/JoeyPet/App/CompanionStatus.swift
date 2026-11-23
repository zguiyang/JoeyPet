import Foundation
import Observation

/// Observable snapshot the nest window reads to reflect the running session.
/// `PetRuntime` remains the source of truth; this type only mirrors it.
@Observable
@MainActor
final class CompanionStatus {
    private(set) var situation = PetSituation()
    private(set) var summary: CompanionSummary = .empty

    var isSessionActive: Bool { situation.session != nil }
    var sessionStartedAt: Date? { situation.session?.startedAt }

    func update(situation: PetSituation, summary: CompanionSummary) {
        self.situation = situation
        self.summary = summary
    }
}
