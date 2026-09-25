import Foundation
import OSLog

/// Best-effort, bounded storage category estimation for the boot volume user domain.
/// Does not replicate macOS System Settings storage breakdown.
enum StorageCategoryEstimator: Sendable {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "StorageCategoryEstimator")

    struct Result: Sendable {
        let categories: [StorageCategorySize]
    }

    static func estimate(homeURL: URL = URL(fileURLWithPath: NSHomeDirectory())) async -> Result {
        await Task.detached(priority: .utility) {
            estimateSync(homeURL: homeURL)
        }.value
    }

    private static func estimateSync(homeURL: URL) -> Result {
        let fileManager = FileManager.default
        var partial = false

        let applications = estimateApplications(fileManager: fileManager, homeURL: homeURL, partial: &partial)
        let developer = estimateDirectoryRoots(
            [
                homeURL.appendingPathComponent("Library/Developer", isDirectory: true),
                homeURL.appendingPathComponent("Library/Caches", isDirectory: true),
            ],
            fileManager: fileManager,
            partial: &partial
        )
        let media = estimateDirectoryRoots(
            [
                homeURL.appendingPathComponent("Pictures", isDirectory: true),
                homeURL.appendingPathComponent("Movies", isDirectory: true),
                homeURL.appendingPathComponent("Music", isDirectory: true),
            ],
            fileManager: fileManager,
            partial: &partial
        )

        let categories = [
            StorageCategorySize(category: .applications, bytes: applications, isEstimatePartial: partial),
            StorageCategorySize(category: .developer, bytes: developer, isEstimatePartial: partial),
            StorageCategorySize(category: .media, bytes: media, isEstimatePartial: partial),
        ].filter { $0.bytes > 0 }

        Self.logger.info("Storage category estimate finished (partial=\(partial))")
        return Result(categories: categories)
    }

    private static func estimateApplications(
        fileManager: FileManager,
        homeURL: URL,
        partial: inout Bool
    ) -> Int64 {
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            homeURL.appendingPathComponent("Applications", isDirectory: true),
        ]
        var total: Int64 = 0
        for root in roots where fileManager.fileExists(atPath: root.path) {
            total += sumApplicationBundles(in: root, fileManager: fileManager, partial: &partial)
        }
        return total
    }

    private static func sumApplicationBundles(
        in directory: URL,
        fileManager: FileManager,
        partial: inout Bool
    ) -> Int64 {
        guard let children = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            partial = true
            return 0
        }

        var total: Int64 = 0
        let limit = 400
        for child in children.prefix(limit) {
            guard child.pathExtension == "app" else { continue }
            let size = allocatedSize(of: child, partial: &partial)
            total += size
        }
        if children.count > limit { partial = true }
        return total
    }

    private static func estimateDirectoryRoots(
        _ roots: [URL],
        fileManager: FileManager,
        partial: inout Bool
    ) -> Int64 {
        var total: Int64 = 0
        for root in roots where fileManager.fileExists(atPath: root.path) {
            total += boundedDirectorySize(root, fileManager: fileManager, partial: &partial)
        }
        return total
    }

    private static func boundedDirectorySize(
        _ root: URL,
        fileManager: FileManager,
        partial: inout Bool,
        maxEntries: Int = 2_000,
        maxDepth: Int = 4
    ) -> Int64 {
        var total: Int64 = 0
        var visited = 0

        func walk(_ url: URL, depth: Int) {
            guard depth <= maxDepth, visited < maxEntries else {
                partial = true
                return
            }
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                partial = true
                return
            }
            for case let fileURL as URL in enumerator {
                visited += 1
                if visited >= maxEntries {
                    partial = true
                    break
                }
                if let values = try? fileURL.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink == true {
                    enumerator.skipDescendants()
                    continue
                }
                guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey]) else {
                    partial = true
                    continue
                }
                if values.isDirectory == true { continue }
                if values.isRegularFile == true {
                    total += allocatedSize(of: fileURL, partial: &partial)
                }
            }
        }

        walk(root, depth: 0)
        return total
    }

    private static func allocatedSize(of url: URL, partial: inout Bool) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) else {
            partial = true
            return 0
        }
        if let allocated = values.totalFileAllocatedSize {
            return Int64(allocated)
        }
        if let size = values.fileSize {
            return Int64(size)
        }
        partial = true
        return 0
    }
}
