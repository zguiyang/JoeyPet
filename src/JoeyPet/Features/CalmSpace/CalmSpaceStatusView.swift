import SwiftUI

/// Health status block below the orb. Plain typography, no card, no chrome.
struct CalmSpaceStatusView: View {
    let status: CalmSpaceHealth
    let palette: CalmSpacePalette
    let layout: CalmSpaceLayout

    private var accent: Color { palette.accent(for: status.level) }

    var body: some View {
        CalmSpaceStatusScaffold(
            palette: palette,
            layout: layout,
            dotColor: accent,
            dotGlow: accent.opacity(palette.isDark ? 0.55 : 0.32),
            headline: status.headline,
            detail: status.detail,
            metaLine: status.metaLine,
            lastCheckedText: status.lastCheckedText
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.accessibilitySummary)
    }
}

/// Work Rhythm is not implemented yet; show a quiet, honest placeholder instead of
/// a fake timer. The surrounding orb/space still changes character for the mode.
struct CalmSpaceWorkRhythmStatusView: View {
    let palette: CalmSpacePalette
    let layout: CalmSpaceLayout
    let hasRealHealthData: Bool

    var body: some View {
        CalmSpaceStatusScaffold(
            palette: palette,
            layout: layout,
            dotColor: palette.orbMid,
            dotGlow: palette.orbGlow.opacity(0.32),
            headline: "工作节奏",
            detail: "专注与休息提醒正在准备中；Mac 状态仍在后台默默监测。",
            metaLine: hasRealHealthData ? "功能尚未开放 · Mac Care 保持运行" : "功能尚未开放",
            lastCheckedText: nil
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("工作节奏。专注与休息提醒正在准备中。Mac 状态仍在后台监测。")
    }
}

private struct CalmSpaceStatusScaffold: View {
    let palette: CalmSpacePalette
    let layout: CalmSpaceLayout
    let dotColor: Color
    let dotGlow: Color
    let headline: String
    let detail: String
    let metaLine: String
    let lastCheckedText: String?

    private var headlineSize: CGFloat { layout.compact ? 23 : 26 }
    private var detailSize: CGFloat { layout.compact ? 12.5 : 14 }
    private var metaSize: CGFloat { layout.compact ? 10.5 : 11 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
                    .shadow(color: dotGlow, radius: 6)
                    .accessibilityHidden(true)

                Text(headline)
                    .font(.system(size: headlineSize, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(detail)
                .font(.system(size: detailSize))
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, layout.compact ? 8 : 10)

            HStack(spacing: 6) {
                Text(metaLine)
                if let lastCheckedText {
                    Text("·")
                    Text(lastCheckedText)
                }
            }
            .font(.system(size: metaSize, weight: .medium))
            .foregroundStyle(palette.statusMetaText)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .padding(.top, layout.compact ? 9 : 12)
        }
        .frame(width: layout.statusWidth)
        .frame(maxWidth: .infinity)
    }
}
