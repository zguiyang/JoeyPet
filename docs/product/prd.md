# JoeyPet PRD

## 1. Product Summary

JoeyPet 是一只生活在 Mac 桌面上的像素宠物：它感知 Mac 的基本状态，用表情、动作和轻提示告诉用户发生了什么，并帮助用户完成安全、简单的日常维护任务。

核心表达：**平时是宠物，有事是工具。**

## 2. Problem

传统系统工具通常只有在用户主动打开时才出现。用户因此要么看不到值得注意的状态，要么必须打开复杂的监控或清理工具才能处理一件小事。

JoeyPet 要解决的是“系统状态和少量维护任务如何自然进入日常桌面体验”。它常驻但安静，在有必要时提供可理解的反馈和下一步操作；其中 Overview 是轻量的 Mac System Overview，而不是专业监控或系统管理套件。

## 3. Target User

V1 面向长期使用 Mac、每天在桌面工作较长时间、愿意使用桌面宠物，并希望快速了解基础设备状态和处理简单维护任务的人。

用户不希望每天打开复杂的系统工具，也不希望宠物频繁打断工作。开发者是 DerivedData 场景的典型用户，但 JoeyPet 不只服务开发者。

## 4. Jobs to Be Done

- 当 Mac 出现值得注意的状态时，我希望不用打开系统监控软件，也能知道发生了什么。
- 当 Mac 积累了一些可以安全处理的内容时，我希望用很少的步骤完成清理，并知道文件去了哪里。
- 当某些内容需要我判断时，我希望先看到原因，再决定是否处理。
- 当电脑一切正常时，我希望 Joey 安静地生活在桌面，不要求我持续操作。
- 当我打开 JoeyPet 时，我希望几秒内理解 Mac 当前是否正常，以及能做什么。

## 5. Product Promise

JoeyPet 平时是一个轻量、安静的桌面存在；当 Mac 有值得注意的状态，或用户需要做一件小维护任务时，它用角色化但不含糊的反馈把事实、建议和操作连接起来。

它不会替用户擅自改变文件或系统设置。涉及用户数据的动作必须由用户发起并且可解释、可恢复优先。

## 6. Product Principles

- **Pet First**：Joey 首先是宠物，不是工具面板。
- **Useful When Needed**：只有有用时才主动出现操作建议。
- **Safe by Default**：读取得到的事实与改变数据的动作严格分开；清理优先移到废纸篓。
- **Quiet by Default**：减少打扰，同一提醒不能反复刷屏。
- **Native Mac Experience**：遵循 macOS 的窗口、菜单、设置和权限习惯。
- **Functional over Complexity**：先把用户路径和状态做完整，不用复杂架构包装简单功能。

## 7. Core Experience Loop

JoeyPet 的核心循环是：

`Observe → Detect → Explain → Recommend → Approve → Act → Feedback`

传感与扫描先观察；只有达到产品定义的状态才反应；Bubble 或页面解释事实；需要改变数据时给出建议；用户明确批准后才执行；完成后反馈结果并回到安静的桌面状态。

## 8. V1 Core Journey

应用启动后 Joey 出现在桌面并保持 ambient 状态。系统状态发生变化时，Joey 以对应动作和严重程度反应；必要时显示一条短 Bubble。用户可以打开主窗口查看 **Mac Care**（含系统状态与清理流程），或从 Bubble、右键菜单进入扫描与清理。清理扫描允许的范围，展示可安全处理和需要查看的内容；用户触发 Quick Clean 或选择并确认项目后，文件被移到废纸篓并显示成功或失败结果。反馈结束后 Joey 回到 ambient 状态，应用继续安静运行。

## 9. Lightweight Mac System Overview

**Mac Care** 中的系统状态区让用户在几秒内理解 Mac 当前运行状态（产品能力亦称 Lightweight Mac System Overview）。它展示当前值，并在有意义的指标上提供短时间趋势：

- CPU Usage：当前使用情况与短时趋势。
- Memory Usage：当前使用情况；同时独立显示 Memory Pressure 这一健康语义。
- Storage Usage：used、free、total 与当前存储健康状态。
- Network Activity：Download、Upload 与短时趋势。
- Thermal State：macOS 的 nominal、fair、serious、critical 状态。
- Fan RPM、Exact Temperature：只有在可靠、稳定且权限合理时才显示；否则保留 Thermal State，不猜测或伪造数值。

System Monitoring 与 System Management 分开。Overview 不显示进程列表，不结束进程，不提供优化动作，也不承担硬件诊断。趋势只属于当前运行 session，不需要长期历史、数据库或指标持久化；应用重启后可以重新开始。

CPU Usage、Memory Usage、Network Activity 首先服务 Overview，不自动新增 Joey 行为。Joey 的语义反应仍由正式的 Thermal、Memory Pressure、Storage 状态定义。

## 10. Success Criteria

V1 以可观察的产品结果判断成功：

- 用户能理解 Joey 为什么改变表情、动作或严重程度。
- Thermal、Memory Pressure、Storage 三种状态能被稳定、正确地表达。
- 用户在 Mac Care 中能看到 CPU、Memory、Storage、Network 和 Thermal 的当前状态；CPU、Memory、Network 在适合时能看到短时趋势。
- Fan RPM 与 Exact Temperature 不可用时，Mac Care 不伪造数值，并能清楚说明不可用。
- 用户可以完成一次从扫描、判断、确认到移入废纸篓的 Cleanup 流程。
- 用户打开 Main Window 后能理解 Mac Care、Work Rhythm、Settings 的用途和当前状态（见 [Design.md](../../Design.md)）。
- 正常状态下 Joey 不频繁打扰；同一警告不会重复刷出。
- 关闭 Main Window 后 Joey 仍然运行，用户可以持续使用并恢复设置与位置。
- 真实 Beta 使用中，核心路径的错误、权限、屏幕切换和睡眠唤醒行为可解释、可恢复。

## 11. Non-goals

V1 不做：

- AI companion、LLM runtime、聊天、Agent 或自然语言控制。
- Memory Cleaner、CPU Optimizer。
- 全盘清理、磁盘分析、重复文件或大文件工具。
- Desktop/Downloads Organizer 和自动文件分类。
- 电池、GPU、Disk I/O、进程列表、网络连接、SMART、CPU 频率、swap dashboard、load average 等未纳入 V1 的指标。
- Process Manager、Kill Process、CPU/Memory Optimizer 或其他系统管理动作。
- Idle/Active Duration、Break Reminder、Pomodoro、Quiet Hours。
- 多角色、角色选择、换肤、Marketplace。
- 云端同步、数据库、运行时网络服务。
- Auto Updater。
