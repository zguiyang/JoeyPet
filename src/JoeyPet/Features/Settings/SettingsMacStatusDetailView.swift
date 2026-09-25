import SwiftUI

struct SettingsMacStatusDetailView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsPageHeader(
                title: "电脑状态",
                description: "配置系统负载预警、缓存巡检策略以及应用卸载保护。"
            )

            SettingsSectionTitle(title: "系统状态提醒")
            disabledToggleRow(title: "内存压力提醒", description: "当 macOS 内存压力进入黄色高负荷区间时提示", isOn: true)
            SettingsRowDivider()
            SettingsFormRow(title: "提醒灵敏度", description: "控制负载感知阈值与通知频率（均衡为推荐设置）") {
                Picker("", selection: .constant(1)) {
                    Text("较早").tag(0)
                    Text("均衡").tag(1)
                    Text("较晚").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: SettingsMetrics.trailingSegmentedWidth)
                .labelsHidden()
                .disabled(true)
            }
            SettingsRowDivider()
            disabledToggleRow(title: "存储空间不足预警", description: "系统可用磁盘空间低于 15 GB 时发出整理建议", isOn: true)
            SettingsRowDivider()
            disabledToggleRow(title: "散热异常关注", description: "风扇高转速持续 5 分钟以上时轻量提醒", isOn: false)

            SettingsSectionTitle(title: "扫描与清理策略")
            disabledToggleRow(title: "包含开发者缓存", description: "自动扫描 Xcode DerivedData、CocoaPods 及 npm 依赖缓存", isOn: true)
            SettingsRowDivider()
            SettingsFormRow(title: "系统与应用日志保留期", description: "仅清理超过指定期限的过期历史日志") {
                Picker("", selection: .constant(0)) {
                    Text("超过 7 天").tag(0)
                }
                .frame(width: SettingsMetrics.trailingPickerWidth)
                .labelsHidden()
                .disabled(true)
            }

            SettingsDetailFooter(resetTitle: "恢复电脑状态推荐设置", onReset: nil)
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
