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
    var updateService: JoeyUpdateService
    var topChromeHeight: CGFloat = 40
    let onPrimaryAction: () -> Void
    let onGreetPet: () -> Void
    var onInviteAccept: (() -> Void)?
    var onInviteSnooze: (() -> Void)?
    var onInviteDoNotDisturb: (() -> Void)?
    var onDebugAction: ((DebugPetAction) -> Void)?
    let onRouteChange: (NestRoute) -> Void
    /// Keeps AppKit window chrome colours in sync with 系统 / 明亮 / 黑夜.
    var onChromeToneChange: ((JoeyChromeTone, Bool) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Poll so 系统 tracks macOS light/dark flips without a manual restart.
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            let chromeTone = settings.appearance.resolveChromeTone()

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
                publishChrome(tone: chromeTone, route: navigation.route)
            }
            .onChange(of: navigation.route) { _, newRoute in
                onRouteChange(newRoute)
                publishChrome(tone: chromeTone, route: newRoute)
            }
            .onChange(of: chromeTone) { _, newTone in
                publishChrome(tone: newTone, route: navigation.route)
            }
            .onChange(of: settings.appearance) { _, _ in
                publishChrome(tone: chromeTone, route: navigation.route)
            }
        }
    }

    /// Home: room paints under the transparent titlebar — no solid nav strip.
    /// Floating title stays blank; window metadata still uses `JoeyCopy.homeTitle`.
    private var immersiveHome: some View {
        immersiveScene(title: nil) {
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

    /// Settings uses windowBg/windowChrome; home/reflection use room chrome.
    private func publishChrome(tone: JoeyChromeTone, route: NestRoute) {
        onChromeToneChange?(tone, route == .settings)
    }

    /// Settings: full-height sidebar under the titlebar (no opaque nav strip).
    private var immersiveSettings: some View {
        ZStack(alignment: .top) {
            SettingsRootView(
                settings: settings,
                updateService: updateService,
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
        title: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .top) {
            content()

            if let title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .padding(.top, 10)
                    .allowsHitTesting(false)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .transition(.opacity)
    }
}
