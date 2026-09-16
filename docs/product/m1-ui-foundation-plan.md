# MVP M1 — UI Foundation Plan

> 本文是 M1 的实现规划与设计评审，不是新的产品 Source of Truth。产品行为仍以 [`ui-spec.md`](ui-spec.md) 与 [`feature-spec.md`](feature-spec.md) 为准；本文只回答下一轮 UI 重构应先改什么、如何组织、依赖什么。

## 1. Goal

把当前的 First Functional Implementation 整理成一个安静、紧凑、符合 macOS 习惯的 Main Window，并把 Desktop Joey 的 Bubble / Context Menu 入口接回同一套清楚的状态与操作规则。

本轮锁定的 IA 不变：

```text
JoeyPet
├── Overview
├── Cleanup
└── Settings

非 Main Window
├── Desktop Joey
├── Status Bubble
└── Context Menu
```

Overview 的目标是让用户在几秒内知道“Mac 现在怎么样”；Cleanup 的目标是让用户在有限范围内安全地判断并把批准的项目移到废纸篓；Settings 只控制登录启动、Joey 的存在感和位置。

本轮明确不做：新增一级页面、扩充指标或 Cleanup 范围、系统管理动作、Sprite/BehaviorEngine 重做、完整设计系统、历史数据、数据库、运行时第三方依赖。

## 2. Current UI Audit

### Audit method and confidence

- **Observed**：基于当前 Debug App 的实际启动、Main Window、导航切换、只读 Scan、Settings 和右键菜单观察。
- **Inferred from code**：基于 `ContentView.swift`、`AppModel.swift`、`MainWindowController.swift`、`JoeyBubbleController.swift`、`AppDelegate.swift` 及 Cleanup 数据模型的实现判断。
- 当前 Debug App 使用真实本机只读状态和只读 Cleanup scan；本次没有点击任何 Move to Trash / Quick Clean 执行路径，也没有修改设置或用户文件。
- Bubble 的左键入口在本次 Computer Use 观察中未成功显现，因此 Bubble 的尺寸、定位和状态缺口属于源码推断，下一轮需补一次可重复的手动验证。

### Main Window

**Observed**

- 窗口标题为 `JoeyPet`，默认实际显示尺寸约为 760×520；左侧为可折叠的 `NavigationSplitView` sidebar，内容区使用 24pt padding。
- sidebar 有且只有 Overview、Cleanup、Settings，入口顺序正确；工具栏有隐藏 sidebar 控件。
- Overview 初始首屏显示 `Mac Status`、三个状态行和 Cleanup 区块；下方有大面积未使用空间。
- 窗口整体是原生 macOS 外观，但当前内容更像功能验证面板：页面标题、状态行和操作的层级还没有形成产品结论。

**Inferred from code**

- `MainWindowController` 只设置了 760×520 的 `contentRect`，没有设置明确的 minimum size、保存窗口尺寸或内容宽度约束。
- 关闭 Main Window 不退出应用，控制器保留同一个 window 实例，符合 F06/F15；这部分保留。
- `ContentView` 的 sidebar 和 detail 结构本身符合锁定 IA，不需要以增加导航来解决页面问题。

**Assessment**

保留 `NavigationSplitView` 作为三个正式页面的原生 shell，但重做 detail 的首屏层级、状态容器和页面间距。窗口不应变成 Dashboard，也不应以大量 card 填充空白。

### Overview

**Observed**

- 当前页面的第一标题是 `Mac Status`，不是 Overall Mac Status 结论；没有 `normal / notice / warning / critical` 的整体文字结论。
- 只显示 Thermal、Memory Pressure、Storage；CPU Usage、Memory Usage、Network Activity 和短时趋势完全不可见。
- Thermal、Memory Pressure、Storage 被放在一个带圆角描边的整体容器中；Cleanup 另有标题、说明和一个 `Scan and view` 按钮。
- 首屏的主要视觉焦点是三个状态行的容器，而不是“Mac 是否正常”的结论。

**Inferred from code**

- `SystemStatusSnapshot` 当前只有 Thermal、Memory Pressure、Storage；`systemStatus.overallSeverity` 已能提供汇总严重程度，但没有被 UI 使用。
- Storage 当前文案为 `free of total · percent used`，没有把 used/free/total 以可扫描的结构分别呈现，也没有 usage bar。
- Cleanup summary 只显示最近执行时间、移入废纸篓数量和处理大小；未扫描时只有 `No scan yet`。

**Assessment**

这是当前最大的信息架构缺口：页面有功能数据，但不能先给结论，也没有达到 V1 的 Lightweight Mac System Overview。Overview presentation 可以先用已有三类数据落地；完整首屏必须等待最小 CPU/Memory/Network data source 和 session trend buffer。

### Cleanup

**Observed**

