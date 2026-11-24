# JoeyPet 音频素材目录（V0.x）

> 状态：**素材已入库；设置已接线；播放服从勿扰 / 安静时段静音。**  
> **不使用 AI 生成轨。** 下列均为频谱筛选后的入围免费素材，作为**用户可选项**内置（非单一默认）。

运行时资源路径：`macos/JoeyPet/Resources/Audio/`  
机器可读清单：同目录 `catalog.json`  
许可归档：同目录 `LICENSES.md`

---

## 产品用法

| 类型 | 何时出现 | 用户选择 |
|------|----------|----------|
| **背景音（Ambient）** | 用户主动「开始陪伴」且未选「无背景音」 | 雨 / 风 / 夏夜虫 / 火 等多选一；默认 **无背景音** |
| **提示音（Cue）** | 开始陪伴、到点休息邀请 | 杯碰 / 竹铃 / 木块 / 木风铃 或多选「无提示音」；默认 **瓷杯轻碰** |

静音规则（硬约束）：**勿扰模式** 或 **安静时段** 生效时，背景音与提示音一律不播（正在播的也会停）。

设置位置：节奏与提醒 → 背景音 / 提示音（各一个菜单选择器，含「无」选项；列表内每条有小喇叭试听，背景床约 2.4s，提示音完整一响；试听不受勿扰 / 安静时段影响）。

---

## 一、背景声可选项（Ambient）

### 雨

| id | 显示名（建议） | 文件 | 气质 |
|----|----------------|------|------|
| `rain_soft_lynks` | 细雨 | `Ambient/rain/rain_soft_lynks.mp3` | 最沉、高频低，首选细雨床 |
| `rain_window_oga` | 窗边雨 | `Ambient/rain/rain_window_oga.wav` | 玻璃窗感，适合桌面陪伴 |
| `rain_skylight_deadrobot` | 天窗雨 | `Ambient/rain/rain_skylight_deadrobot.mp3` | 短循环雨滴纹理 |
| `rain_pattering_henkonen` | 阳台雨 | `Ambient/rain/rain_pattering_henkonen.mp3` | 轻柔雨点 |
| `rain_light_mixkit` | 轻雨（库） | `Ambient/rain/rain_light_mixkit.mp3` | Mixkit 轻雨循环 |
| `rain_roof_spritepilot` | 屋檐雨 | `Ambient/rain/rain_roof_spritepilot.wav` | SpritePilot 屋檐雨 |

### 风

| id | 显示名（建议） | 文件 | 气质 |
|----|----------------|------|------|
| `wind_soft_spritepilot` | 软风 | `Ambient/wind/wind_soft_spritepilot.wav` | 低频软风，不吵 |
| `wind_leaves_nox` | 叶间风 | `Ambient/wind/wind_leaves_nox.mp3` | 中等叶响，音量宜压低 |
| `wind_autumn_nicktayloe` | 秋叶风 | `Ambient/wind/wind_autumn_nicktayloe.mp3` | 无缝秋叶风；**CC BY，需致谢** |

### 夏夜虫鸣

| id | 显示名（建议） | 文件 | 气质 |
|----|----------------|------|------|
| `insects_night_crickets_owlstorm` | 夏夜虫鸣 | `Ambient/insects/insects_night_crickets_owlstorm.mp3` | 远场蟋蟀，筛选后唯一不过刺的虫床 |

说明：免费库中「远蝉」合格轨极少；本轨以蟋蟀为主，作夏夜虫鸣选项。纯蝉墙类已淘汰。

### 火（可选暖色）

| id | 显示名（建议） | 文件 | 气质 |
|----|----------------|------|------|
| `fire_fireplace_oga` | 壁炉 | `Ambient/fire/fire_fireplace_oga.wav` | 室内炉火 |
| `fire_campfire_spritepilot` | 篝火 | `Ambient/fire/fire_campfire_spritepilot.wav` | 轻篝火 |
| `fire_crackling_nicktayloe` | 细火噼啪 | `Ambient/fire/fire_crackling_nicktayloe.mp3` | 近距噼啪、无缝 |

---

## 二、提示音可选项（Cue）

| id | 显示名（建议） | 文件 | 建议场景 | 备注 |
|----|----------------|------|----------|------|
| `cue_ceramic_cups` | 瓷杯轻碰 | `Cues/cue_ceramic_cups.mp3` | 休息邀请 / 开始陪伴 | 暖、软，首选杯声 |
| `cue_bamboo` | 竹风铃 | `Cues/cue_bamboo.mp3` | 休息邀请 | 木质感，无刺耳金属 |
| `cue_woodblock_soft` | 软木块 | `Cues/cue_woodblock_soft.mp3` | 极轻提醒 | 最低打扰 |
| `cue_wooden_chime_breeze` | 木风铃（风中） | `Cues/cue_wooden_chime_breeze.mp3` | 休息邀请 | **接入前裁切到约 0.8–2s 单次敲击**，并略降风噪 |

已淘汰未入库：偏亮的玻璃敲击、教堂钟式铃、SpritePilot `night` 蝉墙等。

---

## 三、实现备忘

1. 双 `AVAudioPlayer`：ambient 循环 + cue 单次；cue 时 duck ambient（`JoeyAudioController`）。  
2. 设置：两个菜单选择器（含「无背景音」「无提示音」）；无独立总开关。  
3. 静音：`isDoNotDisturb || isQuietActive` → 停播；解除后若仍在陪伴中则恢复背景音。  
4. Freesound 轨当前为 **HQ 预览编码**（可播、可试）；正式上架前建议用账号下载原 WAV 替换同名文件并更新 `LICENSES.md` 校验信息。  
5. SpritePilot / OpenGameArt 轨为完整 WAV。  
6. `wind_autumn_nicktayloe` 为 **CC BY**：关于页「声音致谢」署名 NickTayloe + Freesound。

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-11-24 | 初版：入围免费床 + 提示音入库；文档与 `catalog.json` 对齐。 |
| 2026-11-24 | 设置接线：双选择器 + 勿扰/安静时段静音 + 播放控制器。 |
