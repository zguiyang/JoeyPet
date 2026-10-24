import Darwin
import Foundation
import OSLog

/// Filesystem tree scanner: allocated bytes, inode dedup, firmlink-aware traversal, mount boundaries.
enum DiskTreeScanner: Sendable {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "DiskTreeScanner")

    struct Configuration: Sendable {
        let scope: ScanRootResolver.Scope
        let firmlinkSources: Set<String>
        let homeURL: URL
        /// When false, records are not retained (production full-volume scan).
        let retainRecords: Bool
    }

    static func scan(
        configuration: Configuration,
        fileManager: FileManager = .default,
        isCancelled: @escaping @Sendable () -> Bool = { false },
        onFile: (@Sendable (DiskScanFileRecord) -> Void)? = nil
    ) -> DiskScanSnapshot {
        let start = Date()
        var records: [DiskScanFileRecord] = []
        var stats = DiskScanAccessStats()
        var scannedBytes: Int64 = 0
        // The canonical Data volume already presents each directory once. Retaining an
        // inode for every directory on a full-volume scan only duplicates the tree in RAM.
        let tracksDirectoryIdentity = configuration.scope.scanRoot.path != "/System/Volumes/Data"
        var visitedDirectoryIDs = Set<FilesystemIdentity>()
        // Most files have a single link. Keep only multiply-linked identities so the
        // deduplication index scales with hard links, not with every file on the volume.
        var countedFileIDs = Set<FilesystemIdentity>()

        func shouldSkipPath(_ absolutePath: String) -> Bool {
            ScanRootResolver.isExcluded(path: absolutePath, scope: configuration.scope)
        }

        func isOnBootVolume(_ url: URL) -> Bool {
            guard let bootDevice = configuration.scope.bootDeviceID else { return true }
            guard let device = ScanRootResolver.deviceID(for: url) else { return true }
            return device == bootDevice
        }

        func walkDirectory(_ directoryURL: URL) {
            if isCancelled() { return }
            let absolutePath = directoryURL.path
            if shouldSkipPath(absolutePath) {
                stats.skippedCrossVolume += 1
                return
            }
            if !isOnBootVolume(directoryURL) {
                stats.skippedCrossVolume += 1
                return
            }

            if tracksDirectoryIdentity, let dirID = FilesystemIdentity(url: directoryURL) {
                if visitedDirectoryIDs.contains(dirID) {
                    stats.deduplicatedDirectoryIdentities += 1
                    return
                }
                visitedDirectoryIDs.insert(dirID)
            }
            stats.visitedDirectories += 1

            let children: [URL]
            do {
                children = try fileManager.contentsOfDirectory(
                    at: directoryURL,
                    includingPropertiesForKeys: [
                        .isDirectoryKey,
                        .isRegularFileKey,
                        .isSymbolicLinkKey,
                        .isPackageKey,
                        .volumeIdentifierKey,
                        .totalFileAllocatedSizeKey,
                        .fileSizeKey,
                        .linkCountKey,
                        .isUbiquitousItemKey,
                        .ubiquitousItemDownloadingStatusKey,
                    ],
                    options: []
                )
            } catch {
                stats.deniedDirectories += 1
                return
            }

            autoreleasepool {
                for child in children {
                    if isCancelled() { return }
                    let childPath = child.path
                    if shouldSkipPath(childPath) {
                        stats.skippedCrossVolume += 1
                        continue
                    }

                    let values: URLResourceValues
                    do {
                        values = try child.resourceValues(forKeys: [
                            .isDirectoryKey,
                            .isRegularFileKey,
                            .isSymbolicLinkKey,
                            .isPackageKey,
                            .totalFileAllocatedSizeKey,
                            .fileSizeKey,
                            .linkCountKey,
                            .isUbiquitousItemKey,
                            .ubiquitousItemDownloadingStatusKey,
                        ])
                    } catch {
                        continue
                    }

                    if values.isSymbolicLink == true {
                        if APFSFirmlinkCatalog.isFirmlink(path: childPath, catalog: configuration.firmlinkSources) {
                            let resolved = child.resolvingSymlinksInPath()
                            if fileManager.fileExists(atPath: resolved.path) {
                                var isDir: ObjCBool = false
                                if fileManager.fileExists(atPath: resolved.path, isDirectory: &isDir), isDir.boolValue {
                                    walkDirectory(resolved)
                                }
                            }
                        } else {
                            stats.skippedSymlinks += 1
                        }
                        continue
                    }

                    if values.isDirectory == true {
                        walkDirectory(child)
                        continue
                    }

                    guard values.isRegularFile == true else { continue }

                    // Only multiply-linked files need an inode lookup; unique files skip `lstat`.
                    var fileID: FilesystemIdentity?
                    if (values.linkCount ?? 1) > 1,
                       let linkedID = FilesystemIdentity(hardLinkedFileAt: child) {
                        if countedFileIDs.contains(linkedID) {
                            stats.deduplicatedHardLinks += 1
                            continue
                        }
                        countedFileIDs.insert(linkedID)
                        fileID = linkedID
                    }

                    guard let bytes = Self.allocatedBytes(from: values, url: child) else { continue }
                    scannedBytes += bytes
                    stats.visitedFiles += 1

                    let parentPath = directoryURL.path
                    let ext = child.pathExtension.isEmpty ? nil : child.pathExtension
                    let record = DiskScanFileRecord(
                        absolutePath: childPath,
                        name: child.lastPathComponent,
                        parentAbsolutePath: parentPath,
                        fileExtension: ext,
                        allocatedBytes: bytes,
                        isDirectory: false,
                        isPackage: false,
                        identity: fileID
                    )
                    onFile?(record)
                    if configuration.retainRecords {
                        records.append(record)
                    }
                }
            }
        }

        walkDirectory(configuration.scope.scanRoot)

        let duration = Date().timeIntervalSince(start)
        Self.logger.info(
            "Disk scan finished files=\(stats.visitedFiles, privacy: .public) dirs=\(stats.visitedDirectories, privacy: .public) denied=\(stats.deniedDirectories, privacy: .public) bytes=\(scannedBytes, privacy: .public)"
        )

        return DiskScanSnapshot(
            scanRoot: configuration.scope.scanRoot,
            records: records,
            stats: stats,
            scannedAllocatedBytes: scannedBytes,
            duration: duration,
            hadAccessDenied: stats.deniedDirectories > 0
        )
    }

    private static func allocatedBytes(from values: URLResourceValues, url: URL) -> Int64? {
        if values.isUbiquitousItem == true,
           values.ubiquitousItemDownloadingStatus == .notDownloaded {
            return Int64(values.totalFileAllocatedSize ?? 0)
        }
        if let allocated = values.totalFileAllocatedSize {
            return Int64(allocated)
        }
        if let logical = values.fileSize {
            return Int64(logical)
        }
        // Fallback for unusual filesystems where resource values are unavailable.
        return StorageFileSize.allocatedBytes(of: url, isDirectory: false)
    }
}