- 初始页面同时显示 `Scan` 和醒目的 `Quick Clean`；页面下方还有 `No scan yet`、技术性说明和最近一次结果。
- 只读扫描结果实际显示了 `Total / Safe / Review`，但候选按 `Application Caches` 等技术类别分组，行内直接出现 `Review` badge；每一项都有 checkbox、名称、大小和重复的英文原因。
- 本次真实只读 scan 得到 Review 项目、Safe 为 0；此时 `Quick Clean` 仍是可用的醒目按钮，底部 `Move selected to Trash` 因无选择而禁用。
- 扫描结果列表可滚动；页面结构能承载多项候选，但首要信息是技术列表而不是“哪些可以直接处理、哪些建议先看”。

**Inferred from code**

- `CleanupPhase` 只有 idle、scanning、ready、cleaning、completed、failed；没有独立的 no-cleanup、partial-failure、scan-error、cancelled UI 状态。
- `CleanupView` 先判断 `scanResult` 再判断 `cleanupPhase`。因此已有结果时重新扫描或清理期间仍可能显示旧列表，而不是覆盖成明确的 Scanning/Cleaning 状态。
- `quickClean()` 会在没有 Safe 候选时完成一次扫描并通过 Bubble 反馈，但页面仍把 Quick Clean 放在初始和 Safe=0 的主操作位置。
- `CleanupCandidate` 已有名称、大小、category、risk、reason、path、估算标记；UI 目前机械地同时展示或使用其中多项，没有 disclosure 层级。
- Scanner 已冻结三个 allowlisted roots，Executor 使用 `FileManager.trashItem`；本轮不改 Domain 或安全边界。

**Assessment**

Cleanup 的执行能力不是空白，问题是用户决策路径和异步状态不清楚。必须优先修正 CTA、安全分组、旧结果覆盖和部分失败表达；不能靠新增清理能力解决。

### Settings

**Observed**

- 使用 grouped Form，当前可见分组为 General、Pet、Hints；控件是 Launch at Login、Ambient behaviors、Reset Joey Position、Show proactive bubbles。
- 页面控件稀疏且下方有大面积空白，但整体仍接近 macOS Settings 风格；空白本身不是需要新增设置的理由。
- 当前页面没有独立的内容标题，用户主要依靠 sidebar 选中项判断所在页面。

**Inferred from code**

- 产品锁定的是 General + Joey 两组；当前 `Hints` 将 Proactive Bubbles 从 Joey 行为中拆开，属于 IA / 命名不一致。
- Launch at Login 的错误状态已有模型字段和行内错误文本；UI 没有显示 updating 状态，且需确认失败后开关始终跟随真实 `SMAppService` 状态。
- Ambient Behaviors 与 Proactive Bubbles 的持久化和立即生效边界已存在，保留。

**Assessment**

Settings 不需要填满页面。保留 grouped Form，改成两组、短标题和行内状态；Reset Joey Position 是低强调的次要按钮。

### Bubble

**Observed**

- 本轮通过 Computer Use 启动应用并点击 Joey，未能让 Bubble 稳定出现在可观察的 AX/UI 状态中；因此没有把 Bubble 的实际屏幕位置写成已观察事实。

**Inferred from code**

- `JoeyBubbleController` 使用 250pt 固定宽度；无主操作时高度 78pt，有主操作时高度 112pt。
- Bubble 使用 non-activating floating `NSPanel`，新消息会先取消旧 dismiss task 并 `orderOut` 旧 panel，这已经符合“替换而非叠加”的方向。
- 位置直接由 `anchor.maxX - 24, anchor.maxY - 26` 计算，没有基于 `NSScreen.visibleFrame` 做边缘夹取，可能遮挡 Joey 或在屏幕边缘不可见。
- 信息 Bubble 4 秒自动消失，带主操作的 Bubble 7 秒自动消失；没有明确的关闭控件。主动 Bubble 的重复抑制主要由 `lastAnnouncedState` 完成，但结果型 Bubble 与连续事件的统一策略仍需产品化。
- 当前文案整体短而自然；Storage action Bubble 有两个动作（Quick Clean / 查看），符合“一主一辅”，但主动作需要让“只处理 Safe”与后续确认边界保持一致。

**Assessment**

Bubble 不是 Toast。下一轮要把它定义为四种可验证状态：informational、action、success、warning，并补边缘布局、显式关闭、忙碌时动作禁用和重复抑制测试。

### Context Menu

**Observed**

- 右键菜单实际出现，顺序和分隔线正确：打开 JoeyPet、快速清理、扫描并查看、设置、分隔线、退出 JoeyPet。

**Inferred from code**

- `AppDelegate` 每次右键即时创建菜单，所有菜单项 target 都是 AppDelegate；没有依据 `AppModel.cleanupPhase` 设置 Quick Clean / Scan and View 的 enabled 状态。
- 菜单入口名称、退出语义和主窗口复用路径正确，保留菜单结构。

**Assessment**

这是一个小而明确的交互修正：保持菜单顺序，在 scanning/cleaning 时禁用会重复启动 Cleanup 的两个入口；Open JoeyPet、Settings、Quit 保持可用。

