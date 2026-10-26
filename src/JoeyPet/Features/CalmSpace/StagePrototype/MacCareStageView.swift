import SwiftUI

#if DEBUG

// MARK: - Mac Care Stage
//
// The full Mac Care Stage: the dynamic body plus a conclusion-and-context block that is
// one composition with it (a faint 1 px connector establishes the link). This is NOT the
// old "title + description + meta" three-line template — the layering is semantic:
//
//     body → 结论 (status) → 解释句 (detail) → Activity slot → 语境/操作 (context)
//
// The activity slot has a fixed height so it never shifts the copy above it, and an
// action chip only appears when there is something actionable. A healthy Mac never
// shows a cleanup/optimise button.
struct MacCareStageView: View {
    let tokens: MacCareStageTokens
    let material: MacCareStageMaterial
    let layout: CalmSpaceStageLayout
    let content: MacCareStageContent
    let variant: CalmSpaceStageVariant
    let reduceMotion: Bool
    let freeze: Bool
    let onAction: () -> Void

    private var accent: Color { tokens.accent(for: content.level) }
    private var frozen: Bool { reduceMotion || freeze }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Body, centred on the Stage axis (its centre is known, so `.position` fits).
            MacCareStageBody(
                material: material,
                level: content.level,
                diameter: layout.bodyDiameter,
                isDark: tokens.isDark,
                variant: variant,
                reduceMotion: reduceMotion,
                freeze: freeze
            )
            .position(x: layout.bodyCenter.x, y: layout.bodyCenter.y)

            // Conclusion + context block, centred horizontally and top-anchored at
            // `infoTop` so it grows downward and can never ride up over the body.
            VStack(spacing: 0) {
                Color.clear.frame(height: layout.infoTop)
                infoBlock
                    .frame(width: layout.infoWidth)
                Spacer(minLength: 0)
            }
            .frame(width: layout.size.width, height: layout.size.height, alignment: .top)
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .animation(.easeInOut(duration: 1.0), value: content.level)
    }

    // MARK: - Info block

    private var infoBlock: some View {
        VStack(spacing: 0) {
            // Connector: a 1 px, short, faint vertical line that binds the block to the
            // body above. Not a card, not a divider stack.
            Rectangle()
                .fill(tokens.connectorLine)
                .frame(width: 1, height: layout.connectorHeight)

            // 1. Status row: state dot + headline. The dot is pinned to the first line's
            // cap-height (not floated at the vertical centre) so a two-line long-copy
            // headline keeps the dot aligned to line one.
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: tokens.isDark ? 7 : 6.5, height: tokens.isDark ? 7 : 6.5)
                    .shadow(color: accent.opacity(tokens.isDark ? 0.5 : 0.28), radius: 5)
                    .padding(.top, max(0, layout.headlineSize * 0.30))
                    .accessibilityHidden(true)

                Text(content.headline)
                    .font(.system(size: layout.headlineSize, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(tokens.primaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, layout.compact ? 9 : 12)

            // 2. Explanation sentence — at most two lines.
            Text(content.detail)
                .font(.system(size: layout.detailSize))
                .foregroundStyle(tokens.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, layout.compact ? 7 : 9)

            // 3. Activity slot — fixed height; empty keeps its space.
            activitySlot
                .frame(height: layout.activitySlotHeight)
                .padding(.top, layout.compact ? 8 : 10)

            // 4. Context row.
            contextRow
                .padding(.top, layout.compact ? 8 : 10)
        }
    }

    // MARK: - Activity slot

    @ViewBuilder
    private var activitySlot: some View {
        if let activity = content.activity {
            switch activity {
            case .scanning(let label, let progress):
                VStack(spacing: 5) {
                    Text("\(label)… \(Int(progress * 100))%")
                        .font(.system(size: layout.metaSize, weight: .medium))
                        .foregroundStyle(tokens.secondaryText)
                    progressLine(progress)
                }
            case .maintenance(let label):
                VStack(spacing: 5) {
                    Text("\(label)…")
                        .font(.system(size: layout.metaSize, weight: .medium))
                        .foregroundStyle(tokens.secondaryText)
                    progressLine(0.6)
                }
            case .complete(let label):
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(accent)
                    Text(label)
                        .font(.system(size: layout.metaSize, weight: .medium))
                        .foregroundStyle(tokens.secondaryText)
                }
            }
        } else if content.progressLabel != nil {
            // unknown-state supporting progress is shown in the context row instead.
            EmptyView()
        } else {
            EmptyView()
        }
    }

    private func progressLine(_ progress: Double) -> some View {
        GeometryReader { proxy in
            let w = min(proxy.size.width, layout.progressLineWidth)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tokens.progressTrack)
                    .frame(width: w, height: 1.5)
                Capsule()
                    .fill(tokens.progressFill)
                    .frame(width: w * progress, height: 1.5)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 1.5)
    }

    // MARK: - Context row

    @ViewBuilder
    private var contextRow: some View {
        if let action = content.action {
            // attention / critical: inline action chip + a quiet meta line.
            HStack(spacing: 10) {
                actionChip(action)
                Text(content.meta ?? "")
                    .font(.system(size: layout.metaSize))
                    .foregroundStyle(tokens.tertiaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if content.progressLabel != nil {
            // unknown: a thin progress line + its label.
            VStack(spacing: 5) {
                progressLine(0.18)
                Text(content.progressLabel ?? "")
                    .font(.system(size: layout.metaSize))
                    .foregroundStyle(tokens.tertiaryText)
            }
        } else {
            // normal: quiet meta text, no button.
            Text(content.meta ?? "")
                .font(.system(size: layout.metaSize, weight: .medium))
                .foregroundStyle(tokens.tertiaryText)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func actionChip(_ action: MacCareStageAction) -> some View {
        Button(action: onAction) {
            HStack(spacing: 4) {
                Text(action.title)
                    .font(.system(size: layout.compact ? 12 : 12.5, weight: .medium))
                    .foregroundStyle(accent)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.85))
            }
            .padding(.horizontal, 14)
            .frame(height: layout.chipHeight)
            .background(
                Capsule(style: .continuous).fill(tokens.chipFill)
            )
            .overlay(
                Capsule(style: .continuous).strokeBorder(accent.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(action.title)
        .accessibilityLabel(Text(action.title))
    }
}

#endif
