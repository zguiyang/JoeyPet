import Foundation

#if DEBUG

// MARK: - MOCK content
//
// Every countdown, label and statistic here is MOCK (`StagePrototypeFixtures`). None of it
// comes from a real timer, session store, or persistence — it exists only so the Stage
// design can be validated against representative values. Nothing here is reachable from a
// production path.

/// The five Work Rhythm Stage phases.
enum WorkRhythmPhase: String, CaseIterable, Equatable {
    case idle, focus, paused, rest, complete
}

/// A Stage action button. `primary` is the restrained accent-tinted entry (start / resume /
/// again), `ghost` a quiet pill (pause / skip), `text` a tertiary text button (end).
struct WorkRhythmAction: Equatable {
    enum Kind: Equatable { case primary, ghost, text }
    let title: String
    let kind: Kind
}

/// One immutable MOCK snapshot of the Work Rhythm Stage.
struct WorkRhythmStageContent: Equatable {
    let phase: WorkRhythmPhase

    // Countdown. `remainingSeconds == nil` means no timer is running (idle).
    let remainingSeconds: TimeInterval?
    let totalSeconds: TimeInterval
    // Idle central read-out (current local time); nil otherwise.
    let clockText: String?
    // Complete central read-out is words, not digits.
    let wordsText: String?

    let phaseLabel: String?
    let showPhaseDot: Bool
    let secondary: String?
    let showSecondDot: Bool      // idle real-time second dot on the bezel

    let primary: WorkRhythmAction?
    let secondaryAction: WorkRhythmAction?

    /// Periphery stat (bottom-right, above the mode switch); nil on compact / idle / rest.
    let todayStat: String?

    var isPaused: Bool { phase == .paused }
    var showsProgressArc: Bool { remainingSeconds != nil }

    /// Elapsed fraction 0...1 for the progress arc.
    var progress: Double {
        guard let remaining = remainingSeconds, totalSeconds > 0 else {
            return phase == .complete ? 1 : 0
        }
        return min(max((totalSeconds - remaining) / totalSeconds, 0), 1)
    }

    /// The central read-out: a clock (idle), words (complete), or a countdown.
    var centerText: String {
        if let clock = clockText { return clock }
        if let words = wordsText { return words }
        guard let remaining = remainingSeconds else { return "" }
        return WorkRhythmStageFixtures.formatDuration(remaining)
    }
}

enum WorkRhythmStageFixtures {
    /// MOCK content for a Work Rhythm prototype state.
    ///
    /// - Parameters:
    ///   - state: prototype state (idle / focus / paused / rest / complete).
    ///   - longCopy: focus stress variant with a long countdown (`1:02:45`) and copy.
    static func content(
        state: CalmSpaceStagePrototypeState,
        longCopy: Bool = false
    ) -> WorkRhythmStageContent {
        switch state {
        case .focus:
            if longCopy {
                return WorkRhythmStageContent(
                    phase: .focus,
                    remainingSeconds: 3765,          // 1:02:45
                    totalSeconds: 3900,              // 65 min preset
                    clockText: nil,
                    wordsText: nil,
                    phaseLabel: "专注中",
                    showPhaseDot: true,
                    secondary: "第 3 个专注 · 65 分钟预设，中途可暂停，结束后自动进入休息。",
                    showSecondDot: false,
                    primary: WorkRhythmAction(title: "暂停", kind: .ghost),
                    secondaryAction: WorkRhythmAction(title: "结束", kind: .text),
                    todayStat: "今日专注 1 小时 20 分"
                )
            }
            return WorkRhythmStageContent(
                phase: .focus,
                remainingSeconds: 1008,             // 16:48 — 33% elapsed, so the arc reads as real progress
                totalSeconds: 1500,                 // 25 min
                clockText: nil,
                wordsText: nil,
                phaseLabel: "专注中",
                showPhaseDot: true,
                secondary: "第 2 个专注 · 25 分钟",
                showSecondDot: false,
                primary: WorkRhythmAction(title: "暂停", kind: .ghost),
                secondaryAction: WorkRhythmAction(title: "结束", kind: .text),
                todayStat: "今日专注 1 小时 20 分"
            )
        case .paused:
            return WorkRhythmStageContent(
                phase: .paused,
                remainingSeconds: 1008,             // 16:48 (8:12 elapsed of 25:00)
                totalSeconds: 1500,
                clockText: nil,
                wordsText: nil,
                phaseLabel: "已暂停",
                showPhaseDot: true,
                secondary: "已专注 8 分 12 秒",
                showSecondDot: false,
                primary: WorkRhythmAction(title: "继续", kind: .primary),
                secondaryAction: WorkRhythmAction(title: "结束", kind: .text),
                todayStat: "今日专注 1 小时 20 分"
            )
        case .rest:
            return WorkRhythmStageContent(
                phase: .rest,
                remainingSeconds: 252,              // 04:12
                totalSeconds: 300,                  // 5 min
                clockText: nil,
                wordsText: nil,
                phaseLabel: "休息中",
                showPhaseDot: true,
                secondary: "休息 5 分钟",
                showSecondDot: false,
                primary: WorkRhythmAction(title: "跳过休息", kind: .ghost),
                secondaryAction: WorkRhythmAction(title: "结束", kind: .text),
                todayStat: nil
            )
        case .complete:
            return WorkRhythmStageContent(
                phase: .complete,
                remainingSeconds: 0,
                totalSeconds: 1500,
                clockText: nil,
                wordsText: "专注完成",
                phaseLabel: nil,
                showPhaseDot: false,
                secondary: "25 分钟 · 第 2 个专注",
                showSecondDot: false,
                primary: WorkRhythmAction(title: "再来一次", kind: .primary),
                secondaryAction: WorkRhythmAction(title: "休息一下", kind: .ghost),
                todayStat: nil
            )
        default: // .idle
            return WorkRhythmStageContent(
                phase: .idle,
                remainingSeconds: nil,
                totalSeconds: 1500,
                clockText: Self.clockText(),
                wordsText: nil,
                phaseLabel: "现在",
                showPhaseDot: false,
                secondary: "25 分钟专注 · 5 分钟休息",
                showSecondDot: true,
                primary: WorkRhythmAction(title: "开始专注", kind: .primary),
                secondaryAction: nil,
                todayStat: nil
            )
        }
    }

    /// Current local time as `HH:mm` for the idle read-out.
    static func clockText(date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// `1:02:45` when ≥ 1 h, otherwise `mm:ss` (e.g. `24:36`).
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        if total >= 3600 {
            let h = total / 3600
            let m = (total % 3600) / 60
            let s = total % 60
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}

#endif
