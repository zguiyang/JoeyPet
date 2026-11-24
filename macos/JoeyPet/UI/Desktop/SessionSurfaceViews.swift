import SwiftUI

/// `陪伴中 · mm:ss` tip — same paper tip chrome as the greeting「你好。」.
struct JoeyCompanionChipView: View {
    let startedAt: Date

    @Environment(\.joeyAppearance) private var appearance

    private var theme: JoeyTheme { JoeyTheme(appearance: appearance) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            JoeyPetTipView(caret: .none) {
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(theme.sage)
                        .frame(width: 8, height: 8)
                        .rotationEffect(.degrees(-45))

                    Text("陪伴中 · \(CompanionTimeText.elapsedText(from: startedAt, to: context.date))")
                        .monospacedDigit()
                }
            }
        }
    }
}

/// Which edge of the invite card sprouts the caret toward Joey.
enum InvitationCaretEdge: Equatable, Sendable {
    /// Caret on the left; Joey sits to the right of the card.
    case leading
    /// Caret on the right; Joey sits to the left of the card.
    case trailing
    case none
}

enum InvitationCardScale: Equatable, Sendable {
    case desktop
    case nest
}

/// Rest invitation — a quiet paper note beside Joey (invite-greeting family v1).
struct InvitationCardView: View {
    let onAccept: () -> Void
    let onSnooze: () -> Void
    let onDoNotDisturb: () -> Void
    var caretEdge: InvitationCaretEdge = .leading
    var scale: InvitationCardScale = .desktop

    @Environment(\.joeyAppearance) private var appearance
    @State private var hoveredAction: CardAction?

    private enum CardAction: Hashable {
        case accept
        case snooze
        case doNotDisturb
    }

    private var theme: JoeyTheme { JoeyTheme(appearance: appearance) }
    private var isNest: Bool { scale == .nest }
    private var cardWidth: CGFloat { isNest ? 200 : 236 }
    private var cardRadius: CGFloat { isNest ? JoeyRadius.inviteCardNest : JoeyRadius.inviteCard }
    private var titleFont: Font { isNest ? JoeyType.inviteTitleNest : JoeyType.inviteTitle }
    private var primaryHeight: CGFloat { isNest ? 26 : 29 }
    private var quietHeight: CGFloat { isNest ? 25 : 28 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("坐久啦，\n我们一起伸个懒腰？")
                .font(titleFont)
                .lineSpacing(isNest ? 2 : 3)
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: isNest ? 4 : 6) {
                Spacer(minLength: 0)
                quietButton("稍后提醒", action: .snooze, perform: onSnooze)
                quietButton("进入勿扰", action: .doNotDisturb, perform: onDoNotDisturb)
                primaryButton
            }
            .padding(.top, isNest ? 8 : 10)
        }
        .padding(EdgeInsets(
            top: isNest ? 12 : 14,
            leading: isNest ? 12 : 14,
            bottom: isNest ? 10 : 12,
            trailing: isNest ? 12 : 14
        ))
        .frame(width: cardWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(theme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .stroke(theme.hairline, lineWidth: 1)
        )
        .overlay(alignment: caretAlignment) {
            if caretEdge != .none {
                inviteCaret
                    .offset(x: caretEdge == .leading ? -5 : 5)
            }
        }
        .tint(theme.focus)
        .joeyShadowMD()
    }

    private var caretAlignment: Alignment {
        switch caretEdge {
        case .leading: .leading
        case .trailing: .trailing
        case .none: .center
        }
    }

    private var inviteCaret: some View {
        Rectangle()
            .fill(theme.panel)
            .frame(width: 10, height: 10)
            .overlay(Rectangle().stroke(theme.hairline, lineWidth: 1))
            .rotationEffect(.degrees(45))
            .accessibilityHidden(true)
    }

    private var primaryButton: some View {
        Button(action: onAccept) {
            Text("休息一下")
                .font(isNest ? JoeyType.caption.weight(.semibold) : JoeyType.inviteAction)
                .foregroundStyle(theme.sageInk)
                .padding(.horizontal, isNest ? 8 : 13)
                .frame(height: primaryHeight)
                .background(
                    RoundedRectangle(cornerRadius: JoeyRadius.inviteControl, style: .continuous)
                        .fill(theme.sage)
                        .brightness(hoveredAction == .accept ? 0.03 : 0)
                )
                .contentShape(
                    RoundedRectangle(cornerRadius: JoeyRadius.inviteControl, style: .continuous)
                )
        }
        .buttonStyle(JoeyPressButtonStyle())
        .onHover { hoveredAction = $0 ? .accept : nil }
        .accessibilityLabel(Text("休息一下"))
    }

    private func quietButton(
        _ title: String,
        action: CardAction,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            Text(title)
                .font(isNest ? .system(size: 10.5) : JoeyType.inviteQuiet)
                .foregroundStyle(hoveredAction == action ? theme.ink : theme.ink2)
                .padding(.horizontal, isNest ? 4 : 6)
                .frame(height: quietHeight)
                .background(
                    RoundedRectangle(cornerRadius: JoeyRadius.inviteControl, style: .continuous)
                        .fill(hoveredAction == action ? theme.panel2 : Color.clear)
                )
                .contentShape(
                    RoundedRectangle(cornerRadius: JoeyRadius.inviteControl, style: .continuous)
                )
        }
        .buttonStyle(JoeyPressButtonStyle())
        .onHover { hoveredAction = $0 ? action : nil }
        .accessibilityLabel(Text(title))
    }
}

