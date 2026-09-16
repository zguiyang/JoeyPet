import AppKit
import SwiftUI

struct JoeyBubbleMessage {
    let text: String
    let severity: SignalSeverity
    let primaryTitle: String?
    let secondaryTitle: String?
}

@MainActor
final class JoeyBubbleController {
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func show(
        _ message: JoeyBubbleMessage,
        near anchor: NSRect,
        onPrimary: (() -> Void)? = nil,
        onSecondary: (() -> Void)? = nil
    ) {
        dismissTask?.cancel()
        panel?.orderOut(nil)

        let view = JoeyBubbleView(message: message, onPrimary: { [weak self] in
            onPrimary?()
            self?.dismiss()
        }, onSecondary: { [weak self] in
            onSecondary?()
            self?.dismiss()
        })
        let hosting = NSHostingView(rootView: view)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: message.primaryTitle == nil ? 78 : 112),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.contentView = hosting
        panel.setFrameOrigin(NSPoint(x: anchor.maxX - 24, y: anchor.maxY - 26))
        panel.orderFront(nil)
        self.panel = panel

        let seconds: TimeInterval = message.primaryTitle == nil ? 4 : 7
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        panel?.orderOut(nil)
        panel = nil
    }

    deinit {
        dismissTask?.cancel()
    }
}

private struct JoeyBubbleView: View {
    let message: JoeyBubbleMessage
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.text)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if message.primaryTitle != nil || message.secondaryTitle != nil {
                HStack(spacing: 8) {
                    if let primaryTitle = message.primaryTitle {
                        Button(primaryTitle, action: onPrimary)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                    if let secondaryTitle = message.secondaryTitle {
                        Button(secondaryTitle, action: onSecondary)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(message.severity.swiftUIColor, lineWidth: 1))
    }
}
