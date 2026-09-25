# JoeyPet V1 Scope

状态含义：

- **DONE**：实现与产品验收范围基本一致。
- **PARTIAL**：关键路径存在，但仍有明确缺口。
- **NEEDS REDESIGN**：已有实现不能视为最终产品体验，需要按 UI/Feature Spec 重做或整理。
- **MISSING**：V1 必需能力尚不存在。
- **CONDITIONAL**：可选的 V1 能力；只有技术验证满足可靠性、权限和依赖边界时才纳入，不是 V1 blocker。

## V1 Must Have

| 模块 | V1 能力 | 当前实现 |
|---|---|---|
| Desktop Joey | 常驻、像素动画、透明窗口、拖动、短距离 ambient movement、点击与右键入口 | DONE |
| System Awareness | Lightweight Mac System Overview：CPU Usage、Memory Usage、Memory Pressure、Storage Usage、Network Activity、Thermal State，以及有意义的短时趋势 | PARTIAL |
| Bubble | 短解释、必要时一个主要动作、成功/警告反馈、可关闭主动 Bubble | NEEDS REDESIGN |
| Context Menu | 打开、快速清理、扫描并查看、设置、退出 | NEEDS REDESIGN |
| Mac Care | Overall Mac Status、CPU/Memory/Network/Storage/Thermal、短时趋势、清理/扫描流程、Applications（设计范围内） | NEEDS REDESIGN |
| Work Rhythm | 专注/休息/统计（Stitch 冻结稿范围内） | MISSING / PARTIAL |
| Settings | 通用 / 电脑状态 / 工作状态（Stitch 冻结稿）；含 Launch at Login、Joey 行为与位置等 | NEEDS REDESIGN |
| Lifecycle | 关主窗口不退出、Quit 才退出、睡眠唤醒恢复、设置持久化 | DONE |
| Release | 可安装的 macOS Beta/RC 包与基本发布检查 | MISSING |

### V1 Must Have 的边界

- Cleanup 只扫描：Xcode DerivedData、Old User Logs、User Application Caches。
- Safe 项目可由 Quick Clean 处理；Review 项目必须由用户查看、选择并确认。
- 所有执行都移到 macOS Trash；不永久删除、不自动清空废纸篓、不使用 sudo。
- **Baseline cleanup**（三路径 allowlist）不要求 Full Disk Access；**Full Mac Care**（深度分类、Containers/残留扫描等）要求用户在系统设置中授予 **完全磁盘访问**。未授权时为 **Limited Mac Care**，见 [permissions.md](../permissions.md)。
- Joey 的状态使用角色化表达：Thermal serious/critical → sweating；Memory warning/critical → tired；Storage low → carryingTrash。
- `walking` 可以带来短距离桌面移动，但不能频繁移动，并且系统警告可以打断它。
- Overview 的 System Monitoring 与 Joey 的 semantic reactions 分开：CPU Usage、Memory Usage、Network Activity 首先用于 Overview，不自动产生新的 Pet behavior。
- Fan RPM 与 Exact Temperature 是 Conditional；不能为了满足 Overview 伪造或从 Thermal State 推算温度。

## V1 Nice to Have

仅保留不改变核心范围的轻量补充：

- 首次运行时用一条简短提示说明 Joey、右键菜单和安全清理入口。
- Beta 阶段的少量可访问性与文案微调。

Nice to Have 不能引入新传感器、新清理范围、新一级页面或新的数据模型。

## Explicitly Not in V1

### User Activity / Wellness (out of scope unless in Stitch + Feature Spec)

独立于主产品的 Pomodoro 市场功能、Quiet Hours 复杂调度、第三方健康集成。**Work Rhythm** 主窗口模式已在 Stitch 与 [Design.md](../../Design.md) 中定义；实现进度以本表与 Feature F16 为准，不视为“未来才设计”。

### File Organization

Desktop Organizer、Downloads Organizer、自动文件分类。

### System Utilities

Process Manager、Kill Process、Memory Cleaner、CPU Optimizer、Duplicate Finder、Large File Finder、Disk Analyzer。

**Applications / 关联卸载** 在 Stitch Mac Care 流程中有 UI 设计；产品实现须遵守 [`docs/safety.md`](../safety.md) 与确认流程，不等同于无确认的批量卸载工具。

### AI

LLM Runtime、Chat、Agent、自然语言控制、AI companion。

### Characters

