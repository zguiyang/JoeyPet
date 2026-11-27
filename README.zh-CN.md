# JoeyPet

[English](./README.md)

一个安静生活在桌面上的宠物，陪伴用户形成更温和的工作与休息节奏。

JoeyPet 是一款原生 macOS 桌面宠物。它会安静地生活在桌面上，并在合适的时候温和邀请用户短暂恢复。

它不是 AI 女友、聊天机器人、任务清单或效率监督工具，而是一只专注于陪伴与恢复节奏的桌面宠物。

## 下载

最新版本：[GitHub Releases](https://github.com/zguiyang/JoeyPet/releases/latest)

- **推荐**：`JoeyPet-*-macOS.dmg` — 打开后把 JoeyPet 拖进「应用程序」
- 也可：`JoeyPet-*-macOS.zip` — 解压后得到 `JoeyPet.app`

**系统要求**：macOS 14 或更高。

### 首次打开

从网上下载的 App，macOS 可能会提示无法验证开发者。按下面做一次即可：

1. 双击打开 App（或从「应用程序」启动）。若弹出「无法打开」之类提示，先点「完成」或关掉。
2. 打开 **系统设置 → 隐私与安全性**，滚到 **安全性** 一节。
3. 看到 JoeyPet 被拦下时，点 **仍要打开**；再确认一次即可。

也可以在 `JoeyPet.app` 上 **按住 Control 再点按 → 打开**，同样会进入确认流程。

装好后：打开小窝即可开始；桌面 Joey 默认隐藏，可在设置或菜单栏打开「在桌面显示 Joey」。

## 仓库结构

```text
macos/        macOS 工程（Xcode 项目、Swift 源码、测试、平台脚本）
docs/         跨平台产品、设计与 ADR 文档
.agents/      仓库级 Agent skills
```

## 文档

- [AGENTS.md](./AGENTS.md) — Agent 开发规则
- [DESIGN.md](./DESIGN.md) — V0 原生 UI/UX 设计契约
- [V0 UI 设计稿](./docs/reference/joeypet-ui-v0.html) — 冻结的视觉参考
- [V0_FEATURE_SCOPE.md](./V0_FEATURE_SCOPE.md) — 当前测试版功能范围
- [开发交接文档.md](./开发交接文档.md) — 当前交接与开发边界

## 设计原则

- 轻量、低资源占用
- 原生 macOS 使用体验
- 隐私友好、本地优先
- 保持有趣和互动感，但不做 AI 陪伴产品
- 温和提醒，不制造压力或监督感
