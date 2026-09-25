import AppKit
import Foundation
import OSLog

enum SystemSettingsPrivacy {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "SystemSettingsPrivacy")

    /// Opens Privacy & Security → Full Disk Access. Intended for explicit user actions in a future permission UI.
    @discardableResult
    static func openFullDiskAccessSettings() -> Bool {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
        ]
        for string in candidates {
            guard let url = URL(string: string) else { continue }
            if NSWorkspace.shared.open(url) {
                Self.logger.info("Opened Full Disk Access settings via scheme")
                return true
            }
        }
        Self.logger.error("Failed to open Full Disk Access settings URL")
        return false
    }
}
