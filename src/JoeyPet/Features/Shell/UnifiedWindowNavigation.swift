import SwiftUI

/// Window-level navigation shared by Main and Settings presentations. Does not own feature routes.
struct UnifiedWindowNavigation: ToolbarContent {
    @ObservedObject var shellState: AppShellState

    var body: some ToolbarContent {
        switch shellState.presentation {
        case .main:
            mainConfiguration
        case .settings:
            settingsConfiguration
        }
    }

    @ToolbarContentBuilder
    private var mainConfiguration: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("模式", selection: $shellState.mode) {
                ForEach(AppMode.allCases, id: \.self) { mode in
                    Text(mode.navigationTitle).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                shellState.openSettings()
            } label: {
                Label("设置", systemImage: "gearshape")
            }
            .help("设置")
        }
    }

    @ToolbarContentBuilder
    private var settingsConfiguration: some ToolbarContent {
        settingsTitleToolbarItem
    }

    @ToolbarContentBuilder
    private var settingsTitleToolbarItem: some ToolbarContent {
        let item = ToolbarItem(placement: .principal) {
            SettingsGlobalToolbarTitle()
        }
        if #available(macOS 26.0, *) {
            item.sharedBackgroundVisibility(.hidden)
        } else {
            item
        }
    }
}
