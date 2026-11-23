import Foundation
import Observation

/// App-level settings shared by the windows, the menu bar item and the pet panel.
/// Persisted in UserDefaults; no database and no account.
@Observable
@MainActor
final class AppSettings {
    private enum Key {
        static let rhythm = "joey.rhythmMinutes"
        static let pauseUntil = "joey.pauseUntil"
        static let quietStart = "joey.quietStartMinutes"
        static let quietEnd = "joey.quietEndMinutes"
        static let appearance = "joey.appearance"
        static let feedback = "joey.feedback"
        static let showsDesktopPet = PetPreferences.showsDesktopPetKey
    }

    static let rhythmOptions = [45, 60, 90]

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored var onShowsDesktopPetChanged: ((Bool) -> Void)?
    @ObservationIgnored var onAppearanceChanged: ((JoeyAppearance) -> Void)?
    @ObservationIgnored var onScheduleChanged: ((QuietWindow, Int) -> Void)?
    @ObservationIgnored var onPauseChanged: ((Date?) -> Void)?

    var rhythmMinutes: Int {
        didSet {
            defaults.set(rhythmMinutes, forKey: Key.rhythm)
            notifyScheduleChanged()
        }
    }

    var pauseUntil: Date? {
        didSet {
            defaults.set(pauseUntil?.timeIntervalSince1970, forKey: Key.pauseUntil)
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

        if let timestamp = defaults.object(forKey: Key.pauseUntil) as? Double {
            self.pauseUntil = Date(timeIntervalSince1970: timestamp)
        } else {
            self.pauseUntil = nil
        }

        self.quietStartMinutes = defaults.object(forKey: Key.quietStart) as? Int ?? 22 * 60
        self.quietEndMinutes = defaults.object(forKey: Key.quietEnd) as? Int ?? 8 * 60
        self.appearance = JoeyAppearance(
            rawValue: defaults.string(forKey: Key.appearance) ?? ""
        ) ?? .light
        self.showsDesktopPet = defaults.object(forKey: Key.showsDesktopPet) as? Bool ?? false
        self.feedback = defaults.string(forKey: Key.feedback) ?? ""
    }

    var quietWindow: QuietWindow {
        QuietWindow(startMinutes: quietStartMinutes, endMinutes: quietEndMinutes)
    }

    var isPaused: Bool {
        guard let pauseUntil else { return false }
        return pauseUntil > .now
    }

    private func notifyScheduleChanged() {
        onScheduleChanged?(quietWindow, rhythmMinutes)
    }

    var pauseResumeText: String {
        guard let pauseUntil, pauseUntil > .now else {
            return "暂停这一小时里的邀请"
        }
        return "到 \(Self.clockText(for: pauseUntil)) 自动恢复"
    }

    var quietHoursText: String {
        "\(Self.clockText(minutes: quietStartMinutes)) 到 \(Self.clockText(minutes: quietEndMinutes))，Joey 会安静下来"
    }

    func setPaused(_ paused: Bool) {
        pauseUntil = paused ? Date().addingTimeInterval(3600) : nil
        onPauseChanged?(pauseUntil)
    }

    func clearExpiredPause() {
        guard let pauseUntil, pauseUntil <= .now else { return }
        self.pauseUntil = nil
        onPauseChanged?(nil)
    }

    static func clockText(minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static func clockText(for date: Date) -> String {
        clockFormatter.string(from: date)
    }

    static func date(fromMinutes minutes: Int) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .minute, value: minutes, to: start) ?? start
    }

    static func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
