import AppKit
import Foundation
import OSLog
import SpriteKit

/// PNG density folders exported by `macos/scripts/build_joey_pose_assets.py`.
enum JoeyAssetScale: String, CaseIterable, Sendable {
    case x1 = "1x"
    case x2 = "2x"
    case x3 = "3x"

    static func best(for displayScale: CGFloat) -> JoeyAssetScale {
        if displayScale >= 3 { return .x3 }
        if displayScale >= 2 { return .x2 }
        return .x1
    }
}

enum JoeyAssetError: Error, Equatable {
    case missingManifest(URL)
    case invalidManifest(URL)
}

/// Loads `joey_manifest.json` plus the layered/complete PNGs generated from the
/// frozen state atlas. Purely a texture source: it never mutates domain state.
@MainActor
final class JoeyAssetPackage {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "JoeyAssetPackage")

    let manifest: JoeyManifest
    let scale: JoeyAssetScale
    let resourceRoot: URL

    private var textures: [String: SKTexture] = [:]
    private(set) var missingAssetIDs: Set<String> = []

    init(manifest: JoeyManifest, scale: JoeyAssetScale, resourceRoot: URL) {
        self.manifest = manifest
        self.scale = scale
        self.resourceRoot = resourceRoot
    }

    static func load(
        resourceRoot: URL,
        scale: JoeyAssetScale
    ) throws -> JoeyAssetPackage {
        let manifestURL = resourceRoot.appendingPathComponent("joey_manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw JoeyAssetError.missingManifest(manifestURL)
        }
        do {
            let manifest = try JoeyManifest.load(from: manifestURL)
            return JoeyAssetPackage(manifest: manifest, scale: scale, resourceRoot: resourceRoot)
        } catch {
            throw JoeyAssetError.invalidManifest(manifestURL)
        }
    }

    static func load(
        bundle: Bundle = .main,
        packageID: String = "Joey",
        scale: JoeyAssetScale? = nil,
        displayScale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2
    ) -> JoeyAssetPackage? {
        guard let manifestURL = bundle.url(
            forResource: "joey_manifest",
            withExtension: "json",
            subdirectory: "Pets/\(packageID)"
        ) else {
            logger.error("Missing manifest for package \(packageID, privacy: .public)")
            return nil
        }

        do {
            let package = try load(
                resourceRoot: manifestURL.deletingLastPathComponent(),
                scale: scale ?? .best(for: displayScale)
            )
            return package
        } catch {
            logger.error("Failed to load package \(packageID, privacy: .public): \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    // MARK: - Lookups

    func ambient(_ id: String) -> JoeyAmbientSpec? {
        manifest.ambient.first { $0.id == id }
    }

    func sizeSpec(id: String) -> JoeySizeSpec? {
        manifest.sizes.first { $0.id == id }
    }

    var defaultSizeSpec: JoeySizeSpec {
        manifest.sizes.first { $0.isDefault == true }
            ?? manifest.sizes.first
            ?? JoeySizeSpec(id: "m", w: manifest.canvas.w, h: manifest.canvas.h, isDefault: true)
    }

    // MARK: - Textures

    /// Assets use dotted ids in the manifest (`face.calm.blink2`) and
    /// underscored file names (`layer_face_calm_blink2.png`).
    func layerTexture(assetID: String) -> SKTexture? {
        let name = "layer_" + assetID.replacingOccurrences(of: ".", with: "_")
        return texture(named: name, in: "layers/png/\(scale.rawValue)")
    }

    func poseTexture(poseID: String) -> SKTexture? {
        texture(named: "pose_\(poseID)", in: "poses/png/\(scale.rawValue)")
    }

    private func texture(named name: String, in directory: String) -> SKTexture? {
        let key = "\(directory)/\(name)"
        if let cached = textures[key] {
            return cached
        }

        let url = resourceRoot
            .appendingPathComponent(directory, isDirectory: true)
            .appendingPathComponent(name + ".png")
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            if missingAssetIDs.insert(key).inserted {
                Self.logger.error("Missing pet asset \(key, privacy: .public)")
            }
            return nil
        }

        let texture = SKTexture(cgImage: cgImage)
        texture.filteringMode = .linear
        textures[key] = texture
        return texture
    }
}
