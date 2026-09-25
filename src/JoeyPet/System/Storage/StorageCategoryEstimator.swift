import Foundation
import OSLog

/// Best-effort, bounded storage category estimation for the boot volume user domain.
/// Does not replicate macOS System Settings storage breakdown.
enum StorageCategoryEstimator: Sendable {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "StorageCategoryEstimator")

    struct Result: Sendable {
        let categories: [StorageCategorySize]
        let classificationDepth: StorageClassificationDepth
    }

    static func estimate(
        accessLevel: MacCareAccessLevel,
        homeURL: URL = URL(fileURLWithPath: NSHomeDirectory())
    ) async -> Result {
        let depth = MacCareCapability.storageClassificationDepth(accessLevel: accessLevel)
        return await Task.detached(priority: .utility) {
            estimateSync(homeURL: homeURL, depth: depth)
        }.value
    }

    private static func estimateSync(homeURL: URL, depth: StorageClassificationDepth) -> Result {
        let fileManager = FileManager.default
        var partial = false

        let applications = estimateApplications(fileManager: fileManager, homeURL: homeURL, partial: &partial)

        let developerRoots = developerRoots(homeURL: homeURL, depth: depth)
        let developer = estimateDirectoryRoots(developerRoots, fileManager: fileManager, partial: &partial)

        var media: Int64 = 0
        if depth == .full {
            media = estimateDirectoryRoots(
                [
                    homeURL.appendingPathComponent("Pictures", isDirectory: true),
                    homeURL.appendingPathComponent("Movies", isDirectory: true),
                    homeURL.appendingPathComponent("Music", isDirectory: true),
                ],
                fileManager: fileManager,
                partial: &partial
            )
        }

        var categories = [
            StorageCategorySize(category: .applications, bytes: applications, isEstimatePartial: partial),
            StorageCategorySize(category: .developer, bytes: developer, isEstimatePartial: partial),
        ]
        if depth == .full {
            categories.append(StorageCategorySize(category: .media, bytes: media, isEstimatePartial: partial))
        }
        categories = categories.filter { $0.bytes > 0 }

        Self.logger.info(
            "Storage category estimate finished depth=\(depth.rawValue, privacy: .public) partial=\(partial)"
        )
        return Result(categories: categories, classificationDepth: depth)
    }

    private static func developerRoots(homeURL: URL, depth: StorageClassificationDepth) -> [URL] {
        var roots = [
            homeURL.appendingPathComponent("Library/Developer", isDirectory: true),
            homeURL.appendingPathComponent("Library/Caches", isDirectory: true),
        ]
        if depth == .full {
            roots.append(contentsOf: [
                homeURL.appendingPathComponent("Library/Containers", isDirectory: true),
                homeURL.appendingPathComponent("Library/Group Containers", isDirectory: true),
                homeURL.appendingPathComponent("Library/Application Support", isDirectory: true),
            ])
        }
        return roots
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
