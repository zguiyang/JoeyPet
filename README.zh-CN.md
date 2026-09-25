# JoeyPet

[English](./README.md)

一个生活在桌面上的像素宠物，能够展示 Mac 的轻量运行概览，并帮助处理安全、简单的日常维护任务。

JoeyPet 是一款原生 macOS 桌面宠物工具。它会安静地生活在桌面上，根据电脑当前的运行状态产生不同的动作和反馈。

它不是 AI 女友、聊天机器人或通用 AI 助手，而是一只专注于电脑日常小事务的桌面宠物。

当前 MVP 关注：

- 当系统热压力升高时，宠物可能会冒汗
- 当内存压力较高时，宠物会表现出疲惫状态
- 当磁盘空间较低时，宠物可能拖着垃圾桶出现
- 扫描有限范围，并在用户确认后将允许处理的内容移到废纸篓

V1 Overview 目标包括 CPU、内存、存储、网络和 Thermal 的当前状态与有意义的短时趋势；这属于 System Monitoring，不提供进程管理或系统优化。

JoeyPet 不是 AI 陪伴、聊天机器人或系统监控 Dashboard。V1 暂不包含桌面/下载目录整理与无确认的激进系统工具；**Work Rhythm** 与 **Mac Care** 主窗口体验以 Stitch 与 [Design.md](./Design.md) 为准。

## 当前状态

项目目前处于 macOS 桌面宠物 MVP 的持续开发阶段。

第一版本将优先支持 macOS，并使用 Swift 原生技术栈进行开发。

## 文档

- [AGENTS.md](./AGENTS.md) — Agent 开发规则
- [Design.md](./Design.md) — UI/UX 原生实现规范（Stitch 上游）
- [docs/product/](docs/product/) — 产品 Source of Truth：PRD、V1 范围、功能规格与路线图
- [docs/](docs/) — 技术架构、传感器、安全、生命周期与 ADR

## 设计原则

- 轻量、低资源占用
- 原生 macOS 使用体验
- 隐私友好、本地优先
- 默认以只读方式感知系统状态
- 涉及删除或修改数据时必须明确确认
- 保持有趣和互动感，但不做 AI 陪伴产品
- 专注于简单、实用的电脑日常小功能
