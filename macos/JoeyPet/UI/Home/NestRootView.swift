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
    let onGreetPet: () -> Void
    var onInviteAccept: (() -> Void)?
    var onInviteSnooze: (() -> Void)?
    var onInviteDoNotDisturb: (() -> Void)?
    var onDebugAction: ((DebugPetAction) -> Void)?
    let onRouteChange: (NestRoute) -> Void
    /// Keeps AppKit window chrome colours in sync with 时段 / 系统.
    var onChromeToneChange: ((JoeyChromeTone, RoomDaypart?) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Refresh when the clock crosses a daypart boundary (and for system dark flips).
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            let displayDaypart = settings.appearance.resolveRoomDaypart(at: timeline.date)
            let chromeTone = settings.appearance.resolveChromeTone(at: timeline.date)

            Group {
                switch navigation.route {
                case .home:
                    immersiveHome
                case .reflection:
                    immersiveReflection
                case .settings:
                    immersiveSettings
                }
            }
            .animation(reduceMotion ? nil : JoeyMotion.stateEnter, value: navigation.route)
            .environment(\.joeyAppearance, settings.appearance)
            .environment(\.joeyChromeTone, chromeTone)
            .frame(minWidth: 880, minHeight: 560)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                onRouteChange(navigation.route)
                publishChrome(tone: chromeTone, daypart: displayDaypart, route: navigation.route)
            }
            .onChange(of: navigation.route) { _, newRoute in
                onRouteChange(newRoute)
                publishChrome(tone: chromeTone, daypart: displayDaypart, route: newRoute)
            }
            .onChange(of: chromeTone) { _, newTone in
                publishChrome(tone: newTone, daypart: displayDaypart, route: navigation.route)
            }
            .onChange(of: settings.appearance) { _, _ in
                publishChrome(tone: chromeTone, daypart: displayDaypart, route: navigation.route)
            }
            .onChange(of: displayDaypart) { _, _ in
                publishChrome(tone: chromeTone, daypart: displayDaypart, route: navigation.route)
            }
        }
    }

    /// Home: room paints under the transparent titlebar — no solid nav strip.
    private var immersiveHome: some View {
        immersiveScene(title: JoeyCopy.homeTitle) {
            RoomSceneView(
                rhythmMinutes: settings.rhythmMinutes,
                status: status,
                onOpenReflection: { navigation.showReflection() },
                onOpenClockSettings: { navigation.openSettings() },
                onPrimaryAction: onPrimaryAction,
                onGreetPet: onGreetPet,
                onInviteAccept: onInviteAccept,
                onInviteSnooze: onInviteSnooze,
                onInviteDoNotDisturb: onInviteDoNotDisturb
            )
        }
    }

    /// Reflection garden follows the same immersive rule as home.
    private var immersiveReflection: some View {
        immersiveScene(title: JoeyCopy.reflectionTitle) {
            ReflectionView(
                summary: status.summary,
                onReturn: { navigation.showHome() }
            )
        }
    }

    /// Home/reflection keep daypart wall under the titlebar; settings uses fixed
    /// chrome so sidebar, detail and traffic-light band stay one surface.
    private func publishChrome(tone: JoeyChromeTone, daypart: RoomDaypart, route: NestRoute) {
        onChromeToneChange?(tone, route == .settings ? nil : daypart)
    }

    /// Settings: full-height sidebar under the titlebar (no opaque nav strip).
    private var immersiveSettings: some View {
        ZStack(alignment: .top) {
            SettingsRootView(
                settings: settings,
                topInset: topChromeHeight,
                onDebugAction: onDebugAction
            )

            Text(JoeyCopy.settingsTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.72))
                .padding(.top, 10)
                .allowsHitTesting(false)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .transition(.opacity)
    }

    private func immersiveScene<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .top) {
            content()

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.72))
                .padding(.top, 10)
                .allowsHitTesting(false)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .transition(.opacity)
    }
}
