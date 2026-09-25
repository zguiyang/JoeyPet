import SwiftUI

struct MacCareHomeView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var shellState: AppShellState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredStorageCategory: StorageCompositionCategory?

    private var presentation: MacCareHomePresentation {
        MacCareHomePresentationBuilder.make(
            snapshot: model.systemStatus,
            scanResult: model.scanResult,
            cleanupPhase: model.cleanupPhase,
            memoryTrendSampleCount: model.memoryTrendSamples.count,
            storageCompositionState: model.storageCompositionState
        )
    }

    var body: some View {
        let presentation = presentation
        VStack(alignment: .leading, spacing: 0) {
            overallStatusSection(presentation)
            Spacer(minLength: MacCareHomeMetrics.sectionGap)
            metricsGrid(presentation)
            Spacer(minLength: MacCareHomeMetrics.sectionGap)
            maintenanceSection(presentation)
        }
        .padding(.top, MacCareHomeMetrics.topInset)
        .padding(.bottom, MacCareHomeMetrics.bottomInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            model.refreshStorageCompositionIfNeeded()
        }
    }

    // MARK: - Overall status

    private func overallStatusSection(_ presentation: MacCareHomePresentation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(presentation.tone == .normal ? Color.green : Color.orange)
                        .frame(width: MacCareHomeMetrics.statusDotSize, height: MacCareHomeMetrics.statusDotSize)
                        .shadow(color: (presentation.tone == .normal ? Color.green : Color.orange).opacity(0.35), radius: 4)
                        .opacity(reduceMotion ? 1 : 0.95)
                        .accessibilityHidden(true)
                    Text(presentation.headline)
                        .font(.system(size: MacCareHomeMetrics.headlineFontSize, weight: .semibold))
                        .foregroundStyle(.primary)
                        .tracking(-0.2)
                }
                Text(presentation.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(presentation.tone == .attention ? Color.orange : Color.secondary)
                    .padding(.leading, MacCareHomeMetrics.statusDotSize + 8)
            }
            Spacer(minLength: 8)
            if let lastChecked = presentation.lastCheckedText {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11, weight: .medium))
                    Text(lastChecked)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(secondaryPillBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(separatorColor.opacity(0.35), lineWidth: 0.5)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Metrics grid

    private func metricsGrid(_ presentation: MacCareHomePresentation) -> some View {
        ViewThatFits(in: .horizontal) {
            metricsGridRow(presentation)
            VStack(spacing: MacCareHomeMetrics.sectionGap) {
                storagePanel(presentation.storage)
                rightMetricsColumn(presentation)
            }
        }
        .frame(height: MacCareHomeMetrics.metricsGridHeight)
    }

    private func metricsGridRow(_ presentation: MacCareHomePresentation) -> some View {
        HStack(alignment: .top, spacing: MacCareHomeMetrics.sectionGap) {
                storagePanel(presentation.storage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            rightMetricsColumn(presentation)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func rightMetricsColumn(_ presentation: MacCareHomePresentation) -> some View {
        VStack(spacing: MacCareHomeMetrics.sectionGap) {
            memoryPanel(presentation)
                .frame(maxHeight: .infinity)
            thermalPanel(presentation.thermal)
                .frame(maxHeight: .infinity)
        }
    }

    // MARK: - Storage

    private func storagePanel(_ storage: StoragePresentation) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Label {
                    Text(storage.volumeTitle)
                        .font(.system(size: 15, weight: .semibold))
                } icon: {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                Spacer(minLength: 4)
                if let availableText = storage.availableText {
                    Text(availableText)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(colorScheme == .dark ? 0.22 : 0.15), in: Capsule())
                        .contentTransition(.numericText())
                        .animation(MacCareHomeMotion.trendSampleUpdate, value: availableText)
                }
            }

            if let fraction = storage.usedFraction, let usedText = storage.usedText {
                Spacer(minLength: 4)
                ZStack {
                    StorageCompositionDonutView(
                        segments: StorageCompositionDonutView.layouts(from: storage.segments),
                        diameter: MacCareHomeMetrics.donutDiameter,
                        strokeWidth: MacCareHomeMetrics.donutStroke,
                        hoveredCategory: $hoveredStorageCategory
                    )
                    VStack(spacing: 2) {
                        Text(usedText)
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                            .contentTransition(.numericText())
                            .animation(MacCareHomeMotion.trendSampleUpdate, value: usedText)
                        Text("已用 \(Int((fraction * 100).rounded()))%")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .animation(MacCareHomeMotion.trendSampleUpdate, value: fraction)
                    }
                    if let hovered = hoveredStorageCategory,
                       let segment = storage.segments.first(where: { $0.category == hovered }) {
                        StorageSegmentTooltip(
                            segment: segment,
                            totalBytes: storage.totalBytes,
                            usedBytes: storage.usedBytes
                        )
                        .offset(y: -MacCareHomeMetrics.donutDiameter * 0.55)
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: MacCareHomeMetrics.donutDiameter + 8)
                .accessibilityLabel(storage.accessibilitySummary)

                storageLegendGrid(storage)
                    .padding(.top, 4)
            } else {
                Spacer(minLength: 0)
                Text(storage.footnote ?? "存储数据暂不可用")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .padding(MacCareHomeMetrics.cardPadding)
        .frame(maxHeight: .infinity)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: MacCareHomeMetrics.cardCornerRadius, style: .continuous))
        .overlay(cardBorder)
    }

    private func storageLegendGrid(_ storage: StoragePresentation) -> some View {
        Group {
            if storage.compositionState == .loading {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在估算分类…")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    alignment: .leading,
                    spacing: 4
                ) {
                    ForEach(storage.legendSegments, id: \.category) { segment in
                        legendRow(segment, storage: storage)
                    }
                }
                .padding(6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(legendWellBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func legendRow(_ segment: MacCareStorageSegment, storage: StoragePresentation) -> some View {
        let isHighlighted = hoveredStorageCategory == segment.category
        return HStack(spacing: 6) {
            Circle()
                .fill(StorageCompositionDonutView.color(for: segment.category))
                .frame(width: 8, height: 8)
            Text(segmentLegendTitle(segment))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isHighlighted ? Color.primary : Color.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 3)
        .background(isHighlighted ? Color.primary.opacity(0.06) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
        .onHover { hovering in
            hoveredStorageCategory = hovering ? segment.category : nil
        }
        .accessibilityLabel(segmentLegendTitle(segment))
    }

    private func segmentLegendTitle(_ segment: MacCareStorageSegment) -> String {
        "\(segment.title) \(JoeyByteFormat.string(fromByteCount: segment.byteCount))"
    }

    // MARK: - Memory

    private func memoryPanel(_ presentation: MacCareHomePresentation) -> some View {
        let memory = presentation.memory
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label {
                    Text("内存压力")
                        .font(.system(size: 15, weight: .semibold))
                } icon: {
                    Image(systemName: "memorychip")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.green)
                }
                Spacer(minLength: 4)
                statusBadge(
                    title: memory.badgeTitle,
                    tone: memoryBadgeTone(memory.level)
                )
                .animation(MacCareHomeMotion.stateColorTransition, value: memory.level)
            }

            Spacer(minLength: 6)

            MemoryTrendChart(
                samples: model.memoryTrendSamples,
                accent: memoryChartColor(memory.level),
                reduceMotion: reduceMotion
            )
            .animation(MacCareHomeMotion.stateColorTransition, value: memory.level)
            .frame(height: MacCareHomeMetrics.memoryTrendHeight)
            .accessibilityLabel("内存使用趋势")
            .accessibilityValue(memory.accessibilitySummary)

            Spacer(minLength: 6)

            HStack(alignment: .firstTextBaseline) {
                if let usage = memory.usageLine {
                    Text(usage)
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(MacCareHomeMotion.trendSampleUpdate, value: usage)
                }
                Spacer(minLength: 4)
                if let swap = memory.swapLine {
                    Text(swap)
                        .font(.system(size: 12).monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(secondaryPillBackground, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .foregroundStyle(memory.level == .normal ? Color.secondary : Color.orange)
                        .contentTransition(.numericText())
                        .animation(MacCareHomeMotion.stateColorTransition, value: memory.level)
                }
            }
        }
        .padding(MacCareHomeMetrics.cardPadding)
        .frame(maxHeight: .infinity)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: MacCareHomeMetrics.cardCornerRadius, style: .continuous))
        .overlay(cardBorder)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Thermal

    private func thermalPanel(_ thermal: ThermalPresentation) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("散热与风扇")
                        .font(.system(size: 15, weight: .semibold))
                    Text(thermal.badgeTitle)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(secondaryPillBackground, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .foregroundStyle(.secondary)
                        .animation(MacCareHomeMotion.stateColorTransition, value: thermal.level)
                }
                Text(thermal.detailLine)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }
            Spacer(minLength: 8)
            MacCareThermalFanIndicator(
                level: thermal.level,
                reduceMotion: reduceMotion
            )
            .accessibilityHidden(true)
        }
        .padding(MacCareHomeMetrics.cardPadding)
        .frame(maxHeight: .infinity)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: MacCareHomeMetrics.cardCornerRadius, style: .continuous))
        .overlay(cardBorder)
        .accessibilityLabel(thermal.accessibilitySummary)
    }

    // MARK: - Maintenance

    private func maintenanceSection(_ presentation: MacCareHomePresentation) -> some View {
        VStack(spacing: MacCareHomeMetrics.maintenanceGap) {
            cleanupCard(presentation.cleanup)
            applicationsRow
        }
    }

    private func cleanupCard(_ cleanup: CleanupSummaryPresentation) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: MacCareHomeMetrics.cleanupIconSize, height: MacCareHomeMetrics.cleanupIconSize)
                .background(Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(cleanup.title)
                        .font(.system(size: 15, weight: .semibold))
                    if cleanup.kind == .hasReclaimable {
                        Text("常规清理")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                    }
                }
                Text(cleanupSubtitle(cleanup))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(cleanup.primaryActionTitle) {
                openCleanup(from: cleanup)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .font(.system(size: 12, weight: .medium))
        }
        .padding(MacCareHomeMetrics.cleanupRowPadding)
        .background(emphasisCardBackground, in: RoundedRectangle(cornerRadius: MacCareHomeMetrics.cardCornerRadius, style: .continuous))
        .overlay(cardBorder)
    }

    private func cleanupSubtitle(_ cleanup: CleanupSummaryPresentation) -> String {
        guard cleanup.kind == .hasReclaimable,
              let safe = cleanup.safeSizeText,
              let review = cleanup.reviewSizeText
        else {
            return cleanup.subtitle ?? ""
        }
        return "\(cleanup.subtitle ?? "") · \(safe) 安全清理 · \(review) 建议查看"
    }

    private var applicationsRow: some View {
        Button {
            shellState.macCareRoute = .featureDetailMock
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .background(secondaryPillBackground, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                HStack(spacing: 0) {
                    Text("应用卸载")
                        .font(.system(size: 13, weight: .semibold))
                    Text("  ·  ")
                        .foregroundStyle(.tertiary)
                    Text("查看已安装应用及关联缓存残留")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                HStack(spacing: 2) {
                    Text("进入管理")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, MacCareHomeMetrics.appsRowHorizontalPadding)
            .padding(.vertical, MacCareHomeMetrics.appsRowVerticalPadding)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.35 : 0.5),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    private func openCleanup(from cleanup: CleanupSummaryPresentation) {
        shellState.macCareRoute = .legacyCleanup
        switch cleanup.kind {
        case .notScanned:
            model.scan()
        case .scanning, .empty, .hasReclaimable:
            break
        }
    }

    // MARK: - Surfaces

    private var cardBackground: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.55 : 0.88)
    }

    private var emphasisCardBackground: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.62 : 0.94)
    }

    private var legendWellBackground: some ShapeStyle {
        Color(nsColor: .separatorColor).opacity(colorScheme == .dark ? 0.12 : 0.08)
    }

    private var secondaryPillBackground: some ShapeStyle {
        Color(nsColor: .separatorColor).opacity(colorScheme == .dark ? 0.35 : 0.18)
    }

    private var separatorColor: Color {
        Color(nsColor: .separatorColor)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: MacCareHomeMetrics.cardCornerRadius, style: .continuous)
            .strokeBorder(separatorColor.opacity(colorScheme == .dark ? 0.45 : 0.28), lineWidth: 0.5)
    }

    private func statusBadge(title: String, tone: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(tone).frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tone.opacity(colorScheme == .dark ? 0.22 : 0.15), in: Capsule())
        .foregroundStyle(tone)
        .animation(MacCareHomeMotion.stateColorTransition, value: title)
    }

    private func memoryBadgeTone(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private func memoryChartColor(_ level: MemoryPressureLevel) -> Color {
        memoryBadgeTone(level)
    }

}

