import Foundation
import OSLog

/// Read-only FDA capability probe using TCC-protected Library canaries (not Files & Folders locations).
protocol FullDiskAccessProbing: Sendable {
    func probe(homeURL: URL) -> FullDiskAccessProbeOutcome
}

protocol FullDiskAccessDirectoryAccess: Sendable {
    func directoryExists(at url: URL) -> Bool
    func listImmediateChildren(at url: URL) throws -> [URL]
}

struct FileManagerDirectoryAccess: FullDiskAccessDirectoryAccess, Sendable {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    func listImmediateChildren(at url: URL) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )
    }
}

struct FullDiskAccessProbe: FullDiskAccessProbing, Sendable {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "FullDiskAccessProbe")

    /// FDA-protected subtrees; avoids Desktop/Documents/Downloads/Music-only prompts.
    static let canaryRelativePaths: [(label: String, path: String)] = [
        (label: "Library/Safari", path: "Library/Safari"),
        (label: "Library/Messages", path: "Library/Messages"),
    ]

    private let directoryAccess: any FullDiskAccessDirectoryAccess

    init(directoryAccess: any FullDiskAccessDirectoryAccess = FileManagerDirectoryAccess()) {
        self.directoryAccess = directoryAccess
    }

    func probe(homeURL: URL) -> FullDiskAccessProbeOutcome {
        let home = homeURL.standardizedFileURL
        var attempts: [FullDiskAccessProbeAttempt] = []
        var sawExistingCanary = false

        for canary in Self.canaryRelativePaths {
            let url = home.appendingPathComponent(canary.path, isDirectory: true)
            guard directoryAccess.directoryExists(at: url) else {
                attempts.append(FullDiskAccessProbeAttempt(canaryLabel: canary.label, failureKind: .pathMissing))
                continue
            }

            sawExistingCanary = true
            if let failure = probeList(at: url) {
                attempts.append(FullDiskAccessProbeAttempt(canaryLabel: canary.label, failureKind: failure))
                if failure == .permissionDenied {
                    Self.logger.info("FDA probe permission denied via canary \(canary.label, privacy: .public)")
                    return FullDiskAccessProbeOutcome(status: .notGranted, attempts: attempts)
                }
            } else {
                Self.logger.info("FDA probe succeeded via canary \(canary.label, privacy: .public)")
                return FullDiskAccessProbeOutcome(status: .granted, attempts: attempts)
            }
        }

        if !sawExistingCanary {
            Self.logger.info("FDA probe inconclusive: no canary directories present")
            return FullDiskAccessProbeOutcome(status: .unknown, attempts: attempts)
        }

        Self.logger.info("FDA probe inconclusive: canary errors were not permission denials")
        return FullDiskAccessProbeOutcome(status: .unknown, attempts: attempts)
    }

    /// `nil` when listing succeeded; otherwise the classified failure kind.
    private func probeList(at url: URL) -> FullDiskAccessProbeFailureKind? {
        do {
            _ = try directoryAccess.listImmediateChildren(at: url)
            return nil
        } catch {
            return Self.classify(error)
        }
    }

    static func classify(_ error: Error) -> FullDiskAccessProbeFailureKind {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain, ns.code == NSFileReadNoPermissionError {
            return .permissionDenied
        }
        if ns.domain == NSPOSIXErrorDomain, ns.code == EPERM || ns.code == EACCES {
            return .permissionDenied
        }
        if ns.domain == NSCocoaErrorDomain,
           ns.code == NSFileNoSuchFileError || ns.code == NSFileReadNoSuchFileError {
            return .pathMissing
        }
        return .unexpected
    }
}

#if DEBUG
enum FullDiskAccessProbeDebug {
    static func logCurrentCapability(using probe: any FullDiskAccessProbing = FullDiskAccessProbe()) {
        let outcome = probe.probe(homeURL: URL(fileURLWithPath: NSHomeDirectory()))
        print("[JoeyPet] Full Disk Access: \(outcome.status.rawValue)")
    }
}
#endif
