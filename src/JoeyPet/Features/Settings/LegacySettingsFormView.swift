import SwiftUI

/// Pre–Settings Phase form; will move into section detail views later.
struct LegacySettingsFormView: View {
    @ObservedObject var model: AppModel
    @AppStorage(PetPreferences.ambientBehaviorsEnabledKey) private var ambientBehaviorsEnabled = PetPreferences.defaultAmbientBehaviorsEnabled
    @AppStorage(PetPreferences.proactiveBubblesEnabledKey) private var proactiveBubblesEnabled = PetPreferences.defaultProactiveBubblesEnabled

    var body: some View {
        Form {
            Section("登录") {
                Toggle("登录时启动", isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                ))
                if let error = model.launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            Section("Joey") {
                Toggle("自然动作", isOn: $ambientBehaviorsEnabled)
                Toggle("主动提示气泡", isOn: $proactiveBubblesEnabled)
                Button("重置 Joey 位置") { model.resetPetPosition() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 480, alignment: .leading)
        .onChange(of: ambientBehaviorsEnabled) { _, _ in model.notifyPreferencesChanged() }
        .onChange(of: proactiveBubblesEnabled) { _, _ in model.notifyPreferencesChanged() }
    }
}