## 3. UX Problems

### P0

1. **Overview 没有回答首要问题**：缺少 Overall Mac Status 结论，且 V1 必需的 CPU、Memory Usage、Network Activity、短时趋势没有任何 UI 位置；当前页面不能在几秒内判断 Mac 状态。
2. **Cleanup 初始状态暴露了不应成为主操作的 Quick Clean**：未扫描、Safe=0 时仍显示醒目的 Quick Clean，用户无法先知道它会处理什么，且与 UI Spec 的“Initial 只有 Scan”冲突。
3. **异步状态会被旧结果遮蔽**：`scanResult` 优先于 `cleanupPhase` 的呈现顺序可能在重新扫描或清理期间继续显示旧候选；用户无法确认当前列表是否仍有效，也看不到正在把已批准项目移到废纸篓的状态。
4. **Cleanup 结果没有安全决策层级**：Safe/Review 直接以技术 enum 和 badge 呈现，候选按 category 排列，Review 项目的原因和需要用户判断的边界不够突出；这影响核心清理操作的理解与确认。
5. **忙碌期间 Context Menu 没有明确禁用规则**：当前源码没有设置 enabled state，可能允许重复触发 scanning/cleaning 入口；这是既影响可靠性也影响安全反馈的 P0。

### P1

- Overview 使用单一圆角容器包住所有已有状态行，且 Cleanup 另起一块，形成“卡片面板”而不是结论 → 数据 → 行动的层级。
- Overview 的 Storage 文案可读但不易扫描；没有 used/free/total 的结构化表达和轻量使用指示。
- Cleanup 同时并列 Scan、Quick Clean 和底部 Move selected to Trash；主 CTA 随状态变化不够明确。
- Cleanup 的英文原因、`Safe` / `Review` 和 category 名称把技术词放在用户决策层；path 尚未被设计为可折叠详情。
- Cleanup 没有独立、清晰的 no-cleanup、部分成功、扫描错误和执行错误视觉状态；失败数量与逐项下一步不足。
- Settings 分组为 `Pet` + `Hints`，与锁定的 General + Joey 不一致；Launch at Login 的 updating / error 反馈需要与真实状态绑定。
- Bubble 的固定定位没有屏幕边缘处理，也没有稳定可验证的 close affordance；当前实际显示仍需补充复测。
- Main Window 缺少明确 minimum size 与内容宽度策略；760×520 对现有页面足够，对完整 Overview 的趋势和 Cleanup 决策列表偏紧。

### P2

- 颜色、圆角和图标需要统一收敛到 macOS semantic colors / system defaults，但不值得先做成独立 design system。
- 估算大小应使用自然的 `约` / accessible label，而不是让 `~` 成为主要视觉语言。
- 需要补齐 system font、VoiceOver 的状态和趋势描述、键盘焦点顺序、Reduce Motion 下的趋势动画行为。

## 4. Target Information Architecture

不改变三项一级导航，改变每页的阅读顺序：

```text
Main Window
├── Sidebar: Overview / Cleanup / Settings
└── Detail
    ├── 页面标题（只出现一次）
    ├── 当前结论 / 当前状态
    ├── 当前页面唯一主要动作
    ├── 事实与结果
    └── 必要的次要动作
```

页面规则：

- 打开 Main Window 默认进入 Overview；从 Bubble 或 Context Menu 进入时复用同一窗口并切到指定页面。
- Sidebar 保留，因三个稳定入口适合 macOS split view；不增加第二层导航、History 或 Monitor 页面。
- 每页首屏先给结论和主要动作；长列表只在内容确实超过窗口高度时滚动。
- 不用页面 subtitle 解释已经能由 section、控件或状态表达的内容。
- 所有严重程度使用现有 normal / notice / warning / critical 语义；颜色只能辅助，文字必须同时表达。

## 5. Main Window Foundation

### Recommended geometry

| 项目 | 建议 | 依据 |
|---|---:|---|
| 默认尺寸 | 800×560 pt | 只比当前 760×520 略增，给完整 Overview 的 6 个指标和 Cleanup 首屏结论留出空间，不形成 Dashboard 尺寸 |
| 推荐范围 | 780–840 × 540–620 pt | 适合三页共用；Cleanup 列表通过滚动承载数量，Settings 不因空白扩大 |
| 最小尺寸 | 720×480 pt | sidebar、页面标题、当前 CTA 和最小可读内容仍可共存；小于此尺寸应优先压缩留白而非缩小文字 |
| Sidebar | 约 180 pt，允许用户隐藏 | 保持当前可发现性和 macOS 导航习惯，不引入额外导航 |
| Detail 内容 | 约 540–640 pt，左对齐 | Overview 行、mini trend 和 Cleanup 结果摘要都能自然排布；不使用全宽 card wall |

这些是下一轮实现的验证目标，不是本轮修改窗口代码的授权。窗口应保持可调整、可复用、关闭不退出；不要为了恢复尺寸引入数据库或新的持久化状态。

