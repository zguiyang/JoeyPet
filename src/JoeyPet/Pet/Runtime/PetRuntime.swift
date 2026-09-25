import AppKit
import Foundation
import OSLog
import SpriteKit

@MainActor
final class PetRuntime {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "PetRuntime")

    private(set) var currentState: PetState = .idle
    private(set) var currentAnimationID: String
    private(set) var currentTransientBehavior: PetTransientBehavior? = nil
    let scene: PetScene

    private let package: LoadedPetPackage
    private var hasAppliedInitialAnimation = false
    private var transientSessionTask: Task<Void, Never>?

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
        currentState = behavior.state

        if behavior.state != .idle {
            transientSessionTask?.cancel()
            transientSessionTask = nil
            currentTransientBehavior = nil
        } else if currentTransientBehavior != nil {
            return
        }

        let animationID = PetStateAnimationMapping.animationID(for: behavior.state)
        applyAnimation(for: animationID, state: behavior.state)
    }

    /// Requests one explicit or ambient behavior through the runtime arbitration point.
    /// Ambient and explicit behaviors are intentionally dropped while a system state is active.
    @discardableResult
    func perform(_ behavior: PetTransientBehavior) -> Bool {
        guard currentState == .idle, currentTransientBehavior == nil else { return false }
        guard package.manifest.animations[behavior.animationID] != nil else { return false }

        currentTransientBehavior = behavior
        applyAnimation(for: behavior.animationID, state: currentState) { [weak self] in
            self?.finishTransientBehavior(behavior)
        }

        if let duration = behavior.sessionDuration {
            transientSessionTask = Task { [weak self] in
                do {
                    try await Task.sleep(for: .seconds(duration))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                self?.finishTransientBehavior(behavior)
            }
        }

        Self.logger.info("PetRuntime transient -> \(behavior.rawValue, privacy: .public)")
        return true
    }

    func stop() {
        transientSessionTask?.cancel()
        transientSessionTask = nil
        currentTransientBehavior = nil
    }

    /// Direct asset playback hook for Debug builds; it does not alter PetState or behavior mapping.
    func applyDebugAnimation(_ animationID: String) {
        applyAnimation(for: animationID, state: currentState)
    }

    func updateStatusSeverity(_ severity: SignalSeverity) {
        scene.applyStatusSeverity(severity)
    }

    func finishTransientIfCurrent(_ behavior: PetTransientBehavior) {
        finishTransientBehavior(behavior)
    }

    private func applyAnimation(
        for animationID: String,
        state: PetState,
        completion: (() -> Void)? = nil
    ) {
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
        scene.applyAnimation(resolvedID, completion: completion)
        Self.logger.info("PetRuntime state -> \(state.rawValue, privacy: .public) animation -> \(resolvedID, privacy: .public)")
    }

    private func finishTransientBehavior(_ behavior: PetTransientBehavior) {
        guard currentTransientBehavior == behavior else { return }
        transientSessionTask?.cancel()
        transientSessionTask = nil
        currentTransientBehavior = nil

        let animationID = PetStateAnimationMapping.animationID(for: currentState)
        applyAnimation(for: animationID, state: currentState)
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
            displayPointSize: nil,
            textureFiltering: nil,
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
