import SwiftUI

struct SettingsGeneralView: View {
    @ObservedObject var permissionService: PermissionService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsPageHeader(
                    title: "通用",
                    description: "启动、权限与其他常用偏好。"
                )

                SettingsSectionTitle(title: "权限与访问")

                SettingsFormRow(
                    title: "完全磁盘访问",
                    description: "用于完整存储分析、深度扫描和应用残留检测。存储分析与清理在本机完成。"
                ) {
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(FullDiskAccessStatusPresentation.indicatorColor(for: permissionService.fullDiskAccessStatus))
                                .frame(width: 7, height: 7)
                            Text(FullDiskAccessStatusPresentation.statusTitle(for: permissionService.fullDiskAccessStatus))
                                .font(.system(size: SettingsMetrics.rowTitleFontSize, weight: .medium))
                                .foregroundStyle(FullDiskAccessStatusPresentation.indicatorColor(for: permissionService.fullDiskAccessStatus))
                        }
                        if permissionService.fullDiskAccessStatus == .unknown {
                            Button("重新检查") {
                                permissionService.refresh()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        Button(FullDiskAccessStatusPresentation.openSettingsButtonTitle(for: permissionService.fullDiskAccessStatus)) {
                            _ = SystemSettingsPrivacy.openFullDiskAccessSettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                SettingsRowDivider()

                SettingsDetailFooter(resetTitle: "重置 Joey 位置", onReset: nil)
            }
            .frame(maxWidth: SettingsMetrics.detailMaxContentWidth, alignment: .leading)
        }
    }
}
