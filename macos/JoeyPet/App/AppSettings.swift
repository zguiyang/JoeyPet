import Foundation
import Observation

/// App-level settings shared by the windows, the menu bar item and the pet panel.
/// Persisted in UserDefaults; no database and no account.
@Observable
@MainActor
final class AppSettings {
    private enum Key {
        static let rhythm = "joey.rhythmMinutes"
        static let doNotDisturb = "joey.doNotDisturb"
        static let quietStart = "joey.quietStartMinutes"
        static let quietEnd = "joey.quietEndMinutes"
        static let appearance = "joey.appearance"
        static let petCorner = "joey.petCorner"
        static let showsDesktopPet = PetPreferences.showsDesktopPetKey
        static let ambientSound = "joey.ambientSoundID"
        static let cueSound = "joey.cueSoundID"
    }

    /// Preset shortcuts shown in the rhythm combo menu.
    static let rhythmOptions = [45, 60, 90]
    /// Soft cup tap — first preferred cue when the user has not chosen yet.
    static let defaultCueSoundID = "cue_ceramic_cups"

    static func clampRhythmMinutes(_ value: Int) -> Int {
        InvitationPolicy.clampedRhythmMinutes(value)
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored var onShowsDesktopPetChanged: ((Bool) -> Void)?
    @ObservationIgnored var onAppearanceChanged: ((JoeyAppearance) -> Void)?
    @ObservationIgnored var onPetCornerChanged: ((PetCorner) -> Void)?
    @ObservationIgnored var onScheduleChanged: ((QuietWindow, Int) -> Void)?
    @ObservationIgnored var onDoNotDisturbChanged: ((Bool) -> Void)?
    @ObservationIgnored var onSoundSelectionChanged: ((String, String) -> Void)?

    var rhythmMinutes: Int {
        didSet {
            let clamped = Self.clampRhythmMinutes(rhythmMinutes)
            if clamped != rhythmMinutes {
                rhythmMinutes = clamped
                return
            }
            defaults.set(rhythmMinutes, forKey: Key.rhythm)
            notifyScheduleChanged()
        }
    }

    /// Manual do-not-disturb. It never expires on its own; the user turns it off.
    var isDoNotDisturb: Bool {
        didSet {
            guard isDoNotDisturb != oldValue else { return }
            defaults.set(isDoNotDisturb, forKey: Key.doNotDisturb)
            onDoNotDisturbChanged?(isDoNotDisturb)
        }
    }

    var quietStartMinutes: Int {
        didSet {
            defaults.set(quietStartMinutes, forKey: Key.quietStart)
            notifyScheduleChanged()
        }
    }

    var quietEndMinutes: Int {
        didSet {
            defaults.set(quietEndMinutes, forKey: Key.quietEnd)
            notifyScheduleChanged()
        }
    }

    var appearance: JoeyAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: Key.appearance)
            onAppearanceChanged?(appearance)
        }
    }

    /// Where Joey starts when no dragged position has been saved.
    var petCorner: PetCorner {
        didSet {
            defaults.set(petCorner.rawValue, forKey: Key.petCorner)
            onPetCornerChanged?(petCorner)
        }
    }

    /// The desktop pet is hidden by default in this phase.
    var showsDesktopPet: Bool {
        didSet {
            defaults.set(showsDesktopPet, forKey: Key.showsDesktopPet)
            onShowsDesktopPetChanged?(showsDesktopPet)
        }
    }

    /// Ambient bed while companionship is active. `JoeyAudioCatalog.noneID` = 无背景音.
    var ambientSoundID: String {
        didSet {
            guard ambientSoundID != oldValue else { return }
            defaults.set(ambientSoundID, forKey: Key.ambientSound)
            notifySoundSelectionChanged()
        }
    }

    /// One-shot for session start and rest invite. `JoeyAudioCatalog.noneID` = 无提示音.
    var cueSoundID: String {
        didSet {
            guard cueSoundID != oldValue else { return }
            defaults.set(cueSoundID, forKey: Key.cueSound)
            notifySoundSelectionChanged()
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedRhythm = defaults.object(forKey: Key.rhythm) as? Int ?? 45
        self.rhythmMinutes = Self.clampRhythmMinutes(storedRhythm)

        self.isDoNotDisturb = defaults.object(forKey: Key.doNotDisturb) as? Bool ?? false

        self.quietStartMinutes = defaults.object(forKey: Key.quietStart) as? Int ?? 22 * 60
        self.quietEndMinutes = defaults.object(forKey: Key.quietEnd) as? Int ?? 8 * 60
        self.appearance = JoeyAppearance.fromStored(defaults.string(forKey: Key.appearance))
        self.petCorner = PetCorner(
            rawValue: defaults.string(forKey: Key.petCorner) ?? ""
        ) ?? .bottomRight
        self.showsDesktopPet = defaults.object(forKey: Key.showsDesktopPet) as? Bool ?? false
        // Ambient defaults off; cue defaults to the soft ceramic tap.
        self.ambientSoundID = defaults.string(forKey: Key.ambientSound)
            ?? JoeyAudioCatalog.noneID
        self.cueSoundID = defaults.string(forKey: Key.cueSound) ?? Self.defaultCueSoundID
    }

    var quietWindow: QuietWindow {
        QuietWindow(startMinutes: quietStartMinutes, endMinutes: quietEndMinutes)
    }

    private func notifyScheduleChanged() {
        onScheduleChanged?(quietWindow, rhythmMinutes)
    }

    private func notifySoundSelectionChanged() {
        onSoundSelectionChanged?(ambientSoundID, cueSoundID)
    }
}
