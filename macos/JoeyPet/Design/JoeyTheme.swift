import AppKit
import SwiftUI

// MARK: - Appearance

enum JoeyAppearance: String, CaseIterable, Identifiable, Sendable {
    case light
    case dusk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "白天"
        case .dusk: return "黄昏"
        }
    }

    var nsAppearance: NSAppearance? {
        NSAppearance(named: self == .light ? .aqua : .darkAqua)
    }
}

// MARK: - Theme

/// Every surface colour comes from a token here. Views never hardcode hex values.
struct JoeyTheme {
    let appearance: JoeyAppearance

    private var isLight: Bool { appearance == .light }

    // Core tokens (DESIGN.md §4.1)
    var ivory: Color { Color(hex: 0xF7F3EB) }
    var ivory2: Color { Color(hex: 0xF1E9DA) }
    var ink: Color { isLight ? Color(hex: 0x3F3A35) : Color(hex: 0xE9E3D7) }
    var ink2: Color { isLight ? Color(hex: 0x6B6259) : Color(hex: 0xBFB8AB) }
    var muted: Color { isLight ? Color(hex: 0x6E6459) : Color(hex: 0xB0A89C) }
    var sage: Color { Color(hex: 0x86A98A) }
    var sageDeep: Color { isLight ? Color(hex: 0x4F6D54) : Color(hex: 0xA9C6AC) }
    var sageInk: Color { isLight ? Color(hex: 0x263227) : Color(hex: 0x1E2A20) }
    var sageSoft: Color {
        isLight ? Color(hex: 0xE8EEE3) : Color(hex: 0x86A98A, opacity: 0.16)
    }
    var apricot: Color { Color(hex: 0xEFAE7D) }
    var apricotInk: Color { Color(hex: 0xA96B42) }
    var mist: Color { Color(hex: 0x90B9C9) }
    var mistDeep: Color { Color(hex: 0x5E8B9D) }
    var mistSoft: Color { Color(hex: 0xDFE9EB) }
    var clay: Color { Color(hex: 0xC9B08C) }
    var hairline: Color {
        isLight ? Color(hex: 0x3F3A35, opacity: 0.14) : Color(hex: 0xE9E3D7, opacity: 0.14)
    }
    var hairlineStrong: Color {
        isLight ? Color(hex: 0x3F3A35, opacity: 0.24) : Color(hex: 0xE9E3D7, opacity: 0.24)
    }
    var focus: Color { Color(hex: 0x4A90D9) }

    // Surfaces (DESIGN.md §4.2)
    var windowBg: Color { isLight ? Color(hex: 0xFBF8F0) : Color(hex: 0x313A3B) }
    var windowChrome: Color { isLight ? Color(hex: 0xF2ECE1) : Color(hex: 0x262E2F) }
    var panel: Color { isLight ? Color(hex: 0xFFFDF7) : Color(hex: 0x37403F) }
    var panel2: Color { isLight ? Color(hex: 0xF8F3E9) : Color(hex: 0x2F3838) }
    var popover: Color { isLight ? Color(hex: 0xFFFDF8) : Color(hex: 0x394241) }

