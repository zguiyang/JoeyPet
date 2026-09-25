import Foundation

enum MacCareOverallTone: Equatable, Sendable {
    case normal
    case attention
}

struct MacCareHomePresentation: Equatable, Sendable {
    let tone: MacCareOverallTone
    let headline: String
    let detail: String
    let lastCheckedText: String?
    let storage: StoragePresentation
    let memory: MemoryPresentation
    let thermal: ThermalPresentation
    let cleanup: CleanupSummaryPresentation
    let showsMemoryTrend: Bool
}

struct MacCareStorageSegment: Equatable, Sendable {
    let category: StorageCompositionCategory
    let title: String
    let byteCount: Int64
    let fractionOfTotal: Double
}

enum StorageCompositionLoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded(StorageComposition)
    case unavailable
}

struct StoragePresentation: Equatable, Sendable {
    let volumeTitle: String
    let availableText: String?
    let usedText: String?
    let usedFraction: Double?
    let totalBytes: Int64
    let usedBytes: Int64
    let segments: [MacCareStorageSegment]
    let legendSegments: [MacCareStorageSegment]
    let compositionState: StorageCompositionLoadState
    let footnote: String?
    let limitedAnalysisBadge: String?
    let limitedAnalysisFootnote: String?
    let showsFullScanAction: Bool
    let accessibilitySummary: String
}

struct MemoryPresentation: Equatable, Sendable {
    let level: MemoryPressureLevel
    let badgeTitle: String
    let usageLine: String?
    let swapLine: String?
    let accessibilitySummary: String
}

struct ThermalPresentation: Equatable, Sendable {
    let level: ThermalPressureLevel
    let badgeTitle: String
    let detailLine: String
    let accessibilitySummary: String
}

enum MacCareCleanupSummaryKind: Equatable, Sendable {
    case notScanned
    case scanning
    case empty
    case hasReclaimable
}

struct CleanupSummaryPresentation: Equatable, Sendable {
    let kind: MacCareCleanupSummaryKind
    let title: String
    let subtitle: String?
    let primaryActionTitle: String
    let safeSizeText: String?
    let reviewSizeText: String?
    let totalSizeText: String?
    let deepScanDeferredNote: String?
}

enum MacCareHomePresentationBuilder {
    static func make(
        snapshot: SystemStatusSnapshot,
        scanResult: CleanupScanResult?,
        cleanupPhase: CleanupPhase,
        memoryTrendSampleCount: Int,
        storageCompositionState: StorageCompositionLoadState = .idle,
        macCareAccessLevel: MacCareAccessLevel = .full,
        now: Date = Date()
    ) -> MacCareHomePresentation {
        let effective = applyDebugFixture(to: snapshot)
        let tone = deriveTone(from: effective)
        let issues = attentionIssues(from: effective)

        let headline: String
        var detail: String
        switch tone {
        case .normal:
            headline = "Mac 状态良好"
            detail = "没有需要立即处理的问题。"
        case .attention:
            headline = "Mac 需要关注"
            detail = issues.first ?? "部分系统指标需要留意。"
        }

        if macCareAccessLevel == .limited {
            detail = "当前提供有限的磁盘分析。" + (detail.isEmpty ? "" : " \(detail)")
        }

        return MacCareHomePresentation(
            tone: tone,
            headline: headline,
            detail: detail,
            lastCheckedText: relativeCheckText(from: effective.updatedAt, now: now),
            storage: makeStorage(
                from: effective,
                compositionState: storageCompositionState,
                macCareAccessLevel: macCareAccessLevel
            ),
            memory: makeMemory(from: effective),
            thermal: makeThermal(from: effective),
            cleanup: makeCleanup(
                scanResult: scanResult,
                phase: cleanupPhase,
                macCareAccessLevel: macCareAccessLevel
            ),
            showsMemoryTrend: memoryTrendSampleCount >= 2
        )
    }

