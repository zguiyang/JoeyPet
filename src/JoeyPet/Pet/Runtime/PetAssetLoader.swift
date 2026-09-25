import AppKit
import Foundation
import OSLog
import SpriteKit

enum PetAssetLoadError: Error, Equatable {
    case missingManifest(packageID: String)
    case missingSpriteSheet(packageID: String, fileName: String)
    case invalidJSON(packageID: String)
    case invalidDimensions(expectedWidth: Int, expectedHeight: Int, actualWidth: Int, actualHeight: Int)
    case invalidLayout(columns: Int, rows: Int, frameWidth: Int, frameHeight: Int)
    case emptyAnimations
    case outOfBoundsFrame(animationID: String, frameIndex: Int, maxIndex: Int)
    case unknownFallbackAnimation(String)
    case emptyClipFrames(animationID: String)
    case invalidFPS(animationID: String)
    case invalidDefaultScale(Int)
}

struct LoadedPetPackage: Sendable {
    let manifest: PetManifest
    let frameTextures: [SKTexture]
    let clipsByID: [String: AnimationClip]
}

enum PetManifestValidator {
    static func validate(_ manifest: PetManifest, sheetPixelWidth: Int, sheetPixelHeight: Int) -> PetAssetLoadError? {
        guard !manifest.animations.isEmpty else {
            return .emptyAnimations
        }

        guard manifest.defaultScale > 0 else {
            return .invalidDefaultScale(manifest.defaultScale)
        }

        guard manifest.columns > 0, manifest.rows > 0,
              manifest.frameWidth > 0, manifest.frameHeight > 0
        else {
            return .invalidLayout(
                columns: manifest.columns,
                rows: manifest.rows,
                frameWidth: manifest.frameWidth,
                frameHeight: manifest.frameHeight
            )
        }

        let expectedWidth = manifest.columns * manifest.frameWidth
        let expectedHeight = manifest.rows * manifest.frameHeight
        guard sheetPixelWidth == expectedWidth, sheetPixelHeight == expectedHeight else {
            return .invalidDimensions(
                expectedWidth: expectedWidth,
                expectedHeight: expectedHeight,
                actualWidth: sheetPixelWidth,
                actualHeight: sheetPixelHeight
            )
        }

        guard manifest.animations[manifest.fallbackAnimation] != nil else {
            return .unknownFallbackAnimation(manifest.fallbackAnimation)
        }

        for (animationID, clip) in manifest.animations {
            if clip.frames.isEmpty {
                return .emptyClipFrames(animationID: animationID)
            }
            if clip.fps <= 0 {
                return .invalidFPS(animationID: animationID)
            }
            for frameIndex in clip.frames {
                if manifest.frameRect(for: frameIndex) == nil {
                    return .outOfBoundsFrame(
                        animationID: animationID,
                        frameIndex: frameIndex,
                        maxIndex: manifest.totalFrameCount - 1
                    )
                }
            }
        }

        return nil
    }

    static func resolvedAnimationID(
        requestedID: String,
        manifest: PetManifest
    ) -> String {
        if manifest.animations[requestedID] != nil {
            return requestedID
        }
        return manifest.fallbackAnimation
    }
}

@MainActor
final class PetAssetLoader {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "PetAssetLoader")

    nonisolated static let defaultPackageID = "Joey"

    private static var cachedPackage: LoadedPetPackage?
    private static var cachedPackageID: String?

    static func loadBundledPackage(
        packageID: String = defaultPackageID,
        bundle: Bundle = .main
    ) -> LoadedPetPackage? {
        if let cached = cachedPackage, cachedPackageID == packageID {
            return cached
        }

        switch load(packageID: packageID, bundle: bundle) {
        case .success(let package):
            cachedPackage = package
            cachedPackageID = packageID
            return package
        case .failure(let error):
            logger.error("Failed to load pet package \(packageID, privacy: .public): \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    static func load(
        packageID: String,
        bundle: Bundle = .main
    ) -> Result<LoadedPetPackage, PetAssetLoadError> {
        let manifestURL = bundle.url(
            forResource: "pet",
            withExtension: "json",
            subdirectory: "Pets/\(packageID)"
        )
        guard let manifestURL else {
            return .failure(.missingManifest(packageID: packageID))
        }

        let manifestData: Data
        do {
            manifestData = try Data(contentsOf: manifestURL)
        } catch {
            return .failure(.invalidJSON(packageID: packageID))
        }

        let manifest: PetManifest
        do {
            manifest = try JSONDecoder().decode(PetManifest.self, from: manifestData)
        } catch {
            return .failure(.invalidJSON(packageID: packageID))
        }

        let sheetBaseName = (manifest.spriteSheet as NSString).deletingPathExtension
        let sheetExtension = (manifest.spriteSheet as NSString).pathExtension
        let sheetURL = bundle.url(
            forResource: sheetBaseName,
            withExtension: sheetExtension.isEmpty ? "png" : sheetExtension,
            subdirectory: "Pets/\(packageID)"
        )

        guard let sheetURL else {
            return .failure(.missingSpriteSheet(packageID: packageID, fileName: manifest.spriteSheet))
        }

        guard let image = NSImage(contentsOf: sheetURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return .failure(.missingSpriteSheet(packageID: packageID, fileName: manifest.spriteSheet))
        }

        let sheetPixelWidth = cgImage.width
        let sheetPixelHeight = cgImage.height

        if let validationError = PetManifestValidator.validate(
            manifest,
            sheetPixelWidth: sheetPixelWidth,
            sheetPixelHeight: sheetPixelHeight
        ) {
            return .failure(validationError)
        }

        let filtering = manifest.resolvedTextureFiltering.skFilteringMode
        let baseTexture = SKTexture(cgImage: cgImage)
        baseTexture.filteringMode = filtering

        var frameTextures: [SKTexture] = []
        frameTextures.reserveCapacity(manifest.totalFrameCount)

        for frameIndex in 0..<manifest.totalFrameCount {
            guard let position = manifest.frameRect(for: frameIndex) else { continue }

            let normalizedWidth = CGFloat(manifest.frameWidth) / CGFloat(sheetPixelWidth)
            let normalizedHeight = CGFloat(manifest.frameHeight) / CGFloat(sheetPixelHeight)
            let normalizedX = CGFloat(position.column * manifest.frameWidth) / CGFloat(sheetPixelWidth)
            let normalizedY = 1.0 - normalizedHeight - (CGFloat(position.row * manifest.frameHeight) / CGFloat(sheetPixelHeight))

            let rect = CGRect(x: normalizedX, y: normalizedY, width: normalizedWidth, height: normalizedHeight)
            let texture = SKTexture(rect: rect, in: baseTexture)
            texture.filteringMode = filtering
            frameTextures.append(texture)
        }

        return .success(
            LoadedPetPackage(
                manifest: manifest,
                frameTextures: frameTextures,
                clipsByID: manifest.animations
            )
        )
    }

    static func resetCacheForTesting() {
        cachedPackage = nil
        cachedPackageID = nil
    }
}
