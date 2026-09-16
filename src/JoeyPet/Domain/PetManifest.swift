import Foundation

nonisolated struct PetManifest: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let spriteSheet: String
    let frameWidth: Int
    let frameHeight: Int
    let columns: Int
    let rows: Int
    let defaultScale: Int
    let fallbackAnimation: String
    let animations: [String: AnimationClip]

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
        guard defaultScale > 0, frameWidth > 0, frameHeight > 0 else {
            return nil
        }
        return (frameWidth * defaultScale, frameHeight * defaultScale)
    }
}