Multiple pets、Pet picker、Character customization、Skins、Marketplace。

### Distribution Extras

Developer ID、Notarization、DMG、GitHub Release 属于 MVP RC 的发布工作，不是额外 Product Feature。Auto Updater 不在本路线图内。

## V1 Definition of Done

V1 Done 不是“所有 class 写完”。必须同时满足：

1. 核心用户路径可从启动、状态反应、Mac Care 查看、扫描、确认、移入废纸篓一直走到反馈。
2. 主窗口（Mac Care / Work Rhythm / Settings）的信息层级与状态呈现符合 Stitch 冻结稿与 [Design.md](../../Design.md)。
3. Loading、Empty、Normal、Warning、Error、Success、Disabled 等真实需要的状态可理解。
4. 传感、权限、文件消失、部分失败、屏幕变化、睡眠唤醒等主要错误有明确反馈。
5. Cleanup 的 allowlist、Safe/Review 边界、用户确认和 Move to Trash 行为通过验证。
6. 无新增 V1 外功能、无第三方运行时依赖、无数据库、无网络运行时或 LLM。
7. 完成真实 Beta 使用，修复阻断核心路径的问题。
8. 有可安装的 macOS Release Candidate 包和基本发布检查记录。

## Current MVP Gap Matrix

| Module | Capability | Current State | V1 Requirement | Gap |
|---|---|---|---|---|
| Desktop Joey | 常驻、拖动、透明区域 click-through | DONE | 安静、可拖动、可交互 | None |
| Desktop Joey | Ambient locomotion | DONE | 低频短距离移动，可被警告打断 | Product cadence review |
| System Monitoring | CPU Usage + short trend | MISSING | Overview 当前 CPU 使用情况和短时趋势 | M1 data source |
| System Monitoring | Memory Usage + short trend | MISSING | 当前使用情况；趋势可按产品需要展示 | M1 data source |
| System Monitoring | Memory Pressure | DONE | 独立于 Memory Usage 的健康语义 | None |
| System Monitoring | Storage Usage | DONE | used/free/total 与健康状态 | Overview presentation |
| System Monitoring | Network Activity + short trend | MISSING | Download、Upload 与短时趋势 | M1 data source |
| System Monitoring | Thermal State | DONE | nominal/fair/serious/critical；不是温度 | Overview presentation |
| System Monitoring | Fan RPM | CONDITIONAL | 可靠方案可用时展示 | Technical validation required |
| System Monitoring | Exact Temperature | CONDITIONAL | 可靠方案可用时展示，否则 Thermal fallback | Technical validation required |
| System Awareness | Semantic state → Joey reaction | DONE | Thermal/Memory Pressure/Storage 共享 severity 语义 | Product review |
| Bubble | 信息/动作/成功/警告反馈 | PARTIAL | 短、可替换、不刷屏、动作明确 | NEEDS REDESIGN |
| Context Menu | 入口顺序与忙碌状态 | PARTIAL | 固定分组，重复操作时正确禁用 | NEEDS REDESIGN |
| Mac Care | 整体状态、当前 metrics、短时趋势 | PARTIAL | 几秒内理解 Mac 是否正常 | NEEDS REDESIGN |
| Work Rhythm | 专注/休息/统计 | MISSING | 与 Stitch / F16 一致 | MISSING / PARTIAL |
| Cleanup | 三个冻结根目录的只读扫描 | DONE | 只读、allowlist、可解释候选 | None |
| Cleanup | Safe/Review 的用户理解 | PARTIAL | 不要求用户理解技术枚举 | NEEDS REDESIGN |
| Cleanup | Quick Clean | DONE | 只处理 Safe，用户明确触发 | Product/UI verification |
| Cleanup | Review selection/confirmation | PARTIAL | 只处理明确选择并确认的项目 | NEEDS REDESIGN |
| Cleanup | Result/partial failure | PARTIAL | 成功、失败、部分成功可读且可继续 | NEEDS REDESIGN |
| Settings | 四项正式设置 | DONE | 只保留四项并即时生效 | UI redesign |
| Position | 拖动后保存、跨屏恢复、重置 | DONE | 位置安全持久化 | None |
| Lifecycle | Close ≠ Quit、sleep/wake | DONE | Joey 继续运行并正确恢复 | Beta verification |
| Release | 可安装 RC | MISSING | 签名、公证、DMG、发布清单 | M5/RC |