    static func deriveTone(from snapshot: SystemStatusSnapshot) -> MacCareOverallTone {
        if snapshot.memory == .warning || snapshot.memory == .critical {
            return .attention
        }
        if snapshot.storageSeverity >= .warning {
            return .attention
        }
        if snapshot.thermal == .serious || snapshot.thermal == .critical {
            return .attention
        }
        if snapshot.thermal == .fair, snapshot.memory != .normal {
            return .attention
        }
        return .normal
    }

    static func attentionIssues(from snapshot: SystemStatusSnapshot) -> [String] {
        var issues: [String] = []
        switch snapshot.memory {
        case .warning:
            issues.append("内存压力升高，系统可能开始使用 Swap。")
        case .critical:
            issues.append("内存压力较高，建议关闭部分占用较大的应用。")
        case .normal:
            break
        }
        switch snapshot.storageSeverity {
        case .warning:
            issues.append("存储空间偏少，建议清理不需要的文件。")
        case .critical:
            issues.append("存储空间不足，可能影响系统稳定性。")
        case .normal, .notice:
            break
        }
        switch snapshot.thermal {
        case .fair:
            issues.append("散热负载略有升高。")
        case .serious:
            issues.append("散热负载较高，设备可能变慢。")
        case .critical:
            issues.append("散热负载很高，建议减轻当前工作负载。")
        case .nominal:
            break
        }
        return issues
    }

    private static func relativeCheckText(from date: Date?, now: Date) -> String? {
        guard let date else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        let relative = formatter.localizedString(for: date, relativeTo: now)
        return "上次更新 \(relative)"
    }

    private static func makeStorage(
        from snapshot: SystemStatusSnapshot,
        compositionState: StorageCompositionLoadState,
        macCareAccessLevel: MacCareAccessLevel
    ) -> StoragePresentation {
        let volume = snapshot.volumeName ?? "Macintosh HD"
        let title = "存储空间 (\(volume))"

        guard let available = snapshot.storageAvailableBytes,
              let total = snapshot.storageTotalBytes,
              total > 0
        else {
            return StoragePresentation(
                volumeTitle: title,
                availableText: nil,
                usedText: nil,
                usedFraction: nil,
                totalBytes: 0,
                usedBytes: 0,
                segments: [],
                legendSegments: [],
                compositionState: .unavailable,
                footnote: "暂时无法读取磁盘容量。",
                limitedAnalysisBadge: nil,
                limitedAnalysisFootnote: nil,
                showsFullScanAction: false,
                accessibilitySummary: "存储空间数据暂不可用。"
            )
        }

        let used = max(total - available, 0)
        let fraction = min(max(Double(used) / Double(total), 0), 1)
        let availableText = JoeyByteFormat.string(fromByteCount: available) + " 可用"
        let usedText = JoeyByteFormat.string(fromByteCount: used)
        let percent = Int((fraction * 100).rounded())

        let (donutSegments, legendSegments) = segmentsForStorage(
            total: total,
            available: available,
            used: used,
            compositionState: compositionState
        )

        var footnote: String? = snapshot.storageSeverity >= .warning
            ? "可用空间偏少"
            : "空间状态正常"

        let limitedBadge = macCareAccessLevel == .limited ? "有限分析" : nil
        let limitedFootnote = macCareAccessLevel == .limited
            ? "未开启完整磁盘访问，分类结果不完整。"
            : nil
        let showsFullScan = macCareAccessLevel == .limited
        if limitedFootnote != nil, footnote == "空间状态正常" {
            footnote = nil
        }

        var summary =
            "存储空间 \(volume)，已用 \(percent)%，可用 \(JoeyByteFormat.string(fromByteCount: available))。"
        if macCareAccessLevel == .limited {
            summary += " 当前为有限磁盘分析。"
        }

        return StoragePresentation(
            volumeTitle: title,
            availableText: availableText,
            usedText: usedText,
            usedFraction: fraction,
            totalBytes: total,
            usedBytes: used,
            segments: donutSegments,
            legendSegments: legendSegments,
            compositionState: compositionState,
            footnote: footnote,
            limitedAnalysisBadge: limitedBadge,
            limitedAnalysisFootnote: limitedFootnote,
            showsFullScanAction: showsFullScan,
            accessibilitySummary: summary
        )
    }

