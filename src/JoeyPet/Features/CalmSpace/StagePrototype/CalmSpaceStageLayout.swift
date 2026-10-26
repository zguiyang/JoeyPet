import CoreGraphics

#if DEBUG

/// Geometry for the isolated Mac Care Stage prototype.
///
/// Everything derives from the window size — no pinned coordinates, no whole-view
/// scaling. It wraps the production `CalmSpaceLayout` so the bottom dock and the
/// bottom-right mode switch sit at exactly their production positions, then layers the
/// Stage-specific geometry (body diameter, info block, connector, activity slot, chip)
/// on top. Three tiers: compact / regular / large.
struct CalmSpaceStageLayout {
    let size: CGSize

    /// Production layout reused for margins + bottom controls (dock, mode switch).
    let base: CalmSpaceLayout

    let compact: Bool
    let large: Bool

    // Stage body.
    let bodyDiameter: CGFloat
    let bodyCenter: CGPoint

    // Info block.
    let infoWidth: CGFloat
    let infoTop: CGFloat
    /// Design height budget for a *normal* copy block: regular ≤ 150, compact ≤ 128.
    let infoDesignBudget: CGFloat
    /// Vertical space actually reserved — the design budget, widened when the long-copy
    /// worst case is taller so copy can never reach the dock.
    let infoReservedHeight: CGFloat
    let infoBottom: CGFloat

    // Info internals.
    let connectorHeight: CGFloat
    let activitySlotHeight: CGFloat   // fixed 18–20
    let chipHeight: CGFloat           // 28–30
    let chipWidth: CGFloat
    let progressLineWidth: CGFloat    // 150–190

    let headlineSize: CGFloat
    let detailSize: CGFloat
    let metaSize: CGFloat

    // Prototype badge (top-trailing).
    let badgeTop: CGFloat
    let badgeTrailing: CGFloat

    /// Minimum clear space the info block keeps above the bottom controls.
    private var dockGap: CGFloat { compact ? 16 : 24 }

    /// True when the reserved info block clears the bottom controls by `dockGap`.
    var infoClearsBottomControls: Bool {
        infoBottom <= base.bottomControlsTop - dockGap
    }

    init(size: CGSize) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        self.size = CGSize(width: width, height: height)
        self.base = CalmSpaceLayout(size: size)

        // Tiering. `large` is intentionally a distinct upper tier so a big window gets a
        // genuinely bigger Stage instead of the old "subject too small / content too
        // concentrated" result. Measured, not a single arbitrary breakpoint.
        let compact = width < 760 || height < 560
        let large = width >= 1400 || height >= 820
        self.compact = compact
        self.large = large

        let topInset: CGFloat = compact ? 26 : 32
        let infoToBodyGap: CGFloat = compact ? 14 : 20
        let connectorHeight: CGFloat = compact ? 14 : 20
        let activitySlotHeight: CGFloat = compact ? 18 : 20
        let chipHeight: CGFloat = compact ? 28 : 30
        let infoDesignBudget: CGFloat = compact ? 128 : 150
        let dockClear: CGFloat = compact ? 16 : 24
        let headlineSize: CGFloat = compact ? 22 : 26
        let detailSize: CGFloat = compact ? 12.5 : 14

        // Worst-case info block: a two-line headline + two-line detail + action chip +
        // reserved activity slot, plus every gap. The body budget reserves this so even
        // long copy stays clear of the dock, while a normal block simply leaves calm
        // space below it.
        let worstCaseBlock = connectorHeight
            + (compact ? 9.0 : 12.0)
            + 2 * headlineSize * 1.25
            + (compact ? 7.0 : 9.0)
            + (2 * detailSize * 1.3 + 3)
            + (compact ? 8.0 : 10.0)
            + activitySlotHeight
            + (compact ? 8.0 : 10.0)
            + chipHeight
        let infoReservedHeight = max(infoDesignBudget, worstCaseBlock)

        // Vertical budget for the body, keeping the info block and a clear dock gap.
        let reservedBottom = base.bottomInset + base.bottomControlsHeight
        let availableBodyHeight =
            height - topInset - infoToBodyGap - infoReservedHeight - dockClear - reservedBottom

        // Width fraction per tier keeps the body proportionate without letting a wide
        // window blow it up past the intended range. On short windows the available
        // height binds first and the body shrinks rather than colliding with the dock.
        let widthFraction: CGFloat = large ? 0.27 : 0.30
        let tierMax: CGFloat = large ? 440 : (compact ? 240 : 340)
        let hardMin: CGFloat = 180   // physical floor; fit always wins over the tier target

        let proposed = min(width * widthFraction, availableBodyHeight)
        let bodyDiameter = Self.clamp(proposed, hardMin...tierMax)

        // Sit the Stage slightly above the optical centre; leftover room becomes calm
        // breathing space at the bottom rather than pushing copy to the edge. A large
        // window lifts the subject a touch higher so the composition breathes.
        let contentBlockHeight = bodyDiameter + infoToBodyGap + infoReservedHeight
        let freeVerticalSpace = max(0, height - topInset - reservedBottom - dockClear - contentBlockHeight)
        let topFactor: CGFloat = large ? 0.50 : 0.34
        let blockTop = topInset + freeVerticalSpace * topFactor

        self.bodyDiameter = bodyDiameter
        self.bodyCenter = CGPoint(x: width / 2, y: blockTop + bodyDiameter / 2)

        // Info block: centred, width capped so a wide window never stretches the copy.
        let horizontalMargin = base.horizontalMargin
        let infoWidth = min(width - 2 * horizontalMargin, compact ? 460 : 520)
        self.infoWidth = max(infoWidth, 260)
        self.infoTop = blockTop + bodyDiameter + infoToBodyGap
        self.infoDesignBudget = infoDesignBudget
        self.infoReservedHeight = infoReservedHeight
        self.infoBottom = infoTop + infoReservedHeight

        self.connectorHeight = connectorHeight
        self.activitySlotHeight = activitySlotHeight
        self.chipHeight = chipHeight
        self.chipWidth = compact ? 132 : 148
        self.progressLineWidth = compact ? 150 : 176

        self.headlineSize = headlineSize
        self.detailSize = detailSize
        self.metaSize = compact ? 10.5 : 11

        self.badgeTop = 20
        self.badgeTrailing = 20
    }

    private static func clamp(_ value: CGFloat, _ range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

#endif
