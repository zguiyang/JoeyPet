# Mac Care Stage — 设计说明（Unit 2 修订）

方案 **A：精修数字星球**（`-JoeyPetQAStageVariant a`，默认）。备选 B（地平线能量体，`explore-b`）保留为已验证方向。
全部 DEBUG-only，位于 `StagePrototype/MacCareStage*`；不进入生产路径。

## 构图与层级
主体 → 结论（状态行）→ 解释句 → Activity slot → 语境/操作，一条 1px 竖线把信息块绑到主体，形成一个构图而非三行模板。
- 主体居中；信息块水平居中、顶对齐于 `infoTop`，向下生长，永不压 dock。
- 状态点 6.5–7pt 顶对齐到首行 cap-height（长文案两行时点不浮在中间）。
- action chip 只在有可操作问题时出现；normal 永远没有清理按钮；unknown 只有进度线。

## 材质（非对称光照数字星球）
- **主光**左上 ~35°（径向渐变中心 0.36,0.32），右下柔和明暗交界；无中心白热。
- **limb darkening**：球缘 ~10% 向 `bodyEdge` 变暗。
- **纵深**：本体 + 偏移半透明大气壳 + **整盘径向渐隐辉光**（同主光方向，fade to `.clear`，无任何形状边缘）+ limb。无硬边图案、无可辨认圆/椭圆边界。
- **rim light**：仅背光侧（右下）一条 ~55° 细弧（主线 0.45/1.4pt + 柔光 0.14/3.7pt）。
- **轨道**：a≈1.31r、b≈0.36r、tilt −16°，细带 1.0pt；后段 opacity 0.20（浅0.22）；前方 ~32% 段、峰值 0.46、两端渐隐并跨过球体下缘；整条留在画布内，前后遮挡可读。椭圆中心取轨道 Canvas 的**真实中心 (size/2, size/2)**（Unit 3 修复：此前误用 (radius, radius)，导致整条轨道偏移约 0.39×diameter，看起来像漂浮斜线）。

## 状态 → 视觉（语义驱动，1.0s 交叉过渡）
| 状态 | 主体 | 色 | 操作 |
|---|---|---|---|
| normal | 慢呼吸 8s/0.8% | 冷青绿 | 无 |
| attention | 呼吸 11s/0.5%，rim 暖染 | 低饱和琥珀 | 「查看存储」chip |
| critical | 呼吸 7s/1.2%，轨道前段略亮 | 低饱和珊瑚 | 「查看应用」chip |
| unknown | 近静止 12s/0.4%，**整体去饱和为中性灰蓝** | 中性灰蓝 | 无（只有进度线）|

unknown 通过把 bodyLit/Mid/Deep/atmosphere/innerFlow 强 blend 向中性灰蓝（0.34–0.58）实现「一眼区分」，不再偏青。

## 主题
深浅独立调校。浅色为「雾面纸感 + 清晰边缘」：atmosphere opacity 0.09、blur8（几乎无 halo），去除廉价 glow ring；文字对比达标（primary18.5/14.6:1）。

## 自适应
compact <760×560 / large ≥1400×820。主体直径由可用高度推导并 clamp（large 上限 440，1600×900 → ~432pt）；large 竖直 top factor 0.50（内容居中、减少底部空隙）。信息块宽 ≤520。

## Unit 2 相对 Unit 1 的差异
1. 内部流动光：删两个硬边椭圆 → 整盘径向渐隐辉光（无形状边缘，MAC-P0）。
2. 轨道：a 1.42→1.31r、b 0.42→0.36r、亮度0.34→0.20、线宽1.2→1.0、前段30%→32%/峰值0.55→0.46，跨下缘、留在画布（P0-2/MAC-P1）。
3. rim：0.85/2.2+5.0 → 0.45/1.4+3.7，弧长92°→55°（P0-3）。
4. 浅色 atmosphere：0.26/blur13 → 0.09/blur8，去 glow ring（P0-4/MAC-P2）。
5. unknown 去饱和为中性灰蓝（P1）。
6. 长文案状态点顶对齐首行（P1）。
7. large 主体 420–440、top factor 0.34→0.50（P1/MAC-P3）。
8. attention/critical rim 暖染略增强（P1）。

## 复杂度
纯 SwiftUI（Shape/Canvas/RadialGradient/mask/blur）。呼吸=GPU 隐式动画；轨道点=低频 TimelineView(0.25s)。无 SpriteKit/shader/Metal/三方库。Reduce Motion / freeze 全部静止、确定性。

## Unit 3 修复（轨道几何）
- 根因：轨道 Canvas 的实际尺寸是 extent = diameter × 1.78，但椭圆点以 (radius, radius) 为中心计算，
  真正画布中心应为 (extent/2, extent/2)；导致轨道整体左上偏移约 0.39×diameter。
- 修复：改为按 Canvas 真实中心计算（修复方式 B）；`orbitBack` / `orbitFront` / `orbitPointCanvas`
  共用同一个 center。
- 验证：ORCA 独立用同一原型离屏渲染 `normal-dark-1024x680`，与交付截图逐字节一致（2048×1360）。