### Visual foundation

- 使用系统字体、系统背景、默认 control size、semantic colors、separator 和原生 Form/List；不建立 Web 式 spacing/color/shadow token 框架。
- 页面内容采用少量 section 与 row。只在需要包住一个完整状态或结果时使用轻量背景，不给每项指标单独加 card。
- 页面标题使用一个清楚的 `.title2` / 系统等价层级；状态结论比标题更醒目，但不做巨大 hero。
- 主按钮只在当前状态真正可执行时显示为 prominent；不可执行时优先隐藏或改为状态文本，而不是堆叠 disabled buttons。
- 页面可滚动，但首屏不应先看到技术路径、长解释或空的结果表。

### Wireframe

```text
┌─────────────────────────────────────────────────────────────┐
│ JoeyPet                                      [window controls]│
├───────────────┬─────────────────────────────────────────────┤
│ Overview      │ Overview                                     │
│ Cleanup       │ Mac 状态                         需要注意     │
│ Settings      │ Memory pressure 需要留意 · 其他状态可用       │
│               │                                               │
│               │ 使用情况                                      │
│               │ CPU       24%                 ▁▂▃▅▃▂▂        │
│               │ Memory    8.2 / 16 GB       ▁▂▂▃▂▃▂          │
│               │ Pressure  Normal                              │
│               │ Network   ↓ 1.2 MB/s  ↑ 240 KB/s  ▁▃▂▅▂      │
│               │                                               │
│               │ 健康状态                                      │
│               │ Storage   519 GB free · 995 GB total  ━━━━    │
│               │ Thermal   Nominal                             │
│               │                                               │
│               │ Cleanup   尚未扫描                  扫描并查看 │
└───────────────┴─────────────────────────────────────────────┘
```

Wireframe 只表达层级，不锁定最终文案或具体数值。正常状态不需要额外 hero 说明；警告状态只在状态结论旁给最短原因。

## 6. Overview Design Direction

### Information hierarchy

1. **Overall Mac Status**：共享 severity 的文字结论，例如“状态良好”“需要注意”；存在 warning/critical 时必须说明最重要的指标，不能被正常项稀释。
2. **Dynamic metrics**：CPU、Memory Usage、Memory Pressure、Network；当前值是主信息，趋势是辅助信息。
3. **Health metrics**：Storage、Thermal；Storage 既表达 used/free/total，也可提供轻量 usage bar；Thermal 只表达状态，不伪造温度。
4. **Cleanup Summary**：最近执行摘要或“尚未扫描”，是次级入口，不展示候选路径历史。

### Metric presentation

| Metric | 主表达 | 辅助表达 | 不做 |
|---|---|---|---|
| CPU | 当前百分比 | 60 秒 mini trend | per-core、process list、load average、optimizer action |
| Memory | Used / Total | 60 秒 used trend | 把 Usage 当作 Pressure，或把缺失当作 0 |
| Memory Pressure | `Normal / Warning / Critical` 等状态 | severity indicator | 与 Memory Usage 合并成一个百分比 |
| Network | Download / Upload 当前速率 | 60 秒 aggregate trend | connection list、interface picker、网络诊断 |
| Storage | used、free、total | 薄 usage bar + normal/notice/warning | 大型磁盘分析图、自动清理 |
| Thermal | Nominal / Fair / Serious / Critical 的用户可读状态 | 共享 severity | 假的 °C、由 Thermal 推算温度 |

Memory Usage 与 Memory Pressure 可以在同一“使用情况” section 相邻，但必须是两行、两套值语义。Memory 使用率高而 Pressure 正常时，不应显示成严重状态。

### Overall status and action

- `normal`：显示当前指标；Cleanup 未扫描时可以提供 `扫描并查看`，否则 Cleanup Summary 使用低强调的 `查看 Cleanup`。
- `notice/warning/critical`：结论行指出最高严重项；主要动作优先是 `查看状态` 或在 Storage low 时 `查看 Cleanup`，不出现“释放内存”“优化 CPU”“加速 Mac”。
- 某项 unavailable：该行显示“暂时不可用”和简短原因；其他可用指标继续显示，不把 unavailable 当成 normal。
- Fan RPM / Exact Temperature 有可靠数据时作为 Thermal 行的次级附加值；没有数据时整项不占主层级，不显示空 card、`-- °C` 或 `N/A RPM`。

### Mini trend spec

- 类型：轻量 sparkline / trend line，固定高度约 20–24pt，宽度约 96–120pt。
- 信息密度：当前 session 最近约 60 秒，约 12–30 个样本；采用内存 ring buffer，重启后从空状态重新采样。
- 坐标轴、grid、legend、时间范围选择器：全部不显示。
- Tooltip：M1 不做 hover tooltip；无障碍标签提供“最近 60 秒 CPU 使用率趋势”等等价信息。
- 样本不足：显示当前值和“正在采样”/等价短状态，不绘制误导性的完整趋势线。
- Reduce Motion：趋势更新使用静态重绘或降低动画，不依赖持续位移动画来传达状态。

