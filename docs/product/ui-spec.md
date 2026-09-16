# JoeyPet V1 UI Specification

本文件定义用户看到的结构、信息层级、状态和交互，不规定 SwiftUI 或其他实现方式。视觉细节在 MVP M1 期间落地，但不得改变本文件锁定的产品 IA 和状态语义。

## 1. UI Design Principles

JoeyPet UI 应该 native、quiet、compact、clear、friendly、lightweight。

- Pet first：桌面上的 Joey 是第一入口，Main Window 是按需打开的辅助界面。
- 先给结论，再给原因，再给操作；不要把技术数据堆在第一层。
- 每个页面只保留一个主要动作，次要动作不抢主层级。
- 使用 macOS 原生窗口、菜单、表单和反馈习惯。
- 避免 SaaS Dashboard 外观、大量卡片、渐变背景、装饰性标题、密集数据表和工程术语。
- 如果结构已经能解释含义，不再添加一段重复说明。
- 每个标题、说明和提示语都必须帮助用户理解状态或下一步。

## 2. Information Architecture

```text
JoeyPet
├── Overview
├── Cleanup
└── Settings

非 Main Window UI
├── Desktop Joey
├── Status Bubble
└── Context Menu
```

不新增 Dashboard、Activity、History、Pet、Tools、Monitor 或 About 一级页面。

| 区域 | Purpose | Primary Information | Primary Action | Secondary Action |
|---|---|---|---|---|
| Desktop Joey | 安静存在并表达状态 | Joey 当前动作与严重程度 | 左键查看 Bubble | 右键打开菜单、拖动 |
| Status Bubble | 就地解释或给建议 | 一条短消息 | 相关主要动作 | 查看或等待消失 |
| Context Menu | 提供稳定入口 | 五个日常/退出操作 | 选择入口 | 无 |
| Main Window | 查看状态并完成任务 | 当前页面的结论和状态 | 依页面而定 | 切换一级页面 |

## 3. Main Window Shell

### Purpose

提供一个可复用、紧凑、清晰的 macOS 窗口，承载三个正式页面。

### Structure

- 左侧或等价的一级导航：Overview、Cleanup、Settings。
- 右侧内容区：页面标题、当前状态、主要操作和必要的结果。
- 不使用额外的产品级导航、历史页或监控页。
- 页面可以滚动，但首屏应先展示结论和主要操作。

### Shared Rules

- 窗口打开时进入 Overview，或响应入口动作进入指定页面。
- 再次打开复用同一个窗口，不创建重复窗口。
- 关闭窗口只隐藏 Main Window，Joey 继续运行。
- 所有异步状态都必须有可见的 loading、完成或错误反馈。

## 4. Overview

### Page Goal

用户打开后几秒内知道 Mac 当前是否正常，并能找到 Cleanup 的摘要入口。

### Information Hierarchy

1. **Overall status**：正常、需要留意、需要注意或比较紧张。
2. **Thermal / Memory Pressure / Storage**：三项事实和各自严重程度。
3. **Cleanup summary**：最近一次结果或尚未扫描，以及进入 Cleanup 的入口。

不要用三块同等重量的大卡片制造指标墙。整体状态应由位置、文字和颜色共同表达，不能只靠颜色。

### Primary and Secondary Actions

- Primary：当没有可直接处理的状态时为 Scan and View；如果当前已有 Cleanup 结果，则为进入 Cleanup 查看。
- Secondary：查看具体状态或切换到其他一级页面。

### UI States

| State | 用户应看到什么 | 可用操作 |
|---|---|---|
| Loading | 整体状态区域显示正在读取，不显示猜测值 | 等待 |
| Normal | Mac 状态正常；三项状态简洁排列 | 查看 Cleanup |
| Warning | 明确指出哪一项需要注意，并保留其他状态 | 查看相关状态、进入 Cleanup |
| Critical | 明确指出严重项，主要动作优先 | 查看详情、进入相关 Cleanup |
| Unavailable | 具体项显示暂时不可用和简短原因 | 稍后重试或继续查看其他项 |
| Cleanup not scanned | 显示尚未扫描，不假报没有内容 | Scan and View |
| Cleanup summary | 显示最近结果摘要，不展示候选路径历史 | 查看 Cleanup |

### Implementation Gap

当前实现有三项状态和 Cleanup 摘要，但“整体状态优先”、loading/unavailable 以及页面主次层级仍需 M1 重新整理，标记为 **NEEDS REDESIGN**。

## 5. Cleanup

### Page Goal

让用户安全地扫描有限范围，理解哪些内容可以快速处理，哪些内容应先查看，并完成移入废纸篓。

