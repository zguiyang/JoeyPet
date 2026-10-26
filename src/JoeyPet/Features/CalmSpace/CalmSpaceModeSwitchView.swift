import SwiftUI

/// Bottom-right mode switch of the Calm Space main window.
///
/// Sizing contract: the parent pins the trailing edge. Hovering grows the pill to
/// the LEFT only, so the pointer stays over the button while it expands and the
/// control cannot flicker or oscillate. The destination label fades and slides in
/// instead of popping. There is no persistent glow or decoration at rest.
///
/// The collapsed circle uses `layout.modeSwitchDiameter` exactly; a transparent
/// inset keeps the square hit target at 34 pt when the compact token is 32 pt.
struct CalmSpaceModeSwitchView: View {
    let mode: AppMode
    let palette: CalmSpacePalette
    let layout: CalmSpaceLayout
    /// `false` while a mode transition is in flight. The control ignores clicks and
    /// hover, but keeps its exact resting visual — no dimming, no flicker.
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            switchLabel
                .padding(hitTargetInset)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule(style: .continuous))
        .disabled(!isEnabled)
        .onHover { isHovering = isEnabled && $0 }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { isHovering = false }
        }
        .help(destinationTitle)
        .accessibilityLabel(Text(destinationTitle))
        .animation(.easeOut(duration: 0.22), value: isHovering)
    }

    // MARK: - Label

    private var switchLabel: some View {
        HStack(spacing: 8) {
            Text(destinationTitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isHovering ? palette.primaryText : palette.secondaryText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .opacity(isHovering ? 1 : 0)
                .offset(x: isHovering ? 0 : 8)
                .accessibilityHidden(true)

            Spacer(minLength: 8)

            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovering ? palette.primaryText : palette.secondaryText)
                .frame(width: iconSlot, height: iconSlot)
                .accessibilityHidden(true)
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .frame(width: currentWidth, height: visualHeight, alignment: .trailing)
        .background(
            Capsule(style: .continuous)
                .fill(isHovering ? palette.controlHoverFill : palette.controlFill)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    isHovering ? palette.controlHoverStroke : palette.controlStroke,
                    lineWidth: 1
                )
        )
        .clipShape(Capsule(style: .continuous))
    }

    // MARK: - Geometry

    /// Collapsed circle diameter, straight from the layout token (32-34 pt).
    private var visualHeight: CGFloat {
        layout.modeSwitchDiameter
    }

    /// Extra transparent margin so the hit target never drops below 34 × 34 pt.
    private var hitTargetInset: CGFloat {
        max(0, (34 - visualHeight) / 2)
    }

    private var collapsedWidth: CGFloat {
        visualHeight
    }

    private var expandedWidth: CGFloat {
        max(layout.modeSwitchExpandedWidth, visualHeight)
    }

    private var currentWidth: CGFloat {
        isHovering ? expandedWidth : collapsedWidth
    }

    /// Keeps the glyph optically centred in the trailing circle zone.
    private var iconSlot: CGFloat {
        max(visualHeight - 20, 12)
    }

    // MARK: - Copy

    private var destinationTitle: String {
        switch mode {
        case .macCare: return "切换至工作模式"
        case .workRhythm: return "切换至 Mac Care"
        }
    }
}
