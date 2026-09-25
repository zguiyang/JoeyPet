import CoreGraphics

/// Stitch Mac Care Home freeze layout metrics (800×560 content body).
enum MacCareHomeMetrics {
    /// Extra horizontal inset so 20pt shell margin + 4pt ≈ Stitch 24pt (`space-xl`).
    static let horizontalInset: CGFloat = 4
    static let topInset: CGFloat = 18
    static let bottomInset: CGFloat = 16

    static let sectionGap: CGFloat = 12
    static let maintenanceGap: CGFloat = 8

    static let metricsGridHeight: CGFloat = 216
    static let cardCornerRadius: CGFloat = 8
    static let cardPadding: CGFloat = 12

    static let statusDotSize: CGFloat = 10
    static let headlineFontSize: CGFloat = 22
    static let headlineLineSpacing: CGFloat = 28

    static let donutDiameter: CGFloat = 112
    static let donutStroke: CGFloat = 8

    static let memoryTrendHeight: CGFloat = 32

    static let cleanupIconSize: CGFloat = 36
    static let cleanupRowPadding: CGFloat = 14
    static let appsRowVerticalPadding: CGFloat = 8
    static let appsRowHorizontalPadding: CGFloat = 14
}
