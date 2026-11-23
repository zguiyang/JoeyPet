import Observation
import SwiftUI

enum NestRoute {
    case home
    case reflection
    case settings
}

/// Navigation inside the one main window. Settings is a page, not a separate window.
@Observable
@MainActor
final class NestNavigation {
    var route: NestRoute = .home

    private var routeBeforeSettings: NestRoute = .home

    func showHome() {
        route = .home
    }

    func showReflection() {
        route = .reflection
    }

    func openSettings() {
        guard route != .settings else { return }
        routeBeforeSettings = route
        route = .settings
    }

    func closeSettings() {
        guard route == .settings else { return }
        route = routeBeforeSettings
    }

    func toggleSettings() {
        if route == .settings {
            closeSettings()
        } else {
            openSettings()
        }
    }
}

/// The main window content: the room, the reflection view, and settings share one window.
struct NestRootView: View {
    @Bindable var settings: AppSettings
    @Bindable var navigation: NestNavigation
    var status: CompanionStatus
    var topChromeHeight: CGFloat = 40
    let onPrimaryAction: () -> Void
    let onRouteChange: (NestRoute) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            WindowChromeHeader(
                title: title(for: navigation.route),
                height: topChromeHeight
            )

            ZStack {
                switch navigation.route {
                case .home:
                    RoomSceneView(
                        rhythmMinutes: settings.rhythmMinutes,
                        showsDesktopPet: settings.showsDesktopPet,
                        status: status,
                        onOpenReflection: { navigation.showReflection() },
                        onOpenClockSettings: { navigation.openSettings() },
                        onPrimaryAction: onPrimaryAction
                    )
                    .transition(.opacity)
                case .reflection:
                    ReflectionView(
                        summary: status.summary,
                        onReturn: { navigation.showHome() }
                    )
                    .transition(.opacity)
                case .settings:
                    SettingsRootView(settings: settings)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : JoeyMotion.stateEnter, value: navigation.route)
        }
        .environment(\.joeyAppearance, settings.appearance)
        .frame(minWidth: 880, minHeight: 560)
        .onAppear { onRouteChange(navigation.route) }
        .onChange(of: navigation.route) { _, newRoute in
            onRouteChange(newRoute)
        }
    }

    private func title(for route: NestRoute) -> String {
        switch route {
        case .home: return JoeyCopy.homeTitle
        case .reflection: return JoeyCopy.reflectionTitle
        case .settings: return JoeyCopy.settingsTitle
        }
    }
}
