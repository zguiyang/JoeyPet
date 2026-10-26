# Work Rhythm Stage — 设计说明（Unit 2）

一个「时间仪器」Stage：环形时间装置（含倒计时）→ 当前阶段 → 计时操作 → 外围简要统计。
第一眼是「计时 / 专注」，不是雷达、系统监控或刻度盘。全部 DEBUG-only，位于 `StagePrototype/WorkRhythm*`。
MOCK ticker 倒计时仅用于展示，集中在 fixture / 视图，不接真实业务或持久化。

## 装置结构（由外到内）
1. **固定表圈**：0.7pt 发丝圆环(op0.13) + 60 个细刻度（普通 2.0pt/op0.33，12/3/6/9 为 3.75pt/op0.55）。静止，绝不旋转；1:1 可见的精致刻度盘。
2. **进度轨道**：R−10 处 2.2pt 完整中性圆环（低对比）。
3. **进度弧**：12 点起顺时针，2.8pt（rest 2.4pt）、圆头；一条连续 Path + conic 渐变（弧头更亮、尾更淡，无珠链感）；弧头 3pt 圆点 + ≤8pt 柔光(op≤0.26)。无整圈发光、无拖尾。
4. **弧头标记**：3pt 圆点 + 极弱光晕，运行态 5s 极缓呼吸；暂停时变两小竖条、无光晕。
5. **中央时间**：等宽数字（tabular、.medium、tracking+0.5），字号 = clamp(device×0.165, 44…66)；下方阶段标签（5pt 圆点）+ tertiary 次级信息。
6. **Idle**：表圈秒点按真实时间绕行（60s/圈），中央当前本地时间 + 「现在」，**无进度弧**。

## 信息层级
装置中央（时间）→ 阶段标签 → 次级信息；操作行紧贴装置正下方；今日统计只在外围右下（模式切换上方，compact 隐藏）。不形成 Dashboard。

## 五态
| 态 | 中央 | 弧 | 操作 | 色 |
|---|---|---|---|---|
| idle | 真实时间 `18:40` / 「现在」 | 无（仅秒点） | 开始专注(primary, focusAccent) | 中性冷 |
| focus | `16:48` / 「专注中」 | 已用 33%，弧头呼吸 | 暂停(ghost)+结束(text) | 靛蓝 |
| paused | `16:48`(0.72 透明) / 「已暂停」 | 冻结、变暗、弧头两竖条 | 继续(primary, focusAccent)+结束(text) | 中性 |
| rest | `04:12` / 「休息中」 | 休息进度，弧更细 | 跳过休息(ghost)+结束(text) | 暖沙 |
| complete | 「专注完成」 | 闭合 + 一次性柔光 | 再来一次(primary)+休息一下(ghost) | 靛蓝 |

## 色彩
继承 `CalmSpaceStageTokens` 之外新增 `WorkRhythmStageTheme`（focus/rest/paused/idle/track/head/glow，每主题独立）。
- Focus = 雾蓝/靛蓝冷色（暗 0.56,0.66,0.92 / 亮 0.28,0.38,0.64）；Rest = 低饱和暖沙（暗 0.85,0.76,0.55 / 亮 0.56,0.47,0.28）。两者一眼可分，且都不与 Mac Care 青绿/琥珀/珊瑚混淆。
- 深色：象牙数字(ivory) + 深墨蓝底；浅色：纸感 + 墨色数字，≥4.5:1（数字 17.8/13.9:1，focus/rest accent ≥3:1）。非深色反相。无霓虹。
- 主操作（开始/继续/再来一次）统一用 focusAccent（文字/fill0.13/stroke0.42）以突出；ghost（暂停/跳过）保持中性。

## 动效
- Idle：秒点真实时间；可一次 10s 整环微呼吸(op≤0.06)；Reduce Motion 静止。
- Focus/Rest：倒计时 1Hz 推进（mock ticker）；弧头 5s 呼吸（仅光晕 op）。Rest 呼吸更慢。
- Paused：全部停止，倒计时/进度冻结。
- Complete：一次 1.2s 柔和光晕，不循环。
- 状态切换 0.6s 颜色/亮度过渡；数字直接替换。
- `-JoeyPetQAStageFreeze` / Reduce Motion：全部静止、确定性（两次 freeze 逐字节一致）。

## 布局与自适应
装置直径由可用高度推导并 clamp：compact 220–250 / regular 340–380 / large 400–440（1600×900→~416）。
操作行 35–38pt，与 dock/模式切换净距 ≥16（compact≥12）。长倒计时 `1:02:45` 与长文案在 compact 不破构图（中央数字宽度≤内圆，minimumScaleFactor 兜底）。

## 复用 / 替换
- 复用 Unit 1 骨架：QA 参数、离屏快照、背景家族（Work Rhythm 叠一层极轻暖调）、模式切换位置。
- dock 用原型内变体「统计(禁用)+系统设置」，不改生产 `CalmSpaceDockView`；这是后续正式方向。
- 替换：不复用 Mac Care 球体；装置是全新 Canvas/Shape 组合。

## 实现可行性
- SwiftUI：Canvas（表圈/轨道/弧/弧头/秒点）+ 中央 Text + TimelineView 低频驱动。无整页常驻 60FPS 重绘、无 shader/Metal/三方库。
- **计时正确性**：正式实现应以**绝对截止时间**（deadline）计算剩余，帧率不影响准确性；原型的1Hz ticker 仅为演示。暂停记录累计已专注时长，恢复时重设 deadline。
- 复杂度：中等。Reduce Motion、暂停/恢复、Complete 一次性动效均已内建且可测试（布局/fixture 测试 162 通过）。
- 已知：焦点呼吸光晕与1Hz tick 同层时，光晕 opacity 动画由父级 @State 驱动、位置随 tick 更新，实测不抖动。
