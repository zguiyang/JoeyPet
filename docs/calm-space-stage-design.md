# Calm Space 双模式 Stage 设计规范（V1 设计阶段）

> 状态：设计验证完成，待用户确认视觉方案。
> 范围：只做高保真设计、状态化信息结构与实现可行性验证；**未**进入正式业务替换。
> 预览：`calm-space-stage/previews/`（离屏窗口渲染，全部 MOCK 数据）。
> 原型：`src/JoeyPet/Features/CalmSpace/StagePrototype/`（DEBUG-only，`-JoeyPetQAStagePrototype` 进入）。

## 1. 阶段定位

两个模式不再共用「动画 + 标题 + 描述」模板，而是两个独立的 **Functional Stage**：

- **Mac Care Stage**：系统视觉主体 → 健康结论 → 语境/操作。有机、垂直、文字主导。
- **Work Rhythm Stage**：时间装置（含倒计时）→ 当前阶段 → 计时操作 → 外围统计。几何、径向、数字主导。

共享 Calm Space 基础语言（背景、主题、字体、悬浮控件、窗口适配、低频动效），但中央构图与信息结构
**按语义独立设计**，不为复用强行统一。

## 2. 共享设计语言

- **窗口**：沉浸式全窗口背景；原生交通灯；右下模式切换；左下悬浮 dock；不使用卡片/面板/分割线堆叠。
- **字体**：SF Pro。标题 semibold + 负 tracking；正文 regular；时间数字 `.monospacedDigit()`。中文文案克制具体。
- **主题**：深/浅独立调校，不是反色。深色 = 深墨蓝夜色 + 低饱和材质；浅色 = 雾面纸感 + 清晰边缘。
- **动效原则**：低频（呼吸 7–12s、轨道 60–120s、进度过渡 0.4–0.8s）、可暂停、尊重 Reduce Motion；
  所有循环在 `-JoeyPetQAStaticUI` / 系统 Reduce Motion 下静止。不依赖第三方动画库。
- **状态语义色**（Mac Care）：normal 青绿 / attention 低饱和琥珀 / critical 低饱和珊瑚 / unknown 中性灰蓝。
- **Work Rhythm 语义色**：focus 雾蓝-靛蓝 / rest 低饱和暖沙 / paused 中性灰 / idle 中性冷。
  两组色系互不混淆：Mac Care 青绿有机，Work Rhythm 靛蓝+暖沙仪器感。

### 2.1 动效清单（元素 / 驱动源 / 动态内容 / 实现）

| 模式 | 持续运动 | 业务状态驱动 | 动态文字/控件 | 操作反馈 |
|---|---|---|---|---|
| Mac Care | 呼吸 8s（振幅 ≤0.8%）；轨道 90–120s 缓转；内部柔光 12–20s 明暗 | 健康等级切换：材质/色温/亮度 0.8–1.2s 交叉过渡；attention 呼吸更慢更浅；critical 轨道前段略亮；unknown 去饱和 | headline/detail/meta/action chip/activity slot 随状态替换 | chip hover 提亮 + 轻微 scale；dock 沿用现有 hover |
| Work Rhythm | idle 秒点 60s/圈；focus 进度弧随真实时间 1Hz 推进；弧头光晕 5s 呼吸；rest 8–12s；complete 一次性 1.2s 光晕 | 倒计时、进度、阶段（idle/focus/paused/rest/complete）；paused 全部冻结 | 倒计时数字、阶段标签、次级信息、操作按钮、今日统计 | 按钮 hover 提亮；暂停/继续/结束即时切换状态 |

实现：两模式 Stage 均可用 **SwiftUI Shape / Canvas / Gradient / TimelineView（低频）** 完成，无需 SpriteKit；
Mac Care 的呼吸用隐式动画（GPU 组合），Work Rhythm 计时用真实时间差计算、帧率不影响准确性。
相对现有实现属于**中等复杂度新增**（替换 1435 行 OrbScene + 615 行 RhythmScene，净复杂度下降）。
统一气质靠：相同背景家族、相同字体层级、相同 dock/切换控件、相同的低频 + Reduce Motion 规则。

## 3. Mac Care Stage

### 3.1 构图

主体居中略偏上 → 1px 短竖线连接 → 结论块（状态行 / 解释句 / Activity slot / 语境操作行）。
信息块宽度封顶（regular ≤520pt，compact ≤460pt），顶对齐向下生长，永不压底部控件。

### 3.2 视觉主体（方案 A：精修数字星球）

