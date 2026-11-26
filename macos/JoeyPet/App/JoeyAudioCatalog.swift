import Foundation

/// One playable bed or one-shot from `Resources/Audio/catalog.json`.
struct JoeyAudioTrack: Equatable, Identifiable, Sendable {
    let id: String
    let displayNameZh: String
    let relativePath: String
    let category: String?
    let license: String
    let loop: Bool
    let attributionRequired: Bool

    /// Bundle URL under the Audio folder reference.
    func bundleURL(in bundle: Bundle = .main) -> URL? {
        guard let root = bundle.resourceURL?.appendingPathComponent("Audio", isDirectory: true)
        else { return nil }
        let url = root.appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

/// Loaded ambient + cue options. Selection `"none"` means silence for that slot.
struct JoeyAudioCatalog: Equatable, Sendable {
    static let noneID = "none"
    static let noneAmbientTitle = "无背景音"
    static let noneCueTitle = "无提示音"

    var ambient: [JoeyAudioTrack]
    var cues: [JoeyAudioTrack]

    static let empty = JoeyAudioCatalog(ambient: [], cues: [])

    func ambient(id: String) -> JoeyAudioTrack? {
        guard id != Self.noneID else { return nil }
        return ambient.first { $0.id == id }
    }

    func cue(id: String) -> JoeyAudioTrack? {
        guard id != Self.noneID else { return nil }
        return cues.first { $0.id == id }
    }

    /// Returns `none` when the stored id is missing from the catalog.
    func sanitizedAmbientID(_ id: String) -> String {
        if id == Self.noneID { return Self.noneID }
        return ambient.contains(where: { $0.id == id }) ? id : Self.noneID
    }

    func sanitizedCueID(_ id: String) -> String {
        if id == Self.noneID { return Self.noneID }
        return cues.contains(where: { $0.id == id }) ? id : Self.noneID
    }

    /// Tracks that require an About-page credit when present in the catalog.
    var attributionTracks: [JoeyAudioTrack] {
        (ambient + cues).filter(\.attributionRequired)
    }

    static func load(from bundle: Bundle = .main) -> JoeyAudioCatalog {
        guard
            let url = bundle.url(
                forResource: "catalog",
                withExtension: "json",
                subdirectory: "Audio"
            ),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(CatalogFile.self, from: data)
        else {
            return .empty
        }
        return JoeyAudioCatalog(
            ambient: decoded.ambient.map { $0.asTrack(defaultLoop: true) },
            cues: decoded.cues.map { $0.asTrack(defaultLoop: false) }
        )
    }
}

/// Pure mute gate: DND always; quiet hours only while there is no session.
enum JoeyAudioMutePolicy {
    /// Quiet hours mute only when Joey is alone asleep. A session started inside
    /// quiet still plays companionship ambient and invite cues.
    static func shouldSilence(
        isDoNotDisturb: Bool,
        isQuietActive: Bool,
        hasSession: Bool = false
    ) -> Bool {
        if isDoNotDisturb { return true }
        if isQuietActive, !hasSession { return true }
        return false
    }
}

// MARK: - Decoding

private struct CatalogFile: Decodable {
    var ambient: [CatalogEntry]
    var cues: [CatalogEntry]
}

private struct CatalogEntry: Decodable {
    var id: String
    var displayNameZh: String
    var file: String
    var category: String?
    var license: String
    var loop: Bool?
    var attributionRequired: Bool?

    func asTrack(defaultLoop: Bool) -> JoeyAudioTrack {
        JoeyAudioTrack(
            id: id,
            displayNameZh: displayNameZh,
            relativePath: file,
            category: category,
            license: license,
            loop: loop ?? defaultLoop,
            attributionRequired: attributionRequired ?? false
        )
    }
}
