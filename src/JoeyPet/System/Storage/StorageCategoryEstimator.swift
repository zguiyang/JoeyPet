import Foundation
import OSLog

/// Legacy V2 fast estimate: known-root walks for Mac Care Home until V3 composition is wired.
/// Not the authoritative filesystem analyzer — see `StorageAnalyzer` (V3).
enum StorageCategoryEstimator: Sendable {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "StorageCategoryEstimator")

    struct Result: Sendable {
        let categories: [StorageCategorySize]
        let classificationDepth: StorageClassificationDepth
        let status: StorageClassificationStatus
        let coverage: Double
    }

    typealias ProgressHandler = @Sendable (StorageCategorySize) -> Void

    static func estimate(
        fullDiskAccessStatus: FullDiskAccessStatus,
        homeURL: URL = URL(fileURLWithPath: NSHomeDirectory()),
        onProgress: ProgressHandler? = nil
    ) async -> Result {
        let accessLevel = MacCareCapability.accessLevel(fullDiskAccessStatus: fullDiskAccessStatus)
        let depth = MacCareCapability.storageClassificationDepth(accessLevel: accessLevel)
        return await Task.detached(priority: .utility) {
            estimateSync(homeURL: homeURL, depth: depth, onProgress: onProgress)
        }.value
    }

    private static func estimateSync(
        homeURL: URL,
        depth: StorageClassificationDepth,
        onProgress: ProgressHandler?
    ) -> Result {
        let fileManager = FileManager.default
        var anyPartial = false
        var categories: [StorageCategorySize] = []

        let plans = classificationPlans(homeURL: homeURL, depth: depth)
        for plan in plans {
            var partial = false
            let bytes = scan(plan: plan, fileManager: fileManager, partial: &partial)
            if partial { anyPartial = true }
            guard bytes > 0 else { continue }
            let item = StorageCategorySize(
                category: plan.category,
                bytes: bytes,
                isEstimatePartial: partial
            )
            categories.append(item)
            onProgress?(item)
        }

        categories = StorageCompositionBuilder.sortForPresentation(categories)
        let classified = categories.reduce(Int64(0)) { $0 + $1.bytes }
        let status: StorageClassificationStatus = anyPartial ? .partial : .complete

        Self.logger.info(
            "Storage classification finished depth=\(depth.rawValue, privacy: .public) status=\(status.rawValue, privacy: .public) categories=\(categories.count, privacy: .public) classifiedBytes=\(classified, privacy: .public)"
        )

        return Result(
            categories: categories,
            classificationDepth: depth,
            status: status,
            coverage: 0
        )
    }

    // MARK: - Plans (mutually exclusive roots)

    private struct Plan: Sendable {
        let category: StorageCompositionCategory
        let roots: [URL]
        let budget: WalkBudget
    }

    private struct WalkBudget: Sendable {
        let maxEntries: Int
        let maxDepth: Int
        let descendIntoPackages: Bool
    }

    private static func classificationPlans(
        homeURL: URL,
        depth: StorageClassificationDepth
    ) -> [Plan] {
        let library = homeURL.appendingPathComponent("Library", isDirectory: true)
        switch depth {
        case .limited:
            return [
                Plan(
                    category: .applications,
                    roots: [
                        URL(fileURLWithPath: "/Applications", isDirectory: true),
                        homeURL.appendingPathComponent("Applications", isDirectory: true),
                    ],
                    budget: WalkBudget(maxEntries: 40_000, maxDepth: 14, descendIntoPackages: true)
                ),
                Plan(
                    category: .developer,
                    roots: [library.appendingPathComponent("Developer", isDirectory: true)],
                    budget: WalkBudget(maxEntries: 80_000, maxDepth: 14, descendIntoPackages: true)
                ),
                Plan(
                    category: .caches,
                    roots: [library.appendingPathComponent("Caches", isDirectory: true)],
                    budget: WalkBudget(maxEntries: 80_000, maxDepth: 12, descendIntoPackages: true)
                ),
            ]
        case .full:
            return [
                Plan(
                    category: .applications,
                    roots: [
                        URL(fileURLWithPath: "/Applications", isDirectory: true),
                        homeURL.appendingPathComponent("Applications", isDirectory: true),
                    ],
                    budget: WalkBudget(maxEntries: 50_000, maxDepth: 16, descendIntoPackages: true)
                ),
                Plan(
                    category: .documents,
                    roots: [
                        homeURL.appendingPathComponent("Documents", isDirectory: true),
                        homeURL.appendingPathComponent("Desktop", isDirectory: true),
                        homeURL.appendingPathComponent("Downloads", isDirectory: true),
                    ],
                    budget: WalkBudget(maxEntries: 120_000, maxDepth: 14, descendIntoPackages: true)
                ),
                Plan(
                    category: .photos,
                    roots: [homeURL.appendingPathComponent("Pictures", isDirectory: true)],
                    budget: WalkBudget(maxEntries: 120_000, maxDepth: 14, descendIntoPackages: true)
                ),
                Plan(
                    category: .videos,
                    roots: [homeURL.appendingPathComponent("Movies", isDirectory: true)],
                    budget: WalkBudget(maxEntries: 120_000, maxDepth: 14, descendIntoPackages: true)
                ),
                Plan(
                    category: .audio,
                    roots: [homeURL.appendingPathComponent("Music", isDirectory: true)],
                    budget: WalkBudget(maxEntries: 120_000, maxDepth: 14, descendIntoPackages: true)
                ),
                Plan(
                    category: .developer,
                    roots: [library.appendingPathComponent("Developer", isDirectory: true)],
                    budget: WalkBudget(maxEntries: 120_000, maxDepth: 14, descendIntoPackages: true)
                ),
                Plan(
                    category: .caches,
                    roots: [library.appendingPathComponent("Caches", isDirectory: true)],
                    budget: WalkBudget(maxEntries: 120_000, maxDepth: 12, descendIntoPackages: true)
                ),
                Plan(
                    category: .applicationData,
                    roots: [
                        library.appendingPathComponent("Application Support", isDirectory: true),
                        library.appendingPathComponent("Containers", isDirectory: true),
                        library.appendingPathComponent("Group Containers", isDirectory: true),
                    ],
                    budget: WalkBudget(maxEntries: 150_000, maxDepth: 14, descendIntoPackages: true)
                ),
            ]
        }
    }

    private static func scan(plan: Plan, fileManager: FileManager, partial: inout Bool) -> Int64 {
        switch plan.category {
        case .applications:
            return estimateApplications(roots: plan.roots, fileManager: fileManager, budget: plan.budget, partial: &partial)
        default:
            return estimateDirectoryRoots(plan.roots, fileManager: fileManager, budget: plan.budget, partial: &partial)
        }
    }

    // MARK: - Applications

    private static func estimateApplications(
        roots: [URL],
        fileManager: FileManager,
        budget: WalkBudget,
        partial: inout Bool
    ) -> Int64 {
        var total: Int64 = 0
        let appBudget = WalkBudget(
            maxEntries: min(budget.maxEntries, 35_000),
            maxDepth: min(budget.maxDepth, 18),
            descendIntoPackages: true
        )
        for root in roots where fileManager.fileExists(atPath: root.path) {
            total += sumApplicationBundles(in: root, fileManager: fileManager, budget: appBudget, partial: &partial)
        }
        return total
    }

    private static func sumApplicationBundles(
        in directory: URL,
        fileManager: FileManager,
        budget: WalkBudget,
        partial: inout Bool
    ) -> Int64 {
        guard let children = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            partial = true
            return 0
        }

        var total: Int64 = 0
        let limit = 600
        let apps = children.filter { $0.pathExtension == "app" }
        for child in apps.prefix(limit) {
            total += directorySize(root: child, fileManager: fileManager, budget: budget, partial: &partial)
        }
        if apps.count > limit { partial = true }
        return total
    }

    // MARK: - Directory roots

    private static func estimateDirectoryRoots(
        _ roots: [URL],
        fileManager: FileManager,
        budget: WalkBudget,
        partial: inout Bool
    ) -> Int64 {
        var total: Int64 = 0
        for root in roots where fileManager.fileExists(atPath: root.path) {
            total += directorySize(root: root, fileManager: fileManager, budget: budget, partial: &partial)
        }
        return total
    }

    private static func directorySize(
        root: URL,
        fileManager: FileManager,
        budget: WalkBudget,
        partial: inout Bool
    ) -> Int64 {
        var total: Int64 = 0
        var visited = 0

        var options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]
        if !budget.descendIntoPackages {
            options.insert(.skipsPackageDescendants)
        }

        guard fileManager.fileExists(atPath: root.path) else { return 0 }

        func walk(_ url: URL, depth: Int) {
            guard depth <= budget.maxDepth, visited < budget.maxEntries else {
                partial = true
                return
            }
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .isDirectoryKey,
                    .totalFileAllocatedSizeKey,
                    .fileSizeKey,
                    .isSymbolicLinkKey,
                ],
                options: options
            ) else {
                partial = true
                return
            }
            for case let fileURL as URL in enumerator {
                visited += 1
                if visited >= budget.maxEntries {
                    partial = true
                    break
                }
                if let values = try? fileURL.resourceValues(forKeys: [.isSymbolicLinkKey]),
                   values.isSymbolicLink == true
                {
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

    /// Disk footprint: `URLResourceKey.totalFileAllocatedSize` (APFS allocated blocks), falling back to logical `fileSize`.
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
