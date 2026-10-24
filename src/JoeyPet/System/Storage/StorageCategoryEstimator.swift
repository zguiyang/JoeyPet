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
        let plans = classificationPlans(homeURL: homeURL, depth: depth)
        let estimateStartedAt = Date()
        Self.logger.info(
            "Storage classification started depth=\(depth.rawValue, privacy: .public) plans=\(plans.count, privacy: .public)"
        )

        var anyPartial = false
        var categories: [StorageCategorySize] = []

        // Each plan walks a disjoint known root, so the whole set can run concurrently.
        // Budgets are global per plan; parallelism is bounded by the task group executor.
        let batchSize = 8
        var index = 0
        while index < plans.count {
            let end = min(index + batchSize, plans.count)
            let batch = Array(plans[index..<end])
            let outcomes = await withTaskGroup(of: PlanOutcome.self, returning: [PlanOutcome].self) { group in
                for plan in batch {
                    group.addTask(priority: .utility) {
                        let fileManager = FileManager()
                        var partial = false
                        let startedAt = Date()
                        let bytes = scan(plan: plan, fileManager: fileManager, partial: &partial)
                        return PlanOutcome(
                            category: plan.category,
                            bytes: bytes,
                            partial: partial,
                            seconds: Date().timeIntervalSince(startedAt)
                        )
                    }
                }
                var results: [PlanOutcome] = []
                for await outcome in group {
                    results.append(outcome)
                    if outcome.bytes > 0 {
                        onProgress?(StorageCategorySize(
                            category: outcome.category,
                            bytes: outcome.bytes,
                            isEstimatePartial: outcome.partial
                        ))
                    }
                }
                return results
            }

            for outcome in outcomes {
                if outcome.partial { anyPartial = true }
                Self.logger.info(
                    "Storage plan category=\(outcome.category.rawValue, privacy: .public) bytes=\(outcome.bytes, privacy: .public) partial=\(outcome.partial, privacy: .public) seconds=\(String(format: "%.1f", outcome.seconds), privacy: .public)"
                )
                guard outcome.bytes > 0 else { continue }
                categories.append(StorageCategorySize(
                    category: outcome.category,
                    bytes: outcome.bytes,
                    isEstimatePartial: outcome.partial
                ))
            }
            index = end
        }

        categories = StorageCompositionBuilder.sortForPresentation(categories)
        let classified = categories.reduce(Int64(0)) { $0 + $1.bytes }
        let status: StorageClassificationStatus = anyPartial ? .partial : .complete

        Self.logger.info(
            "Storage classification finished depth=\(depth.rawValue, privacy: .public) status=\(status.rawValue, privacy: .public) categories=\(categories.count, privacy: .public) classifiedBytes=\(classified, privacy: .public) seconds=\(String(format: "%.1f", Date().timeIntervalSince(estimateStartedAt)), privacy: .public)"
        )

        return Result(
            categories: categories,
            classificationDepth: depth,
            status: status,
            coverage: 0
        )
    }

    private struct PlanOutcome: Sendable {
        let category: StorageCompositionCategory
        let bytes: Int64
        let partial: Bool
        let seconds: TimeInterval
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
                    budget: WalkBudget(maxEntries: 25_000, maxDepth: 14, descendIntoPackages: true)
                ),
                Plan(
                    category: .caches,
                    roots: [library.appendingPathComponent("Caches", isDirectory: true)],
                    budget: WalkBudget(maxEntries: 30_000, maxDepth: 12, descendIntoPackages: true)
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
                    budget: WalkBudget(maxEntries: 100_000, maxDepth: 16, descendIntoPackages: true)
                ),
                Plan(
                    category: .documents,
                    roots: [
                        homeURL.appendingPathComponent("Documents", isDirectory: true),
                        homeURL.appendingPathComponent("Desktop", isDirectory: true),
                        homeURL.appendingPathComponent("Downloads", isDirectory: true),
                    ],
                    budget: WalkBudget(maxEntries: 30_000, maxDepth: 14, descendIntoPackages: true)
                ),
                Plan(
                    category: .photos,
                    roots: [homeURL.appendingPathComponent("Pictures", isDirectory: true)],
                    budget: WalkBudget(maxEntries: 30_000, maxDepth: 14, descendIntoPackages: true)
                ),
                Plan(
                    category: .videos,
                    roots: [homeURL.appendingPathComponent("Movies", isDirectory: true)],
                    budget: WalkBudget(maxEntries: 10_000, maxDepth: 14, descendIntoPackages: true)
                ),
                Plan(
                    category: .audio,
                    roots: [homeURL.appendingPathComponent("Music", isDirectory: true)],
                    budget: WalkBudget(maxEntries: 5_000, maxDepth: 14, descendIntoPackages: true)
                ),
                Plan(
                    category: .developer,
                    roots: [library.appendingPathComponent("Developer", isDirectory: true)],
                    budget: WalkBudget(maxEntries: 30_000, maxDepth: 14, descendIntoPackages: true)
                ),
                Plan(
                    category: .caches,
                    roots: [library.appendingPathComponent("Caches", isDirectory: true)],
                    budget: WalkBudget(maxEntries: 60_000, maxDepth: 12, descendIntoPackages: true)
                ),
                Plan(
                    category: .applicationData,
                    roots: [
                        library.appendingPathComponent("Application Support", isDirectory: true),
                        library.appendingPathComponent("Containers", isDirectory: true),
                        library.appendingPathComponent("Group Containers", isDirectory: true),
                    ],
                    budget: WalkBudget(maxEntries: 60_000, maxDepth: 14, descendIntoPackages: true)
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
        var visited = 0
        let appLimit = 200
        // Per-bundle cap so a single huge app cannot consume the whole plan budget.
        let perAppBudget = WalkBudget(
            maxEntries: min(6_000, budget.maxEntries),
            maxDepth: min(budget.maxDepth, 18),
            descendIntoPackages: true
        )

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let children = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                partial = true
                continue
            }

            let apps = children.filter { $0.pathExtension == "app" }
            if apps.count > appLimit { partial = true }

            for child in apps.prefix(appLimit) {
                if visited >= budget.maxEntries {
                    partial = true
                    break
                }
                let result = directorySize(
                    root: child,
                    fileManager: fileManager,
                    budget: perAppBudget,
                    partial: &partial
                )
                total += result.bytes
                visited += result.visited
            }
        }
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
        var visited = 0
        for root in roots where fileManager.fileExists(atPath: root.path) {
            if visited >= budget.maxEntries {
                partial = true
                break
            }
            let result = directorySize(
                root: root,
                fileManager: fileManager,
                budget: budget,
                partial: &partial
            )
            total += result.bytes
            visited += result.visited
        }
        return total
    }

    private struct DirectorySizeResult {
        let bytes: Int64
        let visited: Int
    }

    private static func directorySize(
        root: URL,
        fileManager: FileManager,
        budget: WalkBudget,
        partial: inout Bool
    ) -> DirectorySizeResult {
        var total: Int64 = 0
        var visited = 0

        var options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]
        if !budget.descendIntoPackages {
            options.insert(.skipsPackageDescendants)
        }

        guard fileManager.fileExists(atPath: root.path) else {
            return DirectorySizeResult(bytes: 0, visited: 0)
        }

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
            var stop = false
            while !stop, let fileURL = autoreleasepool(invoking: { enumerator.nextObject() as? URL }) {
                autoreleasepool {
                    visited += 1
                    if visited >= budget.maxEntries {
                        partial = true
                        stop = true
                        return
                    }
                    guard let values = try? fileURL.resourceValues(forKeys: Set<URLResourceKey>([
                        .isSymbolicLinkKey,
                        .isRegularFileKey,
                        .isDirectoryKey,
                        .totalFileAllocatedSizeKey,
                        .fileSizeKey,
                    ])) else {
                        partial = true
                        return
                    }
                    if values.isSymbolicLink == true {
                        enumerator.skipDescendants()
                        return
                    }
                    if values.isDirectory == true { return }
                    guard values.isRegularFile == true else { return }
                    if let allocated = values.totalFileAllocatedSize {
                        total += Int64(allocated)
                    } else if let size = values.fileSize {
                        total += Int64(size)
                    } else {
                        partial = true
                    }
                }
            }
        }

        walk(root, depth: 0)
        return DirectorySizeResult(bytes: total, visited: visited)
    }
}
