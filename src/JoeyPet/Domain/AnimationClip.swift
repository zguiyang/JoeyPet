import Foundation

nonisolated struct AnimationClip: Codable, Equatable, Sendable {
    let frames: [Int]
    let fps: Double
    let loop: Bool

    init(frames: [Int], fps: Double, loop: Bool) {
        self.frames = frames
        self.fps = fps
        self.loop = loop
    }
}
