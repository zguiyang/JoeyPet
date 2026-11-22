import Foundation

/// Plain facts shown in the nest and the rhythm reflection.
/// It intentionally has no score, streak or target fields.
struct CompanionSummary: Equatable, Sendable {
    /// Seconds of companionship the user actively started today.
    var todayCompanionship: TimeInterval
    /// Completed short breaks today.
    var todayBreaks: Int
    /// Completed breaks for each day of the current week, Monday first.
    var weekBreakCounts: [Int]

    nonisolated static let empty = CompanionSummary(
        todayCompanionship: 0,
        todayBreaks: 0,
        weekBreakCounts: Array(repeating: 0, count: 7)
    )

    var weekBreakTotal: Int {
        weekBreakCounts.reduce(0, +)
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