### Information Hierarchy

1. 当前 Cleanup 状态和一句话结论。
2. 当前主要动作。
3. Safe 与 Review 两组结果及总量摘要。
4. 每项的名称、大小/估算标记、类别和原因。
5. 执行结果与下一步。

不要要求用户阅读或理解 `safe` / `review` 这样的内部 Risk Enum。面向用户可使用“可快速处理”和“建议先查看”之类的自然表达，但行为边界必须保持一致。

### Primary CTA Rules

| 页面状态 | Primary CTA | Secondary CTA |
|---|---|---|
| Initial | Scan | 无 |
| Scanning | 无（显示进度） | 无 |
| Results with Safe | Quick Clean | 查看/选择 Review |
| Results with Review only | 查看并选择 | Scan again |
| No Cleanup Needed | Scan again | 返回 Overview |
| Safe + Review | Quick Clean | Clean Selected（有选择时） |
| Cleaning | 无（显示进度） | 无 |
| Completed | Scan again | 查看结果 |
| Partial Failure | Scan again 或 Retry（按结果决定） | 查看失败项目 |
| Error | Try Again | 返回 Overview |

Quick Clean 永远只处理 Safe。Clean Selected 只有在用户选择项目并完成确认后才可执行。

### Result Grouping

- **可快速处理**：说明这些项目按 V1 规则可以由 Quick Clean 处理。
- **建议先查看**：说明原因，逐项允许用户选择。
- 每个分组可显示数量和总大小；估算值必须带“约”或等价标记。
- 选择控件只出现在需要用户决定的项目上，避免让 Quick Clean 也看起来像批量删除。

### UI States

#### Initial

说明 Cleanup 会扫描三个有限范围，并提供 Scan。不要在未扫描时显示空结果表。

#### Scanning

显示正在扫描和不可重复触发的状态。保留页面结构，不显示上一轮结果冒充当前结果。

#### Results

先显示结论和两个结果分组，再显示项目。用户应能直接知道 Quick Clean 会处理哪一组。

#### No Cleanup Needed

明确显示目前没有需要清理的内容，并提供再次扫描。不能把“扫描没有结果”写成扫描失败。

#### Safe + Review Results

两个分组都可见，但操作边界明确：Quick Clean 只作用于 Safe；Review 需要选择和确认。

#### Cleaning

显示正在把已批准项目移到废纸篓；禁用会重复启动 Cleanup 的入口。

#### Completed

说明多少项目已移到废纸篓，并提供回到结果或重新扫描的动作。

#### Partial Failure

同时显示成功和失败数量；失败项目可查看简短原因，并允许重新扫描或重试。不能用“完成”掩盖失败。

#### Error

说明扫描/执行无法继续的范围和下一步。不要展示长堆栈，也不要假报没有内容。

### Implementation Gap

当前实现已有扫描、Quick Clean、选择、确认、Move to Trash 和部分失败结果，但 Safe/Review 的用户分组、无结果、扫描中覆盖旧结果、错误/部分失败层级仍需重做，标记为 **NEEDS REDESIGN**。

## 6. Settings

### Page Goal

用最少设置控制 Joey 的存在感和登录启动，不为了填满页面而增加选项。

### Structure

**General**

- Launch at Login

**Joey**

- Ambient Behaviors
- Proactive Bubbles
- Reset Joey Position

不增加 quiet hours、sensor selection、utility opt-in、animation speed、theme、account、AI provider 或 advanced cleanup rules。

### Primary and Secondary Actions

- Toggle 是即时生效的主要操作。
- Reset Joey Position 是明确的次要操作，点击后立即回到安全默认位置。
- 登录启动失败时，在开关附近显示短错误和当前真实状态。

### UI States

- `available`：所有设置可操作。
- `updating`：Launch at Login 请求处理时只禁用该项。
- `error`：只在相关设置附近显示错误，不用全页警告。

### Implementation Gap

当前实现范围已经接近 V1，缺口主要是层级、文案和错误状态呈现，标记为 **NEEDS REDESIGN**；不应通过新增设置解决页面留白。

## 7. Context Menu

### Menu Order and Grouping

```text
打开 JoeyPet
快速清理
扫描并查看
设置
────────
退出 JoeyPet
```

### Enable / Disable Rules

| Item | Normal | Scanning | Cleaning |
|---|---|---|---|
| 打开 JoeyPet | enabled | enabled | enabled |
| 快速清理 | enabled | disabled | disabled |
| 扫描并查看 | enabled | disabled | disabled |
| 设置 | enabled | enabled | enabled |
| 退出 JoeyPet | enabled | enabled | enabled |

