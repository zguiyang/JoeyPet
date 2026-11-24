import Foundation

/// Decoded form of `Resources/Pets/Joey/joey_manifest.json`.
///
/// The manifest is the single source of numeric truth for poses, clips,
/// cooldowns, sizes and render layers. Views must not duplicate these values.
struct JoeyManifest: Codable, Equatable, Sendable {
    let schemaVersion: String
    let canvas: JoeyCanvas
    let sizes: [JoeySizeSpec]
    let ambient: [JoeyAmbientSpec]
    let poses: [JoeyPoseSpec]
    let faces: JoeyFacesSpec
    let states: [JoeyStateSpec]
    let substates: [String]
    let transitions: [JoeyTransitionSpec]
    let mapping: JoeyMappingSpec
    let assets: JoeyAssetsSpec
    let render: JoeyRenderSpec?
}

extension JoeyManifest {
    static func load(from url: URL) throws -> JoeyManifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(JoeyManifest.self, from: data)
    }

    func pose(_ id: String) -> JoeyPoseSpec? {
        poses.first { $0.id == id }
    }

    func state(_ id: String) -> JoeyStateSpec? {
        states.first { $0.id == id }
    }
}

struct JoeyCanvas: Codable, Equatable, Sendable {
    let w: Int
    let h: Int
    let anchor: [Int]
    let safe: Int
}

struct JoeySizeSpec: Codable, Equatable, Sendable {
    let id: String
    let w: Int
    let h: Int
    let isDefault: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case w
        case h
        case isDefault = "default"
    }
}

struct JoeyAmbientSpec: Codable, Equatable, Sendable {
    let id: String
    let loopMs: Int?
    let rangeMs: [Int]?
    let scale: Double?
    let sleepMs: Int?
    let everyMs: [Int]?
    let durationMs: Int?
    let frames: Int?
    let suppressIn: [String]?
    let degrees: JoeyDegrees?
    let sync: String?
    let px: Int?
    let tilt: Double?
    let armDeg: Int?
    let headScale: Double?
    let bobPx: Int?
}

/// `degrees` is a single value for the tail and a two-value range for ears.
enum JoeyDegrees: Codable, Equatable, Sendable {
    case single(Double)
    case range(Double, Double)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Double.self) {
            self = .single(value)
            return
        }
        let values = try container.decode([Double].self)
        guard values.count == 2 else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "degrees must be a number or a two-element array"
            )
        }
        self = .range(values[0], values[1])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .single(value):
            try container.encode(value)
        case let .range(lower, upper):
            try container.encode([lower, upper])
        }
    }
}

struct JoeyPoseSpec: Codable, Equatable, Sendable {
    let id: String
    let clipId: String
    let behavior: String
    let loop: Bool
    let holdLastFrame: Bool?
    let durationMs: Int?
}

struct JoeyFacesSpec: Codable, Equatable, Sendable {
    let ids: [String]
    let blinkFaces: String
}

struct JoeyStateSpec: Codable, Equatable, Sendable {
    let id: String
    let priority: Int
    let pose: String?
    let cooldownMin: Int?
    let window: [String]?
    let inviteGapMin: Int?
}

struct JoeyTransitionSpec: Codable, Equatable, Sendable {
    let from: String
    let to: String
    let ms: Int
    let easing: String
    let afterIdleMs: Int?
}

struct JoeyMappingSpec: Codable, Equatable, Sendable {
    let key: String
    let buckets: [String: [String]]
}

struct JoeyAssetsSpec: Codable, Equatable, Sendable {
    let naming: String
    let layerNaming: String?
    let blinkNaming: String?
    let exports: [String]
    let fallback: String
}

struct JoeyRenderSpec: Codable, Equatable, Sendable {
    let layerOrder: [String]
    let anchors: [String: [Int]]
    let textureFiltering: String?
    let emotion: String?
    let poseLayers: [String: JoeyPoseLayers]
}

struct JoeyPoseLayers: Codable, Equatable, Sendable {
    let shadow: String?
    let tail: String?
    let body: String?
    let ears: String?
    let backArm: String?
    let face: String?
    let frontArm: String?
    let prop: String?
    let rotate: Double?
    let pivot: [Double]?
    let translateX: Double?
    let translateY: Double?
}

struct JoeyManifestIssue: Equatable, Sendable {
    let field: String
    let message: String
}

enum JoeyManifestValidator {
    static let expectedLayerOrder = ["shadow", "tail", "body", "ears", "backArm", "face", "frontArm", "prop"]

