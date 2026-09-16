# JoeyPet V1 Feature Specification

本文件描述产品行为，不描述 Swift 类型、文件名、函数或工程结构。每个开发任务必须引用一个或多个 Feature ID。

## F01 — Desktop Joey

### Purpose

让 Joey 成为产品的主要存在形式：平时在桌面安静地陪伴用户，必要时表达状态并提供入口。

### User Entry

应用启动后自动出现；用户也可以通过 Dock、Main Window 或系统中的应用切换回到 JoeyPet。

### User Flow

应用启动 → Joey 出现在安全的屏幕位置 → 播放 idle/ambient 动作 → 用户可以拖动、左键查看提示、右键打开菜单 → 状态变化时 Joey 以对应动作反应 → 状态解除后回到 ambient。

### States

- `idle`：默认安静状态。
- `ambient`：低频 blink、sleeping 或 walking。
- `reacting`：对系统状态显示 sweating、tired 或 carryingTrash。
- `interrupted`：系统警告打断 ambient movement 或 transient 行为。

### Product Rules

- Joey 是主要产品入口，不要求用户打开 Main Window 才能使用基本反馈。
- 窗口透明、无边框、可拖动；透明区域不应拦截鼠标。
- ambient movement 只做短距离、低频移动；walking 可以移动窗口，但不能频繁移动或造成失控感。
- 系统 warning/critical 可以打断 movement。
- Joey 的动作是对系统事实的角色化表达，不伪装成精确指标。

### Edge Cases

- 当前屏幕不可用、屏幕布局改变或恢复位置完全在屏幕外时，使用当前主屏的安全默认位置。
- 应用从睡眠唤醒后，停止中的 ambient 和传感应安全恢复，不重复创建多个循环。
- 用户拖动期间不能被 ambient movement 抢夺位置。

### Acceptance Criteria

- Given 应用启动，When 初始化完成，Then Joey 可见且位于当前可用屏幕的安全区域。
- Given 用户点击 Joey 的透明区域，When 鼠标落在角色外，Then 不触发 Joey 操作。
- Given 用户拖动 Joey 后松开，When 重新启动应用，Then Joey 回到上次用户拖动后保存的位置或安全恢复位置。
- Given ambient walking 正在进行，When 系统进入 warning/critical，Then movement 停止并显示系统状态反应。

## F02 — Ambient Behaviors

### Purpose

让 Joey 在没有需要用户处理的事情时保持有生命感，同时不变成持续动画或通知源。

### User Entry

应用运行且 Ambient Behaviors 开启、没有持续系统警告时自动发生。

### User Flow

Joey 回到 idle → 等待一个低频间隔 → 触发 blink、sleeping 或 walking → 短暂完成 → 回到当前持续状态。

### States

- `eligible`：系统状态为正常且设置开启。
- `waiting`：等待下一次 ambient 行为。
- `playing`：播放一个短暂动作。
- `paused`：系统状态、睡眠或设置变化导致暂停。

### Product Rules

- Ambient Behaviors 默认开启，用户可以关闭。
- 行为之间留出明显间隔；不使用高频轮询或连续移动。
- warning/critical 优先于 ambient；ambient 不排队等待补播。
- walking 是可见的短距离移动体验，不是自由漫游。
- ambient 行为结束后回到最新持续状态，而不是强制回到旧状态。

### Edge Cases

- 用户关闭设置时，未完成的 ambient 行为应停止或自然收束，并且不再触发新的行为。
- 睡眠时停止等待和播放；唤醒后只恢复一个调度周期。
- Joey 位于屏幕边缘时，walking 仍须留在可见区域内。

### Acceptance Criteria

- Given Ambient Behaviors 关闭，When Joey 处于正常状态，Then 不触发自动 blink、sleeping 或 walking。
- Given Ambient Behaviors 开启，When Joey 连续运行，Then ambient 行为之间有低频间隔且不会连续移动。
- Given ambient 行为正在播放，When 持续系统状态变为 warning/critical，Then 系统反应优先显示。

## F03 — System Status Reactions

### Purpose

用易理解的宠物状态表达三类语义化 Mac 状态，让用户不用打开专业监控工具也能察觉值得注意的变化。