### Overview states

| 状态 | 首屏 | 主要动作 |
|---|---|---|
| Loading | 核心指标行显示读取中，不显示猜测值 | 等待 |
| Normal | Overall Mac Status + 可用指标 | 按 Cleanup 是否扫描决定查看或扫描 |
| Warning/Critical | 首行结论 + 最重要异常指标，其余可用指标保留 | 查看状态 / 进入 Cleanup |
| Unavailable | 指定指标不可用及短原因 | 稍后重试或继续查看 |
| Cleanup 未扫描 | 小型摘要显示“尚未扫描” | Scan and View |
| 有最近摘要 | 只显示时间、成功/失败数量和移入 Trash 结果 | 查看 Cleanup |

## 7. Cleanup Design Direction

### Common structure

```text
Cleanup
当前状态 / 一句话结论
[当前唯一主要动作]

结果摘要
├── 可快速处理     数量 · 约大小
└── 建议先查看     数量 · 约大小

候选列表（需要决定的项目才有 checkbox）
结果 / 错误 / 下一步
```

用户语言不使用 `CleanupRisk.safe/review` 作为主标题。推荐使用“可快速处理”和“建议先查看”；实际最终措辞在实现时以短、自然、明确为准。

### State and CTA table

| 状态 | 需要让用户知道什么 | Primary CTA | Secondary / 禁用规则 |
|---|---|---|---|
| Initial | 将扫描三个有限范围；尚未有结果 | `Scan` | 不显示 Quick Clean，不显示空结果表 |
| Scanning | 正在只读扫描，当前结果尚未可用 | 无 | 隐藏或覆盖旧结果；Scan、Quick Clean、菜单重复入口禁用 |
| Results with Safe | 有可快速处理项目 | `Quick Clean` | `重新扫描` 为低强调；Review 组可展开选择 |
| Safe + Review | 两组边界不同 | `Quick Clean` | Review 仅在选择后显示 `Clean Selected` |
| Review only | 没有可快速处理项目，有内容需判断 | `查看并选择` | Quick Clean 不显示或不可用；可重新扫描 |
| Safe only | 只有 Safe | `Quick Clean` | 不渲染空 Review section |
| No Cleanup Needed | 扫描完成且没有候选，不是失败 | `Scan again` | 可返回 Overview |
| Cleaning | 正在把已批准项目移到废纸篓 | 无 | 显示进度/已处理数量，所有重复执行入口禁用 |
| Completed | 成功数量、移入 Trash 的事实 | `Scan again` | 可查看本次结果；不做巨大庆祝页 |
| Partial Failure | 成功与失败数量都要可见 | `Rescan` 或 `Retry` | 失败项显示短原因和下一步，不写“全部完成” |
| Error | 哪个范围或动作无法继续、用户能做什么 | `Try Again` | 不把权限失败写成无结果，不显示长堆栈 |

### Candidate presentation

- 默认行：名称、自然大小（估算时使用“约”）、用户语言的类别、必要的简短原因。
- Safe 行不显示 checkbox，避免 Quick Clean 看起来像用户必须逐项批量删除。
- Review 行显示 checkbox；未选择时 `Clean Selected` 不可用。选择可包含 Safe + Review 时仍必须统一确认，但 Quick Clean 永远只处理 Safe。
- icon 只有在能帮助识别类别时保留；不使用装饰图标填充行。
- path 不放在主要视觉层级，用 disclosure / detail 展开；不要默认展示长路径。
- `category` 作为辅助信息，不以 Application Caches 等工程命名主导用户决策；原因要说明为什么建议先查看。
- 目录大小不完整时必须保留估算语义；扫描跳过或部分不可读时在结果摘要附近说明受影响范围。

### Confirmation and result

- Review 的确认明确写“将所选项目移到废纸篓”，不写“优化”“释放空间”或含糊的“删除”。
- Quick Clean 的批准边界是 Safe 候选集合；执行前重新扫描，执行中不能复用过期路径。
- Completed 只需显示成功数量、处理大小和“已移到废纸篓”；部分失败同时显示失败数量和可执行的重试/重新扫描。
- 失败信息保持逐项、短、可行动；技术细节进入日志，不出现在主页面。
- 没有候选的 Quick Clean 是“无需处理”，不是“成功清理 0 项”。

## 8. Settings Design Direction

目标结构只有两组：

```text
Settings

General
  Launch at Login                         [toggle]
  （登录项请求失败时，在本行下显示短错误）

Joey
  Ambient Behaviors                       [toggle]
  Proactive Bubbles                       [toggle]
  Reset Joey Position                     [button]
```

