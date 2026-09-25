import SwiftUI

/// Mac Care Home live-state motion tokens (perceptual, not decorative).
enum MacCareHomeMotion {
    static let trendSampleUpdate = Animation.easeOut(duration: 0.25)
    static let trendSampleUpdateReduced = Animation.easeOut(duration: 0.12)
    static let stateColorTransition = Animation.easeOut(duration: 0.28)
    static let fanSpeedTransition = Animation.easeInOut(duration: 0.4)

    static let liveSamplePulse = Animation.easeInOut(duration: 1.85).repeatForever(autoreverses: true)

    /// Seconds per full revolution; mapped from thermal state (no fake RPM).
    static func fanPeriod(for level: ThermalPressureLevel) -> TimeInterval {
        switch level {
        case .nominal: return 6.5
        case .fair: return 4.2
        case .serious: return 2.4
        case .critical: return 1.4
        }
    }

    static func fanAccentColor(for level: ThermalPressureLevel) -> Color {
        switch level {
        case .nominal: return .green
        case .fair: return .orange
        case .serious, .critical: return .red
        }
    }

    static func lerpSamples(from: [Double], to: [Double], progress: Double) -> [Double] {
        guard !to.isEmpty else { return [] }
        let t = min(max(progress, 0), 1)
        return to.enumerated().map { index, target in
            let fromValue: Double
            if from.count == to.count {
                fromValue = from[index]
            } else if from.count < to.count {
                let offset = to.count - from.count
                fromValue = index < offset ? (from.last ?? target) : from[index - offset]
            } else {
                let offset = from.count - to.count
                fromValue = from[offset + index]
            }
            return fromValue + (target - fromValue) * t
        }
    }
}

// MARK: - Thermal fan glyph

struct MacCareThermalFanIndicator: View {
    let level: ThermalPressureLevel
    let reduceMotion: Bool

    @Environment(\.colorScheme) private var colorScheme
    /// Anchor time for continuous rotation (AppKit-hosted windows do not report reliable `scenePhase`).
    @State private var rotationEpoch = Date()
    @State private var displayPeriod: TimeInterval = MacCareHomeMotion.fanPeriod(for: .nominal)

    private var accent: Color { MacCareHomeMotion.fanAccentColor(for: level) }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(accent.opacity(colorScheme == .dark ? 0.18 : 0.12))
                    .frame(width: 32, height: 32)
                fanGlyph
            }
            .frame(width: 32, height: 32)
            Text(secondaryLabel)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 72)
        .onAppear {
            displayPeriod = MacCareHomeMotion.fanPeriod(for: level)
            rotationEpoch = Date()
        }
        .onChange(of: level) { _, newLevel in
            rotationEpoch = Date()
            withAnimation(MacCareHomeMotion.fanSpeedTransition) {
                displayPeriod = MacCareHomeMotion.fanPeriod(for: newLevel)
            }
        }
        .animation(MacCareHomeMotion.stateColorTransition, value: level)
    }

    @ViewBuilder
    private var fanGlyph: some View {
        if reduceMotion {
            Image(systemName: "fan.fill")
                .font(.system(size: 17))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accent)
        } else {
            TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
                let period = max(displayPeriod, 0.5)
                let elapsed = timeline.date.timeIntervalSince(rotationEpoch)
                let angle = (elapsed / period).truncatingRemainder(dividingBy: 1) * 360
                Image(systemName: "fan.fill")
                    .font(.system(size: 17))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(accent)
                    .rotationEffect(.degrees(angle))
            }
        }
    }

    private var secondaryLabel: String {
        switch level {
        case .nominal: return "低负载"
        case .fair: return "轻度负载"
        case .serious: return "负载升高"
        case .critical: return "高负载"
        }
    }
}
