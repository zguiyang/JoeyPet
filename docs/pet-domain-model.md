# JoeyPet 领域与状态模型（V0 工程契约）

> 状态：Draft（领域先行，代码未开始）
> 适用范围：桌宠运行时、状态机、面板交互、会话反馈、持久化
> 上游依据：[DESIGN.md](../DESIGN.md)、[V0_FEATURE_SCOPE.md](../V0_FEATURE_SCOPE.md)、[图谱 v0.1](reference/joeypet-states-v0.html)
> 下游：`macos/JoeyPet` 实现、`macos/JoeyPetTests`、ADR

## 0. 这份文档解决什么问题

这是一份**工程契约**，不是设计稿。它固定四件事：

1. 领域里有哪些对象，各自只能表达什么。
2. 状态如何变化，谁有权决定变化。
3. 多条规则同时成立时谁优先，哪些计时必须保留。
4. 哪些不变量任何实现都不能破坏。

视觉、文案、像素以 [DESIGN.md](../DESIGN.md) 为准；姿态与状态细节以[图谱 v0.1](reference/joeypet-states-v0.html) 为准。本文档只解决“代码里的语义”。

长任务最容易跑偏的地方不是写错一行代码，而是中途自己发明了一个状态、一个计时或一个优先级。出现这种情况时，先改本文档，再改代码。

## 1. 权威顺序与变更协议

发生冲突时按以下顺序裁决：

| 层级 | 来源 | 管什么 |
|---|---|---|
| 1 | [V0_FEATURE_SCOPE.md](../V0_FEATURE_SCOPE.md)、[AGENTS.md](../AGENTS.md) | 产品范围、允许的依赖、禁区 |
| 2 | [DESIGN.md](../DESIGN.md) | 视觉、文案、布局、交互契约 |
| 3 | [图谱 v0.1](reference/joeypet-states-v0.html) | 12 姿态、8 表情、微动效参数、状态阶梯 |
| 4 | 本文档 | 领域对象、状态机、事件、守卫、效果、不变量 |
| 5 | 代码与测试 | 实现细节 |

规则：

- 产品范围冲突：第 1 层赢，需求直接拒掉。
- 视觉/文案冲突：第 2 层赢，并在同一任务里修正图谱。
- 领域语义冲突：第 4 层赢；若它与第 1、2 层冲突，则第 1、2 层赢，并修正本文档。
- 图谱提供姿态事实与数值；本文档提供状态语义与冲突裁决。两者冲突时，本文档的已批准决策优先，并回写图谱。
- 代码与本文档冲突：以本文档为准；不允许“代码已经这样了”作为理由。

变更协议：

- 新增/删除任何一个状态、姿态、事件、守卫、冷却或效果，必须同时更新：本文档、manifest、测试；涉及视觉的再更新图谱与 DESIGN。
- 不允许只改代码不改文档。
- 不确定的规则不许猜；在 §14 增加一条“待裁定”，并停止相关实现。
- P0 建立 ADR 012（领域分层，替代 009）与 ADR 013（HD 分层渲染/缩放，替代 008 的整数倍与 nearest 部分），之后以 ADR 记录例外。

## 2. 范围与非目标

### 2.1 本契约覆盖

- 7 个桌面状态、5 个陪伴子状态。
- 12 个姿态、5 个行为桶、9 个环境微动效。
- 邀请、恢复、完成、稍后、暂停、安静时段、隐藏、拖动。
- 90 秒/30 分钟在场检测。
- 面板位置、拖动、贴边停靠、窗口层级、多屏恢复。
- 会话计时、每日陪伴时长、休息次数、持久化。
- 无障碍与减弱动态的语义。

### 2.2 明确不做

- 不做行为树、通用状态机库、事件总线、队列系统。
- 不做系统监控、清理、Todo、任务管理、聊天、LLM、数据库、云账号。
- 不做声音、触觉、多宠物、侧/背视图（V0）。
- 不新增 V0 设置项；“全屏显示”开关不在 V0。
- 不读键鼠内容、不截屏、不读 App 使用记录；只允许读本地空闲时长。
- 不引入任何第三方运行时依赖。

## 3. 四层模型