- 非对称光照：主光左上约 35°，右下柔和明暗交界；**无中心白热亮斑**。
- limb darkening（球缘 8–14% 变暗）+ 少量大气壳 + 同向极柔内部辉光（无可见形状边缘）+ 下右深度层。
- rim light：只在下右背光侧一条 ~55° 细弧（主线 0.45 alpha / 1.4pt + 柔光 0.14 / 3.7pt）。
- 轨道：单条细带，a≈1.28–1.34r、b≈0.34–0.38r、tilt≈−16°；球后穿过、前方 ~30% 段渐隐跨过下半部；
  整条轨道留在画布内。轨道椭圆中心必须与球心重合（原型此前的偏移 bug 已在 Unit 3 修复）。
- 装饰上限：全窗口微星 ≤6，静止或 60s+ 极慢；禁止粒子雨/同心圆渐变层/雷达扫描。

### 3.3 状态 → 视觉

| 状态 | 主体 | 文案/操作 | 语义 |
|---|---|---|---|
| normal | 冷青绿；慢呼吸 8s/≤0.8%；轨道 90–120s 缓转 | 无按钮，仅「上次检查 / 3 项正常」 | 健康、稳定 |
| attention | 呼吸更慢更浅；rim 暖染 | headline 说明原因 + inline action chip（如「查看存储」） | 需要关注 |
| critical | 呼吸 7s/≤1.2%；轨道前段略亮（仍低于主体） | headline + action chip + 「需要处理」 | 需要处理 |
| unknown | 整体去饱和中性灰蓝；近静止 | 细进度线 + 「正在了解 Mac 状态」，不报健康 | 未知、中性 |

状态切换 0.8–1.2s 颜色/亮度交叉过渡；CPU/内存等实时数值不驱动剧烈视觉变化。

### 3.4 信息层级与 Activity slot

1. 状态行：6.5–7pt 状态点（带极弱辉光）+ headline 22–27pt semibold；多行时点贴首行 cap-height。
2. 解释句：12.5–14pt secondary，≤2 行。
3. Activity slot：固定 18–20pt 高的预留带，同一时刻最多一项 —— 检查进度（1.5pt 细进度线）、维护中、
   完成反馈（勾 + 文案，2s 后淡出）；出现时不推移上方内容。
4. 语境行：normal = 上次检查（tertiary）；attention/critical = action chip（高 28–30pt、发丝描边）+
   「N 项需要关注」；unknown = 进度线 + 说明。

只有存在可操作问题才出现 action chip；健康状态永不出现清理/优化按钮。

## 4. Work Rhythm Stage

### 4.1 装置结构（由外到内）

1. 固定表圈：0.7pt 发丝环 + 60 个刻度（普通 2pt/α0.33，12·3·6·9 为 3.75pt/α0.55）。表圈静止，绝不旋转。
2. 进度轨道：R−10 处 2.2pt 中性圆环（低对比），承载真实进度。
3. 进度弧：12 点起顺时针，2.8pt（rest 2.4pt）圆头；连续路径 + 亮度梯度（弧头更亮、尾部更淡）；
   弧头 3.8pt 点 + ≤8pt 柔光（α≤0.30）；无整圈发光、无拖尾。
4. 中央时间：等宽数字，字号 ≈ clamp(deviceDiameter×0.168, 40…72)；下方阶段标签（圆点 + accent 文字）+
   11pt tertiary 次级信息。
5. Idle：表圈秒点按真实时间绕行；中央当前本地时间 + 「现在」；**无进度弧**。
6. 操作行：装置正下方，主操作（开始/继续/再来一次）使用 focus accent 语义；暂停/跳过为 ghost；
   「结束」为 tertiary 文本。compact 下操作行仍完整可见。
7. 今日统计：只在窗口右下（模式切换上方），11pt tertiary；compact 隐藏。不进入主构图。

### 4.2 五种状态

| 状态 | 中央 | 弧/动效 | 操作 |
|---|---|---|---|
| Idle | 当前时间 + 「现在」 | 无进度弧；秒点 60s/圈 | 开始专注（primary） |
| Focus | 剩余倒计时 + 「专注中」+「第 2 个专注 · 25 分钟」 | 已用比例弧；弧头 ≥4s 极缓呼吸 | 暂停（ghost）+ 结束（text） |
| Paused | 时间冻结（透明度≈0.72）+「已暂停」+「已专注 8 分 12 秒」 | 进度冻结、变暗；弧头变两小竖条 | 继续（primary）+ 结束 |
| Rest | 休息剩余 +「休息中」+「休息 5 分钟」 | 暖沙色弧；呼吸 8–12s，明显更慢 | 跳过休息（ghost）+ 结束 |
| Complete | 「专注完成」+「25 分钟 · 第 2 个专注」 | 弧闭合 + 一次性 1.2s 柔和光晕（不循环） | 再来一次（primary）+ 休息一下（ghost） |