- 使用原生 grouped Form；保留合理空白，不用 subtitle 填充页面。
- `Launch at Login` updating 时只禁用该行并显示处理中的反馈；失败后 toggle 必须回到真实注册状态。
- Ambient Behaviors 与 Proactive Bubbles 立即生效，回到桌面即可观察变化；不需要全页保存按钮。
- Reset Joey Position 是明确的次要操作，不与 toggle 抢主视觉；成功后 Joey 回到安全默认位置。
- 不新增 Quiet Hours、sensor selection、animation speed、theme、account、AI provider 或 advanced cleanup rules。

## 9. Bubble / Context Menu

### Bubble target rules

- Informational 通常一到两行，约 4 秒自动消失；Action / Warning 在操作完成、用户关闭或较长超时前保持可读；Success 短暂显示结果。
- 最大宽度控制在约 260–300pt，按内容自适应高度；一个 Bubble 一个重点，最多一个主要动作和一个查看动作。
- 位置优先在 Joey 上方或侧上方，保持约 12–16pt 间距；根据 `NSScreen.visibleFrame` 选择可见方向并夹取，不能遮挡 Joey 或完全离屏。
- 增加清楚的关闭入口；用户操作后立即消失。新 Bubble 替换旧 Bubble，不叠加队列。
- Proactive Bubbles 关闭时不显示主动系统状态 Bubble；用户主动点击 Joey 的信息 Bubble 仍可用。
- 状态未重新进入或没有新结果时不重复相同 warning；Cleanup 忙碌时不提供会再次启动操作的 action。

### Context Menu target rules

```text
打开 JoeyPet
快速清理
扫描并查看
设置
────────
退出 JoeyPet
```

| Menu item | Normal | Scanning | Cleaning |
|---|---|---|---|
| 打开 JoeyPet | enabled | enabled | enabled |
| 快速清理 | enabled | disabled | disabled |
| 扫描并查看 | enabled | disabled | disabled |
| 设置 | enabled | enabled | enabled |
| 退出 JoeyPet | enabled | enabled | enabled |

菜单忙碌时仍可打开；禁用项必须以 macOS disabled appearance 呈现。Quit 始终是真正退出，不是关闭 Main Window。

## 10. Shared UI Primitives

只抽取多个页面或多个状态真实重复的部分，不创建 `JoeyDesignSystem` / `UIFramework` / Component Library。

| Primitive | 使用范围 | 规则 |
|---|---|---|
| `StatusIndicator` | Overview、Cleanup 状态、Bubble severity | dot/icon + 文字语义；不能只靠颜色；支持 VoiceOver label |
| `SectionHeader` | Overview、Cleanup、Settings | 标题 + 必要时数量/结论；不自动附加 subtitle |
| `MetricRow` | Overview | label、current value、optional secondary value、optional MiniTrend；Memory Usage/Pressure 仍是两行 |
| `MiniTrend` | CPU、Memory、Network | 60 秒 session ring buffer；无轴、无 grid、样本不足时显示采样状态 |
| `AsyncStateHeader` | Overview loading/unavailable、Cleanup scanning/cleaning/error | 统一状态结论和主要 CTA 位置，但不掩盖页面特有内容 |
| `EmptyState` | Cleanup initial/no-cleanup | 只在确实无结果或尚未扫描时出现，不作为全局装饰 |
| `CleanupResultSummary` | Overview 摘要、Cleanup 结果 | 成功/失败数量和 Trash 事实；不展示候选路径历史 |

`CandidateRow`、Settings row、Bubble panel 仍由各自 feature owner 管理；它们有不同交互，不应为了代码对称强行共用。

### Minimal design tokens

仅记录实现验收所需的少量约束：

- 使用系统字体和 Dynamic Type；页面 section 之间使用系统 spacing，必要时统一约 16–24pt 的内容节奏。
- 复用系统 corner radius、背景、separator、control size 和 semantic colors；不建立 8px token 表、shadow scale 或品牌 severity palette。
- 状态颜色沿用 normal/notice/warning/critical 的 macOS semantic color；每个状态同时有文字。
- 内容列保持约 540–640pt 的舒适阅读宽度，列表在更长时滚动。

## 11. Missing Data Dependencies

当前 `SystemStatusSnapshot` 只覆盖 Thermal、Memory Pressure、Storage。以下依赖属于 M1 的最小 data-source 工作，不是新增 Product Phase，也不应演变成完整 monitoring framework。

| Dependency | Planning path | Feasibility | UI implication |
|---|---|---|---|
| CPU Usage | 使用 macOS 原生系统计数器计算整体使用率；只保留 aggregate current value | Needs Spike | 先验证采样间隔、首个样本、睡眠/唤醒和低开销；不做 per-core / process |
| Memory Usage | 使用 macOS 原生 host memory statistics 得到 used/total；与现有 memory pressure sensor 分开 | Needs Spike | 验证 used 语义、统一单位、Unavailable 和重启后的首样本；不把 usage 当 pressure |
| Network Activity | 读取本机接口累计 byte counters，聚合可用接口并以时间差得到 Download/Upload rate | Needs Spike | 验证 loopback/接口变化、睡眠唤醒、零速率与无数据状态；不做接口选择器 |
| Trend buffer | 在 app session 内使用有界内存 ring buffer，按 metric 保存最近样本 | Straightforward after data source | 不持久化；样本不足不画完整 sparkline；不新增数据库 |
| Fan RPM / Exact Temperature | 仅在可靠、稳定、权限合理的原生路径通过独立技术验证后纳入 | Conditional | 无数据时不留占位 card；Thermal State 是完整 fallback |

