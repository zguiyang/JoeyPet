import Foundation

struct VolumeCapacitySnapshot: Sendable, Equatable {
    let totalBytes: Int64
    let availableBytes: Int64

    var usedBytes: Int64 { max(totalBytes - availableBytes, 0) }
}

struct StorageAccountingBreakdown: Sendable, Equatable {
    let volumeUsedBytes: Int64
    let scannedAllocatedBytes: Int64
    let classifiedBytes: Int64
    let otherFilesBytes: Int64
    /// `max(volumeUsed - scannedAllocated, 0)` — not a filesystem category.
    let accountingGap: Int64
    /// When scanned exceeds volume used (duplicate accounting bug signal).
    let scanOverrunBytes: Int64
}

enum StorageAccounting: Sendable {
    static func breakdown(
        volume: VolumeCapacitySnapshot,
        categoryBytes: [StorageCompositionCategory: Int64],
        scannedAllocatedBytes: Int64
    ) -> StorageAccountingBreakdown {
        let filesystemCategories = categoryBytes.filter { key, _ in
            key.isUsedBucket && key != .systemReserved && key != .other && key != .otherFiles
        }
        let classified = filesystemCategories.values.reduce(Int64(0), +)
        let otherFiles = categoryBytes[.otherFiles, default: 0]

        let gap: Int64
        let overrun: Int64
        if scannedAllocatedBytes > volume.usedBytes {
            gap = 0
            overrun = scannedAllocatedBytes - volume.usedBytes
        } else {
            gap = volume.usedBytes - scannedAllocatedBytes
            overrun = 0
        }

        return StorageAccountingBreakdown(
            volumeUsedBytes: volume.usedBytes,
            scannedAllocatedBytes: scannedAllocatedBytes,
            classifiedBytes: classified,
            otherFilesBytes: otherFiles,
            accountingGap: gap,
            scanOverrunBytes: overrun
        )
    }

    /// Invariant: classified categories + Other Files ≈ scanned allocated bytes.
    static func validateCategorySum(
        categoryBytes: [StorageCompositionCategory: Int64],
        scannedAllocatedBytes: Int64,
        toleranceBytes: Int64 = 8
    ) -> Bool {
        let sum = categoryBytes
            .filter { $0.key.isUsedBucket && $0.key != .systemReserved && $0.key != .other }
            .map(\.value)
            .reduce(Int64(0), +)
        return abs(sum - scannedAllocatedBytes) <= toleranceBytes
    }
}
