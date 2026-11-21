import Foundation

/// V0 has no system-health reactions: Joey is a companion, not a Mac monitor.
enum PetState: String, Equatable, Sendable, CaseIterable, Codable { case idle }
