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
        static let feedback = "joey.feedback"
        static let showsDesktopPet = PetPreferences.showsDesktopPetKey
    }

    static let rhythmOptions = [45, 60, 90]

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored var onShowsDesktopPetChanged: ((Bool) -> Void)?
    @ObservationIgnored var onAppearanceChanged: ((JoeyAppearance) -> Void)?
    @ObservationIgnored var onPetCornerChanged: ((PetCorner) -> Void)?
    @ObservationIgnored var onScheduleChanged: ((QuietWindow, Int) -> Void)?
    @ObservationIgnored var onDoNotDisturbChanged: ((Bool) -> Void)?

    var rhythmMinutes: Int {
        didSet {
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

    var feedback: String {
        didSet { defaults.set(feedback, forKey: Key.feedback) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedRhythm = defaults.object(forKey: Key.rhythm) as? Int ?? 45
        self.rhythmMinutes = Self.rhythmOptions.contains(storedRhythm) ? storedRhythm : 45

        self.isDoNotDisturb = defaults.object(forKey: Key.doNotDisturb) as? Bool ?? false

        self.quietStartMinutes = defaults.object(forKey: Key.quietStart) as? Int ?? 22 * 60
        self.quietEndMinutes = defaults.object(forKey: Key.quietEnd) as? Int ?? 8 * 60
        self.appearance = JoeyAppearance(
            rawValue: defaults.string(forKey: Key.appearance) ?? ""
        ) ?? .light
        self.petCorner = PetCorner(
            rawValue: defaults.string(forKey: Key.petCorner) ?? ""
        ) ?? .bottomRight
        self.showsDesktopPet = defaults.object(forKey: Key.showsDesktopPet) as? Bool ?? false
        self.feedback = defaults.string(forKey: Key.feedback) ?? ""
    }

    var quietWindow: QuietWindow {
        QuietWindow(startMinutes: quietStartMinutes, endMinutes: quietEndMinutes)
    }

    private func notifyScheduleChanged() {
        onScheduleChanged?(quietWindow, rhythmMinutes)
    }
}
