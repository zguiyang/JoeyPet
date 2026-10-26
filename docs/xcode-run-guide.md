# 在 Xcode 里运行 JoeyPet / 查看 Calm Space 新设计

本文对应本机当前工作区（`feature/calm-space-main-window`，含未提交改动）。

## 1. 现在的应用只有一个

旧的多份构建产物与旧安装副本已移到废纸篓，当前只剩 Xcode 的 Debug 产物：

```
~/Library/Developer/Xcode/DerivedData/JoeyPet-gwfhbklqvwahpsbthceimgkwhcmw/
  Build/Products/Debug/JoeyPet Dev.app
```

- 名为 **JoeyPet Dev.app** 是 Debug 构建（bundle id `com.zguiyang.JoeyPet.dev`），不是另一个软件。
- 每次在 Xcode 里 ⌘R，会更新这一个 app。
- Release 构建需要 Apple Developer Team（Signing & Capabilities）；本地 Debug 已改为
  “Sign to Run Locally”（ad-hoc），不需要开发者账号。

## 2. Xcode 里如何编译 / 运行

1. 打开 `/Users/joyzhao/Desktop/yang/DreamerWorks/JoeyPet/JoeyPet.xcodeproj`。
2. 顶部 Scheme 选择器里有三个方案：
   - **JoeyPet**：正常开发/运行（显示当前产品界面）。
   - **Calm Space Stage - Mac Care**：直接打开新设计的 Mac Care Stage（隔离原型）。
   - **Calm Space Stage - Work Rhythm**：直接打开新设计的 Work Rhythm Stage（隔离原型）。
3. Destination 选 **My Mac**。
4. **⌘B** 编译；**⌘R** 运行。
5. 如需重新开始：**⇧⌘K**（Clean Build Folder）后再 ⌘R。

## 3. 启动行为（已调整）

JoeyPet 仍是**菜单栏 + 桌面宠物**类型 App，但启动行为已改为：

- **正常启动（Finder 双击 / Dock / Xcode ⌘R）会自动打开主窗口**，不需要再找菜单栏入口；
- 首次运行若权限引导尚未完成，同一个窗口会先显示权限引导页，完成后进入主窗口；
- 菜单栏**帽子图标 → 「打开 JoeyPet」**仍然保留，作为随时重新打开窗口的入口；
- 关闭主窗口后，再次点击 Dock 图标也会重新打开主窗口（`applicationShouldHandleReopen`）；
- 若开启了「登录时启动」，登录后也会打开主窗口（如不希望这样，后续可加开关）。

两个 **Calm Space Stage** 方案是「设计预览」专用：⌘R 后会**直接打开** 1024×680 的主窗口，
显示新设计（右上角有「原型预览 · 模拟数据」标记，数据为 MOCK）。
窗口尺寸/主题等由启动参数控制。

> 注意：正常 Scheme 打开的是**当前正式产品界面**（旧球体/圆盘）；新 Stage 设计只在两个预览 Scheme 中。


## 4. 切换设计预览的状态 / 主题 / 尺寸

Xcode 菜单 **Product → Scheme → Edit Scheme…（⌘<）→ Run → Arguments**，
修改 `-JoeyPetQAStageState` 后面的值：

- Mac Care：`normal` / `attention` / `critical` / `unknown`
- Work Rhythm：`idle` / `focus` / `paused` / `rest` / `complete`

常用附加参数：

| 参数 | 作用 |
|---|---|
| `-JoeyPetQATheme dark` / `light` | 强制深/浅主题（缺省跟随系统） |
| `-JoeyPetQAWindowSize 1024x680` | 窗口尺寸；可改 `680x512` / `1600x900` |
| `-JoeyPetQAStageFreeze` | 冻结动画到确定性相位（截图/静态对比用） |
| `-JoeyPetQAStaticUI` | 模拟 Reduce Motion（所有循环静止） |
| `-JoeyPetQAHidePet` | 隐藏桌面宠物，只看主窗口 |
| `-JoeyPetQAStageVariant b` | Mac Care 的备选构图 B（地平线能量体，默认 A） |

预览方案里目前没有加 `-JoeyPetQATheme`，会跟随系统深浅色；想固定主题就加一行。
所有 QA 参数只在 Debug 生效，Release 无效。

## 5. 关于 Xcode 之前的报错（已修复）

- **Signing 报错**：「Signing for "JoeyPet" requires a development team」——
  原因是工程里没有配置开发者 Team。已将 Debug 配置改为本地 ad-hoc 签名（Sign to Run Locally）。
- **重复编译警告**：`WorkRhythmStageView.swift` 在 pbxproj 中被注册了两次，已删除重复项。
- 旧的 DerivedData（包含失败的/过期的构建）已重置，Xcode 会重新生成。

如果 Xcode 仍显示旧错误或旧产物：关闭 Xcode → 重新打开工程；必要时
`Preferences → Locations → DerivedData` 删除 JoeyPet 相关目录后再 ⌘R。

## 6. 旧副本与 Alfred

以下旧副本已移至废纸篓（可清空）：

- `build/`（仓库内旧构建目录）
- `.derived-data/`（设计阶段的离线构建产物）
- `~/Library/Developer/Xcode/DerivedData/JoeyPet-…`（旧 Xcode 缓存）
- `~/Applications/JoeyPet Dev.app`（10 月 23 日的旧安装副本）

Alfred 可能还残留旧索引：Alfred Preferences → Advanced → **Rebuild macOS Metadata**，
或忽略它，用 Xcode 的 Scheme 启动即可。

## 7. 正常产品界面 vs 设计预览

当前正式主窗口仍使用**现有 Calm Space 实现**（旧球体/圆盘）；新 Stage 设计是隔离原型，
只在 `Calm Space Stage - …` 两个预览方案中出现。按上一阶段约定，确认视觉方向后再做正式替换。
