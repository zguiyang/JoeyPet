import Foundation

/// Local-only pet probes used by the Debug settings pane.
/// The pane is compiled out of Release; keep the enum available so call sites stay simple.
///
/// Each action should surface the **full product moment** (pose + matching card /
/// tip / toast), not only a bare SpriteKit pose.
enum DebugPetAction: String, CaseIterable, Identifiable, Sendable {
    case showDesktopPet
    case greeting
    case notifying
    case recovering
    case celebrating
    case sleeping
    /// Quiet-hours deep sleep pose (`sleep`), distinct from DND/idle `doze`.
    case quietSleep
    case yawning
    case grooming
    case startSession
    case endSession
    case posePreview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .showDesktopPet: return "显示桌面 Joey"
        case .greeting: return "打招呼"
        case .notifying: return "休息邀请"
        case .recovering: return "30 秒恢复"
        case .celebrating: return "完成开心"
        case .sleeping: return "浅睡打盹"
        case .quietSleep: return "深睡"
        case .yawning: return "打哈欠"
        case .grooming: return "理毛"
        case .startSession: return "开始陪伴"
        case .endSession: return "结束陪伴"
        case .posePreview: return "打开姿态预览窗"
        }
    }

    var subtitle: String {
        switch self {
        case .showDesktopPet:
            return "打开「在桌面显示 Joey」"
        case .greeting:
            return "抬爪挥手 + 头顶「你好」胶囊 tip"
        case .notifying:
            return "look + 邀请卡（当前处方）"
        case .recovering:
            return "stretch + 恢复面板（倒计时）"
        case .celebrating:
            return "happy（不计入今日休息）"
        case .sleeping:
            return "doze 浅睡（勿扰 / 空闲打盹同款），约 18 秒"
        case .quietSleep:
            return "sleep 深睡（安静时段同款），约 24 秒"
        case .yawning:
            return "yawn 打哈欠 one-shot，约 1.8 秒"
        case .grooming:
            return "groom 理毛 one-shot，约 2.8 秒"
        case .startSession:
            return "进入陪伴会话"
        case .endSession:
            return "结束当前陪伴"
        case .posePreview:
            return "姿态对照窗（原 Debug 入口）"
        }
    }
}
