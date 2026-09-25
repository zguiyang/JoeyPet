import SwiftUI

struct PermissionOnboardingView: View {
    @ObservedObject var permissionService: PermissionService
    @ObservedObject var shellState: AppShellState

    @State private var awaitingSystemSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                hero
                explanationBlock
                statusCard
                if awaitingSystemSettings, permissionService.fullDiskAccessStatus != .granted {
                    waitingHint
                }
                actionButtons
            }
            .frame(maxWidth: 440)
            .padding(.vertical, 36)
            .padding(.horizontal, ShellMetrics.contentMargin)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: permissionService.fullDiskAccessStatus) { _, newValue in
            if newValue == .granted {
                awaitingSystemSettings = false
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            Image(systemName: "externaldrive.badge.checkmark")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)
            Text("让 JoeyPet 完整了解这台 Mac")
                .font(.system(size: 22, weight: .semibold))
                .multilineTextAlignment(.center)
        }
    }

    private var explanationBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("为了进行完整的存储分析、缓存扫描和应用残留检测，JoeyPet 需要「完全磁盘访问权限」。")
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text("存储分析与清理在本机完成。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("完全磁盘访问")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
            HStack(spacing: 8) {
                Circle()
                    .fill(FullDiskAccessStatusPresentation.indicatorColor(for: permissionService.fullDiskAccessStatus))
                    .frame(width: 8, height: 8)
                Text("状态：\(FullDiskAccessStatusPresentation.statusTitle(for: permissionService.fullDiskAccessStatus))")
                    .font(.system(size: 14, weight: .medium))
            }
            Text(FullDiskAccessStatusPresentation.statusDetail(for: permissionService.fullDiskAccessStatus))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
    }

    private var waitingHint: some View {
        Text("在系统设置中开启 JoeyPet，然后返回这里。")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch permissionService.fullDiskAccessStatus {
        case .granted:
            VStack(spacing: 10) {
                Button("继续") { finishOnboarding() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
            .frame(maxWidth: .infinity)
        case .unknown:
            VStack(spacing: 10) {
                Button("重新检查") {
                    permissionService.refresh()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button(FullDiskAccessStatusPresentation.openSettingsButtonTitle(for: .unknown)) {
                    openSystemSettings()
                }
                .buttonStyle(.bordered)
                Button("稍后设置") { deferOnboarding() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        case .notGranted:
            VStack(spacing: 10) {
                Button(awaitingSystemSettings ? "等待授权…" : "打开系统设置") {
                    openSystemSettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(awaitingSystemSettings)
                Button("稍后设置") { deferOnboarding() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func openSystemSettings() {
        awaitingSystemSettings = true
        _ = SystemSettingsPrivacy.openFullDiskAccessSettings()
    }

    private func finishOnboarding() {
        PermissionOnboardingPreferences.markCompleted()
        shellState.presentation = .main
        shellState.mode = .macCare
        shellState.macCareRoute = .home
    }

    private func deferOnboarding() {
        PermissionOnboardingPreferences.markCompleted()
        shellState.presentation = .main
        shellState.mode = .macCare
        shellState.macCareRoute = .home
    }
}
