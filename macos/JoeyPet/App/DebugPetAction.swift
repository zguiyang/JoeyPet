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
    case carrying
    case sleeping
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
        case .carrying: return "叼叶子"
        case .sleeping: return "睡觉"
        case .startSession: return "开始陪伴"
        case .endSession: return "结束陪伴"
        case .posePreview: return "打开姿态预览窗"
        }
    }

    var subtitle: String {
        switch self {
        case .showDesktopPet:
            return "打开「在桌面上显示 Joey」，便于看桌面效果"
        case .greeting:
            return "抬爪挥手 + 头顶「你好。」胶囊 tip"
        case .notifying:
            return "look + 邀请卡（坐久啦…）"
        case .recovering:
            return "stretch + 恢复面板（倒计时）"
        case .celebrating:
            return "happy + 完成 toast（不计入今日休息）"
        case .carrying:
            return "carry 叼叶子短会话"
        case .sleeping:
            return "sleeping 短会话后回 idle"
        case .startSession:
            return "进入陪伴会话"
        case .endSession:
            return "结束当前陪伴"
        case .posePreview:
            return "姿态对照窗（原 Debug 入口）"
        }
    }
}
