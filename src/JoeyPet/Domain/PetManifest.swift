import Foundation
import SpriteKit

nonisolated enum PetTextureFiltering: String, Codable, Equatable, Sendable {
    case pixel
    case smooth

    var skFilteringMode: SKTextureFilteringMode {
        switch self {
        case .pixel:
            return .nearest
        case .smooth:
            return .linear
        }
    }
}

nonisolated struct PetManifest: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let spriteSheet: String
    let frameWidth: Int
    let frameHeight: Int
    let columns: Int
    let rows: Int
    let defaultScale: Int
    /// When set, logical on-screen size in points (square pets). Overrides `frameWidth * defaultScale`.
    let displayPointSize: Int?
    let textureFiltering: PetTextureFiltering?
    let fallbackAnimation: String
    let animations: [String: AnimationClip]

    var resolvedTextureFiltering: PetTextureFiltering {
        textureFiltering ?? .pixel
    }

    /// SpriteKit `setScale` factor: integer pixel-art multiplier, or `displayPointSize / frameWidth` for HD assets.
    func characterDisplayScaleFactor() -> CGFloat {
        if let displayPointSize, displayPointSize > 0, frameWidth > 0 {
            return CGFloat(displayPointSize) / CGFloat(frameWidth)
        }
        return CGFloat(max(1, defaultScale))
    }

    var totalFrameCount: Int {
        columns * rows
    }

    func frameRect(for index: Int) -> (column: Int, row: Int)? {
        guard index >= 0, index < totalFrameCount else { return nil }
        return (index % columns, index / columns)
    }

    func animationClip(for id: String) -> AnimationClip? {
        animations[id]
    }

    /// Asset frame pixels × integer `defaultScale` → logical points (AppKit / SpriteKit points).
    /// Returns `nil` when scale or frame size is not a positive integer production mapping.
    func logicalPointSize() -> (width: Int, height: Int)? {
        if let displayPointSize, displayPointSize > 0 {
            return (displayPointSize, displayPointSize)
        }
        guard defaultScale > 0, frameWidth > 0, frameHeight > 0 else {
            return nil
        }
        return (frameWidth * defaultScale, frameHeight * defaultScale)
    }
}