    private static func segmentsForStorage(
        total: Int64,
        available: Int64,
        used: Int64,
        compositionState: StorageCompositionLoadState
    ) -> ([MacCareStorageSegment], [MacCareStorageSegment]) {
        if case .loaded(let composition) = compositionState {
            let donut = composition.categories.map { item in
                MacCareStorageSegment(
                    category: item.category,
                    title: item.category.displayName,
                    byteCount: item.bytes,
                    fractionOfTotal: StorageCompositionBuilder.fraction(of: item.bytes, in: total)
                )
            }
            let legend = composition.usedCategories.map { item in
                MacCareStorageSegment(
                    category: item.category,
                    title: item.category.displayName,
                    byteCount: item.bytes,
                    fractionOfTotal: StorageCompositionBuilder.fraction(of: item.bytes, in: total)
                )
            }
            return (donut, legend)
        }

        let fallback = [
            MacCareStorageSegment(
                category: .other,
                title: "已用",
                byteCount: used,
                fractionOfTotal: StorageCompositionBuilder.fraction(of: used, in: total)
            ),
            MacCareStorageSegment(
                category: .available,
                title: StorageCompositionCategory.available.displayName,
                byteCount: available,
                fractionOfTotal: StorageCompositionBuilder.fraction(of: available, in: total)
            ),
        ]
        let legend: [MacCareStorageSegment] = compositionState == .loading
            ? []
            : [fallback[0]]
        return (fallback, legend)
    }

    private static func makeMemory(from snapshot: SystemStatusSnapshot) -> MemoryPresentation {
        let badge: String
        switch snapshot.memory {
        case .normal: badge = "正常"
        case .warning: badge = "需要注意"
        case .critical: badge = "较高"
        }

        let usageLine: String?
        if let used = snapshot.usedMemoryBytes, let physical = snapshot.physicalMemoryBytes, physical > 0 {
            usageLine =
                "\(JoeyByteFormat.string(fromByteCount: used)) / \(JoeyByteFormat.string(fromByteCount: physical)) 统一内存"
        } else {
            usageLine = nil
        }

        let swapLine: String?
        if let swap = snapshot.swapUsedBytes {
            swapLine = "Swap \(JoeyByteFormat.string(fromByteCount: swap))"
        } else {
            swapLine = nil
        }

        var summary = "内存压力 \(badge)。"
        if let usageLine { summary += " \(usageLine)。" }
        if let swapLine { summary += " \(swapLine)。" }

        return MemoryPresentation(
            level: snapshot.memory,
            badgeTitle: badge,
            usageLine: usageLine,
            swapLine: swapLine,
            accessibilitySummary: summary
        )
    }

    private static func makeThermal(from snapshot: SystemStatusSnapshot) -> ThermalPresentation {
        let badge: String
        let detail: String
        switch snapshot.thermal {
        case .nominal:
            badge = "正常"
            detail = "散热状态正常 · 系统未报告异常热负载"
        case .fair:
            badge = "略高"
            detail = "系统报告轻度热负载 · 风扇与温度详情暂不可用"
        case .serious:
            badge = "需要关注"
            detail = "系统报告较高热负载 · 建议减轻当前任务"
        case .critical:
            badge = "较高"
            detail = "系统报告高热负载 · 建议尽快减轻负载"
        }

        return ThermalPresentation(
            level: snapshot.thermal,
            badgeTitle: badge,
            detailLine: detail,
            accessibilitySummary: "散热状态 \(badge)。\(detail)"
        )
    }

