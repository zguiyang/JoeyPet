import AppKit
import Foundation
import SwiftUI

/// Local-clock atmosphere for Joey's nest. Palettes recolor sky, hills, wall,
/// floor and curtains only — no beams, projections or lamps.
enum RoomDaypart: String, CaseIterable, Sendable {
    case morning
    case day
    case dusk
    case night

    /// Matches the accepted `joeypet-home-v1.html` clock windows.
    static func resolve(at date: Date, calendar: Calendar = .autoupdatingCurrent) -> RoomDaypart {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<10: return .morning
        case 10..<17: return .day
        case 17..<20: return .dusk
        default: return .night
        }
    }

    /// Pet-voice line for the desk; stable for a given daypart (not work praise).
    var welcomeLine: String {
        switch self {
        case .morning: return "一年之计在于晨。"
        case .day: return "我在这儿陪着你。"
        case .dusk: return "今天够了，慢慢收一收。"
        case .night: return "夜里也安静陪着。"
        }
    }

    /// Soft wash on the layered nest pet so night/dusk rooms stay coherent.
    var nestPetTint: JoeyPetTint {
        switch self {
        case .morning, .day:
            return .none
        case .dusk:
            return JoeyPetTint(
                color: NSColor(
                    srgbRed: CGFloat(0x57) / 255,
                    green: CGFloat(0x66) / 255,
                    blue: CGFloat(0x5F) / 255,
                    alpha: 1
                ),
                factor: 0.14
            )
        case .night:
            return JoeyPetTint(
                color: NSColor(
                    srgbRed: CGFloat(0x3A) / 255,
                    green: CGFloat(0x42) / 255,
                    blue: CGFloat(0x52) / 255,
                    alpha: 1
                ),
                factor: 0.22
            )
        }
    }
}

/// Room illustration colors for one daypart (DESIGN nest home board).
struct RoomDaypartPalette: Sendable {
    let wall: Color
    let wash: Color
    let floor: Color
    let base: Color
    let floorLine: Color
    let sky: Color
    let frame: Color
    let hill1: Color
    let hill2: Color
    let sill: Color
    let curtain: Color
    let outdoorDisc: Color
    let showStars: Bool
    let clock: Color
    let clockRim: Color
    let clockTick: Color
    let hand: Color
    let pot: Color
    let stem: Color
    let leaf: Color
    let rug: Color
    let nestDark: Color
    let nest: Color
    let nestRim: Color
    let cushion: Color
    let cushion2: Color
    let desk: Color
    let deskLeg: Color
    let paper: Color
    let paperLine: Color
    let noteLine: Color