实施原则：扩展现有 system snapshot / observation contract，让 UI 消费同一条只读数据链；不要为 Overview 再造一个脱离 `SystemSensor → SystemSignal` 边界的 monitor framework。CPU/Memory/Network 只服务 Overview，不自动新增 Joey behavior。

## 12. Current vs Target Matrix

| Area | Current | Problem | Target | Priority |
|---|---|---|---|---|
| Main Shell | 760×520 `NavigationSplitView`，三项 sidebar，detail padding 24 | 无 minimum/content width 规划；完整 Overview 会偏紧；detail 首屏层级弱 | 保留三项原生 split shell；800×560 默认、720×480 minimum 作为验证目标 | P1 |
| Overview | Mac Status + Thermal/Memory Pressure/Storage 卡片 + Cleanup 摘要 | 无 Overall Status；缺 3 个 required metrics；大空白；指标与结论混在一起 | Overall Status → dynamic metrics/trends → health metrics → Cleanup summary | P0 |
| Cleanup | Scan/Quick Clean 并列；按 category 列表；技术 Safe/Review badge；旧结果可能遮蔽 busy 状态 | 初始和 Safe=0 暴露 Quick Clean；安全分组和状态不清；动作边界弱 | 状态驱动单一主 CTA；自然语言 Safe/Review 分组；扫描/清理覆盖旧结果；完整结果反馈 | P0 |
| Settings | General / Pet / Hints grouped Form；四项设置 | Hints 不符合锁定 IA；Launch updating 不可见；空白处理缺少克制规则 | General / Joey 两组；行内 updating/error；空白保留 | P1 |
| Bubble | 固定 250pt panel，定点偏移，自动消失；替换旧 panel | 边缘可能离屏/遮挡；无明确关闭；重复和 busy action 验证不足 | 自适应短 Bubble、边缘夹取、close、替换、重复抑制、状态类型明确 | P1 |
| Context Menu | 顺序和分隔线正确；每次即时创建 | 未按 scanning/cleaning 禁用重复操作 | 固定顺序 + 忙碌 enabled rules；Quit 始终可用 | P0 |

## 13. M1 Implementation Slices

### M1.1 — Main Window shell and shared state presentation

- **Goal**：先建立可承载三页的稳定 shell、页面标题层级、最小尺寸策略和 shared loading/error/status primitives。
- **Scope**：保留 NavigationSplitView；整理 detail padding/width、Overall Status 的通用呈现骨架、Empty/Error/AsyncStateHeader、system font/semantic color 约束；只接已有 Thermal/Memory Pressure/Storage 数据。
- **Dependency**：当前 `AppModel`、`SystemStatusSnapshot`、UI Spec；不等待 CPU/Memory/Network 完整数据才能开始。
- **Exit Criteria**：默认进入 Overview；三项导航、关闭/复用窗口正确；窗口在推荐范围可读；页面不再依赖大面积 card 或重复说明；loading/unavailable 可显示。

### M1.2 — Minimal Overview monitoring data contract

- **Goal**：补齐 Overview 所需的 CPU Usage、Memory Usage、Network Activity 和 bounded session trend buffer 的最小只读数据来源。
- **Scope**：先做原生 API feasibility spike、采样/聚合/Unavailable 规则、睡眠唤醒和首样本行为；扩展同一 snapshot/data contract；不新增 Joey behavior、不做进程列表或长期历史。
- **Dependency**：M1.1 的状态呈现骨架；CPU/Memory/Network 均是 Needs Spike，Fan/Temperature 不阻塞此 slice。
- **Exit Criteria**：三个 required metric 能在无额外用户权限下得到可信 aggregate current value；缺失不伪装为 0；趋势只存在当前 session；单元测试覆盖首样本、无数据和边界。

### M1.3 — Overview final hierarchy and metric rows

- **Goal**：让用户几秒内先看到 Overall Mac Status，再读懂所有 V1 required metrics。
- **Scope**：Dynamic metrics section、Memory Usage/Pressure 分离、Network Download/Upload、Storage used/free/total + usage bar、Thermal state、MiniTrend、Cleanup Summary；Conditional hardware metrics 只按验证结果自然插入。
- **Dependency**：M1.1；CPU/Memory/Network data contract from M1.2；现有 Storage/Thermal/Pressure 能直接接入。
- **Exit Criteria**：Overview loading/normal/warning/critical/unavailable 全部可读；没有 process/system management action；Overview 不因 CPU 高而新增 Pet behavior；小窗口和较长数据均可用。

