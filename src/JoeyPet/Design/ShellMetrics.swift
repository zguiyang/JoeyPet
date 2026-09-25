import CoreGraphics

enum ShellMetrics {
    static let defaultWindowWidth: CGFloat = 800
    static let defaultWindowHeight: CGFloat = 560
    static let minimumWindowWidth: CGFloat = 680
    static let minimumWindowHeight: CGFloat = 480

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
