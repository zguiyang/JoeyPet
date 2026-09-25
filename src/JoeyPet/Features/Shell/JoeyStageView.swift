import SwiftUI

/// Main-window Joey habitat. Placeholder renderer until a dedicated stage SpriteKit view ships.
struct JoeyStageView: View {
    @ObservedObject var stageState: JoeyStageState

    var body: some View {
        let snapshot = stageState.snapshot
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            ZStack {
                RoundedRectangle(cornerRadius: ShellMetrics.stageCornerRadius, style: .continuous)
                    .fill(.quaternary.opacity(0.35))
                RoundedRectangle(cornerRadius: ShellMetrics.stageCornerRadius, style: .continuous)
                    .strokeBorder(.separator.opacity(0.5), lineWidth: 1)

                VStack(spacing: 12) {
                    Image(systemName: stageSymbolName(for: snapshot))
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(snapshot.overallSeverity.swiftUIColor)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)

                    Text("Joey Stage")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(stageStatusLine(for: snapshot))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .padding(20)
            }
            .frame(maxWidth: 220, maxHeight: 220)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(stageAccessibilityLabel(for: snapshot))

            VStack(alignment: .leading, spacing: 6) {
                StatusLabel(severity: snapshot.overallSeverity, text: "Mac \(snapshot.overallSeverity.uiDisplayName)")
                    .font(.callout)
                Text("Stage renderer 占位 — 将与桌面宠物共享状态，独立 SpriteKit 场景。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ShellMetrics.contentMargin)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background.opacity(0.001))
    }

    private func stageSymbolName(for snapshot: JoeyStageSnapshot) -> String {
        if snapshot.transientBehavior != nil {
            return "sparkles"
        }
        switch snapshot.petState {
        case .idle: return "face.smiling"
        case .sweating: return "thermometer.medium"
        case .tired: return "moon.zzz.fill"
        case .carryingTrash: return "externaldrive.fill"
        }
    }

    private func stageStatusLine(for snapshot: JoeyStageSnapshot) -> String {
        if let behavior = snapshot.transientBehavior {
            return "临时动作：\(behavior.rawValue)"
        }
        switch snapshot.petState {
        case .idle: return "安静陪伴"
        case .sweating: return "散热有点吃力"
        case .tired: return "内存有点累"
        case .carryingTrash: return "磁盘有点挤"
        }
    }

    private func stageAccessibilityLabel(for snapshot: JoeyStageSnapshot) -> String {
        "Joey，\(stageStatusLine(for: snapshot))"
    }
}
