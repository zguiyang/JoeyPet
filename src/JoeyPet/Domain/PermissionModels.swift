import Foundation

/// Product-facing permission capabilities. Authorization flows are added per capability over time.
enum PermissionCapability: String, CaseIterable, Sendable {
    case fullDiskAccess
    case notifications
}

/// Best-effort Full Disk Access capability inferred from read-only probes (not TCC database state).
enum FullDiskAccessStatus: String, Sendable, Equatable {
    case unknown
    case notGranted
    case granted
}

/// Mac Care depth derived from FDA capability. Conservative when FDA is unknown.
enum MacCareAccessLevel: String, Sendable, Equatable {
    case limited
    case full
}

enum CleanupScanScope: String, Sendable, Equatable {
    /// V1 allowlisted cleanup roots only.
    case baseline
    /// Full Mac Care scan pipeline (baseline today; deep roots added incrementally).
    case deep
}

enum FullDiskAccessProbeFailureKind: String, Sendable, Equatable {
    case permissionDenied
    case pathMissing
    case unexpected
}

struct FullDiskAccessProbeAttempt: Sendable, Equatable {
    let canaryLabel: String
    let failureKind: FullDiskAccessProbeFailureKind?
}

struct FullDiskAccessProbeOutcome: Sendable, Equatable {
    let status: FullDiskAccessStatus
    let attempts: [FullDiskAccessProbeAttempt]

    var primaryFailureKind: FullDiskAccessProbeFailureKind? {
        attempts.compactMap(\.failureKind).first
    }
}