### User Entry

由系统状态变化自动触发；Overview 和 Bubble 是辅助查看入口。

### User Flow

只读观察 → 归一化严重程度 → Joey 状态改变 → 显示对应动画和必要的 Bubble → 状态解除后回到 idle 或新的最高优先级状态。

### States

- `normal`：无需要行动的异常。
- `notice`：轻量提醒。
- `warning`：需要用户留意。
- `critical`：需要尽快查看。
- `unavailable`：某个状态暂时没有可用读数。

### Product Rules

- F03 只定义 Semantic System State → Joey Behavior，不负责把所有 Overview raw metrics 映射成宠物行为。
- V1 的正式 Joey reaction signals 是 Thermal、Memory Pressure、Storage。
- Thermal serious/critical → `sweating`。
- Memory warning/critical → `tired`。
- Storage low → `carryingTrash`。
- CPU Usage、Memory Usage、Network Activity 首先属于 Overview monitoring；本 Feature 不为它们新增 Pet behavior。
- UI severity 与 Joey severity 使用同一套 normal/notice/warning/critical 语义。
- 只表达压力等级或阈值状态，不把 CPU Usage 当作 CPU 温度，也不从 Thermal State 猜测温度。
- 更高严重程度和更高优先级状态可打断较低优先级反应；状态相同时不重启动画。

### Edge Cases

- 状态在阈值附近变化时，必须避免 Joey 在两个状态间快速闪烁。
- 多个状态同时存在时，页面分别展示三类状态，Joey 采用最高优先级反应。
- 状态读数不可用时，显示 Unavailable，不把缺失当作正常。

### Acceptance Criteria

- Given Thermal 为 serious 或 critical，When 状态稳定达到产品阈值，Then Joey 显示 sweating 且严重程度为 warning 或 critical。
- Given Memory Pressure 为 warning 或 critical，When 状态稳定达到产品阈值，Then Joey 显示 tired。
- Given Storage 进入 low，When 状态可用，Then Joey 显示 carryingTrash 并提供 Cleanup 入口。
- Given 当前状态未改变，When 传感再次报告同一状态，Then Joey 不从第一帧重新开始动画。

## F04 — Status Bubble

### Purpose

在 Joey 附近用一两行话解释当前反应，并在确实有帮助时给出一个主要动作。

### User Entry

系统状态变化时主动出现；用户左键 Joey 时主动查看；Cleanup 完成、失败或没有可清理内容时出现反馈。

### User Flow

Bubble 出现 → 用户阅读短消息 → 可选地点击一个动作 → 打开相关页面或开始已定义的操作 → Bubble 消失；没有动作时短暂自动消失。

### States

- `informational`：无操作，只说明 Joey 的状态。
- `action`：包含一个主要动作，最多一个次要查看动作。
- `success`：操作完成。
- `warning`：操作部分失败或状态需要留意。
- `dismissed`：用户操作或超时后消失。

### Product Rules

- Bubble 不是聊天 UI、通知中心或持久历史。
- 文案短、一条信息一个重点，通常一到两行。
- Proactive Bubbles 可以关闭；用户主动点击 Joey 产生的查看反馈仍可工作。
- 同一 warning 不得重复刷屏；只有状态重新进入或有新结果时才再次提示。
- Action Bubble 最多提供一个主要动作，次要动作只能是查看相关详情。

### Edge Cases

- 新 Bubble 出现时替换旧 Bubble，不叠加多个 Bubble。
- Bubble 位于屏幕边缘时不能完全离开可见区域。
- Cleanup 正在执行时，不重复提供会再次启动 Cleanup 的动作。

### Acceptance Criteria

- Given Proactive Bubbles 关闭，When 系统状态变化，Then 不出现主动状态 Bubble。
- Given 用户左键 Joey，When 当前状态可用，Then 出现一条短信息；严重状态提供查看入口。
- Given 同一 warning 尚未解除，When 传感重复报告该 warning，Then 不重复弹出相同主动 Bubble。
- Given Cleanup 完成，When Bubble 出现，Then 明确说明已移入废纸篓的结果，并可打开 Cleanup 查看详情。

## F05 — Joey Context Menu

### Purpose

提供稳定、可发现的日常操作入口。

