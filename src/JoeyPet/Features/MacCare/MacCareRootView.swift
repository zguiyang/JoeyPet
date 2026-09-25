import SwiftUI

struct MacCareRootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var shellState: AppShellState

    var body: some View {
        Group {
            switch shellState.macCareRoute {
            case .home:
                macCareHomeContainer
            case .featureDetailMock:
                featureDetailMockContainer
            case .legacyCleanup:
                legacyCleanupContainer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var macCareHomeContainer: some View {
        featurePageContainer {
            MacCareHomeView(model: model, shellState: shellState)
        }
    }

    private var featureDetailMockContainer: some View {
        featurePageContainer {
            VStack(alignment: .leading, spacing: ShellMetrics.contentMargin) {
                FeaturePageNavigationHeader(
                    parentTitle: "电脑维护",
                    pageTitle: "应用卸载",
                    onBack: { shellState.macCareRoute = .home }
                )
                Spacer(minLength: 0)
            }
        }
    }

    private var legacyCleanupContainer: some View {
        featurePageContainer {
            VStack(alignment: .leading, spacing: ShellMetrics.contentMargin) {
                FeaturePageNavigationHeader(
                    parentTitle: "电脑维护",
                    pageTitle: "清理",
                    onBack: { shellState.macCareRoute = .home }
                )
                LegacyCleanupView(model: model)
            }
        }
    }

    private func featurePageContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(ShellMetrics.contentMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