    static func issues(in manifest: JoeyManifest) -> [JoeyManifestIssue] {
        var issues: [JoeyManifestIssue] = []
        func fail(_ field: String, _ message: String) {
            issues.append(JoeyManifestIssue(field: field, message: message))
        }

        if manifest.schemaVersion != "0.1" {
            fail("schemaVersion", "expected 0.1, got \(manifest.schemaVersion)")
        }
        if manifest.canvas.w != 320 || manifest.canvas.h != 400 {
            fail("canvas", "expected 320×400")
        }
        if manifest.canvas.anchor != [160, 388] {
            fail("canvas.anchor", "expected [160, 388]")
        }
        if manifest.canvas.safe < 0 {
            fail("canvas.safe", "must be non-negative")
        }

        let sizes = manifest.sizes
        if sizes.count != 3 {
            fail("sizes", "expected 3 sizes, got \(sizes.count)")
        }
        let defaults = sizes.filter { $0.isDefault == true }
        if defaults.count != 1 {
            fail("sizes.default", "expected exactly one default size")
        } else if defaults[0].w != 168 || defaults[0].h != 210 {
            fail("sizes.default", "expected 168×210, got \(defaults[0].w)×\(defaults[0].h)")
        }

        expectIds(
            manifest.ambient.map(\.id),
            PetAmbientEvent.allCases.map(\.rawValue),
            field: "ambient",
            fail: fail
        )
        expectIds(
            manifest.poses.map(\.id),
            PetPose.allCases.map(\.rawValue),
            field: "poses",
            fail: fail
        )
        if Set(manifest.poses.map(\.clipId)).count != manifest.poses.count {
            fail("poses.clipId", "clip ids must be unique")
        }
        for pose in manifest.poses {
            if PetBehaviorBucket(rawValue: pose.behavior) == nil {
                fail("poses.\(pose.id).behavior", "unknown behavior \(pose.behavior)")
            }
            if pose.id == "sign", pose.holdLastFrame != true {
                fail("poses.sign.holdLastFrame", "sign must hold its last frame")
            }
            if pose.id == "happy", pose.durationMs != 2600 {
                fail("poses.happy.durationMs", "expected 2600")
            }
        }

        if manifest.faces.ids.count != 8 {
            fail("faces.ids", "expected 8 faces, got \(manifest.faces.ids.count)")
        }
        if manifest.faces.blinkFaces != "all" {
            fail("faces.blinkFaces", "expected all")
        }

        expectIds(
            manifest.states.map(\.id),
            DesktopState.allCases.map(\.rawValue),
            field: "states",
            fail: fail
        )
        let priorities = manifest.states.map(\.priority).sorted()
        if priorities != Array(1...7) {
            fail("states.priority", "expected unique priorities 1...7, got \(priorities)")
        }

        expectIds(
            manifest.substates,
            CompanionSubstate.allCases.map(\.rawValue),
            field: "substates",
            fail: fail
        )

        if manifest.transitions.count != 12 {
            fail("transitions", "expected 12 transitions, got \(manifest.transitions.count)")
        }
        let poseIds = Set(manifest.poses.map(\.id))
        for transition in manifest.transitions {
            if !poseIds.contains(transition.from) || !poseIds.contains(transition.to) {
                fail("transitions", "unknown pose in \(transition.from) → \(transition.to)")
            }
            if transition.easing != "ease-out" {
                fail("transitions.\(transition.from)→\(transition.to)", "expected ease-out")
            }
        }

        if manifest.mapping.key != "behavior/clip" {
            fail("mapping.key", "expected behavior/clip")
        }
        let bucketKeys = Set(manifest.mapping.buckets.keys)
        let expectedBuckets = Set(PetBehaviorBucket.allCases.map(\.rawValue))
        if bucketKeys != expectedBuckets {
            fail("mapping.buckets", "expected \(expectedBuckets.sorted()), got \(bucketKeys.sorted())")
        }
        let allMappedClips = manifest.mapping.buckets.values.flatMap { $0 }
        if allMappedClips.count != Set(allMappedClips).count {
            fail("mapping.buckets", "a clip appears in more than one bucket")
        }
        for pose in manifest.poses {
            guard let clips = manifest.mapping.buckets[pose.behavior] else { continue }
            if !clips.contains(pose.clipId) {
                fail("mapping.\(pose.behavior)", "missing \(pose.clipId) for pose \(pose.id)")
            }
        }

        if manifest.assets.fallback != "pose_sit" {
            fail("assets.fallback", "expected pose_sit")
        }
        if !manifest.assets.naming.contains("<id>") {
            fail("assets.naming", "expected a pose_<id> pattern")
        }

        guard let render = manifest.render else {
            fail("render", "missing render contract")
            return issues
        }
        if render.layerOrder != expectedLayerOrder {
            fail("render.layerOrder", "expected \(expectedLayerOrder)")
        }
        for anchor in ["canvas", "breath", "head", "ear", "tail", "shoulderRight", "shoulderLeft"] {
            if render.anchors[anchor]?.count != 2 {
                fail("render.anchors.\(anchor)", "expected a two-value point")
            }
        }
        if render.textureFiltering != "linear" {
            fail("render.textureFiltering", "expected linear")
        }
        if render.emotion != "bakedIntoFace" {
            fail("render.emotion", "expected bakedIntoFace for V0")
        }
        let poseIdsSet = Set(manifest.poses.map(\.id))
        if Set(render.poseLayers.keys) != poseIdsSet {
            fail("render.poseLayers", "must cover every pose exactly once")
        }
        for pose in manifest.poses {
            guard let layers = render.poseLayers[pose.id] else { continue }
            if layers.shadow == nil {
                fail("render.poseLayers.\(pose.id).shadow", "shadow is required")
            }
            if layers.face == nil {
                fail("render.poseLayers.\(pose.id).face", "face is required")
            }
            if let pivot = layers.pivot, pivot.count != 2 {
                fail("render.poseLayers.\(pose.id).pivot", "expected a two-value point")
            }
        }

        return issues
    }

    private static func expectIds(
        _ actual: [String],
        _ expected: [String],
        field: String,
        fail: (String, String) -> Void
    ) {
        if actual.sorted() != expected.sorted() {
            fail(field, "expected \(expected.sorted()), got \(actual.sorted())")
        }
        if Set(actual).count != actual.count {
            fail(field, "duplicate ids")
        }
    }
}
