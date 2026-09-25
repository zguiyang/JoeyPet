# JoeyPet MVP Roadmap

路线图按产品 Milestone 管理，不再追加 Phase 6、Phase 7 之类的技术编号。状态依据 Product Acceptance，不依据“代码是否存在”。

## MVP M0 — Product Definition

**Status: Done**

锁定 PRD、V1 Scope、Feature Spec、[Design.md](../../Design.md)（Stitch 上游）与本 Roadmap，建立产品 Source of Truth 和冲突处理规则。

**Exit Criteria**：产品文档与 Design.md 完成，旧 UI Spec 已退役，V1 边界和验收标准可被新开发任务直接引用。

## MVP M1 — UI Foundation

**Status: In Progress**

重新整理 Main Window 基础：Stitch 两栏壳（Joey Stage + Inspector）、Mac Care / Work Rhythm 分段、Settings 独立界面、布局、文字层级、间距、共享状态呈现、共享 loading/error 呈现，并移除临时或 debug-looking 的视觉结构。Mac Care 同时完成 Lightweight Mac System Overview 的 presentation：Overall Mac Status、CPU、Memory、Memory Pressure、Storage、Network、Thermal、短时趋势，以及可靠性允许时的 Conditional hardware metrics。

**Dependencies**：[Design.md](../../Design.md)、Stitch 冻结稿、当前系统状态与 Cleanup 数据契约；CPU Usage、Memory Usage、Network Activity 的 V1 data sources 需要在本 Milestone 补齐。Fan RPM 与 Exact Temperature 只需在可靠方案通过技术验证时纳入。

**Entry Criteria**：Design.md 与 Stitch IA 已对齐；不新增 Stitch 未定义的顶层导航范式。

**Exit Criteria**：主窗口壳与 Mac Care / Work Rhythm / Settings 的主要操作和真实状态符合 Stitch 与 Design.md；Mac Care 能以轻量方式呈现 V1 metrics 与短时趋势，用户不需要阅读长说明才能理解当前 Mac 状态和下一步。

## MVP M2 — Desktop Joey Experience

**Status: In Progress**

把“功能正常”整理为自然的桌面体验：ambient cadence、短距离 locomotion、严重程度视觉反馈、Bubble UX、左/右键交互、Context Menu 和中断行为。

**Dependencies**：M1 的共享状态与文案原则；现有 Runtime 能力。

**Entry Criteria**：桌宠不新增系统能力，已有状态和动画可被产品验收。

**Exit Criteria**：正常状态安静；警告能打断 ambient 行为；walking 移动不频繁；Bubble 不刷屏；右键菜单入口和忙碌禁用规则清楚。

## MVP M3 — Cleanup Experience

**Status: In Progress**

完成 Cleanup 的产品路径：Scan、Quick Clean、Review、Confirmation、Execution、Partial Failure、Result 和 Joey feedback。

**Dependencies**：M1 页面状态基础；现有三个 Cleanup roots、Safe/Review 规则和 Move to Trash 能力。

**Entry Criteria**：不增加新的 Cleanup Root，不改变安全边界。

**Exit Criteria**：用户能区分可快速处理与需要判断的内容；所有改变文件的动作都有用户触发和确认；无结果、失败和部分成功都可继续操作。

## MVP M4 — Settings & Lifecycle Completion

**Status: Ready for Product Review**

验收已有 Settings、position、login item、window lifecycle、sleep/wake；确保设置只包含 V1 四项，关闭主窗口不退出，位置和设置在重启后仍符合预期。

**Dependencies**：M1 的 Settings 结构；macOS 登录项和多屏测试环境。

**Entry Criteria**：四项设置的行为规则已锁定，生命周期边界不可由 UI 文案误导。

**Exit Criteria**：设置即时生效且错误可解释；Quit 才结束应用；睡眠唤醒后传感、ambient、Bubble 与 Cleanup 状态安全恢复。

## MVP M5 — Beta Hardening

**Status: Not Started**

覆盖真实 Beta 使用中的 bug、多屏、睡眠唤醒、权限失败、文件系统边界、文案、UI 状态完整性、合理性能和崩溃处理。

**Dependencies**：M1–M4 产品验收完成。

**Entry Criteria**：核心用户路径在本地可完成，产品范围冻结。

**Exit Criteria**：阻断问题关闭；安全边界和主要错误路径有证据；必要的性能优化只在真实问题被确认后进行。

## MVP RC — Release Candidate

**Status: Not Started**

完成 App icon、versioning、Developer ID、codesign、notarization、DMG、README、GitHub release 和基本 release checklist。

**Dependencies**：M5 Beta 结果与可安装构建。

**Entry Criteria**：V1 Done Definition 满足，发布资产和版本信息已确定。

**Exit Criteria**：用户可安装并启动 RC；签名、公证、安装与核心路径通过检查。Auto Updater 不包含在本 Milestone。

## Milestone Order

`M0 → M1 → M2 / M3 → M4 → M5 → RC`

M2 与 M3 在基础 UI 稳定后可以并行推进，但任何新开发任务都必须引用 Feature ID、所属 Milestone 和验收标准。
