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
        case .permissionOnboarding:
            ToolbarItemGroup { EmptyView() }
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
            .controlSize(.small)
            .frame(maxWidth: 248)
        }
        settingsEntryToolbarItem
    }

    /// Gear opens Settings. Hide the unified-toolbar shared capsule (same as Settings title item).
    @ToolbarContentBuilder
    private var settingsEntryToolbarItem: some ToolbarContent {
        let item = ToolbarItem(placement: .primaryAction) {
            Button {
                shellState.openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderless)
            .help("设置")
            .accessibilityLabel("设置")
        }
        if #available(macOS 26.0, *) {
            item.sharedBackgroundVisibility(.hidden)
        } else {
            item
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
