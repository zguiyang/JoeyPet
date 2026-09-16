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

struct PetPositionRecord: Codable, Equatable, Sendable {
    let screenIdentifier: String?
    let absoluteOrigin: PetPositionPoint
    let normalizedOrigin: PetPositionPoint
    let savedVisibleFrame: PetPositionRect
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
        defaultMargin: Double = 24
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
                    return origin
                }
            }

            let savedRect = windowRect(origin: saved.absoluteOrigin, size: windowSize)
            if screens.contains(where: { savedRect.intersects($0.visibleFrame) }) {
                return saved.absoluteOrigin
            }
        }

        let screen = screens.first(where: \.isMain) ?? screens[0]
        return PetPositionPoint(
            x: screen.visibleFrame.maxX - windowSize.x - defaultMargin,
            y: screen.visibleFrame.minY + defaultMargin
        )
    }

    private static func windowRect(origin: PetPositionPoint, size: PetPositionPoint) -> PetPositionRect {
        PetPositionRect(minX: origin.x, minY: origin.y, width: size.x, height: size.y)
    }
}
