import SwiftUI

struct SettingsGlobalToolbarTitle: View {
    var body: some View {
        Text("设置")
            .font(.system(size: ShellMetrics.settingsToolbarTitleSize, weight: .semibold))
            .foregroundStyle(.primary)
    }
}