    static func palette(for daypart: RoomDaypart) -> RoomDaypartPalette {
        switch daypart {
        case .morning:
            return RoomDaypartPalette(
                wall: Color(hex: 0xF6EEE3),
                wash: Color(hex: 0xFFFDF4, opacity: 0.45),
                floor: Color(hex: 0xE3CDB0),
                base: Color(hex: 0xEBD9C0),
                floorLine: Color(hex: 0xD4BFA3),
                sky: Color(hex: 0xCFE3E6),
                frame: Color(hex: 0xE3D3BC),
                hill1: Color(hex: 0xB9CFC3),
                hill2: Color(hex: 0xA5BDB4),
                sill: Color(hex: 0xEBD9C0),
                curtain: Color(hex: 0xE9E2D3),
                outdoorDisc: Color(hex: 0xFFE7B8),
                showStars: false,
                clock: Color(hex: 0xFBF6EC),
                clockRim: Color(hex: 0xD9C6AE),
                clockTick: Color(hex: 0xC9B08C),
                hand: Color(hex: 0x3F3A35),
                pot: Color(hex: 0xD8B892),
                stem: Color(hex: 0x7E9B7C),
                leaf: Color(hex: 0x86A98A),
                rug: Color(hex: 0xE0CDB6),
                nestDark: Color(hex: 0xB89B73),
                nest: Color(hex: 0xD8BE96),
                nestRim: Color(hex: 0xEBD6B4),
                cushion: Color(hex: 0xE7EDDD),
                cushion2: Color(hex: 0xF0F4E8),
                desk: Color(hex: 0xDEC9AE),
                deskLeg: Color(hex: 0xD2BB9E),
                paper: Color(hex: 0xFBF7EF),
                paperLine: Color(hex: 0xE4D6C1),
                noteLine: Color(hex: 0x3F3A35)
            )
        case .day:
            return RoomDaypartPalette(
                wall: Color(hex: 0xF8F4EC),
                wash: Color(hex: 0xFFFDF4, opacity: 0.55),
                floor: Color(hex: 0xE6D5BE),
                base: Color(hex: 0xEFE5D4),
                floorLine: Color(hex: 0xD9C6AC),
                sky: Color(hex: 0xD9E7E6),
                frame: Color(hex: 0xE3D3BC),
                hill1: Color(hex: 0xC3D8D5),
                hill2: Color(hex: 0xAFC9C5),
                sill: Color(hex: 0xEFE5D4),
                curtain: Color(hex: 0xE8EDE4),
                outdoorDisc: Color(hex: 0xFFF1C9),
                showStars: false,
                clock: Color(hex: 0xFBF6EC),
                clockRim: Color(hex: 0xD9C6AE),
                clockTick: Color(hex: 0xC9B08C),
                hand: Color(hex: 0x3F3A35),
                pot: Color(hex: 0xD8B892),
                stem: Color(hex: 0x7E9B7C),
                leaf: Color(hex: 0x86A98A),
                rug: Color(hex: 0xE0CDB6),
                nestDark: Color(hex: 0xB89B73),
                nest: Color(hex: 0xD8BE96),
                nestRim: Color(hex: 0xE9D3AE),
                cushion: Color(hex: 0xE7EDDD),
                cushion2: Color(hex: 0xF0F4E8),
                desk: Color(hex: 0xDEC9AE),
                deskLeg: Color(hex: 0xD2BB9E),
                paper: Color(hex: 0xFBF7EF),
                paperLine: Color(hex: 0xE4D6C1),
                noteLine: Color(hex: 0x3F3A35)
            )
        case .dusk:
            return RoomDaypartPalette(
                wall: Color(hex: 0xF1DCC6),
                wash: Color(hex: 0xF6B27E, opacity: 0.12),
                floor: Color(hex: 0xD9B994),
                base: Color(hex: 0xE2C4A0),
                floorLine: Color(hex: 0xC9A882),
                sky: Color(hex: 0xF2C9A0),
                frame: Color(hex: 0xD4B89A),
                hill1: Color(hex: 0xB58E78),
                hill2: Color(hex: 0xA07A66),
                sill: Color(hex: 0xE2C4A0),
                curtain: Color(hex: 0xE9C9A6),
                outdoorDisc: Color(hex: 0xF6B27E),
                showStars: false,
                clock: Color(hex: 0xF7E8D4),
                clockRim: Color(hex: 0xC9A882),
                clockTick: Color(hex: 0xB58E78),
                hand: Color(hex: 0x3F3A35),
                pot: Color(hex: 0xC9A07A),
                stem: Color(hex: 0x6E8A6C),
                leaf: Color(hex: 0x7A9A7C),
                rug: Color(hex: 0xD0B590),
                nestDark: Color(hex: 0xA9865F),
                nest: Color(hex: 0xCBA883),
                nestRim: Color(hex: 0xDDBD98),
                cushion: Color(hex: 0xE4DCC8),
                cushion2: Color(hex: 0xEDE6D4),
                desk: Color(hex: 0xC9A882),
                deskLeg: Color(hex: 0xB09070),
                paper: Color(hex: 0xF7E8D4),
                paperLine: Color(hex: 0xD4B89A),
                noteLine: Color(hex: 0x3F3A35)
            )
        case .night:
            return RoomDaypartPalette(
                wall: Color(hex: 0x4A4F5C),
                wash: Color(hex: 0x1F2A3F, opacity: 0.2),
                floor: Color(hex: 0x5A4F49),
                base: Color(hex: 0x6A5C54),
                floorLine: Color(hex: 0x6E6058),
                sky: Color(hex: 0x1F2A3F),
                frame: Color(hex: 0x6A6570),
                hill1: Color(hex: 0x34405A),
                hill2: Color(hex: 0x2A354C),
                sill: Color(hex: 0x6A5C54),
                curtain: Color(hex: 0x5B5F6E),
                outdoorDisc: Color(hex: 0xE9E4D6),
                showStars: true,
                clock: Color(hex: 0x5A5F6C),
                clockRim: Color(hex: 0x7A7F8C),
                clockTick: Color(hex: 0x9A9EAA),
                hand: Color(hex: 0xF4EEE3),
                pot: Color(hex: 0x7A6553),
                stem: Color(hex: 0x5F7A62),
                leaf: Color(hex: 0x6E9077),
                rug: Color(hex: 0x4A423C),
                nestDark: Color(hex: 0x6E5A47),
                nest: Color(hex: 0x8A7660),
                nestRim: Color(hex: 0xA89478),
                cushion: Color(hex: 0x5A6458),
                cushion2: Color(hex: 0x667064),
                desk: Color(hex: 0x7A6553),
                deskLeg: Color(hex: 0x5E4B3D),
                paper: Color(hex: 0x5A5F6C),
                paperLine: Color(hex: 0x7A7F8C),
                noteLine: Color(hex: 0xF4EEE3)
            )
        }
    }
}
