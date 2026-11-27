# JoeyPet

[English](./README.md)

一只安静的桌面宠物，陪你把工作和休息的节奏放得更温和一些。

JoeyPet 会生活在 macOS 桌面上，陪你工作，并在合适的时候邀请你短暂恢复。它不是聊天机器人、待办清单或效率监督工具——只是一只愿意和你共度一天的小宠物。

## 功能

- **桌面 Joey** — 可拖动、隐藏与找回；默认不打扰
- **工作陪伴** — 由你主动开始会话，Joey 跟着你的节奏
- **温和休息邀请** — 稍后提醒、休息一下，或进入勿扰
- **短恢复** — 眺望、站立揉眼、走动伸展、喝水；文案与时长会轮换
- **共同成长** — 小窝与回顾会随陪伴慢慢变化
- **本地优先** — 无账号、无云同步、无分析上报

## 下载

最新版本：[GitHub Releases](https://github.com/zguiyang/JoeyPet/releases/latest)

| 文件 | 用法 |
|------|------|
| `JoeyPet-*-macOS.dmg` | 打开磁盘映像，把 JoeyPet 拖进「应用程序」 |
| `JoeyPet-*-macOS.zip` | 解压得到 `JoeyPet.app` |

**系统要求**：macOS 14 或更高。

### 首次打开

从网上下载的 App，macOS 可能首次拦截。任选一种方式处理一次即可：

**方式 A — 系统设置**

1. 打开 JoeyPet。若提示无法打开，先关掉该对话框。
2. 打开 **系统设置 → 隐私与安全性**。
3. 滚到 **安全性**。看到 JoeyPet 被拦下时，点 **仍要打开**，再确认一次。

**方式 B — 终端命令**

```bash
xattr -cr /Applications/JoeyPet.app
```

若 App 还不在「应用程序」里，把路径改成你放置 `JoeyPet.app` 的位置，然后正常打开即可。

也可以在 App 上 **按住 Control 再点按 → 打开**，效果与方式 A 相同。

### 装好之后

打开小窝即可开始。桌面 Joey 默认隐藏，可在设置或菜单栏打开「在桌面显示 Joey」。

## 隐私

设置与轻度统计保存在本机（UserDefaults）。JoeyPet 可能使用系统空闲时长判断你是否离开，不会读取键鼠内容。反馈通过 mailto，无后台上传。

## 从源码构建

```bash
open macos/JoeyPet.xcodeproj
```

使用 **JoeyPet** scheme、**Release** 配置，目标选 **My Mac**。

## 仓库结构

```text
macos/        macOS 工程（Xcode 项目、Swift 源码、测试、平台脚本）
docs/         产品、设计与 ADR 文档
.agents/      仓库级 Agent skills
```

## 文档

- [AGENTS.md](./AGENTS.md) — Agent 开发规则
- [DESIGN.md](./DESIGN.md) — 原生 UI/UX 设计契约
- [UI 设计稿](./docs/reference/joeypet-ui-v0.html) — 冻结的视觉参考
- [V0_FEATURE_SCOPE.md](./V0_FEATURE_SCOPE.md) — 产品范围
- [开发交接文档.md](./开发交接文档.md) — 交接说明

## 设计原则

- 轻量、低资源占用
- 原生 macOS 体验
- 隐私友好、本地优先
- 有趣但不做成 AI 陪伴产品
- 温和提醒，不制造压力或监督感