### User Entry

用户右键 Joey。

### User Flow

右键 Joey → 显示菜单 → 选择一个入口 → 执行、打开对应页面或退出应用 → 菜单关闭。

### States

- `available`：入口可用。
- `disabled`：扫描或清理进行中，不能重复启动同一类操作。
- `dismissed`：点击外部或完成选择后关闭。

### Product Rules

菜单顺序固定为：

1. 打开 JoeyPet
2. 快速清理
3. 扫描并查看
4. 设置
5. 分隔线
6. 退出 JoeyPet

Quick Clean 和 Scan and View 在对应操作忙碌时禁用，不能制造并发或重复任务。Quit 始终表达真正退出应用。

### Edge Cases

- Cleanup scanning/cleaning 时，菜单仍可打开，忙碌操作显示禁用而不是失效无反馈。
- Main Window 已打开时，打开 JoeyPet 应复用同一个窗口并带到前台。
- 用户取消确认对话框时，菜单操作不应执行文件变化。

### Acceptance Criteria

- Given 用户右键 Joey，When 菜单显示，Then 入口顺序和分组符合上述定义。
- Given Cleanup 正在 scanning 或 cleaning，When 菜单显示，Then Quick Clean 与 Scan and View 不可重复触发。
- Given 用户选择退出，When 应用确认退出，Then Joey、Bubble、传感与 Cleanup 任务停止。

## F06 — Main Window

### Purpose

为状态查看、Cleanup 和正式设置提供一个紧凑、可理解的原生 macOS 窗口。

### User Entry

右键菜单、Bubble 动作、Dock 或应用激活。

### User Flow

打开 Main Window → 默认进入 Overview 或指定页面 → 用户在三个一级页面间切换 → 完成查看或操作 → 关闭窗口，Joey 仍在桌面运行。

### States

- `closed`：窗口不存在或已关闭。
- `open`：窗口可见。
- `active`：窗口在前台并显示用户选中的页面。
- `reused`：再次打开时复用窗口而非创建重复窗口。

### Product Rules

正式 IA 只有：`JoeyPet → Overview / Cleanup / Settings`。

不增加 Dashboard、Activity、History、Pet、Tools、Monitor 或 About 一级页面。主窗口承载理解和操作，不承载高密度监控。

### Edge Cases

- 重复打开时复用现有窗口并切换到请求的页面。
- 关闭窗口不是退出应用；只有 Quit 才终止 JoeyPet。
- 页面数据加载或 Cleanup 忙碌时，窗口仍可关闭和重新打开而不丢失合法的运行状态。

### Acceptance Criteria

- Given 用户打开 JoeyPet，When Main Window 显示，Then 只看到 Overview、Cleanup、Settings 三个一级入口。
- Given Main Window 已打开，When 用户再次从菜单打开某页面，Then 复用窗口并显示目标页面。
- Given 用户关闭 Main Window，When 关闭完成，Then Joey 仍可见且继续运行。

## F07 — Overview

### Purpose

让用户在几秒内知道“我的 Mac 现在运行得怎么样”，同时保留 JoeyPet 的轻量、安静和非管理定位。

### User Entry

Main Window 默认页面、Bubble 的查看动作、Context Menu 的打开 JoeyPet。

### User Flow

打开 Overview → 先看 Overall Mac Status → 查看 CPU、Memory、Network、Storage、Thermal 的当前状态 → 在 CPU/Memory/Network 上查看短时趋势（适用时）→ 查看 Cleanup summary → 需要时进入 Cleanup。

### Metrics

| Metric | V1 product target | Display intent |
|---|---|---|
| CPU Usage | Required | 当前使用情况与短时趋势，帮助理解 Mac 是否繁忙 |
| Memory Usage | Required | used/total 或同等清晰的当前使用表达 |
| Memory Pressure | Required | 与 Memory Usage 分开，表达系统健康压力 |
| Storage Usage | Required | used/free/total 与存储健康状态 |
| Network Activity | Required | Download、Upload 与短时趋势 |
| Thermal State | Required | nominal/fair/serious/critical；不是 CPU 温度 |
| Fan RPM | Conditional | 可靠、稳定、权限合理时显示，否则不占用主层级 |
| Exact Temperature | Conditional | 可靠时显示明确温度，否则显示 Thermal State；绝不猜测 |

