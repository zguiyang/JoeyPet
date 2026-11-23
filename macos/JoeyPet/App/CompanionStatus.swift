import Foundation
import Observation

/// Observable snapshot the nest window reads to reflect the running session.
/// `PetRuntime` remains the source of truth; this type only mirrors it.
@Observable
@MainActor
final class CompanionStatus {
    private(set) var situation = PetSituation()
    private(set) var summary: CompanionSummary = .empty
    /// The pose the desktop renderer is actually showing. The nest mirrors this
    /// value, transients included, so both surfaces always agree.
    private(set) var pose: PetPose = .sit

    var isSessionActive: Bool { situation.session != nil }
    var sessionStartedAt: Date? { situation.session?.startedAt }

    func update(pose: PetPose) {
        self.pose = pose
    }

    func update(situation: PetSituation, summary: CompanionSummary) {
        self.situation = situation
        self.summary = summary
    }
}
