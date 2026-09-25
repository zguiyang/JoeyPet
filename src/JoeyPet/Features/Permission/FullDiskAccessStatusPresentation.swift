import SwiftUI

/// User-facing copy and semantics for Full Disk Access capability (not onboarding completion).
enum FullDiskAccessStatusPresentation {
    static func statusTitle(for status: FullDiskAccessStatus) -> String {
        switch status {
        case .granted:
            return "已开启"
        case .notGranted:
            return "未开启"
        case .unknown:
            return "未确认"
        }
    }

    static func statusDetail(for status: FullDiskAccessStatus) -> String {
        switch status {
        case .granted:
            return "JoeyPet 现在可以进行完整的存储分析和深度清理。"
        case .notGranted:
            return "在系统设置中开启 JoeyPet 的完全磁盘访问权限。"
        case .unknown:
            return "暂时无法确认权限状态，可按 Limited 模式继续使用。"
        }
    }

    static func indicatorColor(for status: FullDiskAccessStatus) -> Color {
        switch status {
        case .granted:
            return .green
        case .notGranted:
            return .secondary
        case .unknown:
            return .orange
        }
    }

    static func openSettingsButtonTitle(for status: FullDiskAccessStatus) -> String {
        switch status {
        case .granted:
            return "打开系统设置"
        case .notGranted, .unknown:
            return "前往设置"
        }
    }
}
