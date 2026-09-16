import AppKit
import Foundation
import OSLog
import SpriteKit

@MainActor
final class PetRuntime {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "PetRuntime")

    private(set) var currentState: PetState = .idle
    private(set) var currentAnimationID: String
    let scene: PetScene

    private let package: LoadedPetPackage
    private var hasAppliedInitialAnimation = false

    init(sceneSize: CGSize, package: LoadedPetPackage? = nil) {
        let loadedPackage = package ?? PetAssetLoader.loadBundledPackage()
        let resolvedPackage = loadedPackage ?? Self.fallbackPackage()

        self.package = resolvedPackage
        self.currentAnimationID = PetStateAnimationMapping.animationID(for: .idle)
        self.scene = PetScene(size: sceneSize, package: resolvedPackage)

        let initialAnimationID = PetStateAnimationMapping.animationID(for: .idle)
        applyAnimation(for: initialAnimationID, state: .idle)
    }

    func apply(behavior: PetBehavior) {
        let animationID = PetStateAnimationMapping.animationID(for: behavior.state)
        applyAnimation(for: animationID, state: behavior.state)
    }

    private func applyAnimation(for animationID: String, state: PetState) {
        let resolvedID = PetManifestValidator.resolvedAnimationID(
            requestedID: animationID,
            manifest: package.manifest
        )

        if hasAppliedInitialAnimation {
            guard resolvedID != currentAnimationID || state != currentState else { return }
        }

        hasAppliedInitialAnimation = true
        currentState = state
        currentAnimationID = resolvedID
        scene.applyAnimation(resolvedID)
        Self.logger.info("PetRuntime state -> \(state.rawValue, privacy: .public) animation -> \(resolvedID, privacy: .public)")
    }

    private static func fallbackPackage() -> LoadedPetPackage {
        logger.error("Using in-memory fallback pet package")

        let manifest = PetManifest(
            id: "fallback",
            name: "Fallback",
            spriteSheet: "spritesheet.png",
            frameWidth: 1,
            frameHeight: 1,
            columns: 1,
            rows: 1,
            defaultScale: 1,
            fallbackAnimation: "idle",
            animations: [
                "idle": AnimationClip(frames: [0], fps: 1, loop: true)
            ]
        )

        return LoadedPetPackage(
            manifest: manifest,
            frameTextures: [makeSolidTexture(color: NSColor.systemGray)],
            clipsByID: manifest.animations
        )
    }

    private static func makeSolidTexture(color: NSColor) -> SKTexture {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1, height: 1)).fill()
        image.unlockFocus()

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            let texture = SKTexture()
            texture.filteringMode = .nearest
            return texture
        }

        let texture = SKTexture(cgImage: cgImage)
        texture.filteringMode = .nearest
        return texture
    }
}
