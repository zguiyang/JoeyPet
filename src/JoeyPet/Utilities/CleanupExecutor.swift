import Foundation
import OSLog

protocol FileTrashMoving: Sendable {
    nonisolated func moveToTrash(_ url: URL) throws
}

struct SystemFileTrashMover: FileTrashMoving {
    nonisolated init() {}

    nonisolated func moveToTrash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}

struct CleanupExecutor: Sendable {
    private nonisolated static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "CleanupExecutor")

    nonisolated init() {}

    nonisolated func execute(_ candidates: [CleanupCandidate], mover: any FileTrashMoving = SystemFileTrashMover()) async -> CleanupExecutionResult {
        let results = await Task.detached(priority: .utility) {
            var items: [CleanupItemResult] = []
            for candidate in candidates {
                if Task.isCancelled {
                    items.append(CleanupItemResult(candidate: candidate, succeeded: false, message: "Cleanup cancelled."))
                    continue
                }
                do {
                    try mover.moveToTrash(candidate.url)
                    items.append(CleanupItemResult(candidate: candidate, succeeded: true, message: "Moved to Trash."))
                } catch {
                    items.append(CleanupItemResult(candidate: candidate, succeeded: false, message: Self.userMessage(for: error)))
                }
            }
            return items
        }.value

        let result = CleanupExecutionResult(items: results, finishedAt: Date())
        Self.logger.info("Cleanup finished: succeeded=\(result.succeededCount, privacy: .public), failed=\(result.failedCount, privacy: .public)")
        return result
    }

    private nonisolated static func userMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError {
            return "The item is no longer available."
        }
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteNoPermissionError {
            return "Permission was denied."
        }
        return "Could not move this item to Trash."
    }
}
