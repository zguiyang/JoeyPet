# Calm Space Stage — 原型预览索引（Unit 2）

> **渲染方式**：全部图片由原型窗口**离屏渲染**（`-JoeyPetQASnapshotOut`，应用内对自身窗口做
> `bitmapImageRepForCachingDisplay` → PNG → 退出）。这是真实运行中的原型窗口像素，**不是** ImageRenderer
> 概念图、**不是**系统截屏。因捕获时 macOS 处于**锁屏**，未使用 `screencapture`（锁屏下系统截屏只能得到锁屏画面）。
> **交通灯伪影**：离屏渲染时窗口非 key，左上角交通灯呈灰色——这是渲染伪影，非设计问题，不修（见 P2 说明）。
> **数据**：全部 MOCK（`StagePrototypeFixtures` / `WorkRhythmStageFixtures`），不接真实计时 / 扫描 / 持久化。
> 每个窗口右上角常驻「原型预览 · 模拟数据」。
> **构建**：Debug 与 Release 均编译通过；原型仅在 `-JoeyPetQAStagePrototype` 存在时进入，Release 行为不变。
> **自检**：每张图校验 2× 像素尺寸；深色中心无 >85% 白斑（Mac Care 球体 0.9%；Work Rhythm 中心亮像素为
> 象牙色倒计时数字，属前景文字非光斑）；文字对比度达标；`-JoeyPetQAStageFreeze` 两次运行逐字节一致。

> **仓库跟踪范围**：仓库跟踪拼版（`sheets/`）与索引；原始 2× 单图可由 `capture-all.sh` 重新生成，默认不提交。

图片均为 2×（Retina）；显示点尺寸 = 像素 ÷ 2。

---

## Work Rhythm Stage（`previews/work-rhythm/`）

环形时间装置：固定表圈（60 刻度）+ 中性进度轨道 + 12 点起顺时针进度弧（弧头更亮）+ 中央等宽倒计时。
Idle 显示真实本地时间 + 表圈秒点，无虚假进度。Focus 冷雾蓝 / Rest 暖沙，一眼可分。

### 常规 1024×680（2048×1360）
| 文件 | 状态 | 尺寸 | 主题 | 说明 | MOCK |
|------|------|------|------|------|------|
| idle-dark-1024x680.png | idle | 1024×680 | dark | 当前时间 + 「现在」+ 秒点绕行，无进度弧 | 是 |
| focus-dark-1024x680.png | focus | 1024×680 | dark | 24:36 倒计时 + 靛蓝进度弧 + 暂停/结束 | 是 |
| paused-dark-1024x680.png | paused | 1024×680 | dark | 数字降透明、弧变暗、弧头两竖条、继续 | 是 |
| rest-dark-1024x680.png | rest | 1024×680 | dark | 暖沙弧 + 休息中 + 跳过休息 | 是 |
| complete-dark-1024x680.png | complete | 1024×680 | dark | 闭合弧 + 一次性柔光 + 专注完成 | 是 |
| idle-light-1024x680.png | idle | 1024×680 | light | 纸感浅色 | 是 |
| focus-light-1024x680.png | focus | 1024×680 | light | 靛蓝墨色弧 | 是 |
| paused-light-1024x680.png | paused | 1024×680 | light | 浅色暂停 | 是 |
| rest-light-1024x680.png | rest | 1024×680 | light | 暖沙墨色弧 | 是 |
| complete-light-1024x680.png | complete | 1024×680 | light | 浅色闭合弧 | 是 |

### 紧凑 680×512（1360×1024）
| 文件 | 状态 | 尺寸 | 主题 | 说明 | MOCK |
|------|------|------|------|------|------|
| idle-dark-680x512.png | idle | 680×512 | dark | 紧凑装置 ~224pt，无重叠 | 是 |
| focus-dark-680x512.png | focus | 680×512 | dark | 操作行贴近装置、不压 dock | 是 |
| paused-dark-680x512.png | paused | 680×512 | dark | 紧凑暂停 | 是 |
| idle-light-680x512.png | idle | 680×512 | light | 紧凑浅色 | 是 |
| focus-light-680x512.png | focus | 680×512 | light | 紧凑浅色 | 是 |

