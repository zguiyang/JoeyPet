import Foundation

/// UI phase for 设置 → 关于 → 检查更新 (pure; no Sparkle types).
enum JoeyUpdatePhase: Equatable, Sendable {
    case idle
    case checking
    case upToDate
    case available(version: String)
    case failed
}

/// Copy + button chrome for the About update row (DESIGN §11.1).
enum JoeyUpdatePresentation {
    static func statusText(_ phase: JoeyUpdatePhase) -> String? {
        switch phase {
        case .idle, .checking:
            return nil
        case .upToDate:
            return "已是最新"
        case .available(let version):
            return "可更新到 \(version)"
        case .failed:
            return "检查失败"
        }
    }

    static func buttonTitle(_ phase: JoeyUpdatePhase) -> String {
        switch phase {
        case .idle, .upToDate:
            return "检查更新"
        case .checking:
            return "检查中…"
        case .available:
            return "更新"
        case .failed:
            return "重试"
        }
    }

    static func isButtonEnabled(_ phase: JoeyUpdatePhase) -> Bool {
        phase != .checking
    }
}
