import Foundation

/// Lightweight storage breakdown for Mac Care Home. Not Apple “System Settings → Storage”.
enum StorageCompositionCategory: String, CaseIterable, Sendable, Equatable {
    case applications
    case developer
    case media
    case other
    case available

    var displayName: String {
        switch self {
        case .applications: return "应用程序"
        case .developer: return "开发者文件"
        case .media: return "媒体"
        case .other: return "其他"
        case .available: return "可用空间"
        }
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

    var usedCategories: [StorageCategorySize] {
        categories.filter { $0.category != .available && $0.bytes > 0 }
    }

    var availableCategory: StorageCategorySize? {
        categories.first { $0.category == .available }
    }
}

enum StorageCompositionBuilder {
    /// Merges volume totals with category estimates. Ensures used buckets sum ≤ usedBytes.
    static func compose(
        totalBytes: Int64,
        availableBytes: Int64,
        estimates: [StorageCategorySize]
    ) -> StorageComposition? {
        guard totalBytes > 0, availableBytes >= 0, availableBytes <= totalBytes else { return nil }

        let usedBytes = max(totalBytes - availableBytes, 0)
        var usedBuckets = estimates.filter { $0.category != .available && $0.bytes > 0 }
        var summed = usedBuckets.reduce(Int64(0)) { $0 + $1.bytes }

        if summed > usedBytes {
            usedBuckets = scaleDown(buckets: usedBuckets, to: usedBytes)
            summed = usedBytes
        }

        let otherBytes = max(usedBytes - summed, 0)
        if otherBytes > 0 {
            if let index = usedBuckets.firstIndex(where: { $0.category == .other }) {
                let existing = usedBuckets[index]
                usedBuckets[index] = StorageCategorySize(
                    category: .other,
                    bytes: existing.bytes + otherBytes,
                    isEstimatePartial: existing.isEstimatePartial
                )
            } else {
                usedBuckets.append(
                    StorageCategorySize(category: .other, bytes: otherBytes, isEstimatePartial: true)
                )
            }
        }

        let available = StorageCategorySize(
            category: .available,
            bytes: availableBytes,
            isEstimatePartial: false
        )

        var all = usedBuckets.sorted { $0.category.rawValue < $1.category.rawValue }
        all.append(available)

        return StorageComposition(
            totalBytes: totalBytes,
            availableBytes: availableBytes,
            usedBytes: usedBytes,
            categories: all,
            computedAt: Date()
        )
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
}