```
DesktopState / CompanionSubstate   正在发生什么（产品语义）
        ↓
PetSituation                       当前状态组合（唯一真值）
        ↓
PetPose                            此刻长什么样（12 选 1）
        ↓
BehaviorBucket + ClipID           运行时播哪个桶、哪个 clip
        ↑
AmbientEvent                       叠加在姿态上的小循环/瞬态
```

四条硬规则：

1. **状态 ≠ 姿态 ≠ clip ≠ 行为桶。** 一个行为桶可以承载多个 clip；一个姿态只对应一个 clip。
2. `BehaviorBucket` 只有 5 个：`idle`、`notifying`、`sleeping`、`walking`、`celebrating`。
3. 运行时键是 `behavior/clip`，例如 `idle/idle_sit`、`sleeping/doze_short`。只有 `behavior` 无法区分姿态。
4. 场景层只负责渲染；它不读系统状态、不决定优先级、不拼 clip 名字。

## 4. 枚举清单

### 4.1 DesktopState（7）

| 优先级 | id | 姿态 | 进入条件 | 退出/冷却 |
|---|---|---|---|---|
| 1 | `dragging` | `look` | 指针按下并移动超过 4 px | 释放后 600 ms 重算 |
| 2 | `hidden` | 无 | 菜单/设置隐藏 | 只能由用户恢复 |
| 3 | `quiet` | `sleep` | 本地时间落在安静时段 | 时段结束立即退出 |
| 4 | `paused` | `sit` | 用户暂停 | 60 分钟或用户恢复 |
| 5 | `snoozed` | `sit` | 邀请卡点“稍后提醒” | 10 分钟或会话结束 |
| 6 | `companion` | `look` | 用户开始陪伴 | 用户结束会话 |
| 7 | `alone` | `sit` | 兜底 | 被更高优先级覆盖 |

优先级只决定**姿态与可见元素**；低优先级状态的计时、计数、会话不被销毁。

### 4.2 CompanionSubstate（5）

仅在 `DesktopState == companion` 时有意义。

| id | 姿态 | 进入条件 | 退出 |
|---|---|---|---|
| `idle` | `look` | 会话进行中，未到邀请窗口 | 到点进入 `approach` |
| `approach` | `look` | 距邀请还有 5 分钟 | 到点进入 `invite` |
| `invite` | `sign` | 邀请到点 | 接受→`recover`；稍后→`snoozed`；暂停→`paused`；关闭→`idle` |
| `recover` | `stretch` | 用户接受邀请 | 30 秒结束或“先跳过” |
| `complete` | `happy` | 恢复完成 | 2.6 秒后回当前桌面姿态 |

### 4.3 PetPose（12）

| pose | clip id | behavior | 循环 | 说明 |
|---|---|---|---|---|
| `sit` | `idle_sit` | `idle` | 是 | 兜底姿态 |
| `look` | `idle_look` | `idle` | 是 | 陪伴/拖动 |
| `sign` | `notify_sign` | `notifying` | 否 | 一次性，停最后一帧 |
| `stretch` | `recover_stretch` | `idle` | 是 | 恢复中 |
| `happy` | `complete_happy` | `celebrating` | 否 | 2.6 秒 |
| `sleep` | `sleep_curl` | `sleeping` | 是 | 安静时段 |
| `groom` | `idle_groom` | `idle` | 否 | 环境瞬态 |
| `yawn` | `idle_yawn` | `idle` | 否 | 环境瞬态 |
| `doze` | `doze_short` | `sleeping` | 是 | 浅睡 |
| `peek` | `peek_edge` | `idle` | 是 | 贴边探头 |
| `step` | `walk_step` | `walking` | 否 | 走两步 |
| `carry` | `idle_carry` | `idle` | 是 | 回窝带叶子 |

clip id 一经交付不再改名。未知 clip → `idle/idle_sit`，记一次日志，不崩溃。

### 4.4 AmbientEvent（9）

