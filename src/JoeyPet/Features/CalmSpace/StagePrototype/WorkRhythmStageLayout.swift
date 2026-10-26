import CoreGraphics

#if DEBUG

/// Geometry for the Work Rhythm "time instrument" Stage.
///
/// Everything derives from the window size — no pinned coordinates, no whole-view
/// scaling. It wraps the production `CalmSpaceLayout` so the bottom dock and mode switch
/// sit at their production positions, then layers the device geometry on top: a central
/// ring device sized from the available height, an action row directly beneath it, and a
/// periphery stat above the mode switch. Three tiers: compact / regular / large.
struct WorkRhythmStageLayout {
    let size: CGSize

    /// Production layout reused for margins + bottom controls.
    let base: CalmSpaceLayout

    let compact: Bool
    let large: Bool

    // Device.
    let deviceDiameter: CGFloat
    let deviceCenter: CGPoint
    let bezelRadius: CGFloat    // == deviceDiameter / 2
    let trackRadius: CGFloat    // bezelRadius − 10

    // Central type.
    let timeFontSize: CGFloat   // rule-based from the device size
    let phaseLabelSize: CGFloat
    let secondarySize: CGFloat

    // Action row (directly under the device).
    let actionRowHeight: CGFloat
    let actionRowTop: CGFloat
    let actionRowBottom: CGFloat

    /// Minimum clear space the action row keeps above the bottom controls.
    private var dockGap: CGFloat { compact ? 12 : 16 }

    var deviceBottom: CGFloat { deviceCenter.y + deviceDiameter / 2 }

    /// True when the action row clears the bottom controls by `dockGap`.
    var actionClearsBottomControls: Bool {
        actionRowBottom <= base.bottomControlsTop - dockGap
    }

    init(size: CGSize) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        self.size = CGSize(width: width, height: height)
        self.base = CalmSpaceLayout(size: size)

        let compact = width < 760 || height < 560
        let large = width >= 1400 || height >= 820
        self.compact = compact
        self.large = large

        let topInset: CGFloat = compact ? 26 : 32
        let actionToDeviceGap: CGFloat = compact ? 16 : 20
        let actionRowHeight: CGFloat = compact ? 35 : 38
        let dockClear: CGFloat = compact ? 12 : 16

        // Vertical budget for the device: leave the action row, its gap and a clear dock
        // gap. On short windows this binds and the device shrinks rather than colliding.
        let reservedBottom = base.bottomInset + base.bottomControlsHeight
        let availableDeviceHeight =
            height - topInset - actionToDeviceGap - actionRowHeight - dockClear - reservedBottom

        // Width fraction per tier; the device is scaled up on big windows, never the whole
        // view. Ranges: compact 220–250, regular 340–380, large 400–440.
        let widthFraction: CGFloat = compact ? 0.33 : (large ? 0.26 : 0.35)
        let tierMax: CGFloat = compact ? 250 : (large ? 440 : 380)
        let hardMin: CGFloat = 200   // physical floor; fit always wins over the tier target

        let proposed = min(width * widthFraction, availableDeviceHeight)
        let deviceDiameter = Self.clamp(proposed, hardMin...tierMax)

        // Sit the device slightly above optical centre; leftover room becomes calm space.
        let contentBlockHeight = deviceDiameter + actionToDeviceGap + actionRowHeight
        let freeVerticalSpace = max(0, height - topInset - reservedBottom - dockClear - contentBlockHeight)
        let topFactor: CGFloat = compact ? 0.34 : 0.38
        let blockTop = topInset + freeVerticalSpace * topFactor

        self.deviceDiameter = deviceDiameter
        self.deviceCenter = CGPoint(x: width / 2, y: blockTop + deviceDiameter / 2)
        self.bezelRadius = deviceDiameter / 2
        self.trackRadius = deviceDiameter / 2 - 10

        // Central digits scale with the device (rule-based, not a whole-view scale):
        // compact ~44, regular ~59, large ~66 pt.
        self.timeFontSize = Self.clamp(deviceDiameter * 0.165, 44...66)
        self.phaseLabelSize = compact ? 11.5 : 12
        self.secondarySize = 11

        self.actionRowHeight = actionRowHeight
        self.actionRowTop = blockTop + deviceDiameter + actionToDeviceGap
        self.actionRowBottom = self.actionRowTop + actionRowHeight
    }

    private static func clamp(_ value: CGFloat, _ range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

#endif
