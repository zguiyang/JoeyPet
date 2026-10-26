import Foundation

/// User-facing health semantics for the Calm Space orb and its status copy.
///
/// This is a presentation mapping over the existing `SystemStatusSnapshot`; it does
/// not re-implement the health evaluation pipeline. Memory pressure, storage severity
/// and thermal pressure are the inputs — raw memory usage or Swap size alone never
/// turn a healthy machine into an alert.
enum CalmSpaceHealthLevel: String, CaseIterable, Equatable, Sendable {
    case normal
    case attention
    case critical
    case unknown

    var accessibilityName: String {
        switch self {
        case .normal: return "正常"
        case .attention: return "需要关注"
        case .critical: return "需要处理"
        case .unknown: return "状态未知"
        }
    }
}

struct CalmSpaceHealth: Equatable, Sendable {
    let level: CalmSpaceHealthLevel
    let headline: String
    let detail: String
    let metaLine: String
    let lastCheckedText: String?

    var accessibilitySummary: String {
        [headline, detail, metaLine, lastCheckedText]
            .compactMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

enum CalmSpaceHealthBuilder {
    /// Builds the status shown below the orb.
    ///
    /// - `updatedAt == nil` means no sensor snapshot has arrived yet, so the honest
    ///   state is `unknown`, never `normal`.
    static func make(
        snapshot: SystemStatusSnapshot,
        accessLevel: MacCareAccessLevel,
        now: Date = Date()
    ) -> CalmSpaceHealth {
        guard let updatedAt = snapshot.updatedAt else {
            return CalmSpaceHealth(
                level: .unknown,
                headline: "正在检查 Mac",
                detail: "正在读取系统状态，请稍候。",
                metaLine: "状态数据暂不可用",
                lastCheckedText: nil
            )
        }

        let level = level(for: snapshot)
        let issues = MacCareHomePresentationBuilder.attentionIssues(from: snapshot)
        let metaLine = metaLine(for: snapshot, accessLevel: accessLevel)

        let headline: String
        let detail: String
        switch level {
        case .normal:
            headline = "Mac 一切正常"
            detail = "你的电脑当前运行平稳，暂时不需要处理任何问题。"
        case .attention:
            headline = "Mac 需要关注"
            detail = issues.first ?? "部分系统指标需要留意。"
        case .critical:
            headline = "Mac 需要处理"
            detail = criticalDetail(for: snapshot, issues: issues)
        case .unknown:
            headline = "正在检查 Mac"
            detail = "正在读取系统状态，请稍候。"
        }

        return CalmSpaceHealth(
            level: level,
            headline: headline,
            detail: detail,
            metaLine: metaLine,
            lastCheckedText: lastCheckedText(from: updatedAt, now: now)
        )
    }

    static func level(for snapshot: SystemStatusSnapshot) -> CalmSpaceHealthLevel {
        if snapshot.memory == .critical
            || snapshot.storageSeverity >= .critical
            || snapshot.thermal == .critical {
            return .critical
        }

        if MacCareHomePresentationBuilder.deriveTone(from: snapshot) == .attention {
            return .attention
        }

        if snapshot.memory == .normal,
           snapshot.storageSeverity < .warning,
           snapshot.thermal == .nominal || snapshot.thermal == .fair {
            return .normal
        }

        return .attention
    }

    private static func criticalDetail(
        for snapshot: SystemStatusSnapshot,
        issues: [String]
    ) -> String {
        if snapshot.memory == .critical {
            return issues.first ?? "内存压力很高，建议关闭部分占用较大的应用。"
        }
        if snapshot.storageSeverity >= .critical {
            return issues.first ?? "存储空间不足，可能影响系统稳定性。"
        }
        if snapshot.thermal == .critical {
            return issues.first ?? "热负载很高，建议减轻当前工作负载。"
        }
        return issues.first ?? "系统有需要处理的问题。"
    }

    private static func metaLine(
        for snapshot: SystemStatusSnapshot,
        accessLevel: MacCareAccessLevel
    ) -> String {
        var parts: [String] = []

        switch snapshot.memory {
        case .normal: parts.append("内存正常")
        case .warning: parts.append("内存偏高")
        case .critical: parts.append("内存紧张")
        }

        switch snapshot.storageSeverity {
        case .normal, .notice: parts.append("存储正常")
        case .warning: parts.append("存储偏少")
        case .critical: parts.append("存储不足")
        }

        switch snapshot.thermal {
        case .nominal: parts.append("散热正常")
        case .fair: parts.append("散热略高")
        case .serious, .critical: parts.append("散热偏高")
        }

        if accessLevel == .limited {
            parts.append("有限磁盘分析")
        }

        return parts.joined(separator: " · ")
    }

    private static func lastCheckedText(from date: Date, now: Date) -> String? {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        let relative = formatter.localizedString(for: date, relativeTo: now)
        return "\(relative)更新"
    }
}

#if DEBUG
extension CalmSpaceHealth {
    /// QA-only fixture. Never used by Release; the real window always maps the live snapshot.
    static func qaFixture(level: CalmSpaceHealthLevel) -> CalmSpaceHealth {
        switch level {
        case .normal:
            return CalmSpaceHealth(
                level: .normal,
                headline: "Mac 一切正常",
                detail: "你的电脑当前运行平稳，暂时不需要处理任何问题。",
                metaLine: "内存正常 · 存储正常 · 散热正常",
                lastCheckedText: "刚刚更新"
            )
        case .attention:
            return CalmSpaceHealth(
                level: .attention,
                headline: "Mac 需要关注",
                detail: "存储空间偏少，建议清理不需要的文件。",
                metaLine: "内存正常 · 存储偏少 · 散热正常",
                lastCheckedText: "1 分钟前更新"
            )
        case .critical:
            return CalmSpaceHealth(
                level: .critical,
                headline: "Mac 需要处理",
                detail: "存储空间不足，可能影响系统稳定性。",
                metaLine: "内存正常 · 存储不足 · 散热正常",
                lastCheckedText: "刚刚更新"
            )
        case .unknown:
            return CalmSpaceHealth(
                level: .unknown,
                headline: "正在检查 Mac",
                detail: "正在读取系统状态，请稍候。",
                metaLine: "状态数据暂不可用",
                lastCheckedText: nil
            )
        }
    }
}
#endif
