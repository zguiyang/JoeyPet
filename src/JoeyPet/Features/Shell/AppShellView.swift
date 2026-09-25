import SwiftUI

struct AppShellView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var shellState: AppShellState

    var body: some View {
        presentationContainer
            .frame(minWidth: ShellMetrics.minimumWindowWidth, minHeight: ShellMetrics.minimumWindowHeight)
            .toolbar {
                UnifiedWindowNavigation(shellState: shellState)
            }
            .removingDefaultWindowToolbarItems()
            .mainWindowChrome()
    }

    @ViewBuilder
    private var presentationContainer: some View {
        switch shellState.presentation {
        case .main:
            mainPresentationBody
        case .settings:
            SettingsRootView(shellState: shellState)
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
