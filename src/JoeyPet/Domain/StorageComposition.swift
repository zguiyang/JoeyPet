import Foundation

/// Lightweight storage breakdown for Mac Care Home. Not Apple “System Settings → Storage”.
enum StorageCompositionCategory: String, CaseIterable, Sendable, Equatable {
    case applications
    case applicationData
    case developer
    case documents
    case photos
    case videos
    case audio
    case caches
    case archives
    /// Classifier remainder: scanned filesystem bytes with no taxonomy match.
    case otherFiles
    /// Scanned macOS-owned paths (e.g. `/System`, system `/Library`).
    case systemFiles
    /// Volume used minus explainable scanned bytes (snapshots, purgeable, inaccessible, metadata).
    case systemReserved
    /// Legacy V2 bucket: classified remainder + volume gap (homepage until V3 wired).
    case other
    case available
    /// Transient UI bucket while classification is in progress (not part of final taxonomy).
    case analyzing

    var displayName: String {
        switch self {
        case .applications: return "应用程序"
        case .applicationData: return "应用数据"
        case .developer: return "开发者文件"
        case .documents: return "文档"
        case .photos: return "图片"
        case .videos: return "视频"
        case .audio: return "音频"
        case .caches: return "缓存"
        case .archives: return "归档"
        case .otherFiles: return "其他文件"
        case .systemFiles: return "系统文件"
        case .systemReserved: return "系统与保留空间"
        case .other: return "系统与其他"
        case .available: return "可用空间"
        case .analyzing: return "分析中"
        }
    }

    /// Stable legend / tie-break ordering (size descending applied first in UI).
    var semanticRank: Int {
        switch self {
        case .applications: return 0
        case .documents: return 1
        case .photos: return 2
        case .videos: return 3
        case .audio: return 4
        case .developer: return 5
        case .caches: return 6
        case .applicationData: return 7
        case .archives: return 8
        case .otherFiles: return 9
        case .systemFiles: return 10
        case .systemReserved: return 11
        case .other: return 12
        case .analyzing: return 13
        case .available: return 14
        }
    }

    var isUsedBucket: Bool {
        self != .available && self != .analyzing
    }
}

enum StorageClassificationStatus: String, Sendable, Equatable {
    case complete
    case completeWithLimitations
    case partial
    case cancelled
    case failed
}

/// Filesystem analyzer scan lifecycle (V3).
enum StorageAnalyzerScanState: String, Sendable, Equatable {
    case idle
    case scanning
    case complete
    case completeWithLimitations
    case partial
    case cancelled
    case failed
}

enum StorageAnalysisPipeline: String, Sendable, Equatable {
    case v2
    case v3

    static func selected(for accessLevel: MacCareAccessLevel) -> StorageAnalysisPipeline {
        accessLevel == .full ? .v3 : .v2
    }
}

struct StorageCategorySize: Equatable, Sendable {
    let category: StorageCompositionCategory
    let bytes: Int64
    /// True when estimation hit safety limits (partial directory walk).
    let isEstimatePartial: Bool
}

struct StorageComposition: Equatable, Sendable {
    let totalBytes: Int64
    let availableBytes: Int64
    let usedBytes: Int64
    let categories: [StorageCategorySize]
    let computedAt: Date
    let classificationStatus: StorageClassificationStatus
    /// V3: scanned allocated bytes divided by volume used bytes.
    let scanCoverage: Double
    /// V3: classified bytes divided by scanned allocated bytes.
    let classificationCoverage: Double

    var usedCategories: [StorageCategorySize] {
        categories.filter {
            ($0.category.isUsedBucket || $0.category == .analyzing) && $0.bytes > 0
        }
    }

    var availableCategory: StorageCategorySize? {
        categories.first { $0.category == .available }
    }
}

