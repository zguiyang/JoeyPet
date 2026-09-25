import SwiftUI

struct AppShellView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var shellState: AppShellState
    @ObservedObject var permissionService: PermissionService

    var body: some View {
        presentationContainer
            .frame(minWidth: ShellMetrics.minimumWindowWidth, minHeight: ShellMetrics.minimumWindowHeight)
            .toolbar {
                if shellState.presentation != .permissionOnboarding {
                    UnifiedWindowNavigation(shellState: shellState)
                }
            }
            .removingDefaultWindowToolbarItems()
            .mainWindowChrome()
    }

    @ViewBuilder
    private var presentationContainer: some View {
        switch shellState.presentation {
        case .permissionOnboarding:
            PermissionOnboardingView(permissionService: permissionService, shellState: shellState)
        case .main:
            mainPresentationBody
        case .settings:
            SettingsRootView(shellState: shellState, permissionService: permissionService)
        }
    }

    @ViewBuilder
    private var mainPresentationBody: some View {
        switch shellState.mode {
        case .macCare:
            MacCareRootView(model: model, shellState: shellState)
        case .workRhythm:
            WorkRhythmRootView()
        }
    }
}