### 4.3 动效与业务状态的关系（正式实现建议）

- 倒计时 = `deadline − now`（绝对时间），**帧率不影响计时准确性**；窗口隐藏/恢复后重算，暂停时不推进。
- 进度弧由真实剩余比例驱动；暂停冻结；完成状态由会话结束事件驱动。
- 数字 1Hz 更新；弧头光晕/秒点由低频 TimelineView 驱动；不需要 SpriteKit。
- Complete 光晕为一次性动画，不循环；Reduce Motion 下直接呈现静止完成态。
- 原型中所有倒计时/统计为 MOCK ticker，不接真实业务、不持久化。

## 5. 自适应布局

| 窗口 | Mac Care 主体 | Work Rhythm 装置 | 关键约束 |
|---|---|---|---|
| 680×512 compact | ~200–240pt | ~220–250pt | 信息块/操作行完整可见；action chip 不被裁切；与 dock 净距 ≥16pt |
| 800×560 | 受可用高度约束（约 210–280pt） | 约 260–300pt | 不得为凑主体尺寸而压到底部控件 |
| 1024×680 regular | ~300–340pt | ~340–380pt | 常规构图；信息块宽度封顶 |
| 1600×900 large | 420–440pt | 400–440pt | 主体随窗口放大，避免主体过小/内容集中；竖直留白更均衡 |

规则：几何由 window size 推导；不使用整体缩放；紧凑窗口可降低信息密度（隐藏今日统计/次级信息），
但核心状态、倒计时与主要操作必须保留。布局不变量已有测试覆盖（`CalmSpaceStageLayoutTests`）。

## 6. 复用 / 替换清单

**可复用（已复用）**
- `CalmSpaceRootView` 双页滑动、模式切换、`CalmSpacePageTransition`、渲染生命周期暂停逻辑。
- `CalmSpaceLayout` 的窗口几何与底部控件位置；`CalmSpacePalette` 背景渐变家族。
- `CalmSpaceDockView`、`CalmSpaceModeSwitchView`（样式不重做）。
- 现有 DEBUG QA 启动参数体系（窗口尺寸/主题/隐藏桌宠/Reduce Motion）+ 新增离屏渲染截图钩子。
- Mac Care 健康状态判定与 `SystemStatusSnapshot` 数据（正式实现时直接接入 Stage 文案）。

**需要替换（正式实施阶段）**
- `CalmSpaceModePage` 的中央动画 + `CalmSpaceStatusView` 文案块 → 替换为 `MacCareStageView` / `WorkRhythmStageView`。
- `CalmSpaceOrbScene`（1435 行 SpriteKit 球体）与 `CalmSpaceRhythmScene`（615 行雷达盘）→ 由 SwiftUI Shape/Canvas
  实现替代；建议保留少量背景氛围场景或改为纯 SwiftUI 背景。
- `CalmSpaceLayout` 扩展为双 Stage 几何（或新增 `CalmSpaceStageLayout` 生产版）。
- Work Rhythm dock 的「专注/休息」禁用项 → 由 Stage 内操作取代（后续功能阶段处理）。

**暂不改动**：清理/磁盘/应用管理业务、设置页、健康算法、窗口 chrome。

## 7. 后续实施建议

1. **先确认视觉方案**（本规范 + 预览）再动正式主窗口，符合本阶段边界。
2. 第一项落地：把 Mac Care Stage 以 DEBUG 外正式路径接入（复用健康状态，无业务行为变化），
   验证真实窗口、主题切换、窗口缩放、Reduce Motion 生命周期。
3. 第二项：Work Rhythm 计时引擎 + 真实倒计时状态机（deadline 驱动、暂停/恢复、窗口隐藏重算），
   再接 Stage 的 Idle/Focus/Paused/Rest/Complete。
4. 最后删除旧 orb/rhythm 场景与旧状态视图，补 ADR 与文档更新。

## 8. 预览与验证

- 预览：`calm-space-stage/previews/`（Mac Care 4 态、Work Rhythm 5 态、深浅主题、三档窗口、长文案、Activity）；
  评审拼版在 `calm-space-stage/previews/sheets/`。
- 渲染方式：应用内离屏窗口渲染（`-JoeyPetQASnapshotOut`），真实运行原型像素；非系统截屏、非 ImageRenderer 概念图；
  因捕获时 macOS 锁屏，未使用 `screencapture`。交通灯为灰色属非 key window 渲染伪影。
- 验证：Debug/Release 构建通过；测试通过（含 Stage 几何/状态断言）；`-JoeyPetQAStageFreeze` 两次输出逐字节一致。
- 所有内容为 MOCK，原型徽标常驻右上角；正式业务接入时移除徽标与 mock fixtures。