### Recent Trends

趋势只关注当前运行 session 的短时间变化。CPU、Memory、Network 可以使用小型 trend line、sparkline 或 usage indicator；不做 7/30 天历史、报表、时间范围选择器、数据库或跨重启指标持久化。

### Overall Status

Overall Mac Status 是首要信息，使用与 Joey 共享的 `normal`、`notice`、`warning`、`critical` 语义。它是系统事实的汇总表达，不建立第二套 severity model，也不把 CPU 高使用量自动转换成新的 Pet behavior。

### States

- `loading`：一个或多个核心指标尚未就绪。
- `normal`：当前没有需要行动的系统状态。
- `warning`：至少一项语义状态需要留意。
- `critical`：至少一项语义状态严重。
- `unavailable`：某项指标无法可靠取得；其他可用指标仍可显示。

### Product Rules

- Overview 是 Lightweight Mac System Overview，不是 Activity Monitor、iStat Menus 或系统管理工具。
- 信息层级固定为：Overall Mac Status → 当前 Metrics 与短时趋势 → Cleanup summary。
- 不显示 process list、network process list、packet inspector、connection manager 或 optimizer action。
- Memory Usage 与 Memory Pressure 必须分别呈现；Storage 保留现有 used/free/total 语义。
- Fan RPM 与 Exact Temperature 只有技术验证通过才进入产品；它们不是 V1 Done blocker。
- Cleanup summary 是摘要和入口，不变成 History 页面。

### Edge Cases

- CPU、Memory 或 Network 尚未可用时，显示具体 unavailable 状态，不把缺失当作 0 或 normal。
- Fan RPM 或 Exact Temperature 不可用时，继续显示 Thermal State，不展示推算或伪造的 °C/RPM。
- 只有一项 warning/critical 时，Overall Mac Status 不能被正常项稀释。
- 没有 Cleanup 扫描记录时，显示简短的未扫描状态和 Scan and View 入口。
- 应用重启后短时趋势可以从空状态重新开始，不显示虚构的历史。

### Acceptance Criteria

- Given 用户打开 Overview，When 核心数据可用，Then 第一眼能看到 Overall Mac Status，并能找到 CPU、Memory、Memory Pressure、Storage、Network 和 Thermal。
- Given CPU Usage 可用，When Overview 显示，Then 用户能看到当前 CPU 使用情况，并在数据足够时看到短时趋势。
- Given Memory Usage 可用，When Overview 显示，Then 当前使用情况与 Memory Pressure 分开呈现。
- Given Storage 数据可用，When Overview 显示，Then 用户能看到 used、free、total 和存储健康状态。
- Given Network Activity 可用，When Overview 显示，Then 用户能看到 Download、Upload，并在适合时看到短时趋势。
- Given Thermal State 为 serious/critical，When Overview 显示，Then 使用共享 severity 语义，不显示猜测的 CPU 温度。
- Given Fan RPM 或 Exact Temperature 不可用，When Overview 显示，Then 显示 unavailable 或 Thermal fallback，不伪造数值。
- Given 用户打开 Overview，When 页面提供操作，Then 不出现 process list、kill process 或 system optimization action。

## F08 — Cleanup Scan

### Purpose

在明确、有限的范围内只读发现可处理内容，为用户做决定提供事实和原因。

### User Entry

Cleanup 页面 Scan、Overview 的 Scan and View、右键菜单的 Scan and View。

### User Flow

用户触发 Scan → 显示扫描中 → 读取三个 allowlisted roots → 按 Safe/Review 和类别整理 → 显示结果或无结果状态。

### States

- `initial`：尚未扫描。
- `scanning`：扫描进行中。
- `results`：找到候选。
- `no-cleanup-needed`：没有候选。
- `error`：扫描无法完成或无法读取部分范围。

### Product Rules

- 扫描是只读的，不在扫描阶段改变文件。
- V1 只扫描 Xcode DerivedData、Old User Logs、User Application Caches。
- 不递归进入未允许的系统范围，不跟随符号链接，不扩大到 Desktop、Downloads、Documents 等目录。
- 每个候选都显示名称、大小或估算标记、所属类别和简短原因。
- 用户不需要理解内部 risk enum；界面用自然语言解释“可快速处理”和“建议先查看”。

