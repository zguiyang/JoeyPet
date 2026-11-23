import SwiftUI

/// `陪伴中 · mm:ss` capsule shown above Joey on the desktop and in the nest.
struct JoeyCompanionChipView: View {
    let startedAt: Date

    @Environment(\.joeyAppearance) private var appearance

    private var theme: JoeyTheme { JoeyTheme(appearance: appearance) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(theme.sage)
                    .frame(width: 8, height: 8)
                    .rotationEffect(.degrees(-45))

                Text("陪伴中 · \(CompanionTimeText.elapsedText(from: startedAt, to: context.date))")
                    .font(JoeyType.roomLabel)
                    .monospacedDigit()
                    .foregroundStyle(theme.ink)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(Capsule().fill(theme.popover))
            .overlay(Capsule().stroke(theme.hairline, lineWidth: 1))
            .joeyShadowMD()
        }
        .fixedSize()
    }
}

/// Rest invitation from DESIGN §10.2. A pet's note, never an alert.
struct InvitationCardView: View {
    let onAccept: () -> Void
    let onSnooze: () -> Void
    let onPause: () -> Void

    @Environment(\.joeyAppearance) private var appearance
    @State private var hoveredAction: CardAction?

    private enum CardAction: Hashable {
        case accept
        case snooze
        case pause
    }

    private var theme: JoeyTheme { JoeyTheme(appearance: appearance) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("坐久啦，\n我们一起伸个懒腰？")
                .font(JoeyType.invitation)
                .lineSpacing(5)
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("不用走开，半分钟就够。")
                .font(JoeyType.body)
                .lineSpacing(3)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            VStack(spacing: JoeySpacing.lg) {
                Button(action: onAccept) {
                    Text("休息一下")
                        .font(JoeyType.primaryButton)
                        .foregroundStyle(theme.sageInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: JoeyRadius.md, style: .continuous)
                                .fill(theme.sage)
                                .brightness(hoveredAction == .accept ? 0.03 : 0)
                        )
                        .contentShape(
                            RoundedRectangle(cornerRadius: JoeyRadius.md, style: .continuous)
                        )
                }
                .buttonStyle(JoeyPressButtonStyle())
                .onHover { hoveredAction = $0 ? .accept : nil }
                .accessibilityLabel(Text("休息一下"))

                HStack(spacing: JoeySpacing.md) {
                    secondaryButton("稍后提醒", action: .snooze, perform: onSnooze)
                    quietButton("暂停一会儿", action: .pause, perform: onPause)
                    Spacer(minLength: 0)
                }
            }
            .padding(.top, 22)
        }
        .padding(EdgeInsets(top: 26, leading: 28, bottom: 24, trailing: 28))
        .frame(width: 400, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: JoeyRadius.lg, style: .continuous)
                .fill(theme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: JoeyRadius.lg, style: .continuous)
                .stroke(theme.hairline, lineWidth: 1)
        )
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(theme.clay.opacity(0.5))
                .frame(width: 86, height: 22)
                .rotationEffect(.degrees(-2.5))
                .offset(y: -11)
        }
        .padding(.top, 14)
        .tint(theme.focus)
        .joeyShadowMD()
    }

    private func secondaryButton(
        _ title: String,
        action: CardAction,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            Text(title)
                .font(JoeyType.body)
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: JoeyRadius.md, style: .continuous)
                        .fill(hoveredAction == action ? theme.panel2 : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: JoeyRadius.md, style: .continuous)
                        .stroke(theme.hairlineStrong, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: JoeyRadius.md, style: .continuous))
        }
        .buttonStyle(JoeyPressButtonStyle())
        .onHover { hoveredAction = $0 ? action : nil }
        .accessibilityLabel(Text(title))
    }

    private func quietButton(
        _ title: String,
        action: CardAction,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            Text(title)
                .font(JoeyType.body)
                .foregroundStyle(hoveredAction == action ? theme.ink : theme.muted)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: JoeyRadius.md, style: .continuous)
                        .fill(hoveredAction == action ? theme.panel2 : Color.clear)
                )
                .contentShape(Rectangle())
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
