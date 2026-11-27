import Foundation

/// Shared visual growth ladder for the nest pot and the week-garden columns.
///
/// **Hard visual ceiling:** `.full` is the last stage. Counters may keep rising,
/// but drawing never goes past the saturated art for that surface.
enum PlantGrowthStage: Int, Equatable, Sendable, Comparable {
    case seed = 0
    case sprout = 1
    case young = 2
    /// Saturated look — layout ceiling for that surface.
    case full = 3

    static func < (lhs: PlantGrowthStage, rhs: PlantGrowthStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Map a break count through fixed thresholds. Values at/above `fullAt` stay `.full`.
    static func from(breaks: Int, sproutAt: Int, youngAt: Int, fullAt: Int) -> PlantGrowthStage {
        let count = max(0, breaks)
        if count >= fullAt { return .full }
        if count >= youngAt { return .young }
        if count >= sproutAt { return .sprout }
        return .seed
    }
}

/// Nest pot growth from **lifetime** completed breaks — irreversible, slow.
///
/// Layout box in room design points (1080×680): pot around x 96…146, foliage top
/// ≈ y 366 at `.full`; clock centre is (250, 140). `.full` reuses the pre-growth
/// pot art and must never be scaled up.
enum NestPlantStage {
    /// First rest still shows a sprout so growth is honest and visible.
    static let sproutAtBreaks = 1
    /// About several light workdays of rests.
    static let youngAtBreaks = 5
    /// Roughly one to two weeks of gentle use before the pot looks finished.
    static let saturatedAtBreaks = 15

    static func from(lifetimeBreaks: Int) -> PlantGrowthStage {
        PlantGrowthStage.from(
            breaks: lifetimeBreaks,
            sproutAt: sproutAtBreaks,
            youngAt: youngAtBreaks,
            fullAt: saturatedAtBreaks
        )
    }
}

/// Per-day column in 节奏回顾. May look larger than the nest pot at `.full` (tree),
/// but still saturates — never scales with unbounded day counts.
enum GardenDayPlantStage {
    static let sproutAtBreaks = 1
    /// A fuller day before the tall sprout.
    static let youngAtBreaks = 3
    /// Busy day → small tree; further rests that day do not enlarge the art.
    static let saturatedAtBreaks = 5

    static func from(dayBreaks: Int) -> PlantGrowthStage {
        PlantGrowthStage.from(
            breaks: dayBreaks,
            sproutAt: sproutAtBreaks,
            youngAt: youngAtBreaks,
            fullAt: saturatedAtBreaks
        )
    }
}

/// Plain facts shown in the nest and the rhythm reflection.
/// It intentionally has no score, streak or target fields.
struct CompanionSummary: Equatable, Sendable {
    /// Seconds of companionship the user actively started today.
    var todayCompanionship: TimeInterval
    /// Completed short breaks today.
    var todayBreaks: Int
    /// Completed breaks for each day of the current week, Monday first.
    var weekBreakCounts: [Int]
    /// All-time completed short breaks; feeds irreversible nest pot growth.
    var lifetimeBreaks: Int

    nonisolated static let empty = CompanionSummary(
        todayCompanionship: 0,
        todayBreaks: 0,
        weekBreakCounts: Array(repeating: 0, count: 7),
        lifetimeBreaks: 0
    )

    var weekBreakTotal: Int {
        weekBreakCounts.reduce(0, +)
    }

    var nestPlantStage: PlantGrowthStage {
        NestPlantStage.from(lifetimeBreaks: lifetimeBreaks)
    }

    /// `2 小时 10 分`; empty string when no companionship has started.
    var todayCompanionshipText: String {
        let minutes = Int(todayCompanionship / 60)
        guard minutes > 0 else { return "" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0, remainder > 0 {
            return "\(hours) 小时 \(remainder) 分"
        }
        if hours > 0 {
            return "\(hours) 小时"
        }
        return "\(remainder) 分"
    }
}
