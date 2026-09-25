import Foundation
import OSLog

struct CleanupScanner: Sendable {
    private nonisolated static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "CleanupScanner")

    let homeURL: URL
    let oldLogAge: TimeInterval
    let now: Date

    nonisolated init(homeURL: URL = URL(fileURLWithPath: NSHomeDirectory()), oldLogAge: TimeInterval = 30 * 24 * 60 * 60, now: Date = Date()) {
        self.homeURL = homeURL.standardizedFileURL
        self.oldLogAge = oldLogAge
        self.now = now
    }

    func scan(
        requestedScope: CleanupScanScope = .deep,
        accessLevel: MacCareAccessLevel
    ) async -> CleanupScanResult {
        let homeURL = self.homeURL
        let oldLogAge = self.oldLogAge
        let now = self.now
        let routing = MacCareCapability.effectiveCleanupScanScope(requested: requestedScope, accessLevel: accessLevel)
        let appliedScope = routing.scope
        let deepScanDeferred = routing.deepScanDeferred
        return await Task.detached(priority: .utility) {
            Self.performScan(
                homeURL: homeURL,
                oldLogAge: oldLogAge,
                now: now,
                requestedScope: requestedScope,
                appliedScope: appliedScope,
                deepScanDeferred: deepScanDeferred,
                accessLevel: accessLevel
            )
        }.value
    }

    /// Backward-compatible entry for baseline-only scans (tests and Quick Clean allowlist).
    func scanBaseline(accessLevel: MacCareAccessLevel = .limited) async -> CleanupScanResult {
        await scan(requestedScope: .baseline, accessLevel: accessLevel)
    }

    nonisolated static func allowedRoots(homeURL: URL) -> [URL] {
        [
            homeURL.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true),
            homeURL.appendingPathComponent("Library/Logs", isDirectory: true),
            homeURL.appendingPathComponent("Library/Caches", isDirectory: true)
        ]
    }

    nonisolated static func isSafeCandidate(_ candidate: URL, inside root: URL) -> Bool {
        let root = root.standardizedFileURL.resolvingSymlinksInPath()
        let candidateURL = candidate.standardizedFileURL
        guard candidateURL != root else { return false }
        guard let values = try? candidateURL.resourceValues(forKeys: [.isSymbolicLinkKey]),
              values.isSymbolicLink != true else { return false }
        let resolved = candidateURL.resolvingSymlinksInPath()
        return resolved.path.hasPrefix(root.path + "/")
    }

    private nonisolated static func performScan(
        homeURL: URL,
        oldLogAge: TimeInterval,
        now: Date,
        requestedScope: CleanupScanScope,
        appliedScope: CleanupScanScope,
        deepScanDeferred: Bool,
        accessLevel: MacCareAccessLevel
    ) -> CleanupScanResult {
        logger.info("Cleanup scan started")
        MacCareCapability.logScannerScope(
            requested: requestedScope,
            applied: appliedScope,
            accessLevel: accessLevel
        )
        let fileManager = FileManager.default
        let roots = allowedRoots(homeURL: homeURL)
        var candidates: [CleanupCandidate] = []
        var skippedCount = 0

        let derivedDataRoot = roots[0]
        if fileManager.fileExists(atPath: derivedDataRoot.path) {
            let contents = contents(of: derivedDataRoot, fileManager: fileManager)
            for url in contents where isSafeCandidate(url, inside: derivedDataRoot) {
                guard let values = resourceValues(for: url), values.isDirectory == true else {
                    skippedCount += 1
                    continue
                }
                let directory = directorySize(url, fileManager: fileManager)
                candidates.append(CleanupCandidate(
                    id: url.standardizedFileURL.path,
                    url: url,
                    displayName: url.lastPathComponent,
                    size: directory.size,
                    category: .developerCache,
                    risk: .safe,
                    reason: "Xcode 需要时会重新生成，一般可以清理。",
                    lastModified: values.contentModificationDate,
                    sizeIsEstimated: !directory.isComplete
                ))
            }
        }

        let logsRoot = roots[1]
        if fileManager.fileExists(atPath: logsRoot.path) {
            let cutoff = now.addingTimeInterval(-oldLogAge)
            for url in recursiveContents(of: logsRoot, fileManager: fileManager, limit: 5_000) {
                guard candidates.count < 500,
                      isSafeCandidate(url, inside: logsRoot),
                      let values = resourceValues(for: url),
                      values.isDirectory != true,
                      values.isRegularFile == true,
                      let modified = values.contentModificationDate,
                      modified < cutoff else { continue }
                candidates.append(CleanupCandidate(
                    id: url.standardizedFileURL.path,
                    url: url,
                    displayName: url.lastPathComponent,
                    size: Int64(values.fileSize ?? 0),
                    category: .oldLogs,
                    risk: .review,
                    reason: "超过 30 天的日志，移入废纸篓前请先确认。",
                    lastModified: modified
                ))
            }
        }

        let cachesRoot = roots[2]
        if fileManager.fileExists(atPath: cachesRoot.path) {
            for url in contents(of: cachesRoot, fileManager: fileManager) where isSafeCandidate(url, inside: cachesRoot) {
                guard let values = resourceValues(for: url), values.isDirectory == true else { continue }
                let directory = directorySize(url, fileManager: fileManager)
                candidates.append(CleanupCandidate(
                    id: url.standardizedFileURL.path,
                    url: url,
                    displayName: url.lastPathComponent,
                    size: directory.size,
                    category: .applicationCaches,
                    risk: .review,
                    reason: "应用缓存可能正在使用，移入废纸篓前请先确认。",
                    lastModified: values.contentModificationDate,
                    sizeIsEstimated: !directory.isComplete
                ))
            }
        }

        if appliedScope == .deep {
            candidates.append(contentsOf: deepCleanupCandidates(homeURL: homeURL, fileManager: fileManager, skippedCount: &skippedCount))
        }

        logger.info("Cleanup scan finished: candidates=\(candidates.count, privacy: .public), skipped=\(skippedCount, privacy: .public)")
        return CleanupScanResult(
            candidates: candidates.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending },
            scannedAt: now,
            skippedCount: skippedCount,
            requestedScope: requestedScope,
            appliedScope: appliedScope,
            deepScanDeferred: deepScanDeferred
        )
    }

    /// FDA-gated deep scan roots (application leftovers, containers). Extended incrementally.
    private nonisolated static func deepCleanupCandidates(
        homeURL: URL,
        fileManager: FileManager,
        skippedCount: inout Int
    ) -> [CleanupCandidate] {
        _ = homeURL
        _ = fileManager
        _ = skippedCount
        return []
    }

    private nonisolated static func contents(of url: URL, fileManager: FileManager) -> [URL] {
        (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: resourceKeys, options: [])) ?? []
    }

    private nonisolated static func recursiveContents(of url: URL, fileManager: FileManager, limit: Int = .max) -> [URL] {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: resourceKeys, options: []) else { return [] }
        var urls: [URL] = []
        for case let child as URL in enumerator {
            if urls.count >= limit { break }
            if let values = try? child.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink == true {
                enumerator.skipDescendants()
            }
            urls.append(child)
        }
        return urls
    }

    private nonisolated static let resourceKeys: [URLResourceKey] = [
        .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .totalFileSizeKey, .contentModificationDateKey
    ]

    private nonisolated static func resourceValues(for url: URL) -> URLResourceValues? {
        try? url.resourceValues(forKeys: Set(resourceKeys))
    }

    private nonisolated static func directorySize(_ url: URL, fileManager: FileManager) -> (size: Int64, isComplete: Bool) {
        let children = contents(of: url, fileManager: fileManager)
        let maximumEntries = 256
        var total: Int64 = 0
        var isComplete = children.count <= maximumEntries
        for child in children.prefix(maximumEntries) {
            if let values = try? child.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink == true {
                continue
            }
            guard let values = resourceValues(for: child) else {
                isComplete = false
                continue
            }
            if values.isDirectory == true {
                isComplete = false
            } else if values.isRegularFile == true {
                total += Int64(values.fileSize ?? values.totalFileSize ?? 0)
            }
        }
        return (total, isComplete)
    }
}
