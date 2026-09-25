import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var shellState: AppShellState

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebarColumn

            Divider()

            settingsDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(ShellMetrics.contentMargin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var settingsSidebarColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSidebarNavigationRow(
                systemImage: "chevron.left",
                title: "返回",
                isSelected: false,
                action: { shellState.closeSettings() }
            )

            Divider()
                .padding(.horizontal, SettingsMetrics.sidebarPadding)
                .padding(.vertical, SettingsMetrics.sidebarItemSpacing)

            VStack(spacing: SettingsMetrics.sidebarItemSpacing) {
                ForEach(SettingsSection.allCases) { section in
                    SettingsSidebarRow(
                        section: section,
                        isSelected: shellState.settingsSection == section,
                        action: { shellState.settingsSection = section }
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.top, SettingsMetrics.sidebarPadding)
        .frame(width: ShellMetrics.settingsSidebarIdealWidth)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var settingsDetail: some View {
        switch shellState.settingsSection {
        case .general:
            sectionHeading("通用")
        case .macStatus:
            sectionHeading("电脑状态")
        case .workStatus:
            sectionHeading("工作状态")
        }
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.title2.weight(.semibold))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