### M1.4 — Cleanup state experience

- **Goal**：完成从 Initial 到结果、确认、执行、部分失败和错误的清楚用户路径，不改 Cleanup Domain。
- **Scope**：状态驱动 CTA；Safe/Review 自然分组；candidate row 的决策信息与 disclosure；scanning/cleaning 覆盖旧结果；no-cleanup、safe-only、review-only、safe+review、completed、partial failure、error；确认文案和禁用规则。
- **Dependency**：M1.1 shared async/empty/error presentation；现有 `CleanupScanner`、`CleanupExecutor`、allowlist、Trash 语义；不允许真实 Cleanup 作为 UI 测试副作用。
- **Exit Criteria**：每个状态只有明确主要动作；Quick Clean 只作用于 Safe；Review 必须选择并确认；没有结果、部分成功、权限/消失项目都有可行动反馈；测试使用 fixture 和 fake Trash mover。

### M1.5 — Settings and Desktop entry integration

- **Goal**：把 Settings、Bubble、Context Menu 与 Main Window 的页面/忙碌状态接成统一的入口体验。
- **Scope**：Settings 改为 General/Joey；Launch updating/error；Bubble 类型、边缘定位、close、替换和 action；Context Menu busy enabled rules；Main Window close ≠ Quit；不改 Sprite、locomotion 或 BehaviorEngine。
- **Dependency**：M1.1 shared status/state rules；Cleanup phase from M1.4；现有 `JoeyBubbleController`、`AppDelegate`、lifecycle 能力。
- **Exit Criteria**：四项设置行为与锁定 spec 一致；主动 Bubble 可关闭且不重复刷屏；用户主动查看仍可用；菜单忙碌时禁用正确；入口全部复用单一 Main Window。

推荐顺序是 M1.1 → M1.2 → M1.3 → M1.4 → M1.5。M1.4 可在 M1.2/M1.3 完成后并行准备，但最终验收仍要先有 shared state presentation。

## 14. Validation Strategy

### Source and state validation

- 每个 slice 只修改其 feature owner 和必要的 shared presentation；不改 PRD、MVP Scope、Feature Spec、UI Spec、Roadmap 的产品要求。
- 用 Swift Testing 覆盖 metric normalization、trend buffer、Overall severity、Cleanup CTA eligibility、Safe/Review selection、partial failure 和 login-item error state。
- Cleanup 使用 temporary fixture directories + fake Trash mover；禁止测试扫描或移动真实用户 Cache/Logs/DerivedData。
- 检查异步竞态：重新扫描覆盖旧结果、重复 Scan/Quick Clean 被阻止、应用退出/睡眠唤醒不把未完成操作报告为成功。

### Manual UI matrix

| Area | 必测状态 |
|---|---|
| Main Window | 首次打开、指定页面打开、重复打开复用、关闭后 Joey 继续运行、最小尺寸 |
| Overview | Loading、Normal、Notice/Warning、Critical、单项 unavailable、趋势采样不足、Cleanup 未扫描/有摘要 |
| Cleanup | Initial、Scanning、Safe only、Review only、Safe + Review、No Cleanup Needed、Cleaning、Completed、Partial Failure、Error |
| Settings | 四项可用、Launch updating、注册失败、重置位置后回桌面 |
| Bubble | informational/action/success/warning、边缘屏幕、主动关闭、超时、替换、重复 warning、busy action |
| Context Menu | 正常、scanning、cleaning；固定顺序、禁用项、Quit 与 Close 区别 |

### Acceptance evidence

- 使用实际 Debug App 检查页面层级、键盘焦点、VoiceOver labels、对比度和 Reduce Motion 基本行为。
- 记录截图只作为临时审查资料，不进入仓库、不写入 planning doc；完成后删除临时截图。
- 每个实现 slice 完成后运行项目 build/test；UI/runtime 变化还要进行一次手动 macOS 窗口与桌面入口检查。

## 15. Out of Scope

- 不增加 Dashboard、Activity、History、Tools、Monitor、Pet Center、AI、Tasks、Marketplace、Account 等一级页面。
- 不增加 Battery、GPU、Disk I/O、Process List、Network Connections、SMART、Load Average、Swap Dashboard、CPU Frequency。
- 不做 process manager、kill process、memory cleaner、CPU optimizer、fan control、network manager。
- 不新增 Cleanup root；不永久删除、不自动清空 Trash、不使用 sudo、不要求 Full Disk Access。
- 不实现 Fan RPM / Exact Temperature，除非其独立技术验证满足 Conditional 约束；不从 Thermal State 推算温度。
- 不做长期历史、7/30 天图表、custom range、数据库、云同步、运行时网络服务或第三方运行时依赖。
- 不重做 Sprite、animation、locomotion、BehaviorEngine；只处理 Bubble / Context Menu 作为入口的衔接。