### Edge Cases

- 根目录不存在或无权限时，显示可继续的部分结果和简短原因；不能把权限失败当作没有内容。
- 文件在扫描期间消失时，结果应允许刷新，执行阶段逐项报告失败。
- 目录大小只是估算时必须标明，不显示为精确值。

### Acceptance Criteria

- Given 用户点击 Scan，When 扫描未完成，Then 显示扫描状态且不能重复触发扫描。
- Given 扫描完成，When 有候选，Then 所有候选来自三个 V1 roots，并显示处理建议与原因。
- Given 扫描完成，When 没有候选，Then 显示“没有需要清理的内容”类空状态和再次扫描入口。
- Given 扫描范围部分不可读，When 结果显示，Then 明确提示受影响范围，不假报完整扫描。

## F09 — Quick Clean

### Purpose

让用户用一次明确操作处理 V1 中可安全处理的候选。

### User Entry

Cleanup 页面 Quick Clean、Context Menu、Storage Bubble 的主要动作。

### User Flow

用户明确触发 Quick Clean → 重新扫描当前允许范围 → 仅取 Safe 候选 → 执行已批准的 Quick Clean → 将项目移到 Trash → 显示结果。

### States

- `ready`：可以触发。
- `scanning`：正在重新确认候选。
- `cleaning`：正在移入 Trash。
- `empty`：没有 Safe 候选。
- `completed`：全部成功。
- `partial-failure`：部分成功。
- `error`：全部失败或无法继续。

### Product Rules

- Quick Clean 只处理 Safe，永远不包含 Review。
- Quick Clean 由用户明确触发；不能由传感器自动执行。
- 执行结果是 Move to Trash，不是永久删除，也不自动清空废纸篓。
- 执行前后不能复用过期的候选路径；应以当前扫描结果为依据。

### Edge Cases

- 没有 Safe 候选时，不进入清理状态，说明暂时无需处理。
- 某项目在执行前消失或权限不足时，其他项目仍可继续，结果必须逐项报告。
- 清理期间再次触发 Quick Clean 或 Scan and View 时，操作不可用。

### Acceptance Criteria

- Given 扫描结果含 Safe 与 Review，When 用户点击 Quick Clean，Then 只执行 Safe 项目。
- Given Quick Clean 已触发，When 项目被处理，Then 项目进入 macOS Trash，且 Trash 不被自动清空。
- Given 没有 Safe 项目，When 用户点击 Quick Clean，Then 显示无可快速处理内容，不改变任何文件。

## F10 — Review Cleanup

### Purpose

让用户在处理不应默认快速处理的内容前，看到原因并做出明确选择。

### User Entry

Cleanup 结果中的 Review 区域。

### User Flow

查看 Review 候选 → 阅读名称、大小、类别、原因 → 选择项目 → 点击 Clean Selected → 确认 → 将选中项目移到 Trash → 查看逐项结果。

### States

- `available`：存在待查看项目。
- `selected`：至少选择一个项目。
- `confirming`：等待用户确认。
- `cleaning`：执行已确认选择。
- `empty`：没有 Review 项目。
- `failed`：部分或全部项目失败。

### Product Rules

- Review 项目不能被 Quick Clean 带走。
- 必须是用户明确选择并确认的项目才可执行。
- 确认文案必须说明“移到废纸篓”，不能使用含糊的“优化”或“释放空间”。
- Safe 与 Review 在结构和文案上清楚分组，但不要求用户理解技术风险枚举。

### Edge Cases

- 用户取消确认时，保留选择但不执行文件变化，或按界面约定清除选择；两者必须一致。
- 已消失项目在执行结果中标记失败，不影响其他选中项目。
- 选择包含 Safe 与 Review 时，仍按用户选择执行，但不能绕过确认。

### Acceptance Criteria

- Given Review 项目存在，When 用户未勾选任何项目，Then Clean Selected 不可用。
- Given 用户选择 Review 项目，When 未完成确认，Then 不发生文件变化。
- Given 用户确认选择，When 执行开始，Then 仅所选项目被尝试移到 Trash，并展示结果。

