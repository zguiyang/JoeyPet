import SwiftUI

/// Conventional feature page used by the main window for non-immersive work
/// (disk management, applications). The central orb is intentionally not rendered
/// here: the immersive scene stops when it is no longer visible.
struct CalmSpaceFeaturePageView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var shellState: AppShellState

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let palette = CalmSpacePalette.palette(for: colorScheme)
            let horizontal = min(max(proxy.size.width * 0.045, 28), 56)

            ZStack {
                background(palette: palette, size: proxy.size)

                VStack(alignment: .leading, spacing: 22) {
                    pageHeader(palette: palette)

                    switch shellState.macCareRoute {
                    case .legacyCleanup:
                        diskContent(palette: palette)
                    case .featureDetailMock:
                        applicationsPlaceholder(palette: palette)
                    case .home:
                        EmptyView()
                    }
                }
                .frame(maxWidth: 880, alignment: .leading)
                .padding(.top, 38)
                .padding(.bottom, 28)
                .padding(.horizontal, horizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Background

    private func background(palette: CalmSpacePalette, size: CGSize) -> some View {
        let diameter = max(size.width, size.height)
        return ZStack {
            LinearGradient(
                colors: [palette.backgroundTop, palette.backgroundMid, palette.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [palette.ambientSecondary.opacity(palette.isDark ? 0.16 : 0.24), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: diameter * 0.78
            )
            RadialGradient(
                colors: [.clear, palette.backgroundBottom.opacity(palette.isDark ? 0.45 : 0.18)],
                center: .center,
                startRadius: diameter * 0.22,
                endRadius: diameter * 0.78
            )
        }
    }

    // MARK: - Header

    private func pageHeader(palette: CalmSpacePalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                shellState.macCareRoute = .home
            } label: {
                Label("Mac Care", systemImage: "chevron.backward")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("返回 Calm Space")

            Text(pageTitle)
                .font(.system(size: 24, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(palette.primaryText)

            Text(pageSubtitle)
                .font(.system(size: 12.5))
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pageTitle: String {
        switch shellState.macCareRoute {
        case .legacyCleanup: return "磁盘管理"
        case .featureDetailMock: return "应用管理"
        case .home: return "Mac Care"
        }
    }

    private var pageSubtitle: String {
        switch shellState.macCareRoute {
        case .legacyCleanup:
            return storageSummary
        case .featureDetailMock:
            return "查看已安装应用及关联缓存残留。"
        case .home:
            return ""
        }
    }

    private var storageSummary: String {
        let snapshot = model.systemStatus
        guard let total = snapshot.storageTotalBytes,
              let available = snapshot.storageAvailableBytes,
              total > 0
        else {
            return "扫描允许范围内的缓存和日志，确认后再移到废纸篓。"
        }
        let used = max(total - available, 0)
        let percent = Int((Double(used) / Double(total) * 100).rounded())
        return "已用 \(JoeyByteFormat.string(fromByteCount: used)) / \(JoeyByteFormat.string(fromByteCount: total))（\(percent)%），可用 \(JoeyByteFormat.string(fromByteCount: available))。"
    }

    // MARK: - Disk management

    private func diskContent(palette: CalmSpacePalette) -> some View {
        LegacyCleanupView(model: model)
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(palette.controlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(palette.controlStroke, lineWidth: 0.5)
            }
    }

    // MARK: - Applications

    private func applicationsPlaceholder(palette: CalmSpacePalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(palette.secondaryText)
                .symbolRenderingMode(.hierarchical)

            Text("应用卸载尚未开放")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.primaryText)

            Text("当前版本还没有实现应用列表、卸载流程与关联残留清理。为了避免误导，这里不提供占位操作。")
                .font(.system(size: 12.5))
                .foregroundStyle(palette.secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 520, alignment: .leading)
        }
        .padding(24)
        .frame(maxWidth: 620, alignment: .leading)
        .background(palette.controlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(palette.controlStroke, lineWidth: 0.5)
        }
    }
}
