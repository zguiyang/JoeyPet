import Foundation

struct DiskScanFileRecord: Sendable, Equatable {
    let absolutePath: String
    let name: String
    let parentAbsolutePath: String
    let fileExtension: String?
    let allocatedBytes: Int64
    let isDirectory: Bool
    let isPackage: Bool
    let identity: FilesystemIdentity?
}

struct DiskScanAccessStats: Sendable, Equatable {
    var visitedFiles: Int = 0
    var visitedDirectories: Int = 0
    var deniedDirectories: Int = 0
    var skippedSymlinks: Int = 0
    var skippedCrossVolume: Int = 0
    var deduplicatedHardLinks: Int = 0
    var deduplicatedDirectoryIdentities: Int = 0
}

struct DiskScanSnapshot: Sendable {
    let scanRoot: URL
    let records: [DiskScanFileRecord]
    let stats: DiskScanAccessStats
    let scannedAllocatedBytes: Int64
    let duration: TimeInterval
    let hadAccessDenied: Bool
}
