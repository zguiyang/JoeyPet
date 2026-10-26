import Foundation

#if DEBUG

// MARK: - MOCK content
//
// Every string, percentage and timestamp in the Stage prototype comes from this file.
// None of it is produced by real timing / scanning / cleanup logic. It exists only so a
// design can be validated against representative copy. Nothing here is reachable from a
// production path (the whole StagePrototype folder is DEBUG-only and gated on
// `-JoeyPetQAStagePrototype`).

/// The transient activity shown in the Stage's reserved activity slot. At most one is
/// present at a time.
enum MacCareStageActivity: Equatable {
    case scanning(label: String, progress: Double)   // "正在检查存储… 42%"
    case maintenance(label: String)                  // "正在整理缓存…"
    case complete(label: String)                     // "检查完成 · 刚刚"

    var label: String {
        switch self {
        case .scanning(let label, _): return label
        case .maintenance(let label): return label
        case .complete(let label): return label
        }
    }
}

/// A tappable inline action. Only present when there is something actionable — a healthy
/// Mac never shows a cleanup/optimise button.
struct MacCareStageAction: Equatable {
    let title: String
    let systemImage: String
}

/// One immutable MOCK snapshot of the Mac Care Stage copy.
struct MacCareStageContent: Equatable {
    let level: CalmSpaceHealthLevel
    let headline: String
    let detail: String
    /// Quiet context line (normal) or the meta text beside the action chip.
    let meta: String?
    /// Action chip; `nil` for normal / unknown.
    let action: MacCareStageAction?
    let activity: MacCareStageActivity?
    /// unknown-state supporting line rendered with its own thin progress line.
    let progressLabel: String?
}

enum StagePrototypeFixtures {
    /// MOCK Mac Care content for a prototype state.
    ///
    /// - Parameters:
    ///   - state: prototype state (normal / attention / critical / unknown).
    ///   - activityOverride: forces an activity slot (used by the `activity-*` captures).
    ///   - longCopy: swaps in stress-test long copy.
    static func macCareContent(
        state: CalmSpaceStagePrototypeState,
        activityOverride: MacCareStageActivity? = nil,
        longCopy: Bool = false
    ) -> MacCareStageContent {
        let level = state.healthLevel

        // Base copy per state.
        var content: MacCareStageContent
        switch state {
        case .attention:
            content = MacCareStageContent(
                level: level,
                headline: "存储空间偏少",
                detail: "可用空间仅剩 12.4 GB，系统更新可能受影响。",
                meta: "1 项需要关注 · 2 分钟前检查",
                action: MacCareStageAction(title: "查看存储", systemImage: "internaldrive"),
                activity: nil,
                progressLabel: nil
            )
        case .critical:
            content = MacCareStageContent(
                level: level,
                headline: "内存紧张",
                detail: "系统正在频繁压缩内存，建议关闭暂时不用的应用。",
                meta: "需要处理 · 刚刚检查",
                action: MacCareStageAction(title: "查看应用", systemImage: "square.grid.2x2"),
                activity: nil,
                progressLabel: nil
            )
        case .unknown:
            content = MacCareStageContent(
                level: level,
                headline: "正在了解 Mac 状态",
                detail: "首次检查需要一点时间，完成后会显示结果。",
                meta: nil,
                action: nil,
                activity: nil,
                progressLabel: "正在检查…"
            )
        default: // .normal
            content = MacCareStageContent(
                level: .normal,
                headline: "Mac 一切正常",
                detail: "运行平稳，没有需要处理的问题。",
                meta: "内存 · 存储 · 散热 正常",
                action: nil,
                activity: nil,
                progressLabel: nil
            )
        }

        // Long-copy stress variants: longer headline/detail that must not break the
        // compact composition or collide with the dock.
        if longCopy {
            switch state {
            case .attention:
                content = MacCareStageContent(
                    level: level,
                    headline: "存储空间长期偏少，可能影响系统更新与日常使用",
                    detail: "可用空间仅剩 12.4 GB。系统更新、照片库和应用缓存都需要占用空间，长时间不足可能导致更新失败或应用响应变慢。",
                    meta: "1 项需要关注 · 2 分钟前检查",
                    action: MacCareStageAction(title: "查看存储", systemImage: "internaldrive"),
                    activity: nil,
                    progressLabel: nil
                )
            case .critical:
                content = MacCareStageContent(
                    level: level,
                    headline: "内存持续紧张，多个大型应用同时占用大量资源",
                    detail: "系统正在频繁压缩内存并使用交换空间，可能导致卡顿。建议暂时关闭不用的大型应用，为当前工作腾出资源。",
                    meta: "需要处理 · 刚刚检查",
                    action: MacCareStageAction(title: "查看应用", systemImage: "square.grid.2x2"),
                    activity: nil,
                    progressLabel: nil
                )
            case .unknown:
                content = MacCareStageContent(
                    level: level,
                    headline: "正在了解这台 Mac 的整体状态",
                    detail: "首次检查需要读取内存、存储与散热信息，会花一点时间；完成后这里会显示结果，期间不会改动任何数据。",
                    meta: nil,
                    action: nil,
                    activity: nil,
                    progressLabel: "正在检查…"
                )
            default:
                content = MacCareStageContent(
                    level: .normal,
                    headline: "Mac 一切正常，运行平稳",
                    detail: "内存、存储与散热都在正常范围内，暂时没有需要处理的问题。你可以继续专注手头的事情。",
                    meta: "内存 · 存储 · 散热 正常 · 2 分钟前检查",
                    action: nil,
                    activity: nil,
                    progressLabel: nil
                )
            }
        }

        // Activity override for the dedicated activity captures.
        if let activityOverride {
            content = MacCareStageContent(
                level: content.level,
                headline: content.headline,
                detail: content.detail,
                meta: content.meta,
                action: content.action,
                activity: activityOverride,
                progressLabel: content.progressLabel
            )
        }

        return content
    }

    /// Fixed MOCK activity presets used by the `activity-*` captures.
    static let scanningActivity = MacCareStageActivity.scanning(label: "正在检查存储", progress: 0.42)
    static let completeActivity = MacCareStageActivity.complete(label: "检查完成 · 刚刚")
    static let maintenanceActivity = MacCareStageActivity.maintenance(label: "正在整理缓存")

    /// Fixed MOCK star field (≤ 6, positions as unit points). Static or a 60 s+ shimmer.
    static let stars: [CGPoint] = [
        CGPoint(x: 0.14, y: 0.22),
        CGPoint(x: 0.82, y: 0.18),
        CGPoint(x: 0.90, y: 0.62),
        CGPoint(x: 0.08, y: 0.70),
        CGPoint(x: 0.68, y: 0.86),
        CGPoint(x: 0.28, y: 0.90),
    ]
}

#endif
