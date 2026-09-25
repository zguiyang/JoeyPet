import Combine
import Foundation
import SwiftUI

enum AppMode: String, CaseIterable, Hashable, Sendable {
    case macCare
    case workRhythm

    /// Segmented control label in the unified window navigation.
    var navigationTitle: String {
        switch self {
        case .macCare: return "电脑维护"
        case .workRhythm: return "工作节奏"
        }
    }
}

enum MacCareRoute: Equatable, Sendable {
    case home
    /// Shell QA: page-level navigation under unchanged global toolbar.
    case featureDetailMock
    case legacyCleanup
}

enum SettingsSection: String, CaseIterable, Hashable, Identifiable, Sendable {
    case workStatus
    case macStatus
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workStatus: return "工作状态"
        case .macStatus: return "电脑状态"
        case .general: return "通用"
        }
    }

    var systemImage: String {
        switch self {
        case .workStatus: return "figure.mind.and.body"
        case .macStatus: return "laptopcomputer"
        case .general: return "gearshape"
        }
    }
}

enum AppPresentation: Equatable, Sendable {
    case main
    case settings
}

enum MainWindowIntent: Sendable {
    case `default`
    case macCareCleanup
    case macCareDetailMock
    case workRhythm
    case settings
}

/// Top-level main window navigation and presentation. Not cleanup/sensor/pet runtime state.
@MainActor
final class AppShellState: ObservableObject {
    @Published var presentation: AppPresentation = .main
    @Published var mode: AppMode = .macCare
    @Published var macCareRoute: MacCareRoute = .home
    @Published var settingsSection: SettingsSection = .general

    func apply(intent: MainWindowIntent) {
        switch intent {
        case .default:
            presentation = .main
            mode = .macCare
            macCareRoute = .home
        case .macCareCleanup:
            presentation = .main
            mode = .macCare
            macCareRoute = .legacyCleanup
        case .macCareDetailMock:
            presentation = .main
            mode = .macCare
            macCareRoute = .featureDetailMock
        case .workRhythm:
            presentation = .main
            mode = .workRhythm
            macCareRoute = .home
        case .settings:
            presentation = .settings
        }
    }

    func openSettings() {
        presentation = .settings
    }

    func closeSettings() {
        presentation = .main
    }

    #if DEBUG
    /// Maps legacy QA launch flags to the new shell.
    static func intent(fromQAArgument raw: String) -> MainWindowIntent? {
        switch raw {
        case "overview", "maccare", "macCare":
            return .default
        case "cleanup":
            return .macCareCleanup
        case "macCareDetail", "maccareDetail", "detail":
            return .macCareDetailMock
        case "workRhythm", "workrhythm":
            return .workRhythm
        case "settings":
            return .settings
        default:
            return nil
        }
    }
    #endif
}
