import SwiftUI

/// Stable semantic colors for storage composition segments (light/dark friendly).
enum StorageCategoryPresentation {
    static func color(for category: StorageCompositionCategory, colorScheme: ColorScheme) -> Color {
        switch category {
        case .applications:
            return Color(red: 0.22, green: 0.48, blue: 0.95)
        case .applicationData:
            return Color(red: 0.55, green: 0.36, blue: 0.86)
        case .developer:
            return Color(red: 0.95, green: 0.55, blue: 0.22)
        case .documents:
            return Color(red: 0.20, green: 0.65, blue: 0.58)
        case .photos:
            return Color(red: 0.32, green: 0.72, blue: 0.38)
        case .videos:
            return Color(red: 0.18, green: 0.58, blue: 0.42)
        case .audio:
            return Color(red: 0.45, green: 0.78, blue: 0.35)
        case .caches:
            return Color(red: 0.72, green: 0.58, blue: 0.28)
        case .archives:
            return Color(red: 0.62, green: 0.52, blue: 0.38)
        case .otherFiles:
            return Color(red: 0.58, green: 0.58, blue: 0.62)
        case .systemFiles:
            return Color(red: 0.48, green: 0.52, blue: 0.58)
        case .systemReserved:
            return colorScheme == .dark
                ? Color(white: 0.48)
                : Color(white: 0.55)
        case .other:
            return colorScheme == .dark
                ? Color(white: 0.55)
                : Color(white: 0.62)
        case .available:
            return colorScheme == .dark
                ? Color.white.opacity(0.14)
                : Color.black.opacity(0.08)
        case .analyzing:
            return colorScheme == .dark
                ? Color.white.opacity(0.22)
                : Color.black.opacity(0.12)
        }
    }

    static func systemAndOtherTooltipFootnote() -> String {
        "包含系统占用、快照及暂未分类空间，统计口径可能与 macOS 系统设置不同。"
    }
}