| id | 类型 | 关键参数 | 允许条件摘要 |
|---|---|---|---|
| `breathe` | 持续 | 4.2–6.0 s，基准 4.8 s，睡眠 6.0 s，缩放 1.012 | 按图谱第 12 章矩阵 |
| `blink` | 瞬态 | 2.5–6 s 随机，180 ms，3 帧 | `sit`/`look`/`carry`；`happy`/`yawn`/`sleep` 抑制 |
| `ear` | 瞬态 | 12–35 s，−7°→4°，240 ms | 按图谱第 12 章矩阵 |
| `tail` | 持续 | ±8°，与呼吸同拍，绕尾根旋转 | 按图谱第 12 章矩阵 |
| `shift` | 持续 | 6–9 s，±2 px，0.5°，800 ms | 按图谱第 12 章矩阵 |
| `groom` | 瞬态 | 3.8 s，3 次 | 仅 `sit`，非邀请/恢复 |
| `yawn` | 瞬态 | 1.8 s | 离开 ≥30 分钟或刚醒；非邀请/恢复 |
| `step` | 瞬态 | 2.4 s，移动 40–120 pt | 仅独自/暂停/稍后；非贴边/隐藏 |
| `peek` | 持续 | 3.6 s，单次 4 px | 仅贴边停靠 |

完整的 12 姿态 × 9 事件矩阵以图谱第 12 章为准。实现必须把矩阵写成数据（manifest 或 `AmbientMatrix`），不允许散落在 if/switch 里。

## 5. 状态机

### 5.1 事件

| 分组 | 事件 |
|---|---|
| 时间 | `tick(now)`、`invitationDue`、`approachStarted`、`snoozeExpired`、`pauseExpired`、`recoveryFinished`、`completeFinished` |
| 会话 | `sessionStart`、`sessionEnd` |
| 邀请 | `inviteAccepted`、`inviteSnoozed`、`invitePaused`、`inviteDismissed`、`recoverySkipped` |
| 指针 | `dragBegan`、`dragEnded`、`menuOpened`、`menuClosed`、`hoverBegan`、`hoverEnded` |
| 可见性 | `hideRequested`、`showRequested` |
| 系统 | `quietWindowChanged(Bool)`、`systemSleep`、`systemWake`、`screenLocked`、`screenUnlocked`、`displayChanged`、`lowPowerChanged(Bool)`、`reduceMotionChanged(Bool)` |
| 在场 | `presenceIdle90`、`presenceAway30`、`presenceReturned` |
| 环境 | 由 `AmbientScheduler` / `PetRuntime` 处理，不进入 reducer；`presenceReturned` 触发的 yawn 除外 |

### 5.2 效果

`PetStateMachine` 不直接操作 UI，只返回效果：

| 效果 | 执行者 |
|---|---|
| `schedule(deadline, event)` / `cancel(event)` | Coordinator |
| `play(pose)` / `playAmbient(event)` / `stopAmbient` | PetRuntime |
| `showInviteCard` / `dismissInviteCard` | PanelCoordinator |
| `startRecovery` / `finishRecovery` / `skipRecovery` | PanelCoordinator |
| `setHidden(Bool)` / `setDocked(Bool)` | PetPanelController |
| `persist(PetPersistedState)` | PetSessionStore |
| `updateChip` / `updateMenu` | PanelCoordinator |
| `addLeaf` / `incrementBreak` | CompanionStore |
| `log(event)` | Logger |

### 5.3 Reducer 契约

```
reduce(situation: PetSituation, event: PetEvent, now: Date) -> (PetSituation, [PetEffect])
```

要求：

- 纯函数：不读 `Date()`、不写 UserDefaults、不碰 UI。
- 幂等：同一事件重复投递不产生第二种结果。
- 计时用“截止时间”而不是累加 tick；`tick` 只负责触发到期事件。
- 每个事件最多产生一个姿态变化；不允许在一个事件里连续播三个姿态。
- 任何未处理事件都返回原状态并记录一次 debug 日志。

### 5.4 桌面状态转移

