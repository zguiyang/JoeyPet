import SwiftUI

struct SettingsGeneralDetailView: View {
    @ObservedObject var model: AppModel
    @AppStorage(PetPreferences.ambientBehaviorsEnabledKey) private var ambientBehaviorsEnabled = PetPreferences.defaultAmbientBehaviorsEnabled
    @AppStorage(PetPreferences.proactiveBubblesEnabledKey) private var proactiveBubblesEnabled = PetPreferences.defaultProactiveBubblesEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsPageHeader(
                title: "通用",
                description: "配置 Joey 桌面伴随形态、系统外观、通知交互及启动行为。"
            )

            SettingsSectionTitle(title: "JOEY 伴随设置")
            SettingsFormRow(title: "显示 Joey 桌面伴侣", description: "在屏幕右下角显示 Joey 浮动交互小角色") {
                Toggle("", isOn: .constant(true))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .disabled(true)
            }
            SettingsRowDivider()
            SettingsFormRow(title: "仅在桌面闲置时可见", description: "全屏工作或全屏应用时自动隐藏，避免视觉打扰") {
                Toggle("", isOn: .constant(false))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .disabled(true)
            }
            SettingsRowDivider()
            SettingsFormRow(title: "呼吸与微动效", description: "允许 Joey 具有轻微的自然眨眼与呼吸节律") {
                Toggle("", isOn: $ambientBehaviorsEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            SettingsRowDivider()
            SettingsFormRow(title: "主动提示气泡", description: "在到达休息或高负载节点时弹出轻巧气泡") {
                Toggle("", isOn: $proactiveBubblesEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            SettingsSectionTitle(title: "外观与语言")
            SettingsFormRow(title: "外观模式", description: "切换浅色模式、深色模式或自动跟随系统") {
                Picker("", selection: .constant(0)) {
                    Text("跟随系统").tag(0)
                    Text("浅色").tag(1)
                    Text("深色").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: SettingsMetrics.trailingSegmentedWidth)
                .labelsHidden()
                .disabled(true)
            }
            SettingsRowDivider()
            SettingsFormRow(title: "界面语言", description: "选择应用显示语言") {
                Picker("", selection: .constant(0)) {
                    Text("简体中文").tag(0)
                }
                .frame(width: SettingsMetrics.trailingLanguagePickerWidth)
                .labelsHidden()
                .disabled(true)
            }

            SettingsSectionTitle(title: "应用行为")
            SettingsFormRow(title: "开机自启动", description: "在系统登录时静默启动并在后台守护") {
                Toggle("", isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            if let error = model.launchAtLoginError {
                Text(error)
                    .font(.system(size: SettingsMetrics.rowDescriptionFontSize))
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }

            SettingsDetailFooter(resetTitle: "恢复通用默认设置") {
                ambientBehaviorsEnabled = PetPreferences.defaultAmbientBehaviorsEnabled
                proactiveBubblesEnabled = PetPreferences.defaultProactiveBubblesEnabled
                model.notifyPreferencesChanged()
            }
        }
        .onChange(of: ambientBehaviorsEnabled) { _, _ in model.notifyPreferencesChanged() }
        .onChange(of: proactiveBubblesEnabled) { _, _ in model.notifyPreferencesChanged() }
    }
}