/// 30-second recovery panel from DESIGN §10.3. The ring follows the real deadline.
struct RecoveryPanelView: View {
    let endsAt: Date
    var total: TimeInterval = 30
    let onDone: () -> Void
    let onSkip: () -> Void

    @Environment(\.joeyAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHoveringDone = false
    @State private var isHoveringSkip = false

    private var theme: JoeyTheme { JoeyTheme(appearance: appearance) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, endsAt.timeIntervalSince(context.date))

            VStack(alignment: .leading, spacing: 0) {
                Text("望向远处")
                    .font(JoeyType.recoveryTitle)
                    .foregroundStyle(theme.ink)

                Text("找个六米外的点，肩膀放松。")
                    .font(JoeyType.body)
                    .lineSpacing(3)
                    .foregroundStyle(theme.muted)
                    .padding(.top, 6)

                HStack(spacing: 22) {
                    ring(remaining: remaining)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("吸气四拍，呼气六拍")
                            .font(JoeyType.rowTitle)
                            .foregroundStyle(theme.ink)
                        Text("不用数得很准。")
                            .font(JoeyType.reflectionBody)
                            .lineSpacing(2)
                            .foregroundStyle(theme.muted)
                    }
                }
                .padding(.top, 22)
                .padding(.bottom, 24)

                HStack(spacing: JoeySpacing.lg) {
                    Button(action: onDone) {
                        Text("好了")
                            .font(JoeyType.primaryButton)
                            .foregroundStyle(theme.sageInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: JoeyRadius.md, style: .continuous)
                                    .fill(theme.sage)
                                    .brightness(isHoveringDone ? 0.03 : 0)
                            )
                            .contentShape(
                                RoundedRectangle(cornerRadius: JoeyRadius.md, style: .continuous)
                            )
                    }
                    .buttonStyle(JoeyPressButtonStyle())
                    .onHover { isHoveringDone = $0 }
                    .accessibilityLabel(Text("好了"))

                    Button(action: onSkip) {
                        Text("先跳过")
                            .font(JoeyType.body)
                            .foregroundStyle(isHoveringSkip ? theme.ink : theme.muted)
                            .padding(.horizontal, 14)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: JoeyRadius.md, style: .continuous)
                                    .fill(isHoveringSkip ? theme.panel2 : Color.clear)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(JoeyPressButtonStyle())
                    .onHover { isHoveringSkip = $0 }
                    .accessibilityLabel(Text("先跳过"))
                }
            }
            .padding(EdgeInsets(top: 28, leading: 30, bottom: 26, trailing: 30))
            .frame(width: 420, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: JoeyRadius.xl, style: .continuous)
                    .fill(theme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: JoeyRadius.xl, style: .continuous)
                    .stroke(theme.hairline, lineWidth: 1)
            )
            .tint(theme.focus)
            .joeyShadowMD()
        }
    }

    private func ring(remaining: TimeInterval) -> some View {
        let fraction = max(0, min(1, remaining / max(total, 1)))

        return ZStack {
            Circle()
                .stroke(theme.panel2, lineWidth: 8)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(theme.sage, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: fraction)

            VStack(spacing: 4) {
                Text(Self.clockText(remaining))
                    .font(JoeyType.reflectionHeadline)
                    .monospacedDigit()
                    .foregroundStyle(theme.ink)
                Text("剩余 \(Int(remaining.rounded(.up))) 秒")
                    .font(JoeyType.caption)
                    .foregroundStyle(theme.muted)
            }
        }
        .frame(width: 104, height: 104)
    }

    private static func clockText(_ remaining: TimeInterval) -> String {
        let seconds = max(0, Int(remaining.rounded(.up)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

/// Short one-sentence feedback toast (DESIGN §10.2 / §10.3).
struct JoeyToastView: View {
    let text: String

    @Environment(\.joeyAppearance) private var appearance

    private var theme: JoeyTheme { JoeyTheme(appearance: appearance) }

    var body: some View {
        Text(text)
            .font(JoeyType.reflectionBody)
            .lineSpacing(2)
            .foregroundStyle(theme.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(Capsule().fill(theme.popover))
            .overlay(Capsule().stroke(theme.hairline, lineWidth: 1))
            .joeyShadowMD()
            .fixedSize()
    }
}