| 事件 | 目标 |
|---|---|
| `sessionStart` | `companion`，子态 `idle` |
| `sessionEnd` | `alone`；关闭邀请卡/恢复面板 |
| `inviteSnoozed` | `snoozed`；会话保留；10 分钟后重算 |
| `invitePaused` | `paused`；会话保留；60 分钟后重算 |
| `pauseExpired` | 若会话仍在→`companion`；否则 `alone` |
| `snoozeExpired` | 若会话仍在→`companion` 并立即评估邀请（跳过 `approach`）；否则 `alone` |
| `quietWindowChanged(true)` | `quiet`；关闭邀请卡；恢复倒计时允许走完 |
| `quietWindowChanged(false)` | 会话在→`companion`；否则 `alone` |
| `screenLocked` | 冻结计时与动画；状态不变 |
| `screenUnlocked` | 恢复计时；2 秒内不触发瞬态 |
| `hideRequested` | `hidden`；保留会话与计时 |
| `showRequested` | 重算：quiet > paused > snoozed > companion > alone |
| `dragBegan` | `dragging`；暂停环境瞬态 |
| `dragEnded` | 600 ms 后重算 |
| `systemSleep` | 冻结所有计时与动画 |
| `systemWake` | 恢复计时；2 秒内不触发瞬态 |

`pauseExpired` / `snoozeExpired` 到期后立即重排邀请：若 `nextDue` 已过且守卫通过，直接进入 `invite`（不补 `approach`）。

### 5.5 陪伴流程

```
idle --(距邀请 5 分钟)--> approach
approach --(到点)--> invite
invite --接受--> recover --30 秒--> complete --2.6 秒--> idle
invite --稍后--> snoozed --10 分钟--> idle（一次重试，见 §6.3）
invite --暂停--> paused --60 分钟--> idle
invite --关闭--> idle（45 分钟冷却）
recover --先跳过--> idle（不扣次数）
```

邀请到点的计算：

```
effectiveGap = max(45 分钟, rhythmMinutes)   // rhythmMinutes ∈ {45, 60, 90}
firstDue = sessionStart + effectiveGap
nextDue  = lastInvitationClosedAt + effectiveGap
```

`lastInvitationClosedAt` 是全局值，不随新会话重置。

### 5.6 冲突裁决

与图谱第 14 章一致，另加本文档的裁定：

| 组合 | 结果 |
|---|---|
| 拖动 × 任何 | 拖动赢；姿态 `look`；不弹卡；环境瞬态停 |
| 隐藏 × 任何 | 隐藏赢；不渲染；会话与计时继续 |
| 安静 × 暂停/稍后 | 安静赢；姿态 `sleep`；计时继续 |
| 安静 × 恢复中 | 恢复倒计时允许走完；期间 `stretch`；完成后再 `sleep` |
| 安静 × 完成动画 | 2.6 秒 `happy` 允许走完，再 `sleep` |
| 安静 × 邀请卡已开 | 关闭邀请卡，无惩罚，`sleep` |
| 暂停 × 稍后 | 暂停赢；稍后标记保留 |
| 暂停 × 会话 | 会话继续；专注时间继续累计 |
| 隐藏 × 会话 | 会话继续；不补发邀请 |
| 拖动 × 邀请 | 邀请卡不弹出；释放后重算 |
| 会话结束 × 恢复中 | 关闭恢复面板；不计数；回 `sit` |
| 系统睡眠 × 拖动 | 睡眠赢；释放后按静止位置恢复 |

硬互斥：

- 同一时刻只有一张邀请卡、一个恢复面板。
- 同一时刻只有一个姿态、一个主 clip。
- `sign`、`stretch`、`happy` 期间不叠加环境瞬态。
- `groom`、`yawn`、`step` 三选一，不并存。
- 贴边停靠 ≠ 隐藏；停靠时仍呼吸。
- 邀请/恢复/拖动/菜单期间不播 `step`、`groom`、`yawn`。

### 5.7 邀请守卫

| 守卫 | 规则 |
|---|---|
| 会话 | 必须 `companion` 且子态允许 |
| 安静 | 安静时段内一律不邀请 |
| 暂停/稍后 | 到期前不邀请 |
| 隐藏/拖动/菜单 | 不邀请 |
| 间隔 | `effectiveGap` 内不重复邀请 |
| 卡片 | 同一时刻只有一张 |
| 恢复 | 恢复未结束时不再邀请 |
| 稍后 | 每会话最多一次 |

## 6. 计时与持久化

### 6.1 时钟

