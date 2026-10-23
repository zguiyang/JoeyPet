import Darwin
import Foundation

/// Resolves the canonical boot data-volume scan root and mount boundaries.
enum ScanRootResolver: Sendable {
    struct Scope: Sendable {
        /// Directory URL to traverse (no trailing duplicate firmlink roots).
        let scanRoot: URL
        /// `st_dev` for the boot data volume backing the user home.
        let bootDeviceID: UInt64?
        /// Absolute paths skipped entirely (external `/Volumes/*` mounts).
        let excludedAbsolutePathPrefixes: [String]

        init(scanRoot: URL, bootDeviceID: UInt64?, excludedAbsolutePathPrefixes: [String]) {
            self.scanRoot = scanRoot
            self.bootDeviceID = bootDeviceID
            self.excludedAbsolutePathPrefixes = excludedAbsolutePathPrefixes
        }
    }

    static func bootDataScope(
        homeURL: URL = URL(fileURLWithPath: NSHomeDirectory()),
        fileManager: FileManager = .default
    ) -> Scope {
        let dataRoot = URL(fileURLWithPath: "/System/Volumes/Data", isDirectory: true)
        let scanRoot: URL
        if fileManager.fileExists(atPath: dataRoot.path) {
            scanRoot = dataRoot
        } else {
            scanRoot = URL(fileURLWithPath: "/", isDirectory: true)
        }

        let bootDeviceID = deviceID(for: homeURL)
        let excluded = externalVolumePrefixes(excludingHomeDevice: bootDeviceID, fileManager: fileManager)

        return Scope(
            scanRoot: scanRoot,
            bootDeviceID: bootDeviceID,
            excludedAbsolutePathPrefixes: excluded
        )
    }

    static func deviceID(for url: URL) -> UInt64? {
        var statBuffer = stat()
        guard stat(url.path, &statBuffer) == 0 else { return nil }
        return UInt64(statBuffer.st_dev)
    }

    /// Paths under `/Volumes` that belong to other disks (not the boot data volume).
    private static func externalVolumePrefixes(
        excludingHomeDevice bootDeviceID: UInt64?,
        fileManager: FileManager
    ) -> [String] {
        let volumesRoot = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        guard let children = try? fileManager.contentsOfDirectory(
            at: volumesRoot,
            includingPropertiesForKeys: [],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var excluded: [String] = []
        for mount in children {
            if let bootDeviceID, let mountDevice = deviceID(for: mount), mountDevice == bootDeviceID {
                continue
            }
            excluded.append(mount.path + "/")
        }
        return excluded.sorted()
    }

    static func isExcluded(path: String, scope: Scope) -> Bool {
        for prefix in scope.excludedAbsolutePathPrefixes where path.hasPrefix(prefix) {
            return true
        }
        return false
    }
}
