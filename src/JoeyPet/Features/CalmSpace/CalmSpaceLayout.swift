import CoreGraphics

/// Geometry for the immersive main window.
///
/// All values derive from the window/content size; nothing is pinned to a design
/// screenshot. The orb is always a circle, and the status block is placed below it
/// with a reserved height so it can never collide with the bottom controls.
struct CalmSpaceLayout: Equatable {
    let size: CGSize
    let compact: Bool

    let horizontalMargin: CGFloat
    let topInset: CGFloat
    let bottomInset: CGFloat

    let orbDiameter: CGFloat
    let orbCenter: CGPoint

    let orbToStatusGap: CGFloat
    let statusTop: CGFloat
    let statusWidth: CGFloat
    let statusReservedHeight: CGFloat
    let statusBottom: CGFloat

    let dockHeight: CGFloat
    let modeSwitchDiameter: CGFloat
    let modeSwitchExpandedWidth: CGFloat
    let bottomControlsHeight: CGFloat
    let bottomControlsTop: CGFloat

    /// True when the reserved status block and the bottom controls do not overlap.
    var controlsDoNotOverlap: Bool {
        statusBottom <= bottomControlsTop
    }

    init(size: CGSize) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        self.size = CGSize(width: width, height: height)

        // Measured, not a single arbitrary breakpoint: below this width the three
        // labelled dock entries plus the expanded mode switch start to crowd.
        let compact = width < 760 || height < 520
        self.compact = compact

        let horizontalMargin: CGFloat = compact ? 22 : Self.clamp(width * 0.05, 30, 48)
        let topInset: CGFloat = compact ? 30 : 34
        let bottomInset: CGFloat = compact ? 18 : 24
        let dockHeight: CGFloat = compact ? 36 : 38
        let modeSwitchDiameter: CGFloat = compact ? 32 : 34
        let modeSwitchExpandedWidth: CGFloat = compact ? 154 : 178
        let statusReservedHeight: CGFloat = compact ? 100 : 108
        let orbToStatusGap: CGFloat = compact ? 20 : 30
        let bottomControlsHeight: CGFloat = max(dockHeight, modeSwitchDiameter)
        let reservedBottom: CGFloat = bottomInset + bottomControlsHeight

        let availableOrbHeight: CGFloat = max(
            150,
            height - topInset - orbToStatusGap - statusReservedHeight - reservedBottom
        )
        let maxOrbDiameter: CGFloat = min(compact ? 280 : 330, width - 2 * horizontalMargin)
        let proposedOrb: CGFloat = min(width * 0.30, availableOrbHeight * 0.80)
        let orbDiameter: CGFloat = Self.clamp(proposedOrb, 140, maxOrbDiameter)

        let contentBlockHeight: CGFloat = orbDiameter + orbToStatusGap + statusReservedHeight
        let freeVerticalSpace: CGFloat = max(0, height - topInset - reservedBottom - contentBlockHeight)
        // Sit the orb slightly above the optical centre; extra room becomes calm
        // breathing space at the bottom instead of pushing the text to the edge.
        let blockTop: CGFloat = topInset + freeVerticalSpace * 0.42

        let statusWidth: CGFloat = min(
            width - 2 * horizontalMargin,
            compact ? 520 : 560
        )

        self.horizontalMargin = horizontalMargin
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.orbDiameter = orbDiameter
        self.orbCenter = CGPoint(x: width / 2, y: blockTop + orbDiameter / 2)
        self.orbToStatusGap = orbToStatusGap
        self.statusTop = blockTop + orbDiameter + orbToStatusGap
        self.statusWidth = max(statusWidth, 240)
        self.statusReservedHeight = statusReservedHeight
        self.statusBottom = statusTop + statusReservedHeight
        self.dockHeight = dockHeight
        self.modeSwitchDiameter = modeSwitchDiameter
        self.modeSwitchExpandedWidth = modeSwitchExpandedWidth
        self.bottomControlsHeight = bottomControlsHeight
        self.bottomControlsTop = height - bottomInset - bottomControlsHeight
    }

    private static func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), max(lower, upper))
    }
}