- 所有时间通过可注入的 `Clock.now` 获取，测试用固定时钟。
- 使用 `Calendar.autoupdatingCurrent` 做本地日界与安静时段判断。
- 计时保存为“截止时间”，不保存“剩余秒数”。
- 系统时钟跳变：按新的 `now` 重算；不补发错过的邀请，不补播动画。
- 跨午夜：安静时段按每时刻重新判断；每日统计按本地日界切分。

### 6.2 持久化键

| 键 | 类型 | 说明 |
|---|---|---|
| `pauseUntil` | Date? | 暂停截止 |
| `snoozeUntil` | Date? | 稍后截止 |
| `lastInvitationClosedAt` | Date? | 上次邀请关闭/完成时间（全局） |
| `todayKey` | String | `yyyy-MM-dd` 本地日 |
| `todayCompanionshipSeconds` | Int | 当日陪伴时长 |
| `todayBreaks` | Int | 当日休息次数 |
| `weekStartKey` | String | 本周周一的 `yyyy-MM-dd` |
| `weekBreakCounts` | [Int] | 7 天休息次数 |
| `quietStartMinutes` | Int | 默认 1320（22:00） |
| `quietEndMinutes` | Int | 默认 480（08:00） |
| `rhythmMinutes` | Int | 45 / 60 / 90 |
| `showsDesktopPet` | Bool | 隐藏状态 |

规则：

- 会话在 App 退出时结束；`sessionStartedAt`、`snoozeUsedThisSession` 只存在内存。
- 暂停、安静、上次邀请关闭时间、每日统计跨启动保留。
- 完成一次休息：`todayBreaks +1`、`weekBreakCounts` 当日 +1、加一片叶子。
- 跳过/关闭：不扣次数、不扣叶子、不惩罚。
- 会话进行中每分钟把当日陪伴秒数写入 store；会话结束/退出时再写一次，避免崩溃丢失整天数据。
- 跨午夜会话：当日陪伴时长按 `[sessionStartedAt, min(now, 当日结束)]` 与当日的交集计算，不靠午夜定时器累加。
- 跨周：本地周一换周时把 `weekBreakCounts` 左移并清零新一天；`weekStartKey` 同步更新。

### 6.3 “稍后提醒”的裁定

这是本轮已批准的例外，优先于 DESIGN 原文“45 分钟内不会第二次邀请”：

- 用户点“稍后提醒” → `snoozeUntil = now + 10 分钟`，`snoozeUsedThisSession = true`。
- 到点后允许**一次**邀请，绕过 45 分钟冷却。
- 这次重试被关闭/完成/暂停/结束后，`lastInvitationClosedAt = now`，重新按 `effectiveGap` 计算。
- 重试到点时若会话已结束、处于安静时段、暂停、隐藏或拖动，直接丢弃，不排队；清除稍后标记。
- 每会话最多一次；第二次点“稍后”不再延长，只关闭卡片并回到 `idle`。

DESIGN §13.1 的相应措辞在实现时同步修正。

## 7. 在场与空闲

| 规则 | 值 |
|---|---|
| 进入 doze | 无指针/键盘活动满 90 秒 |
| 长离开 | 满 30 分钟记为 `wasAwayLong` |
| 回到电脑前 | 任意输入；先 `yawn` 1.8 秒，再回当前桌面姿态 |
| 唤醒保护 | 系统唤醒/解锁后 2 秒内不触发任何瞬态 |
| 允许 doze 的状态 | `alone`、`paused`、`snoozed` |
| 禁止 doze 的状态 | `companion`、`dragging`、`hidden`、邀请卡/恢复面板打开、菜单打开 |
| 数据源 | 系统空闲时长（`CGEventSource.secondsSinceLastEventType`） |
| 隐私 | 只读时长，不读内容；不申请权限；不可用时关闭 doze |

若系统空闲时长不可用：`PresencePolicy` 返回 `unavailable`，doze/yawn 自动停用，其余状态不受影响。

## 8. 微动效并发

