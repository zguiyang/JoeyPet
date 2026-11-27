import SwiftUI

/// `陪伴中 · mm:ss` tip — same paper tip chrome as the greeting「你好」.
struct JoeyCompanionChipView: View {
    let startedAt: Date

    @Environment(\.joeyChromeTone) private var chromeTone

    private var theme: JoeyTheme { JoeyTheme(chromeTone: chromeTone) }

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
    var recipe: RecoveryRecipe = RecoveryRecipeCatalog.recipe(id: .lookFar)
    let onAccept: () -> Void
    let onSnooze: () -> Void
    let onDoNotDisturb: () -> Void
    var caretEdge: InvitationCaretEdge = .leading
    var scale: InvitationCardScale = .desktop

    @Environment(\.joeyChromeTone) private var chromeTone
    @State private var hoveredAction: CardAction?

    private enum CardAction: Hashable {
        case accept
        case snooze
        case doNotDisturb
    }

    private var theme: JoeyTheme { JoeyTheme(chromeTone: chromeTone) }
    private var isNest: Bool { scale == .nest }
    private var cardWidth: CGFloat { isNest ? 200 : 236 }
    private var cardRadius: CGFloat { isNest ? JoeyRadius.inviteCardNest : JoeyRadius.inviteCard }
    private var titleFont: Font { isNest ? JoeyType.inviteTitleNest : JoeyType.inviteTitle }
    private var primaryHeight: CGFloat { isNest ? 26 : 29 }
    private var quietHeight: CGFloat { isNest ? 25 : 28 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(recipe.inviteCopy)
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

/// Recovery panel — centered vertical stack; duration comes from the active recipe.
struct RecoveryPanelView: View {
    var recipe: RecoveryRecipe = RecoveryRecipeCatalog.recipe(id: .lookFar)
    let endsAt: Date
    let onDone: () -> Void
    let onSkip: () -> Void

    @Environment(\.joeyChromeTone) private var chromeTone
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredAction: RecoveryAction?

    private enum RecoveryAction: Hashable {
        case done
        case skip
    }

    private var theme: JoeyTheme { JoeyTheme(chromeTone: chromeTone) }
    private var total: TimeInterval { recipe.clampedDurationSec }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, endsAt.timeIntervalSince(context.date))

            VStack(spacing: 0) {
                Text(recipe.recoveryTitle)
                    .font(JoeyType.recoveryTitle)
                    .foregroundStyle(theme.ink)
                    .multilineTextAlignment(.center)

                Text(recipe.recoveryHint)
                    .font(JoeyType.recoveryHint)
                    .lineSpacing(2)
                    .foregroundStyle(theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)

                ring(remaining: remaining)
                    .padding(.top, 18)
                    .padding(.bottom, 16)

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

            Text(Self.clockText(remaining))
                .font(JoeyType.recoveryRingTime)
                .monospacedDigit()
                .foregroundStyle(theme.ink)
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

    @Environment(\.joeyChromeTone) private var chromeTone

    private var theme: JoeyTheme { JoeyTheme(chromeTone: chromeTone) }

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

/// Opt-in full-screen rest stage (invite + recover on one veil).
enum FullscreenRestPhase: Equatable, Sendable {
    case invite
    case recover
}

struct FullscreenRestStageView: View {
    let phase: FullscreenRestPhase
    var recipe: RecoveryRecipe = RecoveryRecipeCatalog.recipe(id: .lookFar)
    var endsAt: Date?
    let onAccept: () -> Void
    let onSnooze: () -> Void
    let onDoNotDisturb: () -> Void
    let onDone: () -> Void
    let onSkip: () -> Void

    @Environment(\.joeyChromeTone) private var chromeTone
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredAction: StageAction?

    private enum StageAction: Hashable {
        case accept, snooze, doNotDisturb, done, skip
    }

    private var theme: JoeyTheme { JoeyTheme(chromeTone: chromeTone) }
    private var isLight: Bool { chromeTone == .light }

    var body: some View {
        ZStack {
            atmosphere
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(theme.focus)
    }

    private var atmosphere: some View {
        ZStack {
            theme.windowBg
            RadialGradient(
                colors: [
                    theme.sage.opacity(isLight ? 0.18 : 0.16),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.38),
                startRadius: 40,
                endRadius: 520
            )
            RadialGradient(
                colors: [
                    theme.mist.opacity(isLight ? 0.15 : 0.13),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.64),
                startRadius: 20,
                endRadius: 420
            )
            // Soft vignette — dusk a touch deeper.
            RadialGradient(
                colors: [
                    .clear,
                    Color.black.opacity(isLight ? 0.08 : 0.22)
                ],
                center: .center,
                startRadius: 160,
                endRadius: 780
            )
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .invite:
            inviteContent
        case .recover:
            recoverContent
        }
    }

    private var inviteContent: some View {
        VStack(spacing: 0) {
            Text(recipe.inviteCopy)
                .font(.system(size: 34, weight: .medium))
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.ink)
                .frame(maxWidth: 520)

            HStack(spacing: 18) {
                quietTextButton("稍后提醒", action: .snooze, perform: onSnooze)
                quietTextButton("进入勿扰", action: .doNotDisturb, perform: onDoNotDisturb)
                primaryButton("休息一下", action: .accept, perform: onAccept)
            }
            .padding(.top, 42)
        }
    }

    private var recoverContent: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let ends = endsAt ?? context.date
            let remaining = max(0, ends.timeIntervalSince(context.date))
            let total = recipe.clampedDurationSec
            let fraction = max(0, min(1, remaining / max(total, 1)))

            VStack(spacing: 0) {
                Text(recipe.recoveryTitle)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(theme.ink)

                Text(recipe.recoveryHint)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.muted)
                    .padding(.top, 8)

                ZStack {
                    Circle()
                        .stroke(theme.panel2, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(
                            isLight ? theme.sageDeep : theme.sage,
                            style: StrokeStyle(lineWidth: 5.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .linear(duration: 1), value: fraction)
                    Text(clockText(remaining))
                        .font(.system(size: 32, weight: .medium).monospacedDigit())
                        .foregroundStyle(theme.ink)
                }
                .frame(width: 196, height: 196)
                .padding(.top, 28)
                .padding(.bottom, 8)

                HStack(spacing: 14) {
                    primaryButton("好了", action: .done, perform: onDone, compact: true)
                    quietTextButton("先跳过", action: .skip, perform: onSkip)
                }
                .padding(.top, 16)
            }
        }
    }

    private func primaryButton(
        _ title: String,
        action: StageAction,
        perform: @escaping () -> Void,
        compact: Bool = false
    ) -> some View {
        Button(action: perform) {
            Text(title)
                .font(.system(size: compact ? 13 : 14, weight: .semibold))
                .foregroundStyle(theme.sageInk)
                .padding(.horizontal, compact ? 15 : 18)
                .frame(height: compact ? 29 : 32)
                .background(
                    RoundedRectangle(cornerRadius: JoeyRadius.inviteControl, style: .continuous)
                        .fill(theme.sage)
                        .brightness(hoveredAction == action ? 0.03 : 0)
                )
                .contentShape(
                    RoundedRectangle(cornerRadius: JoeyRadius.inviteControl, style: .continuous)
                )
        }
        .buttonStyle(JoeyPressButtonStyle())
        .onHover { hoveredAction = $0 ? action : nil }
        .accessibilityLabel(Text(title))
    }

    private func quietTextButton(
        _ title: String,
        action: StageAction,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(hoveredAction == action ? theme.ink : theme.ink2)
                .padding(.horizontal, 4)
                .frame(height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(JoeyPressButtonStyle())
        .onHover { hoveredAction = $0 ? action : nil }
        .accessibilityLabel(Text(title))
    }

    private func clockText(_ remaining: TimeInterval) -> String {
        let seconds = max(0, Int(remaining.rounded(.up)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
