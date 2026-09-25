import Foundation
import OSLog

/// Maps permission state to Mac Care scanning and classification scope.
enum MacCareCapability {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "MacCareCapability")

    static func accessLevel(fullDiskAccessStatus: FullDiskAccessStatus) -> MacCareAccessLevel {
        switch fullDiskAccessStatus {
        case .granted:
            return .full
        case .notGranted, .unknown:
            return .limited
        }
    }

    static func effectiveCleanupScanScope(
        requested: CleanupScanScope,
        accessLevel: MacCareAccessLevel
    ) -> (scope: CleanupScanScope, deepScanDeferred: Bool) {
        switch (requested, accessLevel) {
        case (.baseline, _):
            return (.baseline, false)
        case (.deep, .full):
            return (.deep, false)
        case (.deep, .limited):
            return (.baseline, true)
        }
    }

    static func storageClassificationDepth(accessLevel: MacCareAccessLevel) -> StorageClassificationDepth {
        switch accessLevel {
        case .full:
            return .full
        case .limited:
            return .limited
        }
    }

    static func logScannerScope(requested: CleanupScanScope, applied: CleanupScanScope, accessLevel: MacCareAccessLevel) {
        Self.logger.info(
            "Cleanup scan scope requested=\(requested.rawValue, privacy: .public) applied=\(applied.rawValue, privacy: .public) access=\(accessLevel.rawValue, privacy: .public)"
        )
    }
}

enum StorageClassificationDepth: String, Sendable, Equatable {
    case limited
    case full
}