- 同一时刻最多 2 个：1 个持续（呼吸/尾巴/重心/探头）+ 1 个瞬态（眨眼/耳抖/理毛/哈欠/走两步）。
- 任意两个环境事件间隔 ≥ 12 秒。
- 同一瞬态 60 秒内不重复第三次。
- 进入 `sign`、`stretch`、`happy`、拖动、隐藏、邀请、恢复时，取消排队中的瞬态；正在播的瞬态在 240 ms 内收尾。
- 减弱动态：所有循环与瞬态停止，使用每个姿态的静态帧；姿态切换时长视为 0。
- 低电量：环境事件间隔 ×1.5；状态机与冷却不变。
- 锁屏/系统睡眠/隐藏：冻结；恢复后从当前帧继续，不从头播。

## 9. 渲染层契约

### 9.1 图层顺序

```
shadow → tail → body → ears → backArm → face → frontArm → prop
```

`emotion` 在 V0 烘焙进 `face`，不单独渲染。若后续需要动态腮红/眉形，再新增层并走产品决定。

### 9.2 画布、锚点与轴心

| 项 | 值 |
|---|---|
| 画布 | 320 × 400 |
| 锚点 | (160, 388) |
| 呼吸/重心原点 | (160, 340) |
| 头颈原点 | (160, 240) |
| 耳根 | (160, 150) |
| 尾根 | (250, 286) |
| 肩点 | (230, 254)；左肩镜像 |
| 尺寸档 | 132×165 / 168×210（默认）/ 216×270 |
| 导出 | PNG 1x/2x/3x，透明背景，8 px 安全边距 |
| 过滤 | 线性过滤；不使用 nearest |

320×400 → 168×210 是 0.525 的非整数缩放，旧 ADR 008 的整数倍/nearest 规则对 HD 资产退役，P0 以 ADR 013 正式替代。

### 9.3 姿态组合

每个姿态在 manifest 中声明：

```json
{
  "id": "sit",
  "clipId": "idle_sit",
  "behavior": "idle",
  "loop": true,
  "holdLastFrame": false,
  "layers": {
    "body": "body_default",
    "ears": "ears_default",
    "tail": "tail_default",
    "backArm": "arm_back_rest",
    "face": "face_calm",
    "frontArm": "arm_front_rest",
    "prop": null,
    "shadow": "shadow_default"
  },
  "transform": { "rotate": 0, "pivot": [160, 340], "translateX": 0, "translateY": 0 }
}
```

- `sleep` 与 `peek` 允许使用专用 body/face；其余姿态复用通用层。
- 旋转轴心由 `render.poseLayers.<id>.pivot` 声明（SVG 坐标），未声明时使用呼吸原点 (160, 340)；数值必须与图谱 symbol 的 `rotate` 轴心一致。
- 具体组合由图谱 symbol 在 P0 生成，不与图谱冲突。
- 眨眼只替换 `face` 为 `face_<id>_blink2/3`；`happy`/`yawn`/`sleep` 不眨眼。
- 道具跟手；阴影位置不随姿态变换。
- 姿态之间不交叉淡入；在动作低谷硬切，切换点由 `PoseTransitionCoordinator` 选择。

### 9.4 回退

| 情况 | 行为 |
|---|---|
| pose 缺 clip | `idle/idle_sit` |
| 缺贴图 | `pose_sit`，日志一次 |
| manifest 版本不认识 | 拒绝加载，显示 `pose_sit` 占位，日志 |
| 未知环境事件 | 忽略，不改姿态 |

## 10. 面板与交互契约

| 项 | 规则 |
|---|---|
| 面板 | 168×210 默认；三档内部支持；不新增尺寸设置 |
| 初始位置 | 主屏右下，距右 40，距底 92 |
| 拖动夹取 | 距可见区 8 px；不压菜单栏/Dock |
| 拖动 | 4 px 阈值；0.98 缩放；释放 180 ms 回 1.0 |
| 贴边 | 左/右 24 pt 触发；600 ms 后收进 40%，最小 24 pt；热区 24 pt；180 ms 滑回 |
| 停靠 | 停靠 ≠ 隐藏；仍呼吸；邀请先滑出；拖动可离边 |
| 窗口 | `.floating`，低于菜单栏/Dock；默认不进全屏；只渲染一份 |
| 多屏 | 屏 UUID + 归一化位置；断屏回主屏右下 |
| 菜单 | 3 项 + 分隔；160 ms；Esc/点外关闭；悬停 600 ms 提示 |
| 键盘 | 方向键 1 px，Shift 10 px；回车开菜单；Esc 收起 |
| 命中区 | 最小 44×44；透明区不拦截 |
| 焦点环 | 鼠尾草；不裁切 |