enum StorageCompositionBuilder {
    /// Merges volume totals with category estimates. Partial estimates keep the remainder as `.analyzing`.
    static func compose(
        totalBytes: Int64,
        availableBytes: Int64,
        estimates: [StorageCategorySize],
        includeSystemRemainder: Bool,
        classificationStatus: StorageClassificationStatus = .complete
    ) -> StorageComposition? {
        guard totalBytes > 0, availableBytes >= 0, availableBytes <= totalBytes else { return nil }

        let usedBytes = max(totalBytes - availableBytes, 0)
        var usedBuckets = estimates.filter { $0.category.isUsedBucket && $0.bytes > 0 }
        var summed = usedBuckets.reduce(Int64(0)) { $0 + $1.bytes }

        if summed > usedBytes {
            usedBuckets = scaleDown(buckets: usedBuckets, to: usedBytes)
            summed = usedBytes
        }

        if includeSystemRemainder {
            let otherBytes = max(usedBytes - summed, 0)
            if otherBytes > 0 {
                let unresolvedCategory: StorageCompositionCategory = classificationStatus == .complete
                    ? .other
                    : .analyzing
                if let index = usedBuckets.firstIndex(where: { $0.category == unresolvedCategory }) {
                    let existing = usedBuckets[index]
                    usedBuckets[index] = StorageCategorySize(
                        category: unresolvedCategory,
                        bytes: existing.bytes + otherBytes,
                        isEstimatePartial: existing.isEstimatePartial
                    )
                } else {
                    usedBuckets.append(
                        StorageCategorySize(
                            category: unresolvedCategory,
                            bytes: otherBytes,
                            isEstimatePartial: classificationStatus != .complete
                        )
                    )
                }
            }
        }

        let classifiedUsed = usedBuckets
            .filter { $0.category != .other && $0.category != .analyzing }
            .reduce(Int64(0)) { $0 + $1.bytes }
        let coverage = usedBytes > 0 ? min(Double(classifiedUsed) / Double(usedBytes), 1) : 0

        let available = StorageCategorySize(
            category: .available,
            bytes: availableBytes,
            isEstimatePartial: false
        )

        var all = sortForPresentation(usedBuckets)
        all.append(available)

        return StorageComposition(
            totalBytes: totalBytes,
            availableBytes: availableBytes,
            usedBytes: usedBytes,
            categories: all,
            computedAt: Date(),
            classificationStatus: classificationStatus,
            scanCoverage: 0,
            classificationCoverage: coverage
        )
    }

    /// In-progress scan: classified buckets + `.analyzing` for unclassified used bytes (never `.other`).
    static func composeScanning(
        totalBytes: Int64,
        availableBytes: Int64,
        estimates: [StorageCategorySize]
    ) -> StorageComposition? {
        guard totalBytes > 0, availableBytes >= 0, availableBytes <= totalBytes else { return nil }

        let usedBytes = max(totalBytes - availableBytes, 0)
        var usedBuckets = estimates.filter { $0.category.isUsedBucket && $0.bytes > 0 }
        var summed = usedBuckets.reduce(Int64(0)) { $0 + $1.bytes }
        if summed > usedBytes {
            usedBuckets = scaleDown(buckets: usedBuckets, to: usedBytes)
            summed = usedBytes
        }

        let pending = max(usedBytes - summed, 0)
        if pending > 0 {
            usedBuckets.append(
                StorageCategorySize(category: .analyzing, bytes: pending, isEstimatePartial: true)
            )
        }

        let classifiedUsed = usedBuckets.filter { $0.category != .analyzing }.reduce(Int64(0)) { $0 + $1.bytes }
        let coverage = usedBytes > 0 ? min(Double(classifiedUsed) / Double(usedBytes), 1) : 0

        let available = StorageCategorySize(
            category: .available,
            bytes: availableBytes,
            isEstimatePartial: false
        )
        var all = sortForPresentation(usedBuckets)
        all.append(available)

        return StorageComposition(
            totalBytes: totalBytes,
            availableBytes: availableBytes,
            usedBytes: usedBytes,
            categories: all,
            computedAt: Date(),
            classificationStatus: .partial,
            scanCoverage: 0,
            classificationCoverage: coverage
        )
    }

    static func sortForPresentation(_ buckets: [StorageCategorySize]) -> [StorageCategorySize] {
        buckets.sorted { lhs, rhs in
            if lhs.bytes != rhs.bytes { return lhs.bytes > rhs.bytes }
            return lhs.category.semanticRank < rhs.category.semanticRank
        }
    }