## F11 — Cleanup Result

### Purpose

让用户知道清理实际完成了什么，尤其是部分失败时下一步是什么。

### User Entry

Quick Clean 或 Review Cleanup 执行结束后；Cleanup 页面重新打开时可看到最近摘要。

### User Flow

执行 → 显示 cleaning → 显示全部成功、部分成功、全部失败或取消结果 → 提供查看详情/重新扫描 → Joey 播放 celebrating 或 notifying → 回到 ambient。

### States

- `cleaning`：执行中。
- `success`：全部批准项目已移到 Trash。
- `partial-failure`：至少一项成功且至少一项失败。
- `error`：全部失败或没有可靠结果。
- `cancelled`：应用退出或操作被取消。

### Product Rules

- 结果要说明成功数量、失败数量和移入 Trash 的事实。
- 失败要给出用户能采取的下一步，例如重试、跳过或查看详情；不要暴露长技术错误堆栈。
- 只持久化最近一次执行摘要，不持久化候选路径列表。
- 成功反馈使用 celebrating；有失败使用 notifying 或 warning 反馈。

### Edge Cases

- 执行过程中应用退出时，不声称全部完成；下次重新扫描。
- 结果中大小为估算值时保持估算标记。
- 没有候选的 Quick Clean 是“无需处理”，不是成功清理零项目。

### Acceptance Criteria

- Given 全部项目成功，When 执行结束，Then 显示全部已移到 Trash，并能回到 Cleanup 或 ambient。
- Given 部分项目失败，When 执行结束，Then 同时显示成功与失败数量，并允许重新扫描。
- Given 应用重启，When Cleanup 页面打开，Then 最多显示最近摘要，不显示过期候选路径作为待执行项目。

## F12 — Settings

### Purpose

让用户控制 Joey 的存在感和两个日常行为，并恢复位置；保持设置页面极简。

### User Entry

Main Window 的 Settings 或 Context Menu。

### User Flow

打开 Settings → 查看 General 与 Joey 两组 → 切换设置或重置位置 → 设置立即生效并在下次启动保持。

### States

- `available`：设置可修改。
- `saving`：系统设置请求处理中（仅 Launch at Login 可能需要）。
- `error`：Launch at Login 操作失败，保留当前真实状态并给出说明。

### Product Rules

V1 只支持：

- General：Launch at Login。
- Joey：Ambient Behaviors、Proactive Bubbles、Reset Joey Position。

不加入 quiet hours、sensor selection、utility opt-in、animation speed、theme、account、AI provider 或 advanced cleanup rules。

### Edge Cases

- 登录启动注册失败时，开关必须反映真实注册状态并说明失败。
- 关闭 Ambient Behaviors 或 Proactive Bubbles 后，新行为立即停止；不要求重启。
- Reset Joey Position 清除保存位置并把 Joey 放回安全默认位置。

### Acceptance Criteria

- Given 用户关闭 Ambient Behaviors，When 返回桌面，Then Joey 不再触发新的 ambient 行为。
- Given 用户关闭 Proactive Bubbles，When 系统状态变化，Then 不出现主动 Bubble。
- Given 用户点击 Reset Joey Position，When 操作完成，Then Joey 位于安全默认位置且旧位置不再恢复。
- Given 用户切换 Launch at Login，When macOS 接受或拒绝请求，Then 开关与真实注册状态一致。

## F13 — Pet Position Persistence

### Purpose

让用户拖到合适位置后不必每次重新摆放，同时安全应对多屏变化。

### User Entry

用户拖动 Joey 后自动保存；Settings 中的 Reset Joey Position 手动清除。

### User Flow

拖动 Joey → 松开 → 保存用户位置 → 下次启动按显示器和可见区域恢复 → 若无法恢复则使用主屏安全默认位置。

### States

- `unsaved`：本次拖动尚未结束。
- `saved`：用户拖动结束后已保存。
- `restored`：成功恢复到对应屏幕。
- `fallback`：屏幕消失或位置不可见，使用安全默认位置。

### Product Rules

