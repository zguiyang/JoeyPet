import Darwin
import Foundation

/// Stable `(device, inode)` identity for deduplication across firmlinks and hard links.
struct FilesystemIdentity: Hashable, Sendable {
    let deviceID: UInt64
    let inode: UInt64

    init(deviceID: UInt64, inode: UInt64) {
        self.deviceID = deviceID
        self.inode = inode
    }

    init?(url: URL) {
        var statBuffer = stat()
        guard lstat(url.path, &statBuffer) == 0 else { return nil }
        deviceID = UInt64(statBuffer.st_dev)
        inode = UInt64(statBuffer.st_ino)
    }

    /// Returns an identity only when another directory entry can refer to this inode.
    /// Unique files do not need to occupy the scan's deduplication set.
    init?(hardLinkedFileAt url: URL) {
        var statBuffer = stat()
        guard lstat(url.path, &statBuffer) == 0,
              (statBuffer.st_mode & S_IFMT) == S_IFREG,
              statBuffer.st_nlink > 1
        else { return nil }
        deviceID = UInt64(statBuffer.st_dev)
        inode = UInt64(statBuffer.st_ino)
    }
}

enum APFSFirmlinkCatalog: Sendable {
    /// Firmlink source paths from `/usr/share/firmlinks` (leading `/` normalized).
    static func firmlinkSourcePaths(fileManager: FileManager = .default) -> Set<String> {
        let catalogURL = URL(fileURLWithPath: "/usr/share/firmlinks")
        guard let text = try? String(contentsOf: catalogURL, encoding: .utf8) else {
            return fallbackFirmlinks
        }
        var paths = Set<String>()
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let source = trimmed.split(whereSeparator: { $0 == "\t" || $0 == " " }).first.map(String.init) ?? trimmed
            let normalized = normalizeFirmlinkPath(source)
            if !normalized.isEmpty { paths.insert(normalized) }
        }
        return paths.isEmpty ? fallbackFirmlinks : paths
    }

    static func isFirmlink(path: String, catalog: Set<String>) -> Bool {
        catalog.contains(normalizeFirmlinkPath(path))
    }

    static func normalizeFirmlinkPath(_ path: String) -> String {
        var p = path.trimmingCharacters(in: .whitespaces)
        if !p.hasPrefix("/") { p = "/\(p)" }
        while p.count > 1, p.hasSuffix("/") { p.removeLast() }
        return p
    }

    private static let fallbackFirmlinks: Set<String> = [
        "/Applications",
        "/Library",
        "/Users",
        "/Users/Shared",
        "/private",
        "/usr/local",
    ]
}
