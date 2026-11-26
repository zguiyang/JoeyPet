import AVFoundation
import Foundation
import OSLog

/// Dual-player bed + one-shot. Mute on DND, or quiet hours while alone; ambient only during companionship.
@MainActor
final class JoeyAudioController {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "JoeyAudio")

    private let catalog: JoeyAudioCatalog
    private var ambientPlayer: AVAudioPlayer?
    private var cuePlayer: AVAudioPlayer?
    private var ambientID = JoeyAudioCatalog.noneID
    private var cueID = JoeyAudioCatalog.noneID
    private var isSessionActive = false
    private var isSilenced = false
    private var wasInviteVisible = false
    private var duckRestoreTask: Task<Void, Never>?

    private let ambientVolume: Float = 0.32
    private let cueVolume: Float = 0.42
    private let duckedAmbientVolume: Float = 0.12

    init(catalog: JoeyAudioCatalog = .load()) {
        self.catalog = catalog
    }

    var loadedCatalog: JoeyAudioCatalog { catalog }

    func applySelection(ambientID: String, cueID: String) {
        self.ambientID = catalog.sanitizedAmbientID(ambientID)
        self.cueID = catalog.sanitizedCueID(cueID)
        syncAmbientPlayback()
    }

    /// Call on every situation change and after selection updates.
    func sync(situation: PetSituation, now: Date = Date()) {
        let sessionActive = situation.session != nil
        let silence = JoeyAudioMutePolicy.shouldSilence(
            isDoNotDisturb: situation.isDoNotDisturb,
            isQuietActive: situation.isQuietActive,
            hasSession: sessionActive
        )
        let inviteVisible = situation.isInviteCardVisible(at: now)

        let silenceChanged = silence != isSilenced
        let sessionChanged = sessionActive != isSessionActive
        isSilenced = silence
        isSessionActive = sessionActive

        if silence {
            stopAll()
        } else {
            var didPlayCue = false
            if sessionChanged, sessionActive {
                playCueIfConfigured()
                didPlayCue = true
            }
            syncAmbientPlayback()
            if inviteVisible, !wasInviteVisible, !didPlayCue {
                playCueIfConfigured()
            }
            if silenceChanged, sessionActive {
                syncAmbientPlayback()
            }
        }

        wasInviteVisible = inviteVisible
    }

    func stop() {
        duckRestoreTask?.cancel()
        duckRestoreTask = nil
        stopAll()
        isSessionActive = false
        wasInviteVisible = false
    }

    // MARK: - Private

    private func syncAmbientPlayback() {
        guard !isSilenced, isSessionActive else {
            stopAmbient()
            return
        }
        guard let track = catalog.ambient(id: ambientID) else {
            stopAmbient()
            return
        }
        if ambientPlayer?.url == track.bundleURL(), ambientPlayer?.isPlaying == true {
            return
        }
        startAmbient(track)
    }

    private func startAmbient(_ track: JoeyAudioTrack) {
        guard let url = track.bundleURL() else {
            Self.logger.error("Ambient file missing: \(track.relativePath, privacy: .public)")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = track.loop ? -1 : 0
            player.volume = ambientVolume
            player.prepareToPlay()
            ambientPlayer?.stop()
            ambientPlayer = player
            player.play()
        } catch {
            Self.logger.error("Ambient play failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func playCueIfConfigured() {
        guard !isSilenced, let track = catalog.cue(id: cueID) else { return }
        guard let url = track.bundleURL() else {
            Self.logger.error("Cue file missing: \(track.relativePath, privacy: .public)")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0
            player.volume = cueVolume
            player.prepareToPlay()
            cuePlayer?.stop()
            cuePlayer = player
            duckAmbientForCue(duration: max(player.duration, 0.6))
            player.play()
        } catch {
            Self.logger.error("Cue play failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func duckAmbientForCue(duration: TimeInterval) {
        guard let ambient = ambientPlayer, ambient.isPlaying else { return }
        ambient.volume = duckedAmbientVolume
        duckRestoreTask?.cancel()
        duckRestoreTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration + 0.15))
            guard !Task.isCancelled else { return }
            ambientPlayer?.volume = ambientVolume
        }
    }

    private func stopAmbient() {
        ambientPlayer?.stop()
        ambientPlayer = nil
    }

    private func stopAll() {
        duckRestoreTask?.cancel()
        duckRestoreTask = nil
        stopAmbient()
        cuePlayer?.stop()
        cuePlayer = nil
    }
}
