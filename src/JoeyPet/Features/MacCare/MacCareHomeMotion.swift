import AppKit
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
            // Core Animation keeps the rotation on the render server; a SwiftUI
            // `repeatForever` animation forced the whole window to redraw at ~11% CPU.
            RotatingSymbolView(
                systemName: "fan.fill",
                pointSize: 17,
                color: NSColor(accent),
                period: MacCareHomeMotion.fanPeriod(for: level)
            )
            .frame(width: 32, height: 32)
            .accessibilityHidden(true)
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

// MARK: - Core Animation–backed motion

/// Rotating SF Symbol rendered by a `CALayer` so the hosting SwiftUI view stays idle.
struct RotatingSymbolView: NSViewRepresentable {
    let systemName: String
    let pointSize: CGFloat
    let color: NSColor
    let period: TimeInterval

    func makeNSView(context: Context) -> RotatingSymbolNSView {
        let view = RotatingSymbolNSView()
        view.update(image: symbol(), period: period)
        return view
    }

    func updateNSView(_ nsView: RotatingSymbolNSView, context: Context) {
        nsView.update(image: symbol(), period: period)
    }

    private func symbol() -> NSImage? {
        let base = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        let palette = NSImage.SymbolConfiguration(paletteColors: [color])
        return NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
            .withSymbolConfiguration(base.applying(palette))
    }
}

final class RotatingSymbolNSView: NSView {
    private let imageLayer = CALayer()
    private var currentPeriod: TimeInterval?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        imageLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        imageLayer.contentsGravity = .resizeAspect
        layer?.addSublayer(imageLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        imageLayer.bounds = CGRect(origin: .zero, size: bounds.size)
        imageLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        imageLayer.contentsScale = window?.backingScaleFactor ?? 2
    }

    func update(image: NSImage?, period: TimeInterval) {
        imageLayer.contents = image
        guard currentPeriod != period else { return }
        currentPeriod = period
        imageLayer.removeAnimation(forKey: "rotation")
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = 0
        animation.toValue = 2 * Double.pi
        animation.duration = max(period, 0.5)
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        imageLayer.add(animation, forKey: "rotation")
    }
}

/// Pulsing dot rendered by a `CALayer` (scale + opacity), keeping the trend chart idle.
struct PulsingDotLayer: NSViewRepresentable {
    let color: NSColor

    func makeNSView(context: Context) -> PulsingDotNSView {
        PulsingDotNSView(color: color)
    }

    func updateNSView(_ nsView: PulsingDotNSView, context: Context) {
        nsView.apply(color: color)
    }
}

final class PulsingDotNSView: NSView {
    private let dotLayer = CALayer()

    init(color: NSColor) {
        super.init(frame: .zero)
        wantsLayer = true
        dotLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        dotLayer.cornerRadius = 2
        layer?.addSublayer(dotLayer)
        apply(color: color)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        dotLayer.bounds = CGRect(x: 0, y: 0, width: 4, height: 4)
        dotLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    func apply(color: NSColor) {
        dotLayer.backgroundColor = color.cgColor
        guard dotLayer.animation(forKey: "pulse") == nil else { return }

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.96
        scale.toValue = 1.0
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.72
        opacity.toValue = 1.0

        let group = CAAnimationGroup()
        group.animations = [scale, opacity]
        group.duration = 0.925
        group.autoreverses = true
        group.repeatCount = .infinity
        group.isRemovedOnCompletion = false
        dotLayer.add(group, forKey: "pulse")
    }
}