    // Room scene tokens (DESIGN.md §9.3)
    var roomWall: Color { isLight ? Color(hex: 0xF8F4EC) : Color(hex: 0x2F3736) }
    var roomWash: Color {
        isLight ? Color(hex: 0xFFFDF4, opacity: 0.55) : Color(hex: 0xC4D6D2, opacity: 0.05)
    }
    var roomFloor: Color { isLight ? Color(hex: 0xE6D5BE) : Color(hex: 0x29302F) }
    var roomBase: Color { isLight ? Color(hex: 0xEFE5D4) : Color(hex: 0x3A4240) }
    var roomFloorLine: Color { isLight ? Color(hex: 0xD9C6AC) : Color(hex: 0x3D4644) }
    var roomSky: Color { isLight ? Color(hex: 0xD9E7E6) : Color(hex: 0x3E5560) }
    var roomFrame: Color { isLight ? Color(hex: 0xE3D3BC) : Color(hex: 0x4A5451) }
    var roomHill1: Color { isLight ? Color(hex: 0xC3D8D5) : Color(hex: 0x35474B) }
    var roomHill2: Color { isLight ? Color(hex: 0xAFC9C5) : Color(hex: 0x2E4045) }
    var roomSill: Color { isLight ? Color(hex: 0xEFE5D4) : Color(hex: 0x3A4240) }
    var roomCurtain: Color { isLight ? Color(hex: 0xE8EDE4) : Color(hex: 0x3D4744) }
    var roomClock: Color { isLight ? Color(hex: 0xFBF6EC) : Color(hex: 0x3B4544) }
    var roomClockRim: Color { isLight ? Color(hex: 0xD9C6AE) : Color(hex: 0x4A5451) }
    var roomClockTick: Color { isLight ? Color(hex: 0xC9B08C) : Color(hex: 0x5A6A66) }
    var roomHand: Color { isLight ? Color(hex: 0x3F3A35) : Color(hex: 0xD9D2C4) }
    var roomPot: Color { isLight ? Color(hex: 0xD8B892) : Color(hex: 0x4A443B) }
    var roomStem: Color { isLight ? Color(hex: 0x7E9B7C) : Color(hex: 0x5F7A62) }
    var roomLeaf: Color { isLight ? Color(hex: 0x86A98A) : Color(hex: 0x6E9077) }
    var roomRug: Color { isLight ? Color(hex: 0xE0CDB6) : Color(hex: 0x232A29) }
    var roomNestDark: Color { isLight ? Color(hex: 0xD2B189) : Color(hex: 0x3A342C) }
    var roomNest: Color { isLight ? Color(hex: 0xD9BD97) : Color(hex: 0x4A4238) }
    var roomCushion: Color { isLight ? Color(hex: 0xE7EDDD) : Color(hex: 0x3E4A42) }
    var roomCushion2: Color { isLight ? Color(hex: 0xF0F4E8) : Color(hex: 0x46544A) }
    var roomDesk: Color { isLight ? Color(hex: 0xDEC9AE) : Color(hex: 0x4A4238) }
    var roomDeskLeg: Color { isLight ? Color(hex: 0xD2BB9E) : Color(hex: 0x3A342C) }
    var roomPaper: Color { isLight ? Color(hex: 0xFBF7EF) : Color(hex: 0x3F4847) }
    var roomPaperLine: Color { isLight ? Color(hex: 0xE4D6C1) : Color(hex: 0x55605E) }
    var roomNoteLine: Color { isLight ? Color(hex: 0x3F3A35) : Color(hex: 0xD9D2C4) }
    var roomMug: Color { Color(hex: 0xEFAE7D) }
    var roomMugTop: Color { Color(hex: 0xC98F6E) }

    // Joey in the room (drawn from the frozen vector reference)
    var joeyBody: Color { Color(hex: 0xF3E3CD) }
    var joeyShade: Color { Color(hex: 0xEBD7BE) }
    var joeyInnerEar: Color { Color(hex: 0xEFC8AA) }
    var joeyPaw: Color { Color(hex: 0xF8ECDA) }
    var joeyArm: Color { Color(hex: 0xEDDAC1) }
    var joeyTail: Color { Color(hex: 0xF0DFC8) }
    var joeyNose: Color { Color(hex: 0xC98F6E) }
    var joeyMouth: Color { Color(hex: 0x6F5F53) }
    var joeyEye: Color { Color(hex: 0x3F3A35) }
    var joeyScarf: Color { Color(hex: 0x86A98A) }
    var joeyBlush: Color { Color(hex: 0xEFAE7D) }
}

// MARK: - Type scale (DESIGN.md §5.2)

enum JoeyType {
    static let invitation = Font.system(size: 27, weight: .semibold)
    static let recoveryTitle = Font.system(size: 23, weight: .semibold)
    static let reflectionHeadline = Font.system(size: 21, weight: .semibold)
    static let settingsTitle = Font.system(size: 17, weight: .semibold)
    static let primaryButton = Font.system(size: 16, weight: .semibold)
    static let body = Font.system(size: 13.5)
    static let rowTitle = Font.system(size: 13.5, weight: .semibold)
    static let reflectionBody = Font.system(size: 13)
    static let roomLabel = Font.system(size: 12.5)
    static let rowDescription = Font.system(size: 12)
    static let meta = Font.system(size: 11.5, weight: .semibold)
    static let caption = Font.system(size: 11)
}

// MARK: - Spacing, radius, motion

enum JoeySpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 10
    static let xl: CGFloat = 12
    static let xxl: CGFloat = 14
    static let xxxl: CGFloat = 16
    static let section: CGFloat = 20
    static let panel: CGFloat = 26
}

enum JoeyRadius {
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let xl: CGFloat = 26
}

enum JoeyMotion {
    static let stateEnter = Animation.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.3)
    static let hover = Animation.easeOut(duration: 0.16)
    static let press = Animation.easeOut(duration: 0.12)
}

// MARK: - Environment

private struct JoeyAppearanceKey: EnvironmentKey {
    nonisolated static let defaultValue: JoeyAppearance = .light
}

extension EnvironmentValues {
    var joeyAppearance: JoeyAppearance {
        get { self[JoeyAppearanceKey.self] }
        set { self[JoeyAppearanceKey.self] = newValue }
    }
}

// MARK: - Helpers

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension View {
    func joeyShadowSM() -> some View {
        shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    func joeyShadowMD() -> some View {
        shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
            .shadow(color: .black.opacity(0.12), radius: 30, x: 0, y: 10)
    }
}
