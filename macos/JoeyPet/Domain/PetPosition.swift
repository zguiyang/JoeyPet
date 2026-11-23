import Foundation

struct PetPositionPoint: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
}

struct PetPositionRect: Codable, Equatable, Sendable {
    let minX: Double
    let minY: Double
    let width: Double
    let height: Double

    var maxX: Double { minX + width }
    var maxY: Double { minY + height }

    func intersects(_ other: PetPositionRect) -> Bool {
        minX < other.maxX && maxX > other.minX && minY < other.maxY && maxY > other.minY
    }
}

struct PetScreenGeometry: Equatable, Sendable {
    let identifier: String
    let visibleFrame: PetPositionRect
    let isMain: Bool
}

enum PetCorner: String, CaseIterable, Codable, Sendable {
    case bottomRight
    case bottomLeft

    var title: String {
        switch self {
        case .bottomRight: return "右下角"
        case .bottomLeft: return "左下角"
        }
    }
}

struct PetPositionRecord: Codable, Equatable, Sendable {
    let screenIdentifier: String?
    let absoluteOrigin: PetPositionPoint
    let normalizedOrigin: PetPositionPoint
    let savedVisibleFrame: PetPositionRect
}

enum PetDockEdge: Equatable, Sendable {
    case left
    case right
}

/// Docking numbers come from `joey_manifest.json` (`docking`).
struct PetDockingPolicy: Equatable, Sendable {
    var edgePt: Double
    var collapseDelay: TimeInterval
    var exposeRatio: Double
    var minExposePt: Double
    var hotZonePt: Double
    var slideDuration: TimeInterval

    init(
        edgePt: Double = 24,
        collapseDelay: TimeInterval = 0.6,
        exposeRatio: Double = 0.4,
        minExposePt: Double = 24,
        hotZonePt: Double = 24,
        slideDuration: TimeInterval = 0.18
    ) {
        self.edgePt = edgePt
        self.collapseDelay = collapseDelay
        self.exposeRatio = exposeRatio
        self.minExposePt = minExposePt
        self.hotZonePt = hotZonePt
        self.slideDuration = slideDuration
    }

    init(spec: JoeyDockingSpec) {
        self.init(
            edgePt: Double(spec.edgePt),
            collapseDelay: TimeInterval(spec.collapseDelayMs) / 1000,
            exposeRatio: spec.exposeRatio,
            minExposePt: Double(spec.minExposePt),
            hotZonePt: Double(spec.hotZonePt),
            slideDuration: TimeInterval(spec.slideMs) / 1000
        )
    }
}

/// Panel placement rules from the domain contract §10.
enum PetPanelGeometry {
    static let defaultSize = PetPositionPoint(x: 168, y: 210)
    static let initialRightMargin: Double = 40
    static let initialBottomMargin: Double = 92
    static let dragMargin: Double = 8

    static func initialOrigin(
        in visibleFrame: PetPositionRect,
        windowSize: PetPositionPoint = defaultSize,
        corner: PetCorner = .bottomRight
    ) -> PetPositionPoint {
        let x: Double
        switch corner {
        case .bottomRight:
            x = visibleFrame.maxX - windowSize.x - initialRightMargin
        case .bottomLeft:
            x = visibleFrame.minX + initialRightMargin
        }
        return clampedOrigin(
            PetPositionPoint(
                x: x,
                y: visibleFrame.minY + initialBottomMargin
            ),
            in: visibleFrame,
            windowSize: windowSize
        )
    }

    /// Keeps the panel inside the visible frame with an 8 pt margin.
    static func clampedOrigin(
        _ origin: PetPositionPoint,
        in visibleFrame: PetPositionRect,
        windowSize: PetPositionPoint,
        margin: Double = dragMargin
    ) -> PetPositionPoint {
        PetPositionPoint(
            x: clamp(
                origin.x,
                lower: visibleFrame.minX + margin,
                upper: visibleFrame.maxX - windowSize.x - margin
            ),
            y: clamp(
                origin.y,
                lower: visibleFrame.minY + margin,
                upper: visibleFrame.maxY - windowSize.y - margin
            )
        )
    }