// MARK: - Memory trend

private struct MemoryTrendChart: View {
    let samples: [Double]
    let accent: Color
    let reduceMotion: Bool

    @State private var morphFrom: [Double] = []
    @State private var morphTo: [Double] = []
    @State private var morphProgress: Double = 1

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let displayed = MacCareHomeMotion.lerpSamples(from: morphFrom, to: morphTo, progress: morphProgress)
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.secondary.opacity(0.06))

                if displayed.count >= 2 {
                    trendPaths(width: width, height: height, samples: displayed)
                    liveSampleIndicator(width: width, height: height, samples: displayed)
                } else if let only = displayed.first ?? samples.first {
                    flatTrendLine(width: width, height: height, value: only, accent: accent.opacity(0.5))
                }

                if samples.count < 2 {
                    Text(samples.isEmpty ? "正在收集趋势" : "趋势样本不足")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .onAppear {
            morphFrom = samples
            morphTo = samples
            morphProgress = 1
        }
        .onChange(of: samples) { _, new in
            morphFrom = MacCareHomeMotion.lerpSamples(from: morphFrom, to: morphTo, progress: morphProgress)
            morphTo = new
            morphProgress = 0
            let animation = reduceMotion
                ? MacCareHomeMotion.trendSampleUpdateReduced
                : MacCareHomeMotion.trendSampleUpdate
            withAnimation(animation) {
                morphProgress = 1
            }
        }
    }

    @ViewBuilder
    private func trendPaths(width: CGFloat, height: CGFloat, samples: [Double]) -> some View {
        let points = chartPoints(width: width, height: height, samples: samples)
        if points.count >= 2 {
            MemoryTrendAreaShape(points: points, baselineY: height)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.32), accent.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            MemoryTrendLineShape(points: points)
                .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }

    @ViewBuilder
    private func liveSampleIndicator(width: CGFloat, height: CGFloat, samples: [Double]) -> some View {
        let points = chartPoints(width: width, height: height, samples: samples)
        if let last = points.last, morphProgress > 0.92 {
            if reduceMotion {
                Circle()
                    .fill(accent.opacity(0.85))
                    .frame(width: 4, height: 4)
                    .position(last)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 20, paused: false)) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                    let pulse = 0.5 + 0.5 * sin(phase * (2 * .pi / 1.85))
                    let scale = 0.96 + 0.04 * pulse
                    let opacity = 0.72 + 0.28 * pulse
                    Circle()
                        .fill(accent)
                        .frame(width: 4, height: 4)
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .position(last)
                }
            }
        }
    }

    private func flatTrendLine(width: CGFloat, height: CGFloat, value: Double, accent: Color) -> some View {
        let y = height - CGFloat(min(max(value, 0), 1)) * (height - 6) - 3
        return Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
        }
        .stroke(accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 3]))
    }

    private func chartPoints(width: CGFloat, height: CGFloat, samples: [Double]) -> [CGPoint] {
        guard samples.count >= 2 else { return [] }
        let minV = samples.min() ?? 0
        let maxV = samples.max() ?? 1
        let span = max(maxV - minV, 0.04)
        let stepX = width / CGFloat(samples.count - 1)
        return samples.enumerated().map { index, value in
            let normalized = (value - minV) / span
            let y = height - CGFloat(normalized) * (height - 6) - 3
            return CGPoint(x: CGFloat(index) * stepX, y: y)
        }
    }
}

private struct MemoryTrendLineShape: Shape {
    var points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

private struct MemoryTrendAreaShape: Shape {
    var points: [CGPoint]
    var baselineY: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.x, y: baselineY))
        for point in points {
            path.addLine(to: point)
        }
        path.addLine(to: CGPoint(x: points.last?.x ?? first.x, y: baselineY))
        path.closeSubpath()
        return path
    }
}
