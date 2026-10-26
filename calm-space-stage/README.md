# Calm Space 双模式 Functional Stage — 设计交付（V1 设计阶段）

本目录是 **Mac Care / Work Rhythm 双模式 Stage** 的高保真设计与隔离原型交付物。
本阶段只做设计验证，**未替换正式主窗口业务**。

- 设计规范：[docs/calm-space-stage-design.md](../docs/calm-space-stage-design.md)
- 在 Xcode 里运行/查看预览：[docs/xcode-run-guide.md](../docs/xcode-run-guide.md)
- 原型代码：`src/JoeyPet/Features/CalmSpace/StagePrototype/`（全部 `#if DEBUG`，仅在
  `-JoeyPetQAStagePrototype` 下进入，Release 行为不变）
- 预览索引：[previews/INDEX.md](previews/INDEX.md)
- 设计说明：[notes/mac-care-stage.md](notes/mac-care-stage.md)、[notes/work-rhythm-stage.md](notes/work-rhythm-stage.md)

## 预览

| 模式 | 交付状态 |
|---|---|
| Mac Care | normal / attention / critical / unknown × dark / light；compact 680×512、large 1600×900；Activity（检查中/完成）、长文案 |
| Work Rhythm | idle / focus / paused / rest / complete × dark / light；compact、large；长文案+长倒计时、Reduce Motion |

目录：`previews/mac-care/`、`previews/work-rhythm/`、`previews/sheets/`（拼版）、`previews/INDEX.md`。

> **仓库跟踪范围**：仓库只跟踪设计说明、脚本、索引、6 张拼版和少量 Xcode 运行截图；
> 42 张原始 2× 预览体积较大且可由 `capture-all.sh` 重新生成，默认不提交（见 `.gitignore`）。

### 渲染方式（重要说明）

所有预览图由**应用内离屏窗口渲染**生成（`-JoeyPetQASnapshotOut`：对运行中的原型窗口做
`bitmapImageRepForCachingDisplay` → PNG → 退出）：

- 这是**真实运行的原型窗口像素**，不是 ImageRenderer 概念图，也不是静态设计资产；
- **不是系统截屏**（`screencapture`）：捕获时 macOS 处于锁屏，系统截屏只能得到锁屏画面，
  因此在应用内自渲染。若需系统截屏版，解锁后运行 `capture-all.sh` 的 screencapture 分支即可；
- 离屏渲染时窗口非 key，交通灯呈灰色，属渲染伪影，不是设计问题；
- 全部内容为 **MOCK**（`StagePrototypeFixtures` / `WorkRhythmStageFixtures`），窗口右上角常驻
  「原型预览 · 模拟数据」徽标。

## 复现 / 重新截图

```bash
cd /Users/joyzhao/Desktop/yang/DreamerWorks/JoeyPet

# Debug 构建（截图用）
xcodebuild -project JoeyPet.xcodeproj -scheme JoeyPet -destination 'platform=macOS' \
  -derivedDataPath .derived-data/calm-space-qa \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual JOEYPET_DEVELOPMENT_TEAM="" build

# 离屏渲染全部预览（无需屏幕录制权限，锁屏下也可用）
bash calm-space-stage/capture-all.sh

# 或单个配置
APP="$PWD/.derived-data/calm-space-qa/Build/Products/Debug/JoeyPet Dev.app"
"$APP/Contents/MacOS/JoeyPet Dev" \
  -JoeyPetQAOpenMain workRhythm -JoeyPetQAStagePrototype workRhythm \
  -JoeyPetQAStageState focus -JoeyPetQAStageFreeze \
  -JoeyPetQAWindowSize 1024x680 -JoeyPetQATheme dark -JoeyPetQAHidePet \
  -JoeyPetQASnapshotOut "$PWD/calm-space-stage/previews/work-rhythm/focus-dark-1024x680.png"
```

QA 参数（全部 DEBUG-only，Release 无效）：

- `-JoeyPetQAStagePrototype macCare|workRhythm`
- `-JoeyPetQAStageState normal|attention|critical|unknown|idle|focus|paused|rest|complete`
- `-JoeyPetQAStageFreeze`：冻结动画到确定性相位（截图可复现）
- `-JoeyPetQAStageLongCopy`：长文案/长倒计时压力测试
- `-JoeyPetQAStageVariant a|b`：Mac Care A/B 构图（a 为选定方案）
- 复用：`-JoeyPetQAWindowSize WxH`、`-JoeyPetQATheme dark|light`、`-JoeyPetQAHidePet`、`-JoeyPetQAStaticUI`
- `-JoeyPetQASnapshotOut <abs.png>`：离屏渲染窗口并写 PNG 后退出

## 设计要点速览

- **Mac Care**：非对称光照的数字星球（无中心白热/无同心圆层），一条前后遮挡的细轨道；
  主体 → 结论 → 语境/操作，action chip 只在可操作时出现；Activity slot 预留检查/维护/完成反馈。
- **Work Rhythm**：固定表圈（60 刻度）+ 进度轨道 + 12 点起顺时针进度弧 + 中央等宽倒计时；
  Idle 显示真实时间与秒点、无虚假进度；Focus 靛蓝 / Rest 暖沙；暂停冻结；完成一次性柔光；
  操作紧贴装置，今日统计只在右下外围。
- 深浅主题独立调校；三档窗口自适应；Reduce Motion 全部静止；无新增运行时依赖。

## 验证状态

- Debug / Release 构建通过。
- 测试通过（含 `CalmSpaceStageLayoutTests`：Stage 几何不重叠、长文案、长倒计时、状态语义断言）。
- `-JoeyPetQAStageFreeze` 两次运行输出逐字节一致。
- 像素自检：深色中心无 >85% 白斑；文字与背景对比度达标。
