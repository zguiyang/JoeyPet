import Foundation

enum CleanupCategory: String, CaseIterable, Codable, Sendable {
    case developerCache
    case oldLogs
    case applicationCaches

    var displayName: String {
        switch self {
        case .developerCache: return "Developer Caches"
        case .oldLogs: return "Old Logs"
        case .applicationCaches: return "Application Caches"
        }
    }
}

enum CleanupRisk: String, CaseIterable, Codable, Sendable {
    case safe
    case review

    var displayName: String {
        switch self {
        case .safe: return "Safe"
        case .review: return "Review"
        }
    }
}

struct CleanupCandidate: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let displayName: String
    let size: Int64
    let category: CleanupCategory
    let risk: CleanupRisk
    let reason: String
    let lastModified: Date?
    let sizeIsEstimated: Bool

    nonisolated init(id: String, url: URL, displayName: String, size: Int64, category: CleanupCategory, risk: CleanupRisk, reason: String, lastModified: Date?, sizeIsEstimated: Bool = false) {
        self.id = id
        self.url = url
        self.displayName = displayName
        self.size = size
        self.category = category
        self.risk = risk
        self.reason = reason
        self.lastModified = lastModified
        self.sizeIsEstimated = sizeIsEstimated
    }
}

struct CleanupScanResult: Sendable {
    let candidates: [CleanupCandidate]
    let scannedAt: Date
    let skippedCount: Int
    let requestedScope: CleanupScanScope
    let appliedScope: CleanupScanScope
    let deepScanDeferred: Bool

    nonisolated init(
        candidates: [CleanupCandidate],
        scannedAt: Date,
        skippedCount: Int,
        requestedScope: CleanupScanScope = .baseline,
        appliedScope: CleanupScanScope? = nil,
        deepScanDeferred: Bool = false
    ) {
        self.candidates = candidates
        self.scannedAt = scannedAt
        self.skippedCount = skippedCount
        self.requestedScope = requestedScope
        self.appliedScope = appliedScope ?? requestedScope
        self.deepScanDeferred = deepScanDeferred
    }

    nonisolated var totalSize: Int64 { candidates.reduce(0) { $0 + $1.size } }
    nonisolated var safeCandidates: [CleanupCandidate] { candidates.filter { $0.risk == .safe } }
    nonisolated var reviewCandidates: [CleanupCandidate] { candidates.filter { $0.risk == .review } }
    nonisolated var quickCleanCandidates: [CleanupCandidate] { safeCandidates }
    nonisolated var safeSize: Int64 { safeCandidates.reduce(0) { $0 + $1.size } }
    nonisolated var reviewSize: Int64 { reviewCandidates.reduce(0) { $0 + $1.size } }
}

struct CleanupItemResult: Sendable {
    let candidate: CleanupCandidate
    let succeeded: Bool
    let message: String

    nonisolated init(candidate: CleanupCandidate, succeeded: Bool, message: String) {
        self.candidate = candidate
        self.succeeded = succeeded
        self.message = message
    }
}

struct CleanupExecutionResult: Sendable {
    let items: [CleanupItemResult]
    let finishedAt: Date

    nonisolated init(items: [CleanupItemResult], finishedAt: Date) {
        self.items = items
        self.finishedAt = finishedAt
    }

    nonisolated var succeededItems: [CleanupItemResult] { items.filter(\.succeeded) }
    nonisolated var failedItems: [CleanupItemResult] { items.filter { !$0.succeeded } }
    nonisolated var succeededCount: Int { succeededItems.count }
    nonisolated var failedCount: Int { failedItems.count }
    nonisolated var movedBytes: Int64 { succeededItems.reduce(0) { $0 + $1.candidate.size } }
}

struct CleanupExecutionSummary: Codable, Equatable, Sendable {
    let finishedAt: Date
    let succeededCount: Int
    let failedCount: Int
    let movedBytes: Int64

    nonisolated init(finishedAt: Date, succeededCount: Int, failedCount: Int, movedBytes: Int64) {
        self.finishedAt = finishedAt
        self.succeededCount = succeededCount
        self.failedCount = failedCount
        self.movedBytes = movedBytes
    }

    nonisolated init(execution: CleanupExecutionResult) {
        self.finishedAt = execution.finishedAt
        self.succeededCount = execution.succeededCount
        self.failedCount = execution.failedCount
        self.movedBytes = execution.movedBytes
    }
}