Mission Control 用 `NSWorkspace` 空间切换 + App 失活做 best-effort 冻结；不碰私有 API。无法可靠检测时，不新增假状态。

## 11. 不变量

任何实现都必须满足：

1. 同一时刻只有一个 `PetSituation`、一个姿态、一个主 clip。
2. 状态只能通过事件变化；视图不能直接改状态。
3. `JoeyDesktopScene` / `JoeyCharacterNode` 不读系统状态、不决定优先级、不拼 pose 名。
4. `AmbientBehaviorScheduler` 不直接操作 `SKScene`。
5. 高优先级状态只覆盖姿态与可见元素，不销毁低优先级的计时、计数、会话。
6. 环境事件与邀请不排队；不满足条件直接丢弃。
7. 同一时刻最多一张邀请卡、一个恢复面板、一次邀请。
8. 隐藏 ≠ 停靠；隐藏只能由用户恢复；停靠仍呼吸。
9. 会话只能由用户主动开始；不能从键鼠、App 使用或“看起来在忙”推断。
10. 休息完成只能由用户确认；不能伪造检测。
11. 跳过/关闭/稍后不扣次数、不扣叶子、不惩罚。
12. manifest 是数值唯一来源；视图不写死时长、尺寸、间隔。
13. clip id 稳定；未知回退 `idle/idle_sit`。
14. 不新增 V0 设置、界面或依赖，除非有明确产品决定。
15. 安静时段不邀请；恢复倒计时允许走完。
16. 任何新规则必须先写进本文档，再写代码。

## 12. 测试矩阵

### 12.1 领域

- 7 个桌面状态 × 所有事件的目标状态。
- 45/60/90 分钟节奏、45 分钟下限、首次邀请、跨会话 `lastInvitationClosedAt`。
- 稍后的一次重试、绕过 45 分钟、重试被阻止时丢弃。
- 暂停 60 分钟、暂停中会话继续、暂停到期回陪伴。
- 安静跨午夜、安静×恢复、安静×完成、安静×邀请卡。
- 隐藏×会话、隐藏×安静、隐藏恢复。
- 拖动×邀请、拖动×瞬态。
- 系统睡眠/唤醒、锁屏/解锁、时钟跳变、跨午夜统计。
- 同一事件重复投递幂等。

### 12.2 运行时

- 12 姿态 × 9 环境事件的矩阵门控。
- 12 秒间隔、同瞬态 60 秒、三选一互斥。
- `sign` 停最后一帧、`happy` 2.6 秒、一次性 clip 收尾。
- 同 clip 不重启；姿态低谷硬切；阴影不动。
- reduce motion 静态；低电量 ×1.5。
- 缺图/clip 回退。

### 12.3 几何

- 168×210、132×165、216×270 的缩放与锚点。
- 初始位置、8 px 夹取、多屏恢复、断屏回退。
- 贴边 24 pt、40%/24 pt、热区 24 pt、180 ms。
- 拖动阈值与点击/拖动区分。

### 12.4 视觉与无障碍

- 12 姿态 × 3 尺寸 × 明/暗。
- 200% 下无像素台阶、无 1 px 白缝。
- 8 张脸 × 眨眼三帧；抑制姿态。
- VoiceOver 每个状态/姿态的标签；键盘全流程；焦点环不被裁切。

### 12.5 命令

```bash
cd macos
xcodebuild -project JoeyPet.xcodeproj -scheme JoeyPet -destination 'platform=macOS' build
xcodebuild -project JoeyPet.xcodeproj -scheme JoeyPet -destination 'platform=macOS' test
```

## 13. 实施顺序

