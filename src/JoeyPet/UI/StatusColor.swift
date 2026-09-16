import AppKit
import SwiftUI

extension SignalSeverity {
    var statusColor: NSColor {
        switch self {
        case .normal: return .systemGreen
        case .notice: return .systemYellow
        case .warning: return .systemOrange
        case .critical: return .systemRed
        }
    }

    var swiftUIColor: Color { Color(nsColor: statusColor) }
}
