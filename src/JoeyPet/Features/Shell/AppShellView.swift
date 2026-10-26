import SwiftUI

struct AppShellView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var shellState: AppShellState
    @ObservedObject var permissionService: PermissionService

    var body: some View {
        presentationContainer
            .frame(minWidth: ShellMetrics.minimumWindowWidth, minHeight: ShellMetrics.minimumWindowContentHeight)
            .mainWindowChrome()
    }

    @ViewBuilder
    private var presentationContainer: some View {
        switch shellState.presentation {
        case .permissionOnboarding:
            PermissionOnboardingView(permissionService: permissionService, shellState: shellState)
        case .main:
            if shellState.mode == .macCare, shellState.macCareRoute != .home {
                CalmSpaceFeaturePageView(model: model, shellState: shellState)
            } else {
                CalmSpaceRootView(model: model, shellState: shellState)
            }
        case .settings:
            SettingsRootView(model: model, shellState: shellState, permissionService: permissionService)
        }
    }
}
