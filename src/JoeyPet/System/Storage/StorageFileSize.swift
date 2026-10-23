import Darwin
import Foundation

/// Single size semantics for Storage Analyzer V3 (see `docs/storage-accounting.md`).
enum StorageFileSize {
    /// On-disk allocated bytes for a regular file (never directory `totalFileAllocatedSize`).
    static func allocatedBytes(of url: URL, isDirectory: Bool) -> Int64? {
        guard !isDirectory else { return nil }

        if let values = try? url.resourceValues(forKeys: [
            .totalFileAllocatedSizeKey,
            .fileSizeKey,
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
        ]) {
            if values.isUbiquitousItem == true,
               values.ubiquitousItemDownloadingStatus == .notDownloaded
            {
                if let allocated = values.totalFileAllocatedSize {
                    return Int64(allocated)
                }
                return 0
            }
            if let allocated = values.totalFileAllocatedSize {
                return Int64(allocated)
            }
            if let logical = values.fileSize {
                return Int64(logical)
            }
        }

        var statBuffer = stat()
        guard lstat(url.path, &statBuffer) == 0 else { return nil }
        guard (statBuffer.st_mode & S_IFMT) == S_IFREG else { return nil }
        let blockBytes = Int64(statBuffer.st_blocks) * 512
        if blockBytes > 0 { return blockBytes }
        return Int64(statBuffer.st_size)
    }
}
