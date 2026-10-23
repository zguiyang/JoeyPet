import Foundation
import OSLog

/// Storage Analyzer V3 orchestrator (filesystem scan → classify → account).
enum StorageAnalyzer: Sendable {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "StorageAnalyzer")

    struct Result: Sendable {
        let snapshot: DiskScanSnapshot
        let categoryBytes: [StorageCompositionCategory: Int64]
        let topLevelBytes: [String: Int64]
        let otherFilesBySource: [String: Int64]
        let accounting: StorageAccountingBreakdown
        let volume: VolumeCapacitySnapshot
        let scanState: StorageAnalyzerScanState
        let composition: StorageComposition?
    }

    struct Progress: Sendable {
        let categories: [StorageCategorySize]
        let filesScanned: Int
    }

    typealias ProgressHandler = @Sendable (Progress) -> Void

    /// Cancellation shared by the MainActor caller and utility-queue traversal.
    nonisolated private final class CancellationFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }

        func cancel() {
            lock.lock()
            cancelled = true
            lock.unlock()
        }
    }

    static func analyze(
        fullDiskAccessStatus: FullDiskAccessStatus,
        homeURL: URL = URL(fileURLWithPath: NSHomeDirectory()),
        volumeURL: URL = URL(fileURLWithPath: NSHomeDirectory()),
        onProgress: ProgressHandler? = nil
    ) async -> Result {
        logger.info(
            "Storage runtime FDA=\(fullDiskAccessStatus.rawValue, privacy: .public) access=\(MacCareCapability.accessLevel(fullDiskAccessStatus: fullDiskAccessStatus).rawValue, privacy: .public)"
        )
        // Entry gate only — classification/scan algorithms run only after explicit FDA grant.
        guard MacCareCapability.allowsProtectedStorageWork(fullDiskAccessStatus: fullDiskAccessStatus) else {
            return failedResult(reason: "Full Disk Access required for Storage Analyzer V3")
        }

        guard let volume = readVolumeCapacity(volumeURL: volumeURL) else {
            return failedResult(reason: "Unable to read boot volume capacity")
        }

        let cancellation = CancellationFlag()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    // GCD's global utility queue keeps traversal off MainActor and the main thread.
                    let result = analyzeSync(
                        homeURL: homeURL,
                        volume: volume,
                        isCancelled: { cancellation.isCancelled },
                        onProgress: onProgress
                    )
                    continuation.resume(returning: result)
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    private static func analyzeSync(
        homeURL: URL,
        volume: VolumeCapacitySnapshot,
        isCancelled: @escaping @Sendable () -> Bool,
        onProgress: ProgressHandler?
    ) -> Result {
        assert(!Thread.isMainThread, "Storage filesystem traversal must never run on the main thread")
        logger.info("Storage traversal started isMainThread=\(Thread.isMainThread, privacy: .public)")
        if isCancelled() {
            return cancelledResult(volume: volume)
        }

        let scope = ScanRootResolver.bootDataScope(homeURL: homeURL)
        let firmlinks = APFSFirmlinkCatalog.firmlinkSourcePaths()
        let config = DiskTreeScanner.Configuration(
            scope: scope,
            firmlinkSources: firmlinks,
            homeURL: homeURL,
            retainRecords: false
        )

        var categoryBytes: [StorageCompositionCategory: Int64] = [:]
        var topLevelBytes: [String: Int64] = [:]
        var otherFilesBySource: [String: Int64] = [:]
        var processedFiles = 0
        var lastPublishedFiles = 0
        var lastProgressAt = Date()
        let classifierContext = StorageClassifier.makeContext(homeURL: homeURL)
        let snapshot = DiskTreeScanner.scan(configuration: config, isCancelled: isCancelled) { record in
            let category = StorageClassifier.category(for: record, context: classifierContext)
            categoryBytes[category, default: 0] += record.allocatedBytes
            let canonicalPath = canonicalDataPath(record.absolutePath)
            let topLevel = canonicalPath.split(separator: "/").first.map(String.init) ?? "(root)"
            topLevelBytes["/\(topLevel)", default: 0] += record.allocatedBytes
            let canonicalHome = canonicalDataPath(homeURL.standardizedFileURL.path)
            if canonicalPath == canonicalHome || canonicalPath.hasPrefix(canonicalHome + "/") {
                topLevelBytes["/Users/Current User Home", default: 0] += record.allocatedBytes
            }
            if category == .otherFiles {
                let source = privacySafeSourceGroup(
                    for: canonicalPath,
                    homePath: homeURL.standardizedFileURL.path
                )
                otherFilesBySource[source, default: 0] += record.allocatedBytes
            }

            processedFiles += 1
            if processedFiles % 4_096 == 0 {
                let now = Date()
                if processedFiles - lastPublishedFiles >= 10_000
                    || now.timeIntervalSince(lastProgressAt) >= 2
                {
                    let readyCategories = categoryBytes
                        .filter { $0.key != .otherFiles && $0.value > 0 }
                        .map { StorageCategorySize(category: $0.key, bytes: $0.value, isEstimatePartial: true) }
                    onProgress?(Progress(
                        categories: StorageCompositionBuilder.sortForPresentation(readyCategories),
                        filesScanned: processedFiles
                    ))
                    lastPublishedFiles = processedFiles
                    lastProgressAt = now
                }
            }
        }

        if isCancelled() {
            return cancelledResult(volume: volume, snapshot: snapshot)
        }
        let accounting = StorageAccounting.breakdown(
            volume: volume,
            categoryBytes: categoryBytes,
            scannedAllocatedBytes: snapshot.scannedAllocatedBytes
        )

        let scanState: StorageAnalyzerScanState = {
            if snapshot.hadAccessDenied { return .completeWithLimitations }
            return .complete
        }()

        if !StorageAccounting.validateCategorySum(
            categoryBytes: categoryBytes,
            scannedAllocatedBytes: snapshot.scannedAllocatedBytes
        ) {
            logger.error("Storage accounting invariant failed: category sum != scanned bytes")
        }

        if accounting.scanOverrunBytes > 0 {
            logger.error(
                "Scanned bytes exceed volume used by \(accounting.scanOverrunBytes, privacy: .public) — investigate dedup"
            )
        }

        let composition = StorageCompositionBuilder.composeFromFilesystemAnalysis(
            totalBytes: volume.totalBytes,
            availableBytes: volume.availableBytes,
            categoryBytes: categoryBytes,
            scannedAllocatedBytes: snapshot.scannedAllocatedBytes,
            accountingGap: accounting.accountingGap,
            scanOverrunBytes: accounting.scanOverrunBytes,
            scanState: scanState
        )

        return Result(
            snapshot: snapshot,
            categoryBytes: categoryBytes,
            topLevelBytes: topLevelBytes,
            otherFilesBySource: otherFilesBySource,
            accounting: accounting,
            volume: volume,
            scanState: scanState,
            composition: composition
        )
    }

    private static func readVolumeCapacity(volumeURL: URL) -> VolumeCapacitySnapshot? {
        guard let values = try? volumeURL.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeTotalCapacityKey,
        ]) else { return nil }
        let available = values.volumeAvailableCapacityForImportantUsage
            ?? values.volumeAvailableCapacity.map(Int64.init)
        guard let available, let total = values.volumeTotalCapacity else { return nil }
        return VolumeCapacitySnapshot(totalBytes: Int64(total), availableBytes: available)
    }

    private static func failedResult(reason: String) -> Result {
        logger.error("\(reason, privacy: .public)")
        let emptySnapshot = DiskScanSnapshot(
            scanRoot: URL(fileURLWithPath: "/"),
            records: [],
            stats: DiskScanAccessStats(),
            scannedAllocatedBytes: 0,
            duration: 0,
            hadAccessDenied: false
        )
        return Result(
            snapshot: emptySnapshot,
            categoryBytes: [:],
            topLevelBytes: [:],
            otherFilesBySource: [:],
            accounting: StorageAccountingBreakdown(
                volumeUsedBytes: 0,
                scannedAllocatedBytes: 0,
                classifiedBytes: 0,
                otherFilesBytes: 0,
                accountingGap: 0,
                scanOverrunBytes: 0
            ),
            volume: VolumeCapacitySnapshot(totalBytes: 0, availableBytes: 0),
            scanState: .failed,
            composition: nil
        )
    }

    private static func cancelledResult(
        volume: VolumeCapacitySnapshot,
        snapshot: DiskScanSnapshot? = nil
    ) -> Result {
        let snap = snapshot ?? DiskScanSnapshot(
            scanRoot: URL(fileURLWithPath: "/"),
            records: [],
            stats: DiskScanAccessStats(),
            scannedAllocatedBytes: 0,
            duration: 0,
            hadAccessDenied: false
        )
        return Result(
            snapshot: snap,
            categoryBytes: [:],
            topLevelBytes: [:],
            otherFilesBySource: [:],
            accounting: StorageAccounting.breakdown(
                volume: volume,
                categoryBytes: [:],
                scannedAllocatedBytes: snap.scannedAllocatedBytes
            ),
            volume: volume,
            scanState: .cancelled,
            composition: nil
        )
    }

    /// Text report for developer diagnostics from the stable JoeyPet Dev app workflow.
    static func formatDiagnosticReport(
        _ result: Result,
        fullDiskAccessStatus: FullDiskAccessStatus = .unknown
    ) -> String {
        var lines: [String] = []
        lines.append("JoeyPet Storage Analyzer V3 Diagnostic")
        lines.append("Pipeline: V3")
        lines.append("FullDiskAccessStatus: \(fullDiskAccessStatus.rawValue)")
        lines.append("MacCareAccessLevel: \(MacCareCapability.accessLevel(fullDiskAccessStatus: fullDiskAccessStatus).rawValue)")
        lines.append("Scan state: \(result.scanState.rawValue)")
        lines.append("Scan root: \(result.snapshot.scanRoot.path)")
        lines.append("Duration: \(String(format: "%.1f", result.snapshot.duration))s")
        lines.append("")
        lines.append("Volume total: \(result.volume.totalBytes)")
        lines.append("Volume available: \(result.volume.availableBytes)")
        lines.append("Volume used: \(result.accounting.volumeUsedBytes)")
        lines.append("Scanned allocated: \(result.accounting.scannedAllocatedBytes)")
        let scanCoverage = result.accounting.volumeUsedBytes > 0
            ? Double(result.accounting.scannedAllocatedBytes) / Double(result.accounting.volumeUsedBytes)
            : 0
        let classificationCoverage = result.accounting.scannedAllocatedBytes > 0
            ? Double(result.accounting.classifiedBytes) / Double(result.accounting.scannedAllocatedBytes)
            : 0
        lines.append("Scan coverage: \(String(format: "%.1f", scanCoverage * 100))%")
        lines.append("Classified filesystem bytes: \(result.accounting.classifiedBytes)")
        lines.append("Classification coverage: \(String(format: "%.1f", classificationCoverage * 100))%")
        lines.append("Accounting gap: \(result.accounting.accountingGap)")
        if result.accounting.scanOverrunBytes > 0 {
            lines.append("Scan overrun (BUG): \(result.accounting.scanOverrunBytes)")
        }
        lines.append("")
        let ordered: [StorageCompositionCategory] = [
            .applications, .applicationData, .developer, .caches,
            .documents, .photos, .videos, .audio, .archives,
            .systemFiles, .otherFiles, .systemReserved,
        ]
        for cat in ordered {
            if cat == .systemReserved {
                if result.accounting.accountingGap > 0 {
                    lines.append("\(cat.rawValue): \(result.accounting.accountingGap)")
                }
                continue
            }
            let bytes = result.categoryBytes[cat, default: 0]
            if bytes > 0 {
                lines.append("\(cat.rawValue): \(bytes)")
            }
        }
        lines.append("")
        lines.append("Top-level allocated bytes:")
        for (path, bytes) in result.topLevelBytes.sorted(by: { $0.value > $1.value }) {
            lines.append("\(path): \(bytes)")
        }
        lines.append("")
        lines.append("Other Files by source (paths grouped; filenames omitted):")
        for (path, bytes) in result.otherFilesBySource.sorted(by: { $0.value > $1.value }).prefix(20) {
            lines.append("\(path): \(bytes)")
        }
        lines.append("")
        lines.append("Files visited: \(result.snapshot.stats.visitedFiles)")
        lines.append("Directories visited: \(result.snapshot.stats.visitedDirectories)")
        lines.append("Access denied dirs: \(result.snapshot.stats.deniedDirectories)")
        lines.append("Hard link dedups: \(result.snapshot.stats.deduplicatedHardLinks)")
        lines.append("Dir identity dedups: \(result.snapshot.stats.deduplicatedDirectoryIdentities)")
        return lines.joined(separator: "\n")
    }

    private static func canonicalDataPath(_ path: String) -> String {
        let dataPrefix = "/System/Volumes/Data"
        guard path.hasPrefix(dataPrefix) else { return path }
        let suffix = path.dropFirst(dataPrefix.count)
        return suffix.isEmpty ? "/" : String(suffix)
    }

    private static func privacySafeSourceGroup(for path: String, homePath: String) -> String {
        var safePath = path
        if path == homePath || path.hasPrefix(homePath + "/") {
            safePath = "/Users/Current User Home" + String(path.dropFirst(homePath.count))
        }
        let components = safePath.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return "/" }
        let groupDepth = min(components.count, 4)
        return "/" + components.prefix(groupDepth).joined(separator: "/")
    }
}
