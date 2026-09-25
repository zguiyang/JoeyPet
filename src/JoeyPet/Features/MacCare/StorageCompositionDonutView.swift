import SwiftUI

struct DonutSegmentLayout: Identifiable, Equatable {
    let category: StorageCompositionCategory
    let startFraction: Double
    let endFraction: Double

    var id: String { category.rawValue }

    var midFraction: Double { (startFraction + endFraction) / 2 }
}

struct StorageCompositionDonutView: View {
    let segments: [DonutSegmentLayout]
    let diameter: CGFloat
    let strokeWidth: CGFloat
    @Binding var hoveredCategory: StorageCompositionCategory?

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.14), lineWidth: strokeWidth)
                    .frame(width: size, height: size)
                ForEach(segments) { segment in
                    let isHovered = hoveredCategory == segment.category
                    let stroke = strokeWidth + (isHovered ? 1.5 : 0)
                    Circle()
                        .trim(from: segment.startFraction, to: segment.endFraction)
                        .stroke(
                            color(for: segment.category).opacity(isHovered ? 1 : 0.92),
                            style: StrokeStyle(lineWidth: stroke, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: size, height: size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Circle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoveredCategory = category(at: location, in: proxy.size)
                case .ended:
                    hoveredCategory = nil
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(.easeOut(duration: 0.22), value: segments.map(\.endFraction))
    }

    private func category(at location: CGPoint, in size: CGSize) -> StorageCompositionCategory? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let outer = min(size.width, size.height) / 2
        let inner = outer - strokeWidth
        guard distance >= inner - 2, distance <= outer + 2 else { return nil }

        var angle = atan2(dy, dx) + .pi / 2
        if angle < 0 { angle += 2 * .pi }
        let fraction = angle / (2 * .pi)

        for segment in segments where fraction >= segment.startFraction && fraction < segment.endFraction {
            return segment.category
        }
        if fraction >= (segments.last?.startFraction ?? 0) {
            return segments.last?.category
        }
        return nil
    }

    static func layouts(from segments: [MacCareStorageSegment]) -> [DonutSegmentLayout] {
        var cursor = 0.0
        var layouts: [DonutSegmentLayout] = []
        for segment in segments where segment.fractionOfTotal > 0 {
            let end = cursor + segment.fractionOfTotal
            layouts.append(
                DonutSegmentLayout(
                    category: segment.category,
                    startFraction: cursor,
                    endFraction: min(end, 1)
                )
            )
            cursor = end
        }
        return layouts
    }

    static func color(for category: StorageCompositionCategory) -> Color {
        switch category {
        case .applications: return Color.accentColor
        case .developer: return Color.orange
        case .media: return Color.green
        case .other: return Color.secondary
        case .available: return Color.secondary.opacity(0.28)
        }
    }

    private func color(for category: StorageCompositionCategory) -> Color {
        Self.color(for: category)
    }
}

struct StorageSegmentTooltip: View {
    let segment: MacCareStorageSegment
    let totalBytes: Int64
    let usedBytes: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(segment.title)
                .font(.system(size: 12, weight: .semibold))
            Text(tooltipLine)
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
    }

    private var tooltipLine: String {
        let size = JoeyByteFormat.string(fromByteCount: segment.byteCount)
        let ofTotal = StorageCompositionBuilder.fraction(of: segment.byteCount, in: totalBytes) * 100
        if segment.category == .available {
            return "\(size) · \(String(format: "%.1f", ofTotal))%"
        }
        let ofUsed = StorageCompositionBuilder.fractionOfUsed(segment.byteCount, usedBytes: usedBytes) * 100
        return "\(size) · \(String(format: "%.1f", ofUsed))% 已用 · \(String(format: "%.1f", ofTotal))% 总计"
    }
}
