import SwiftUI

/// Bottom-left floating dock of the Calm Space main window.
///
/// Sizing contract: this view is content-sized. The parent pins it to the
/// bottom-leading corner and applies `layout.horizontalMargin` /
/// `layout.bottomInset`, so the dock must not add outer padding of its own.
/// Compact mode makes every entry icon-only (~36 pt), which keeps the dock clear
/// of the bottom-trailing mode switch at the minimum window size.
struct CalmSpaceDockView: View {
    let palette: CalmSpacePalette
    let layout: CalmSpaceLayout
    let mode: AppMode
    let onOpenDisk: () -> Void
    let onOpenApplications: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: layout.compact ? 8 : 10) {
            switch mode {
            case .macCare:
                liveEntry(title: "磁盘管理", systemImage: "internaldrive", action: onOpenDisk)
                liveEntry(title: "应用管理", systemImage: "square.grid.2x2", action: onOpenApplications)
                liveEntry(title: "系统设置", systemImage: "gearshape", action: onOpenSettings)

            case .workRhythm:
                // Focus / rest timers do not exist in the product yet. They are shown
                // honestly as disabled entries instead of dead-looking live buttons.
                CalmSpaceDockUnavailableEntry(
                    title: "专注",
                    systemImage: "timer",
                    palette: palette,
                    layout: layout
                )
                CalmSpaceDockUnavailableEntry(
                    title: "休息",
                    systemImage: "cup.and.saucer",
                    palette: palette,
                    layout: layout
                )
                liveEntry(title: "系统设置", systemImage: "gearshape", action: onOpenSettings)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("快捷操作"))
    }

    private func liveEntry(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        CalmSpaceDockEntryButton(
            title: title,
            systemImage: systemImage,
            palette: palette,
            layout: layout,
            action: action
        )
    }
}

// MARK: - Live entry

/// One working dock entry. Hover state is intentionally local to the pill so a
/// pointer move only invalidates that entry — never the whole dock, never the orb.
private struct CalmSpaceDockEntryButton: View {
    let title: String
    let systemImage: String
    let palette: CalmSpacePalette
    let layout: CalmSpaceLayout
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            CalmSpaceDockEntryPill(
                title: title,
                systemImage: systemImage,
                palette: palette,
                layout: layout,
                isHovering: isHovering,
                isEnabled: true
            )
        }
        .buttonStyle(.plain)
        .contentShape(entryShape)
        .onHover { isHovering = $0 }
        .help(title)
        .accessibilityLabel(Text(title))
        .animation(.easeOut(duration: 0.17), value: isHovering)
    }

    private var entryShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: layout.compact ? 10 : layout.dockHeight / 2,
            style: .continuous
        )
    }
}

// MARK: - Unavailable entry

/// Dock entry for a Work Rhythm feature that is not implemented yet.
///
/// It is a real `Button` marked `.disabled(true)`: VoiceOver announces it as
/// dimmed, the pointer gets no hover state, and no action can fire. The visual
/// stays in the tertiary range so it never reads as an active control.
private struct CalmSpaceDockUnavailableEntry: View {
    let title: String
    let systemImage: String
    let palette: CalmSpacePalette
    let layout: CalmSpaceLayout

    var body: some View {
        Button(action: {}) {
            CalmSpaceDockEntryPill(
                title: title,
                systemImage: systemImage,
                palette: palette,
                layout: layout,
                isHovering: false,
                isEnabled: false
            )
        }
        .buttonStyle(.plain)
        .contentShape(entryShape)
        .disabled(true)
        .help("工作节奏功能尚未开放")
        .accessibilityLabel(Text("\(title)，尚未开放"))
    }

    private var entryShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: layout.compact ? 10 : layout.dockHeight / 2,
            style: .continuous
        )
    }
}

// MARK: - Pill

/// The quiet floating pill: translucent fill + hairline stroke, no material stack,
/// no gradient. Regular layout shows the 11 pt label; compact layout is icon-only.
private struct CalmSpaceDockEntryPill: View {
    let title: String
    let systemImage: String
    let palette: CalmSpacePalette
    let layout: CalmSpaceLayout
    let isHovering: Bool
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(labelColor)
                .accessibilityHidden(true)

            if !layout.compact {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityHidden(true)
            }
        }
        .scaleEffect(isHovering ? 1.035 : 1)
        .padding(.horizontal, layout.compact ? 0 : 11)
        .frame(width: compactWidth, height: layout.dockHeight)
        .background(shape.fill(fillColor))
        .overlay(shape.strokeBorder(strokeColor, lineWidth: 1))
    }

    private var labelColor: Color {
        if !isEnabled { return palette.tertiaryText }
        return isHovering ? palette.primaryText : palette.secondaryText
    }

    private var fillColor: Color {
        isHovering ? palette.controlHoverFill : palette.controlFill
    }

    private var strokeColor: Color {
        isHovering ? palette.controlHoverStroke : palette.controlStroke
    }

    /// Compact entries are squares of `dockHeight`; regular entries size to content.
    private var compactWidth: CGFloat? {
        layout.compact ? layout.dockHeight : nil
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: layout.compact ? 10 : layout.dockHeight / 2,
            style: .continuous
        )
    }
}