    /// Top used categories for compact legend (largest first), always including `.other` when present.
    static func legendCategories(from composition: StorageComposition, maxItems: Int = 6) -> [StorageCategorySize] {
        let used = composition.usedCategories
        guard !used.isEmpty else { return [] }

        var picked: [StorageCategorySize] = []
        if let other = used.first(where: { $0.category == .other }) {
            let nonOther = used.filter { $0.category != .other }
            picked.append(contentsOf: nonOther.prefix(max(0, maxItems - 1)))
            if picked.count < maxItems {
                picked.append(other)
            }
        } else {
            picked = Array(used.prefix(maxItems))
        }
        return sortForPresentation(picked)
    }

    private static func scaleDown(buckets: [StorageCategorySize], to cap: Int64) -> [StorageCategorySize] {
        guard cap > 0 else { return [] }
        let total = buckets.reduce(Int64(0)) { $0 + $1.bytes }
        guard total > cap else { return buckets }
        return buckets.map { bucket in
            let scaled = Int64((Double(bucket.bytes) / Double(total)) * Double(cap))
            return StorageCategorySize(
                category: bucket.category,
                bytes: max(scaled, 0),
                isEstimatePartial: true
            )
        }
    }

    static func fraction(of bytes: Int64, in total: Int64) -> Double {
        guard total > 0, bytes > 0 else { return 0 }
        return min(max(Double(bytes) / Double(total), 0), 1)
    }

    static func fractionOfUsed(_ bytes: Int64, usedBytes: Int64) -> Double {
        guard usedBytes > 0, bytes > 0 else { return 0 }
        return min(max(Double(bytes) / Double(usedBytes), 0), 1)
    }

    /// V3: classified filesystem categories + explicit `otherFiles` + `systemReserved` (no Used − Classified merge).
    static func composeFromFilesystemAnalysis(
        totalBytes: Int64,
        availableBytes: Int64,
        categoryBytes: [StorageCompositionCategory: Int64],
        scannedAllocatedBytes: Int64,
        accountingGap: Int64,
        scanOverrunBytes: Int64,
        scanState: StorageAnalyzerScanState
    ) -> StorageComposition? {
        guard totalBytes > 0, availableBytes >= 0, availableBytes <= totalBytes else { return nil }

        let usedBytes = max(totalBytes - availableBytes, 0)
        var usedBuckets: [StorageCategorySize] = categoryBytes
            .filter { $0.key.isUsedBucket && $0.value > 0 }
            .map { StorageCategorySize(category: $0.key, bytes: $0.value, isEstimatePartial: false) }

        if accountingGap > 0 {
            usedBuckets.append(
                StorageCategorySize(category: .systemReserved, bytes: accountingGap, isEstimatePartial: false)
            )
        }

        if scanOverrunBytes > 0 {
            usedBuckets.append(
                StorageCategorySize(
                    category: .otherFiles,
                    bytes: scanOverrunBytes,
                    isEstimatePartial: true
                )
            )
        }

        usedBuckets = sortForPresentation(usedBuckets)
        let classifiedBytes = categoryBytes
            .filter {
                $0.key.isUsedBucket
                    && $0.key != .systemReserved
                    && $0.key != .other
                    && $0.key != .otherFiles
            }
            .values
            .reduce(Int64(0), +)
        let scanCoverage = usedBytes > 0 ? min(Double(scannedAllocatedBytes) / Double(usedBytes), 1) : 0
        let classificationCoverage = scannedAllocatedBytes > 0
            ? min(Double(classifiedBytes) / Double(scannedAllocatedBytes), 1)
            : 0

        let classificationStatus: StorageClassificationStatus = {
            switch scanState {
            case .complete: return .complete
            case .completeWithLimitations: return .completeWithLimitations
            case .partial: return .partial
            case .cancelled: return .partial
            case .failed: return .failed
            case .idle, .scanning: return .partial
            }
        }()

        var all = usedBuckets
        all.append(
            StorageCategorySize(category: .available, bytes: availableBytes, isEstimatePartial: false)
        )

        return StorageComposition(
            totalBytes: totalBytes,
            availableBytes: availableBytes,
            usedBytes: usedBytes,
            categories: all,
            computedAt: Date(),
            classificationStatus: classificationStatus,
            scanCoverage: scanCoverage,
            classificationCoverage: classificationCoverage
        )
    }
}
