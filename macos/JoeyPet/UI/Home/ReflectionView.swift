import SwiftUI

struct ReflectionView: View {
    let summary: CompanionSummary
    let onReturn: () -> Void

    @Environment(\.joeyAppearance) private var appearance

    private let designSize = CGSize(width: 1080, height: 680)
    private var theme: JoeyTheme { JoeyTheme(appearance: appearance) }

    var body: some View {
        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / designSize.width,
                geometry.size.height / designSize.height
            )
            let originX = (geometry.size.width - designSize.width * scale) / 2
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
                        x: originX + 52 * scale,
                        y: originY + 42 * scale
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

            Text(subtitleText)
                .font(JoeyType.reflectionBody)
                .foregroundStyle(theme.ink2)
                .lineSpacing(4)
        }
        .padding(.init(top: 18, leading: 22, bottom: 20, trailing: 22))
        .frame(width: 388, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: JoeyRadius.md, style: .continuous)
                .fill(theme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: JoeyRadius.md, style: .continuous)
                .stroke(theme.hairline, lineWidth: 1)
        )
        .joeyShadowMD()
    }

    private var headline: Text {
        Text("这周我们一起休息了 ")
            + Text("\(summary.weekBreakTotal) 次")
                .fontWeight(.semibold)
                .foregroundStyle(theme.sageDeep)
            + Text("。")
    }

    private var subtitleText: String {
        guard summary.weekBreakTotal > 0 else {
            return JoeyCopy.emptyWeek
        }

        var parts: [String] = []
        if summary.todayCompanionship > 0 {
            parts.append("今天陪了 \(summary.todayCompanionshipText)。")
        } else {
            parts.append("今天还没开始。")
        }

        let todayIndex = Self.indexOfToday
        if summary.weekBreakCounts.count == 7, todayIndex >= 0 {
            let missing = (0...todayIndex)
                .filter { summary.weekBreakCounts[$0] == 0 }
                .map { "周" + Self.weekdayNames[$0] }
            if !missing.isEmpty {
                parts.append(missing.joined(separator: "、") + "没有记录。")
            }
        }
        return parts.joined()
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
        hill1.move(to: CGPoint(x: 0, y: 360))
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
        hill1.addLine(to: CGPoint(x: 1080, y: 680))
        hill1.addLine(to: CGPoint(x: 0, y: 680))
        hill1.closeSubpath()
        context.fill(hill1, with: .color(theme.roomHill1.opacity(0.7)))

        var hill2 = Path()
        hill2.move(to: CGPoint(x: 0, y: 420))
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
        hill2.addLine(to: CGPoint(x: 1080, y: 680))
        hill2.addLine(to: CGPoint(x: 0, y: 680))
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
        path.move(to: CGPoint(x: 120, y: 560))
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
            if count > 0 {
                drawSprout(&context, origin: CGPoint(x: x, y: 500))
            } else {
                drawStone(&context, origin: CGPoint(x: x, y: 504))
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

    private func drawSprout(_ context: inout GraphicsContext, origin: CGPoint) {
        context.drawLayer { layer in
            layer.translateBy(x: origin.x, y: origin.y)
            layer.fill(
                Path(ellipseIn: CGRect(x: 2, y: 47, width: 36, height: 10)),
                with: .color(theme.roomSill)
            )
            var stem = Path()
            stem.move(to: CGPoint(x: 20, y: 48))
            stem.addCurve(
                to: CGPoint(x: 25, y: 4),
                control1: CGPoint(x: 20, y: 28),
                control2: CGPoint(x: 23, y: 12)
            )
            layer.stroke(
                stem,
                with: .color(theme.roomStem),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            layer.drawLayer { leaf in
                leaf.translateBy(x: 31, y: 12)
                leaf.rotate(by: .degrees(28))
                leaf.fill(
                    Path(ellipseIn: CGRect(x: -8, y: -13, width: 16, height: 26)),
                    with: .color(theme.roomLeaf)
                )
            }
            layer.drawLayer { leaf in
                leaf.translateBy(x: 12, y: 18)
                leaf.rotate(by: .degrees(-30))
                leaf.fill(
                    Path(ellipseIn: CGRect(x: -7, y: -11, width: 14, height: 22)),
                    with: .color(theme.roomLeaf.opacity(0.8))
                )
            }
            layer.fill(
                Path(ellipseIn: CGRect(x: 17, y: -8, width: 14, height: 20)),
                with: .color(theme.roomLeaf)
            )
        }
    }

    private func drawStone(_ context: inout GraphicsContext, origin: CGPoint) {
        context.drawLayer { layer in
            layer.translateBy(x: origin.x, y: origin.y)
            layer.fill(
                Path(ellipseIn: CGRect(x: 4, y: 47, width: 32, height: 14)),
                with: .color(theme.roomSill)
            )
            layer.fill(
                Path(ellipseIn: CGRect(x: 8, y: 37, width: 24, height: 18)),
                with: .color(theme.roomFrame)
            )
        }
    }
}

extension ReflectionView {
    static func weekdayName(at index: Int) -> String {
        guard index >= 0, index < weekdayNames.count else { return "" }
        return weekdayNames[index]
    }
}
