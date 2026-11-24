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

/// 30-second recovery panel — centered vertical stack (recovery-panel v0).
struct RecoveryPanelView: View {
    let endsAt: Date
    var total: TimeInterval = 30
    let onDone: () -> Void
    let onSkip: () -> Void

    @Environment(\.joeyAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredAction: RecoveryAction?

    private enum RecoveryAction: Hashable {
        case done
        case skip
    }

    private var theme: JoeyTheme { JoeyTheme(appearance: appearance) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, endsAt.timeIntervalSince(context.date))

            VStack(spacing: 0) {
                Text("望向远处")
                    .font(JoeyType.recoveryTitle)
                    .foregroundStyle(theme.ink)
                    .multilineTextAlignment(.center)

                Text("找个六米外的点，肩膀放松。")
                    .font(JoeyType.recoveryHint)
                    .lineSpacing(2)
                    .foregroundStyle(theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)

                ring(remaining: remaining)
                    .padding(.top, 18)
                    .padding(.bottom, 14)

                Text("吸气四拍，呼气六拍")
                    .font(JoeyType.recoveryBreath)
                    .foregroundStyle(theme.ink)
                    .multilineTextAlignment(.center)

                Text("不用数得很准。")
                    .font(JoeyType.recoveryBreathHint)
                    .foregroundStyle(theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 3)

                HStack(spacing: 8) {
                    primaryButton
                    quietButton
                }
                .padding(.top, 16)
            }
            .frame(width: 300)
            .padding(EdgeInsets(top: 22, leading: 22, bottom: 18, trailing: 22))
            .background(
                RoundedRectangle(cornerRadius: JoeyRadius.recoveryCard, style: .continuous)
                    .fill(theme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: JoeyRadius.recoveryCard, style: .continuous)
                    .stroke(theme.hairline, lineWidth: 1)
            )
            .tint(theme.focus)
            .joeyShadowMD()
        }
    }

    private var primaryButton: some View {
        Button(action: onDone) {
            Text("好了")
                .font(JoeyType.inviteAction)
                .foregroundStyle(theme.sageInk)
                .padding(.horizontal, 16)
                .frame(height: 29)
                .background(
                    RoundedRectangle(cornerRadius: JoeyRadius.inviteControl, style: .continuous)
                        .fill(theme.sage)
                        .brightness(hoveredAction == .done ? 0.03 : 0)
                )
                .contentShape(
                    RoundedRectangle(cornerRadius: JoeyRadius.inviteControl, style: .continuous)
                )
        }
        .buttonStyle(JoeyPressButtonStyle())
        .onHover { hoveredAction = $0 ? .done : nil }
        .accessibilityLabel(Text("好了"))
    }

    private var quietButton: some View {
        Button(action: onSkip) {
            Text("先跳过")
                .font(JoeyType.inviteQuiet)
                .foregroundStyle(hoveredAction == .skip ? theme.ink : theme.ink2)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: JoeyRadius.inviteControl, style: .continuous)
                        .fill(hoveredAction == .skip ? theme.panel2 : Color.clear)
                )
                .contentShape(
                    RoundedRectangle(cornerRadius: JoeyRadius.inviteControl, style: .continuous)
                )
        }
        .buttonStyle(JoeyPressButtonStyle())
        .onHover { hoveredAction = $0 ? .skip : nil }
        .accessibilityLabel(Text("先跳过"))
    }

    private func ring(remaining: TimeInterval) -> some View {
        let fraction = max(0, min(1, remaining / max(total, 1)))

        return ZStack {
            Circle()
                .stroke(theme.panel2, lineWidth: 7.5)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(theme.sage, style: StrokeStyle(lineWidth: 7.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: fraction)

            VStack(spacing: 4) {
                Text(Self.clockText(remaining))
                    .font(JoeyType.recoveryRingTime)
                    .monospacedDigit()
                    .foregroundStyle(theme.ink)
                Text("剩余 \(Int(remaining.rounded(.up))) 秒")
                    .font(JoeyType.recoveryRingCaption)
                    .foregroundStyle(theme.muted)
            }
        }
        .frame(width: 96, height: 96)
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