- 只在用户拖动结束后持久化；ambient movement 不改变保存位置。
- 保存位置必须与屏幕识别和可见区域相关联。
- 恢复后若窗口完全在屏幕外，使用当前主屏安全默认位置。
- 不引入数据库或跨设备同步。

### Edge Cases

- 外接显示器拔出后，不能恢复到不可见屏幕。
- 分辨率、菜单栏或 Dock 改变后，需保证窗口仍可见。
- 用户重置后再次启动不能回到旧记录。

### Acceptance Criteria

- Given 用户拖动 Joey 并松开，When 下次启动，Then 恢复到可见且接近保存位置的屏幕区域。
- Given 保存的屏幕已不存在，When 应用启动，Then Joey 出现在当前主屏安全位置。
- Given ambient walking 发生，When 应用重启，Then 不把 ambient 临时位置当作用户保存位置。

## F14 — Launch at Login

### Purpose

让用户选择是否在登录后自动启动 JoeyPet，同时遵循 macOS 的真实登录项状态。

### User Entry

Settings → General → Launch at Login。

### User Flow

用户打开/关闭开关 → 请求 macOS 登录项注册或注销 → 读取真实状态 → 显示最终开关状态和可能的错误。

### States

- `off`：默认不登录启动。
- `on`：已注册登录项。
- `updating`：正在处理请求。
- `error`：请求失败，保留真实状态。

### Product Rules

- 默认关闭。
- 登录启动只负责启动应用，不默认打开 Main Window；Joey 安静出现在桌面。
- 用户可随时关闭；不能用隐藏方式注册。
- 失败时不能把意向状态伪装成成功状态。

### Edge Cases

- macOS 拒绝注册或注销时，显示短错误并保持实际状态。
- 应用已通过登录项启动时，仍遵循正常生命周期，不打开多份 Joey。
- Main Window 关闭不影响登录项设置。

### Acceptance Criteria

- Given 登录启动为 off，When 用户开启并且 macOS 注册成功，Then 下次登录可启动 JoeyPet，且不自动打开 Main Window。
- Given 注册失败，When 设置返回，Then 开关显示 off 并给出可理解的错误。
- Given 用户关闭登录启动，When 注销成功，Then 下次登录不自动启动 JoeyPet。

## F15 — App Lifecycle

### Purpose

让常驻桌宠、Main Window、Cleanup、睡眠唤醒和退出之间的边界可预测。

### User Entry

应用启动、关闭 Main Window、Quit、系统睡眠/唤醒。

### User Flow

启动 → Joey 可见、Main Window 不自动打开 → 用户按需打开/关闭 Main Window → 系统睡眠时暂停可暂停工作 → 唤醒后恢复 → 用户选择 Quit 才真正退出。

### States

- `running`：Joey、传感和允许的 ambient 正常运行。
- `main-window-closed`：主窗口关闭，但应用仍运行。
- `sleeping`：系统睡眠，暂停传感、ambient 和临时动作。
- `waking`：恢复并重新建立必要运行状态。
- `terminating`：停止任务、Bubble 与资源后退出。

### Product Rules

- Close Main Window ≠ Quit JoeyPet。
- Joey 继续运行；Quit 才结束应用。
- 退出时停止/取消传感、ambient、Bubble 和 Cleanup 任务。
- 睡眠/唤醒后不得产生重复传感器、调度器或窗口。
- 设置和用户位置按各自规则持久化；Cleanup 只保留最近执行摘要。

### Edge Cases

- 用户在 Cleanup 执行时退出，不能把未确认或未完成项目报告为成功。
- 从睡眠唤醒时若屏幕布局变化，先进行安全位置恢复。
- Main Window 关闭后从菜单重新打开，应复用同一窗口状态而不是退出或新建多个窗口。

### Acceptance Criteria

- Given Main Window 已打开，When 用户关闭它，Then Joey 仍运行且可通过右键菜单再次打开。
- Given 系统进入睡眠，When 睡眠处理完成，Then ambient、传感和临时动作停止或暂停。
- Given 系统唤醒，When 恢复完成，Then Joey 可见、状态链恢复，且没有重复任务。
- Given 用户选择 Quit，When 应用结束，Then Joey、Bubble、传感与 Cleanup 任务均停止。