### 大 1600×900（3200×1800）
| 文件 | 状态 | 尺寸 | 主题 | 说明 | MOCK |
|------|------|------|------|------|------|
| focus-dark-1600x900.png | focus | 1600×900 | dark | 装置放大 ~416pt | 是 |
| rest-dark-1600x900.png | rest | 1600×900 | dark | 大窗口休息 | 是 |
| focus-light-1600x900.png | focus | 1600×900 | light | 大窗口浅色 | 是 |
| rest-light-1600x900.png | rest | 1600×900 | light | 大窗口浅色休息 | 是 |

### 特殊
| 文件 | 状态 | 尺寸 | 主题 | 说明 | MOCK |
|------|------|------|------|------|------|
| focus-longcopy-680x512-dark.png | focus(long) | 680×512 | dark | 1:02:45 长倒计时 + 长文案，构图稳定 | 是 |
| focus-staticui-1024x680-dark.png | focus | 1024×680 | dark | Reduce Motion（`-JoeyPetQAStaticUI`）静止 | 是 |

---

## Mac Care Stage（`previews/mac-care/`，Unit 2 修订重出）

方案 A（精修数字星球）保留。P0/P1 修订已落实：内部流动光改为极柔辉光 + 下右深度层（无硬边椭圆）；
轨道收窄调暗并留在画布内；rim 细化；浅色去廉价光晕；unknown 去饱和为中性灰蓝；长文案状态点贴首行；
large 主体提升到 ~432pt。

### 常规 1024×680 / 紧凑 680×512 / 大 1600×900
| 文件模式 | 状态 | 主题 | 说明 |
|---------|------|------|------|
| `normal/attention/critical/unknown-<theme>-1024x680` | 四态 | dark/light | 健康/关注/处理/未知语义（各 8 张） |
| `normal/attention-<theme>-680x512` | normal/attention | dark/light | 紧凑（各 4 张） |
| `normal/critical-<theme>-1600x900` | normal/critical | dark/light | 大窗口主体放大（各 4 张） |
| `activity-scanning/complete-dark-1024x680` | normal+activity | dark | Activity slot |
| `attention-dark-680x512-longcopy` | attention(long) | dark | 长文案状态点贴首行 |
| `explore-a/b-1024x680-dark` | normal | dark | 方案 A（选定）/ 方案 B（备选） |

修订前后差异见 `notes/mac-care-stage.md`。

---

## 设计说明
- `notes/mac-care-stage.md` — Mac Care Stage 构图 / 材质 / 状态映射 / Unit 2 修订差异。
- `notes/work-rhythm-stage.md` — Work Rhythm 装置结构 / 层级 / 色彩 / 动效 / 实现可行性。
- 视频：未录制（见报告；动效规范已文字化，冻结帧已覆盖各状态）。

---

## 拼版（评审用，`previews/sheets/`）

| 文件 | 内容 |
|---|---|
| `sheets/mac-care-states-dark.png` | Mac Care 四态 · 深色 · 1024×680 |
| `sheets/mac-care-states-light.png` | Mac Care 四态 · 浅色 · 1024×680 |
| `sheets/work-rhythm-states-dark.png` | Work Rhythm 五态 · 深色 · 1024×680 |
| `sheets/work-rhythm-states-light.png` | Work Rhythm 五态 · 浅色 · 1024×680 |
| `sheets/compact-matrix-dark.png` | 680×512 紧凑矩阵（Mac Care normal/attention、Work Rhythm idle/focus） |
| `sheets/large-matrix-dark.png` | 1600×900 大窗口矩阵（Mac Care normal、Work Rhythm focus） |

拼版由 ORCA 从原始 2× 截图生成（`.orca-backup/orca/make-contact-sheets.py`），不改变像素内容。

## 独立复核

- ORCA 用同一 Debug 原型独立执行一次 `-JoeyPetQASnapshotOut` 离屏渲染（`normal-dark-1024x680`），
  与交付文件逐字节一致（2048×1360，max channel diff = 0），确认交付截图可由原型复现。
- 屏幕锁定时系统截屏不可用（`screencapture` 仅得锁屏画面），故全部预览使用应用内离屏渲染；
  解锁后可用 `capture-all.sh` 的 `screencapture` 分支补系统截屏版。