菜单可以在忙碌时打开；禁用项必须呈现为明确不可用，而不是点击后无反应。Quit 始终是退出应用，不是关闭 Main Window。

### Implementation Gap

当前菜单顺序正确，但尚未按 scanning/cleaning 明确禁用重复操作，标记为 **NEEDS REDESIGN**。

## 8. Desktop Joey Interactions

### Left Click

左键显示当前状态的 Bubble。点击角色外的透明区域不触发操作。

### Drag

拖动角色可改变位置；松开后保存用户位置。拖动不应被 ambient movement 抢占。

### Right Click

右键打开 Context Menu。菜单动作完成后回到 Joey 的正常运行状态。

### Ambient Movement

walking 是低频、短距离、在可见区域内的自然移动。系统 warning/critical 出现时可以打断。临时移动不改变用户保存的位置。

## 9. Bubble

### General Rules

- 通常一到两行；一个 Bubble 只传达一个重点。
- 出现在 Joey 附近，不遮挡主要操作；屏幕边缘要做可见性处理。
- 新 Bubble 替换旧 Bubble，不叠加成通知中心。
- 用户操作后立即消失；没有操作时短暂自动消失。
- Proactive Bubbles 关闭后，不显示主动系统状态 Bubble；用户主动点击 Joey 的反馈仍可用。

### Bubble Types

| Type | When | Duration | Action |
|---|---|---|---|
| Informational | 左键查看或普通状态 | 短暂自动消失 | 无 |
| Action | Storage low 或需要用户决定 | 保留稍长时间或直到操作 | 一个主要动作，可有一个查看动作 |
| Success | Cleanup 全部成功 | 短暂或点击后消失 | 查看结果（可选） |
| Warning | 部分失败、全部失败或需要留意 | 保留稍长时间 | 查看结果/重试（按场景） |

Bubble 不支持对话历史、连续追问、复杂通知队列或长篇解释。

### Implementation Gap

当前已支持短文本、严重程度、动作按钮、超时和成功/失败反馈；类型规则、重复抑制、边缘布局和动作禁用仍需 M2 统一，标记为 **NEEDS REDESIGN**。

## 10. Copy Principles

- 短：删掉不影响行动的背景句。
- 自然：像 Joey 在说话，但不装成聊天机器人。
- 明确：说事实、影响和下一步，不使用模糊的“优化”。
- 非工程术语：把系统枚举和执行结果翻译成用户能理解的话。
- 重要动作说清楚“移到废纸篓”，不写成“删除”或“清理完成”。

Examples:

- Prefer：`磁盘空间有点挤。`；Avoid：`检测到当前设备存储空间已达到警告阈值。`
- Prefer：`已经移到废纸篓。`；Avoid：`Cleanup execution successfully completed.`

示例用于锁定语气，不是要求一次性编写几十条最终文案。

## 11. UI State Completeness Checklist

| Area | Loading | Empty | Normal | Warning | Error | Success | Disabled |
|---|---:|---:|---:|---:|---:|---:|---:|
| Overview | yes | n/a | yes | yes | unavailable | n/a | n/a |
| Cleanup | yes | yes | results | yes | yes | yes | yes |
| Settings | updating | n/a | yes | n/a | login-item error | n/a | per control |
| Bubble | n/a | n/a | informational | warning | n/a | success | action-specific |
| Context Menu | n/a | n/a | yes | n/a | n/a | n/a | busy actions |

只为真实需要的状态设计界面；不为凑齐表格而新增功能。

## Current Implementation Gaps

| Area | Current State | V1 UI Requirement | Gap |
|---|---|---|---|
| Overview | 三项状态、Cleanup 摘要、Scan and View 已有 | 整体状态优先，状态完整且不可用可解释 | NEEDS REDESIGN |
| Cleanup | Scan、Quick Clean、候选选择、确认和结果已有 | 安全分组、全状态、主 CTA 和失败处理清晰 | NEEDS REDESIGN |
| Settings | 四项正式设置大体已有 | 极简分组、即时状态和错误反馈 | NEEDS REDESIGN |
| Bubble | 信息、动作、成功/警告文本与超时已有 | 统一类型、重复抑制、动作与边缘布局 | NEEDS REDESIGN |
| Context Menu | 入口顺序和分组已有 | 忙碌时正确禁用、避免重复操作 | NEEDS REDESIGN |
| Desktop interaction | 左键、拖动、右键、透明点击区已有 | 低频移动与交互优先级经过产品验收 | PARTIAL |