    private static func makeCleanup(
        scanResult: CleanupScanResult?,
        phase: CleanupPhase,
        macCareAccessLevel: MacCareAccessLevel
    ) -> CleanupSummaryPresentation {
        let deferredNote = deepScanDeferredNote(scanResult: scanResult, accessLevel: macCareAccessLevel)

        switch phase {
        case .scanning:
            return CleanupSummaryPresentation(
                kind: .scanning,
                title: "正在扫描可清理内容",
                subtitle: "请稍候，扫描完成后会显示可释放空间。",
                primaryActionTitle: "查看清理项",
                safeSizeText: nil,
                reviewSizeText: nil,
                totalSizeText: nil,
                deepScanDeferredNote: deferredNote
            )
        case .idle, .ready, .cleaning, .completed, .failed:
            break
        }

        guard let scanResult else {
            return CleanupSummaryPresentation(
                kind: .notScanned,
                title: "扫描可清理内容",
                subtitle: "查找可安全处理或需要你确认的文件。",
                primaryActionTitle: "开始扫描",
                safeSizeText: nil,
                reviewSizeText: nil,
                totalSizeText: nil,
                deepScanDeferredNote: deferredNote
            )
        }

        if scanResult.candidates.isEmpty {
            return CleanupSummaryPresentation(
                kind: .empty,
                title: "暂无可清理项",
                subtitle: "当前未发现允许范围内的可清理文件。",
                primaryActionTitle: "查看清理项",
                safeSizeText: nil,
                reviewSizeText: nil,
                totalSizeText: nil,
                deepScanDeferredNote: deferredNote
            )
        }

        let total = JoeyByteFormat.string(fromByteCount: scanResult.totalSize)
        let safe = JoeyByteFormat.string(fromByteCount: scanResult.safeSize)
        let review = JoeyByteFormat.string(fromByteCount: scanResult.reviewSize)
        var subtitle = "扫描发现一些可以安全处理或需要确认的文件"
        if let deferredNote {
            subtitle += " \(deferredNote)"
        }

        return CleanupSummaryPresentation(
            kind: .hasReclaimable,
            title: "可释放 \(total)",
            subtitle: subtitle,
            primaryActionTitle: "查看清理项",
            safeSizeText: safe,
            reviewSizeText: review,
            totalSizeText: total,
            deepScanDeferredNote: deferredNote
        )
    }

    private static func deepScanDeferredNote(
        scanResult: CleanupScanResult?,
        accessLevel: MacCareAccessLevel
    ) -> String? {
        guard accessLevel == .limited else { return nil }
        if scanResult?.deepScanDeferred == true {
            return "已完成基础扫描；开启完全磁盘访问后可进行完整扫描。"
        }
        return nil
    }

    #if DEBUG
    private static func applyDebugFixture(to snapshot: SystemStatusSnapshot) -> SystemStatusSnapshot {
        MacCareHomeDebugPresentation.injected?.adjustedSnapshot(snapshot) ?? snapshot
    }
    #else
    private static func applyDebugFixture(to snapshot: SystemStatusSnapshot) -> SystemStatusSnapshot {
        snapshot
    }
    #endif
}

#if DEBUG
enum MacCareHomeDebugPresentation: String, Sendable {
    case normal
    case attention

    static var injected: MacCareHomeDebugPresentation? {
        guard let raw = DebugStateInjector.macCareHomePresentationRaw() else { return nil }
        return MacCareHomeDebugPresentation(rawValue: raw)
    }

    func adjustedSnapshot(_ snapshot: SystemStatusSnapshot) -> SystemStatusSnapshot {
        switch self {
        case .normal:
            return snapshot
        case .attention:
            return SystemStatusSnapshot(
                thermal: snapshot.thermal == .nominal ? .fair : snapshot.thermal,
                memory: .warning,
                storageAvailableBytes: snapshot.storageAvailableBytes,
                storageTotalBytes: snapshot.storageTotalBytes,
                storageSeverity: max(snapshot.storageSeverity, .warning),
                physicalMemoryBytes: snapshot.physicalMemoryBytes,
                usedMemoryBytes: snapshot.usedMemoryBytes,
                swapUsedBytes: snapshot.swapUsedBytes,
                volumeName: snapshot.volumeName,
                updatedAt: snapshot.updatedAt
            )
        }
    }
}
#endif
