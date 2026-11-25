import SwiftUI

struct ReflectionView: View {
    let summary: CompanionSummary
    let onReturn: () -> Void

    @Environment(\.joeyChromeTone) private var chromeTone

    private let designSize = CGSize(width: 1080, height: 680)
    private var theme: JoeyTheme {
        JoeyTheme(chromeTone: chromeTone)
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / designSize.width,
                geometry.size.height / designSize.height
            )
            let originX = (geometry.size.width - designSize.width * scale) / 2
            // Keep garden sky under the transparent titlebar (same rule as home).
            let originY = (geometry.size.height - designSize.height * scale) / 2

            ZStack(alignment: .topLeading) {
                theme.roomWall

                Canvas { context, _ in
                    var painterContext = context
                    painterContext.translateBy(x: originX, y: originY)
                    painterContext.scaleBy(x: scale, y: scale)
                    GardenPainter(theme: theme, breaks: summary.weekBreakCounts)
                        .draw(in: &painterContext)
                }

                sign
                    .frame(width: 388, alignment: .leading)
                    .offset(
                        x: originX + 60 * scale,
                        // Clear the floating window title.
                        y: originY + max(48, 56) * scale
                    )

                JoeySecondaryButton(
                    title: JoeyCopy.returnHome,
                    systemImage: "house",
                    action: onReturn
                )
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .bottomTrailing
                )
                .padding(.trailing, 44)
                .padding(.bottom, 24)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .background(theme.roomWall)
    }

    private var sign: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(weekRangeText)
                .font(JoeyType.meta)
                .foregroundStyle(theme.muted)
                .monospacedDigit()

            headline
                .font(JoeyType.reflectionHeadline)
                .foregroundStyle(theme.ink)
                .lineSpacing(4)

            if !subtitleText.isEmpty {
                Text(subtitleText)
                    .font(JoeyType.reflectionBody)
                    .foregroundStyle(theme.ink2)
                    .lineSpacing(4)
            }
        }
        .frame(width: 388, alignment: .leading)
    }

    private var headline: Text {
        if summary.weekBreakTotal == 0 {
            return Text(JoeyCopy.emptyWeek)
        }
        return Text("这周一起休息 ")
            + Text("\(summary.weekBreakTotal) 次")
                .fontWeight(.semibold)
                .foregroundStyle(theme.sageDeep)
    }

    private var subtitleText: String {
        guard summary.weekBreakTotal > 0 else {
            if summary.todayCompanionship > 0 {
                return "今天陪了 \(summary.todayCompanionshipText)"
            }
            return ""
        }

        var parts: [String] = []
        if summary.todayCompanionship > 0 {
            parts.append("今天陪了 \(summary.todayCompanionshipText)")
        } else {
            parts.append(JoeyCopy.emptyToday)
        }

        let todayIndex = Self.indexOfToday
        if summary.weekBreakCounts.count == 7, todayIndex >= 0 {
            let missing = (0...todayIndex)
                .filter { summary.weekBreakCounts[$0] == 0 }
                .map { "周" + Self.weekdayNames[$0] }
            if !missing.isEmpty {
                parts.append(missing.joined(separator: "、") + "没有记录")
            }
        }
        return parts.joined(separator: " · ")
    }

    private var weekRangeText: String {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: now) ?? now
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? now
        return "\(Self.dateFormatter.string(from: monday)) – \(Self.dateFormatter.string(from: sunday))"
    }

    private static let weekdayNames = ["一", "二", "三", "四", "五", "六", "日"]

    private static var indexOfToday: Int {
        let weekday = Calendar.current.component(.weekday, from: .now)
        return (weekday + 5) % 7
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()
}

// MARK: - Garden illustration

private struct GardenPainter {
    let theme: JoeyTheme
    let breaks: [Int]

    func draw(in context: inout GraphicsContext) {
        drawScene(&context)
        drawDays(&context)
    }

