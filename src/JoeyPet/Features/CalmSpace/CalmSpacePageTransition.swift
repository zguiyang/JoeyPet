import CoreGraphics
import Foundation

/// Pure geometry/animation model for the Calm Space two-page paging container.
/// No SwiftUI, no AppKit: keeps the transition rules testable.
struct CalmSpacePageTransition {
    static let duration: TimeInterval = 0.45

    /// Horizontal offset for `mode`'s page while `currentMode` is displayed.
    /// macCare parks at 0 when current and slides off to `-width`; workRhythm parks at
    /// 0 when current and slides off to `+width`. Reduce Motion parks both at 0.
    /// The width is clamped at 0 so a pre-layout pass can never produce NaN or a
    /// wrong direction.
    static func offsetX(
        for mode: AppMode,
        currentMode: AppMode,
        width: CGFloat,
        reduceMotion: Bool
    ) -> CGFloat {
        let clampedWidth = max(width, 0)
        if reduceMotion { return 0 }
        switch mode {
        case .macCare: return currentMode == .macCare ? 0 : -clampedWidth
        case .workRhythm: return currentMode == .workRhythm ? 0 : clampedWidth
        }
    }

    /// Opacity for `mode`'s page (cross-fade when Reduce Motion is on, 1 otherwise).
    static func opacity(
        for mode: AppMode,
        currentMode: AppMode,
        reduceMotion: Bool
    ) -> Double {
        guard reduceMotion else { return 1 }
        return mode == currentMode ? 1 : 0
    }

    /// Whether `mode`'s SpriteKit scene may render: always for the current page, and
    /// for both pages while a transition is in flight so neither shows a frozen frame.
    static func isSceneActive(for mode: AppMode, currentMode: AppMode, isTransitioning: Bool) -> Bool {
        mode == currentMode || isTransitioning
    }

    /// Mode a mode-switch request lands on (strict toggle of the two-page set).
    static func landingMode(from currentMode: AppMode) -> AppMode {
        switch currentMode {
        case .macCare: return .workRhythm
        case .workRhythm: return .macCare
        }
    }
}
