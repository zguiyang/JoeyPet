import SwiftUI

enum JoeyCopy {
    static let homeTitle = "Joey 的家"
    static let reflectionTitle = "节奏回顾"
    static let settingsTitle = "JoeyPet 设置"

    static let startCompanionship = "开始一起工作"
    static let endCompanionship = "结束陪伴"
    static let returnHome = "回巢"
    static let reviewHint = "回顾这周"

    static let emptyToday = "今天还没开始"
    static let emptyBreaks = "今天还没有休息"
    static let emptyWeek = "今天还没开始，这一周还没有记录。"
}

struct JoeyPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    @Environment(\.joeyAppearance) private var appearance
    @State private var isHovering = false

    private var theme: JoeyTheme { JoeyTheme(appearance: appearance) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: JoeySpacing.md) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(JoeyType.primaryButton)
            }
            .foregroundStyle(theme.sageInk)
            .padding(.horizontal, JoeySpacing.panel)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: JoeyRadius.md, style: .continuous)
                    .fill(theme.sage)
                    .brightness(isHovering ? 0.03 : 0)
            )
            .contentShape(RoundedRectangle(cornerRadius: JoeyRadius.md, style: .continuous))
        }
        .buttonStyle(JoeyPressButtonStyle())
        .onHover { isHovering = $0 }
        .accessibilityLabel(Text(title))
    }
}

struct JoeySecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    @Environment(\.joeyAppearance) private var appearance
    @State private var isHovering = false

    private var theme: JoeyTheme { JoeyTheme(appearance: appearance) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: JoeySpacing.md) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(JoeyType.body)
            }
            .foregroundStyle(theme.ink)
            .padding(.horizontal, 20)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: JoeyRadius.md, style: .continuous)
                    .fill(isHovering ? theme.panel2 : theme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: JoeyRadius.md, style: .continuous)
                    .stroke(theme.hairlineStrong, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: JoeyRadius.md, style: .continuous))
        }
        .buttonStyle(JoeyPressButtonStyle())
        .onHover { isHovering = $0 }
        .accessibilityLabel(Text(title))
    }
}

struct JoeyPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(JoeyMotion.press, value: configuration.isPressed)
    }
}

/// Centred window title drawn in the content so it stays centred on every macOS version.
/// Native traffic lights and the settings tool button remain AppKit-owned and float above it.
struct WindowChromeHeader: View {
    let title: String
    var height: CGFloat = 32

    @Environment(\.joeyAppearance) private var appearance

    private var theme: JoeyTheme { JoeyTheme(appearance: appearance) }

    var body: some View {
        ZStack {
            theme.windowChrome

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.ink2)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.hairline)
                .frame(height: 1)
        }
    }
}

/// Small in-scene information tag bound to a room object.
struct JoeyRoomLabel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    @Environment(\.joeyAppearance) private var appearance

    private var theme: JoeyTheme { JoeyTheme(appearance: appearance) }

    var body: some View {
        content
            .font(JoeyType.roomLabel)
            .foregroundStyle(theme.ink2)
            .lineSpacing(2)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(theme.popover)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(theme.hairline, lineWidth: 1)
            )
            .joeyShadowSM()
            .fixedSize()
    }
}