    private func drawScene(_ context: inout GraphicsContext) {
        context.fill(
            Path(CGRect(x: -1000, y: -1000, width: 3000, height: 1520)),
            with: .color(theme.roomWall)
        )
        context.fill(
            Path(CGRect(x: -1000, y: -1000, width: 3000, height: 1520)),
            with: .linearGradient(
                Gradient(colors: [
                    theme.roomSky.opacity(0.12),
                    theme.roomSky.opacity(0.42),
                    theme.roomSky.opacity(0.82)
                ]),
                startPoint: CGPoint(x: 540, y: 0),
                endPoint: CGPoint(x: 540, y: 520)
            )
        )

        context.fill(
            Path(ellipseIn: CGRect(x: 774, y: 20, width: 256, height: 256)),
            with: .radialGradient(
                Gradient(colors: [
                    theme.apricot.opacity(0.26),
                    theme.apricot.opacity(0.12),
                    theme.apricot.opacity(0)
                ]),
                center: CGPoint(x: 902, y: 148),
                startRadius: 0,
                endRadius: 128
            )
        )
        context.fill(
            Path(ellipseIn: CGRect(x: 868, y: 114, width: 68, height: 68)),
            with: .color(theme.apricot.opacity(0.22))
        )

        var hill1 = Path()
        hill1.move(to: CGPoint(x: -1000, y: 420))
        hill1.addCurve(
            to: CGPoint(x: 0, y: 360),
            control1: CGPoint(x: -650, y: 420),
            control2: CGPoint(x: -180, y: 420)
        )
        hill1.addCurve(
            to: CGPoint(x: 540, y: 330),
            control1: CGPoint(x: 180, y: 300),
            control2: CGPoint(x: 340, y: 350)
        )
        hill1.addCurve(
            to: CGPoint(x: 1080, y: 320),
            control1: CGPoint(x: 760, y: 308),
            control2: CGPoint(x: 900, y: 350)
        )
        hill1.addCurve(
            to: CGPoint(x: 2000, y: 300),
            control1: CGPoint(x: 1260, y: 290),
            control2: CGPoint(x: 1600, y: 295)
        )
        hill1.addLine(to: CGPoint(x: 2000, y: 680))
        hill1.addLine(to: CGPoint(x: -1000, y: 680))
        hill1.closeSubpath()
        context.fill(hill1, with: .color(theme.roomHill1.opacity(0.7)))

        var hill2 = Path()
        hill2.move(to: CGPoint(x: -1000, y: 470))
        hill2.addCurve(
            to: CGPoint(x: 0, y: 420),
            control1: CGPoint(x: -650, y: 470),
            control2: CGPoint(x: -220, y: 468)
        )
        hill2.addCurve(
            to: CGPoint(x: 640, y: 400),
            control1: CGPoint(x: 220, y: 372),
            control2: CGPoint(x: 420, y: 420)
        )
        hill2.addCurve(
            to: CGPoint(x: 1080, y: 400),
            control1: CGPoint(x: 860, y: 380),
            control2: CGPoint(x: 1000, y: 420)
        )
        hill2.addCurve(
            to: CGPoint(x: 2000, y: 380),
            control1: CGPoint(x: 1160, y: 380),
            control2: CGPoint(x: 1600, y: 380)
        )
        hill2.addLine(to: CGPoint(x: 2000, y: 680))
        hill2.addLine(to: CGPoint(x: -1000, y: 680))
        hill2.closeSubpath()
        context.fill(hill2, with: .color(theme.roomHill2.opacity(0.6)))

        context.fill(
            Path(CGRect(x: -1000, y: 520, width: 3000, height: 2000)),
            with: .color(theme.roomFloor)
        )
        context.fill(
            Path(CGRect(x: -1000, y: 512, width: 3000, height: 8)),
            with: .color(theme.roomBase)
        )

        var path = Path()
        path.move(to: CGPoint(x: -1000, y: 600))
        path.addCurve(
            to: CGPoint(x: 120, y: 560),
            control1: CGPoint(x: -600, y: 600),
            control2: CGPoint(x: -60, y: 600)
        )
        path.addCurve(
            to: CGPoint(x: 620, y: 562),
            control1: CGPoint(x: 300, y: 520),
            control2: CGPoint(x: 460, y: 590)
        )
        path.addCurve(
            to: CGPoint(x: 980, y: 560),
            control1: CGPoint(x: 780, y: 534),
            control2: CGPoint(x: 900, y: 588)
        )
        path.addCurve(
            to: CGPoint(x: 2000, y: 540),
            control1: CGPoint(x: 1060, y: 532),
            control2: CGPoint(x: 1500, y: 540)
        )
        context.stroke(
            path,
            with: .color(theme.roomFloorLine.opacity(0.4)),
            style: StrokeStyle(lineWidth: 26, lineCap: .round)
        )
        context.stroke(
            path,
            with: .color(theme.roomFloorLine.opacity(0.8)),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 12])
        )
    }

    private func drawDays(_ context: inout GraphicsContext) {
        for index in 0..<7 {
            let x = 120 + index * 128
            let count = index < breaks.count ? breaks[index] : 0
            switch count {
            case 0:
                drawSeed(&context, origin: CGPoint(x: x, y: 500))
            case 1:
                drawSprout(&context, origin: CGPoint(x: x, y: 500))
            case 2:
                drawSprout(&context, origin: CGPoint(x: x, y: 500), growth: 1.32)
            default:
                drawTree(&context, origin: CGPoint(x: x, y: 500))
            }

            context.draw(
                Text(ReflectionView.weekdayName(at: index))
                    .font(.system(size: 13))
                    .foregroundStyle(theme.ink2),
                at: CGPoint(x: x + 20, y: 596),
                anchor: .center
            )
        }
    }

    private func drawSeed(_ context: inout GraphicsContext, origin: CGPoint) {
        context.drawLayer { layer in
            layer.translateBy(x: origin.x, y: origin.y)
            layer.fill(
                Path(ellipseIn: CGRect(x: 2, y: 46, width: 36, height: 11)),
                with: .color(theme.roomFloorLine.opacity(0.35))
            )

            layer.drawLayer { seed in
                seed.translateBy(x: 20, y: 39)
                seed.rotate(by: .degrees(-24))
                seed.fill(
                    Path(ellipseIn: CGRect(x: -5.5, y: -8.5, width: 11, height: 17)),
                    with: .color(theme.apricotInk.opacity(0.9))
                )
                seed.fill(
                    Path(ellipseIn: CGRect(x: -2, y: -5, width: 4, height: 7)),
                    with: .color(theme.apricot.opacity(0.6))
                )
            }

            layer.fill(
                Path(ellipseIn: CGRect(x: 4, y: 44, width: 32, height: 10)),
                with: .color(theme.roomSill)
            )
        }
    }

    private func drawTree(_ context: inout GraphicsContext, origin: CGPoint) {
        context.drawLayer { layer in
            layer.translateBy(x: origin.x, y: origin.y)
            layer.fill(
                Path(ellipseIn: CGRect(x: 4, y: 47, width: 32, height: 10)),
                with: .color(theme.roomSill)
            )

            var trunk = Path()
            trunk.move(to: CGPoint(x: 20, y: 48))
            trunk.addCurve(
                to: CGPoint(x: 22, y: -8),
                control1: CGPoint(x: 18, y: 30),
                control2: CGPoint(x: 20, y: 10)
            )
            layer.stroke(
                trunk,
                with: .color(theme.roomStem),
                style: StrokeStyle(lineWidth: 5, lineCap: .round)
            )

            layer.fill(
                Path(ellipseIn: CGRect(x: -2, y: -40, width: 34, height: 30)),
                with: .color(theme.roomLeaf.opacity(0.85))
            )
            layer.fill(
                Path(ellipseIn: CGRect(x: 10, y: -56, width: 32, height: 30)),
                with: .color(theme.roomLeaf)
            )
            layer.fill(
                Path(ellipseIn: CGRect(x: 18, y: -38, width: 32, height: 28)),
                with: .color(theme.roomLeaf.opacity(0.92))
            )
            layer.fill(
                Path(ellipseIn: CGRect(x: 4, y: -30, width: 38, height: 26)),
                with: .color(theme.roomLeaf)
            )
            layer.fill(
                Path(ellipseIn: CGRect(x: 14, y: -50, width: 12, height: 8)),
                with: .color(theme.roomCushion2.opacity(0.45))
            )
            layer.fill(
                Path(ellipseIn: CGRect(x: 9, y: -31, width: 5, height: 5)),
                with: .color(theme.apricot)
            )
            layer.fill(
                Path(ellipseIn: CGRect(x: 31, y: -26, width: 4, height: 4)),
                with: .color(theme.apricot.opacity(0.9))
            )
        }
    }

    private func drawSprout(
        _ context: inout GraphicsContext,
        origin: CGPoint,
        growth: CGFloat = 1
    ) {
        context.drawLayer { layer in
            layer.translateBy(x: origin.x, y: origin.y)
            layer.fill(
                Path(ellipseIn: CGRect(x: 2, y: 47, width: 36, height: 10)),
                with: .color(theme.roomSill)
            )
            layer.drawLayer { plant in
                plant.translateBy(x: 20, y: 48)
                plant.scaleBy(x: 1 + (growth - 1) * 0.12, y: growth)
                plant.translateBy(x: -20, y: -48)

                var stem = Path()
                stem.move(to: CGPoint(x: 20, y: 48))
                stem.addCurve(
                    to: CGPoint(x: 25, y: 4),
                    control1: CGPoint(x: 20, y: 28),
                    control2: CGPoint(x: 23, y: 12)
                )
                plant.stroke(
                    stem,
                    with: .color(theme.roomStem),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                plant.drawLayer { leaf in
                    leaf.translateBy(x: 31, y: 12)
                    leaf.rotate(by: .degrees(28))
                    leaf.fill(
                        Path(ellipseIn: CGRect(x: -8, y: -13, width: 16, height: 26)),
                        with: .color(theme.roomLeaf)
                    )
                }
                plant.drawLayer { leaf in
                    leaf.translateBy(x: 12, y: 18)
                    leaf.rotate(by: .degrees(-30))
                    leaf.fill(
                        Path(ellipseIn: CGRect(x: -7, y: -11, width: 14, height: 22)),
                        with: .color(theme.roomLeaf.opacity(0.8))
                    )
                }
                plant.fill(
                    Path(ellipseIn: CGRect(x: 17, y: -8, width: 14, height: 20)),
                    with: .color(theme.roomLeaf)
                )
            }
        }
    }
}

extension ReflectionView {
    static func weekdayName(at index: Int) -> String {
        guard index >= 0, index < weekdayNames.count else { return "" }
        return weekdayNames[index]
    }
}