| PR | 内容 | 约束 |
|---|---|---|
| 1 | P0 + P1：manifest、ADR 012/013、领域模型、reducer、测试 | 不改 UI，App 仍按旧路径运行 |
| 2 | P2：素材拆分、PNG、分层渲染、缩放 | 可用 Debug 预览 12 姿态 |
| 3 | P3：运行时、调度、在场检测、协调器 | 映射表唯一入口 |
| 4 | P4：面板几何、拖动、停靠、菜单、无障碍 | 不新增尺寸设置 |
| 5 | P5：会话反馈 UI、邀请卡、恢复面板、胶囊 | 复用 DESIGN §10.2/10.3 |
| 6 | P6：视觉/手动验收、文档、清理旧资产 | 全绿后收口 |

P1 与 P2 可并行；P3 必须等两者完成。每个 PR 保持可构建、可运行、可回滚。

## 14. 已批准决策

| id | 决策 | 理由 |
|---|---|---|
| D1 | 稍后提醒允许一次 10 分钟重试，绕过 45 分钟冷却；重试后重新起算 | “稍后 10 分钟”必须真实，且每会话仅一次 |
| D2 | V0 不新增“在全屏上显示”设置，默认不进全屏 | 控制在 V0 设置清单内，避免边缘场景扩范围 |
| D3 | 素材由开发期脚本从图谱 SVG 拆分并栅格化，运行时不依赖 Chrome/第三方 | 保持零运行时依赖 |
| D4 | 会话在 App 退出时结束；暂停、安静、上次邀请、每日统计持久化 | 简单、可预测、无幽灵会话 |
| D5 | Mission Control best-effort 冻结；emotion 烘焙进 face；V0 不做侧/背视图 | 不碰私有 API，不引入低收益复杂度 |

## 15. 待裁定 / 未来项

- “在全屏上显示”开关：若未来产品决定加入，需新增设置、权限说明与测试。
- emotion 独立层：若需要动态腮红/眉形，再新增层与参数。
- 侧/背视图：V0 不做；`step` 使用正面帧。
- 声音/触觉：V0 不做。
- 多宠物/多实例：V0 不做。

## 16. 变更记录

| 日期 | 变更 |
|---|---|
| 2026-11-23 | 初稿：四层模型、7 状态/5 子态/12 姿态/9 环境事件、冲突裁决、计时持久化、不变量、测试矩阵 |
| 2026-11-23 | PR1：ADR 012/013 建立；manifest 入库并补渲染层契约；领域模型、纯 reducer、持久化与 21 条测试落地 |
| 2026-11-23 | PR2：素材管线与分层渲染落地；46 组层/姿态资产 ×3 尺寸；`JoeyCharacterNode` 与 `-JoeyPetDebugPoses` 预览；修复耳朵/尾巴 pivot 图层初始隐藏的问题 |
| 2026-11-23 | PR3：`PetRuntime` 接入纯 reducer 与截止时间 tick；新增在场检测、系统睡眠/锁屏协调、可见性与节奏配置持久化；桌面宠物改用 `JoeyCharacterNode` 分层渲染，旧 `PetScene` 仅作回退 |
| 2026-11-23 | PR4：面板改为 168×210，初始位置 40/92 并保留 8 pt 拖动夹取；拖动阈值 4 pt、0.98 缩放与 `dragBegan/dragEnded` 接线；贴边 24 pt 停靠、600 ms 收起、40%/24 pt 露出与热区滑回；桌面菜单（结束陪伴/隐藏/暂停一小时）、键盘移动、悬停提示、VoiceOver 标签与鼠尾草焦点环 |
| 2026-11-23 | PR5：会话反馈 UI 落地；`SessionSurfacePresentation` 从 situation 派生胶囊/邀请卡/恢复面板/完成反馈，`SessionSurfacesController` 只渲染并回传用户意图；桌面 `陪伴中 · mm:ss` 胶囊、邀请卡（休息一下/稍后提醒/暂停一会儿）、真实 30 秒恢复环（好了/先跳过）与完成/稍后/暂停 toast；小窝主按钮接通开始/结束陪伴，`CompanionStatus` 同步主窗口状态 |
| 2026-11-23 | PR6：移除旧 spritesheet 管线与资产（`pet.json`、spritesheet、runtime/source 源图、旧 `.py` 生成脚本及各旧渲染类）；`PetRuntime` 只加载分层 `JoeyAssetPackage`，加载失败时使用 `EmptyPoseRenderer` 并记录日志；文档统一到 ADR 013 |
