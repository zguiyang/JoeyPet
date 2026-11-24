import AVFoundation
import Foundation
import OSLog

/// Settings-only audition. Ignores DND / quiet hours; does not start companionship ambient.
@MainActor
final class JoeySoundPreviewPlayer {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "JoeySoundPreview")

    private let catalog: JoeyAudioCatalog
    private var player: AVAudioPlayer?
    private var stopTask: Task<Void, Never>?

    /// Ambient beds only play this long in Settings so the list stays browseable.
    private let ambientPreviewSeconds: TimeInterval = 2.4
    private let previewVolume: Float = 0.4

    init(catalog: JoeyAudioCatalog = .load()) {
        self.catalog = catalog
    }

    func previewAmbient(id: String) {
        guard let track = catalog.ambient(id: id) else {
            stop()
            return
        }
        play(track, maxDuration: ambientPreviewSeconds)
    }

    func previewCue(id: String) {
        guard let track = catalog.cue(id: id) else {
            stop()
            return
        }
        play(track, maxDuration: nil)
    }

    func stop() {
        stopTask?.cancel()
        stopTask = nil
        player?.stop()
        player = nil
    }

    private func play(_ track: JoeyAudioTrack, maxDuration: TimeInterval?) {
        guard let url = track.bundleURL() else {
            Self.logger.error("Preview file missing: \(track.relativePath, privacy: .public)")
            return
        }
        do {
            let next = try AVAudioPlayer(contentsOf: url)
            next.numberOfLoops = 0
            next.volume = previewVolume
            next.prepareToPlay()
            stop()
            player = next
            next.play()

            let limit = maxDuration ?? next.duration
            guard limit > 0 else { return }
            stopTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(limit + 0.05))
                guard !Task.isCancelled else { return }
                if self.player === next {
                    self.stop()
                }
            }
        } catch {
            Self.logger.error("Preview failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

enum JoeySoundKind: Equatable, Sendable {
    case ambient
    case cue
}
