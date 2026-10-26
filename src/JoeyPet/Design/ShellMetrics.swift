import CoreGraphics

enum ShellMetrics {
    static let defaultWindowWidth: CGFloat = 800
    static let defaultWindowHeight: CGFloat = 560
    static let minimumWindowWidth: CGFloat = 680
    /// Window frame minimum. macOS adds the native titlebar/traffic-light area on top of
    /// the content minimum below (32 pt on macOS 14+).
    static let minimumWindowHeight: CGFloat = 512
    /// SwiftUI content minimum below the titlebar. The full-bleed canvas ignores the safe
    /// area, so it is laid out at the frame size (>= 512 pt high).
    static let minimumWindowContentHeight: CGFloat = 480

    /// Joey Stage pattern width (Work Rhythm and other feature-local layouts—not a global shell column).
    static let stageIdealWidth: CGFloat = 320
    static let contentIdealWidth: CGFloat = 480
    static let settingsSidebarIdealWidth: CGFloat = 200
    static let stageLayoutPriority: Double = 320
    static let contentLayoutPriority: Double = 480

    static let contentMargin: CGFloat = 20
    static let stageCornerRadius: CGFloat = 8

    /// Stitch Settings freeze — 44pt titlebar, 12/14pt toolbar typography.
    static let settingsToolbarHeight: CGFloat = 44
    static let settingsToolbarTitleSize: CGFloat = 14
}