    static func dockEdge(
        for origin: PetPositionPoint,
        in visibleFrame: PetPositionRect,
        windowSize: PetPositionPoint,
        edgePt: Double
    ) -> PetDockEdge? {
        if origin.x - visibleFrame.minX <= edgePt {
            return .left
        }
        if visibleFrame.maxX - (origin.x + windowSize.x) <= edgePt {
            return .right
        }
        return nil
    }

    /// The collapsed frame keeps `exposeRatio` of the panel (at least `minExposePt`)
    /// inside the screen so the hot zone stays reachable.
    static func collapsedOrigin(
        edge: PetDockEdge,
        expandedOrigin: PetPositionPoint,
        in visibleFrame: PetPositionRect,
        windowSize: PetPositionPoint,
        exposeRatio: Double,
        minExposePt: Double
    ) -> PetPositionPoint {
        let exposed = max(windowSize.x * exposeRatio, minExposePt)
        let x: Double
        switch edge {
        case .left:
            x = visibleFrame.minX - (windowSize.x - exposed)
        case .right:
            x = visibleFrame.maxX - exposed
        }
        return PetPositionPoint(x: x, y: expandedOrigin.y)
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        guard upper >= lower else { return lower }
        return min(max(value, lower), upper)
    }
}

enum PetPositionGeometry {
    static func normalizedOrigin(
        _ origin: PetPositionPoint,
        in visibleFrame: PetPositionRect,
        windowSize: PetPositionPoint
    ) -> PetPositionPoint {
        let availableWidth = max(visibleFrame.width - windowSize.x, 0)
        let availableHeight = max(visibleFrame.height - windowSize.y, 0)
        return PetPositionPoint(
            x: availableWidth == 0 ? 0 : (origin.x - visibleFrame.minX) / availableWidth,
            y: availableHeight == 0 ? 0 : (origin.y - visibleFrame.minY) / availableHeight
        )
    }

    static func restore(
        _ saved: PetPositionRecord?,
        on screens: [PetScreenGeometry],
        windowSize: PetPositionPoint,
        corner: PetCorner = .bottomRight
    ) -> PetPositionPoint {
        guard !screens.isEmpty else {
            return PetPositionPoint(x: 120, y: 120)
        }

        if let saved {
            if let identifier = saved.screenIdentifier,
               let screen = screens.first(where: { $0.identifier == identifier }) {
                let availableWidth = max(screen.visibleFrame.width - windowSize.x, 0)
                let availableHeight = max(screen.visibleFrame.height - windowSize.y, 0)
                let origin = PetPositionPoint(
                    x: screen.visibleFrame.minX + saved.normalizedOrigin.x * availableWidth,
                    y: screen.visibleFrame.minY + saved.normalizedOrigin.y * availableHeight
                )
                if windowRect(origin: origin, size: windowSize).intersects(screen.visibleFrame) {
                    return PetPanelGeometry.clampedOrigin(
                        origin,
                        in: screen.visibleFrame,
                        windowSize: windowSize
                    )
                }
            }

            let savedRect = windowRect(origin: saved.absoluteOrigin, size: windowSize)
            if let screen = screens.first(where: { savedRect.intersects($0.visibleFrame) }) {
                return PetPanelGeometry.clampedOrigin(
                    saved.absoluteOrigin,
                    in: screen.visibleFrame,
                    windowSize: windowSize
                )
            }
        }

        let screen = screens.first(where: \.isMain) ?? screens[0]
        return PetPanelGeometry.initialOrigin(
            in: screen.visibleFrame,
            windowSize: windowSize,
            corner: corner
        )
    }

    private static func windowRect(origin: PetPositionPoint, size: PetPositionPoint) -> PetPositionRect {
        PetPositionRect(minX: origin.x, minY: origin.y, width: size.x, height: size.y)
    }
}
