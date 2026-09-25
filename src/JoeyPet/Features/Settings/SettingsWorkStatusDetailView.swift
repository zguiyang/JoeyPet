import SwiftUI

struct SettingsWorkStatusDetailView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsPageHeader(
                title: "工作状态",
                description: "配置工作与休息节律，以及健康提醒偏好。"
            )

            SettingsSectionTitle(title: "工作与休息")
            workDurationRow(title: "连续工作时长", description: "达到建议时长后提醒休息", selection: "50 分钟")
            SettingsRowDivider()
            workDurationRow(title: "休息时长", description: "单次舒展身体与视线放松时间", selection: "10 分钟")
            SettingsRowDivider()
            workDurationRow(title: "稍后提醒", description: "推迟休息建议的缓冲时长", selection: "5 分钟")
            SettingsRowDivider()
            SettingsFormRow(title: "闲置时自动暂停", description: "键盘鼠标离开 3 分钟后暂缓计时") {
                Toggle("", isOn: .constant(true))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .disabled(true)
            }

            SettingsSectionTitle(title: "健康提醒")
            disabledToggleRow(title: "眼睛休息 (20-20-20 法则)", description: "工作 20 分钟远眺 20 英尺外物体 20 秒", isOn: true)
            SettingsRowDivider()
            disabledToggleRow(title: "喝水与补水提醒", description: "定时温和提示补充水分", isOn: true)
            SettingsRowDivider()
            disabledToggleRow(title: "起身活动提醒", description: "连续久坐达到预设时长时建议起身走动", isOn: true)

            SettingsDetailFooter(resetTitle: "恢复工作状态默认设置", onReset: nil)
        }
    }

    private func workDurationRow(title: String, description: String, selection: String) -> some View {
        SettingsFormRow(title: title, description: description) {
            Picker("", selection: .constant(0)) {
                Text(selection).tag(0)
            }
            .frame(width: SettingsMetrics.trailingPickerWidth)
            .labelsHidden()
            .disabled(true)
        }
    }

    private func disabledToggleRow(title: String, description: String, isOn: Bool) -> some View {
        SettingsFormRow(title: title, description: description) {
            Toggle("", isOn: .constant(isOn))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(true)
        }
    }
}
