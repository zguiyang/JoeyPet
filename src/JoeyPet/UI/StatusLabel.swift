import SwiftUI

struct StatusLabel: View {
    let severity: SignalSeverity
    let text: String?

    init(severity: SignalSeverity, text: String? = nil) {
        self.severity = severity
        self.text = text
    }

    var body: some View {
        Label {
            Text(text ?? severity.uiDisplayName)
        } icon: {
            Image(systemName: severity.uiSymbolName)
                .foregroundStyle(severity.swiftUIColor)
        }
        .accessibilityLabel("状态：\(text ?? severity.uiDisplayName)")
    }
}

extension SignalSeverity {
    var uiDisplayName: String {
        switch self {
        case .normal: return "正常"
        case .notice: return "留意"
        case .warning: return "需注意"
        case .critical: return "较紧张"
        }
    }

    var uiSymbolName: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .notice: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
}

extension CleanupCategory {
    var uiDisplayName: String {
        switch self {
        case .developerCache: return "开发者缓存"
        case .oldLogs: return "旧日志"
        case .applicationCaches: return "应用缓存"
        }
    }
}

enum JoeyByteFormat {
    static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    static func string(fromByteCount: Int64) -> String {
        formatter.string(fromByteCount: fromByteCount)
    }
}
