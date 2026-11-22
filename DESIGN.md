# JoeyPet — V0 Design Contract

**Status:** Design source of truth for the V0 desktop-companion product.
**Scope:** visual language, layout, tokens, components, copy voice, motion, and the six agreed surfaces.
**Frozen visual reference:** [`docs/reference/joeypet-ui-v0.html`](docs/reference/joeypet-ui-v0.html) — the reviewed high-fidelity design artifact (six states, light + dusk). Open it in a browser. It is a **visual target, not implementation code**.
**Not in scope here:** product acceptance rules ([`V0_FEATURE_SCOPE.md`](V0_FEATURE_SCOPE.md)), pet animation runtime ([`docs/pet-runtime.md`](docs/pet-runtime.md)).

The previous Mac Care / Calm Space contract is **Legacy**. It lives in the `archive/mac-care-calm-space-2026-11` branch and must not guide new work.

---

## 1. Design authority

Sources are layered, not ranked. Each layer answers a different question:

```text
Platform    Apple HIG (official macOS pages)     → interaction, native behavior, accessibility
Product     This file                            → visual language, layout, tokens, copy, motion
Exception   docs/decisions/ ADRs                 → one named deviation from this file or HIG
Reference   docs/reference/joeypet-ui-v0.html    → the frozen visual target for the six states
Engineering AGENTS.md, docs/tech-stack.md        → AppKit/SwiftUI/SpriteKit split, zero deps
```

- **This file is the reviewable baseline.** Implementation is checked against it.
- **The HTML reference resolves visual ambiguity, not product rules.** If it disagrees with this file, this file wins; fix the reference in the same task when the artifact is wrong.
- **Apple HIG governs platform behavior and accessibility.** Prefer the official pages (`https://developer.apple.com/design/human-interface-guidelines/<page>.md`).
- **The legacy Calm Space main-window decision is retired.** It lives only in the archive branch; do not cite it as permission for custom chrome on new surfaces.

---

## 2. Status vocabulary

| Status | Meaning |
|--------|---------|
| **Agreed** | Frozen V0 design. Build it as specified. |
| **Pending** | Agreed but not implemented yet. Never present it as shipped. |
| **Legacy** | Retired direction. Do not restore without a new product decision. |

| Surface | Design | Implementation |
|---------|--------|----------------|
| Desktop Joey (idle, drag, hide, menu) | Agreed | Implemented (V0 base), hidden by default |
| Rest invitation | Agreed | Pending |
| 30-second recovery | Agreed | Pending |
| Nest home (main window, room scene) | Agreed | Implemented (room shell, draggable Joey; session CTA not wired) |
| Rhythm reflection (garden view) | Agreed | Implemented (seed / sprout / tall sprout / tree stages; waiting on session data) |
| Settings | Agreed | Implemented (page inside the main window) |
| Light + dusk appearances | Agreed | Implemented |
| Calm Space / Mac Care shell | Legacy | Removed — archive branch only |

> Shipped today: the desktop panel (drag, hide, show; hidden by default), menu bar item, the nest window with in-scene reflection navigation, and settings with light/dusk appearance and persisted V0 settings. Rest invitation and 30-second recovery remain design-only until their row says otherwise. The nest primary action is visual only — it is not wired to a companionship session yet. Do not treat planned rows as shipped.

---

## 3. Product visual language

JoeyPet is a small, warm, living desktop pet for Chinese knowledge workers.

> 你忙你的，Joey 在旁边陪着。到了该休息的时候，它会轻轻叫你一下。

| Keyword | Meaning |
|---------|---------|
| **Storybook** | Soft 2D illustration, hand-made warmth, no 3D, no pixel art. |
| **Calm** | Quiet at rest; no decorative loops on static data. |
| **Alive** | Posture, gaze, props and breath carry life — not UI decoration. |
| **Warm** | Ivory paper light, sage growth, apricot kindness. |
| **Unhurried** | One idea and one primary action per state. |
| **Honest** | Only real states. No fake metrics, fake progress, or invented growth. |

**JoeyPet is not** a productivity dashboard, habit tracker, Pomodoro app, task manager, system monitor, or health app. It is not childish or gamified.

**Never use:** warnings or OS alert dialogs for invitations; punishment, guilt, failure, broken streaks, scores; XP bars, levels, loot, shops, leaderboards; dense cards or KPI grids; pixel art, 3D characters, cyberpunk, neon, glossy glassmorphism.

**Primary UI language:** Simplified Chinese (V0). Copy must stay short enough for English later.

---

## 4. Color

### 4.1 Core tokens

Every surface colour comes from a token. Never hardcode a hex in a view.

| Token | Light | Dusk | Role |
|-------|-------|------|------|
| `ivory` | `#F7F3EB` | — | Desktop ground, page background |
| `ivory-2` | `#F1E9DA` | — | Secondary ground, warm band |
| `ink` | `#3F3A35` | `#E9E3D7` | Primary text, pet outline |
| `ink-2` | `#6B6259` | `#BFB8AB` | Secondary text, labels |
| `muted` | `#6E6459` | `#B0A89C` | Captions, helper text |
| `sage` | `#86A98A` | `#86A98A` | Growth, calm completion, primary action |
| `sage-deep` | `#4F6D54` | `#A9C6AC` | Emphasis on light surfaces, active labels |
| `sage-ink` | `#263227` | `#1E2A20` | Text on sage fills |
| `sage-soft` | `#E8EEE3` | `rgba(134,169,138,.16)` | Selected rows, hover fills |
| `apricot` | `#EFAE7D` | `#EFAE7D` | Warm pet interaction, rest invitation accent |
| `apricot-ink` | `#A96B42` | `#A96B42` | Apricot text on light |
| `mist` | `#90B9C9` | `#90B9C9` | Quiet mode, evening atmosphere |
| `mist-deep` | `#5E8B9D` | `#5E8B9D` | Mist emphasis |
| `mist-soft` | `#DFE9EB` | `#DFE9EB` | Mist wash |
| `clay` | `#C9B08C` | `#C9B08C` | Paper, wood, tape, illustration props |
| `hairline` | `rgba(63,58,53,.14)` | `rgba(233,227,215,.14)` | 1 px strokes, dividers |
| `hairline-strong` | `rgba(63,58,53,.24)` | `rgba(233,227,215,.24)` | Secondary button border, fields |
| `focus` | `#4F6D54` | `#86A98A` | Sage focus ring; never system blue |

### 4.2 Surfaces

| Token | Light | Dusk | Use |
|-------|-------|------|-----|
| `window-bg` | `#FBF8F0` | `#313A3B` | Window content |
| `window-chrome` | `#F2ECE1` | `#262E2F` | Titlebar, sidebar |
| `panel` | `#FFFDF7` | `#37403F` | Cards, panels, sign |
| `panel-2` | `#F8F3E9` | `#2F3838` | Inset fills, segmented track, hover |
| `popover` | `#FFFDF8` | `#394241` | Chips, menus, tooltips, labels |

### 4.3 Semantic rules

- **Sage = growth, calm completion, the one primary action.** Do not use it for warnings.
- **Apricot = warmth between user and pet.** Invitation accent, pet blush, mug. Not a status colour.
- **Mist = quiet / evening.** Quiet hours, dusk atmosphere, "Joey is resting".
- **Never colour alone.** Every state pairs colour with text, an icon, or a shape.
- **Dusk is an independently tuned palette**, not an inversion. Check it whenever you change a light value.

### 4.4 Measured contrast (design pass)

| Pair | Ratio | Verdict |
|------|-------|---------|
| `ink` on `ivory` | 10.2:1 | Pass |
| `muted` on `panel` (light) | 5.7:1 | Pass |
| `muted` on `panel` (dusk) | 4.5:1 | Pass (floor) |
| `sage-deep` on `sage-soft` | 4.9:1 | Pass |
| `sage-ink` on `sage` | 5.1:1 | Pass |

Treat these as the floor. Any new pair must be measured before shipping; do not claim compliance otherwise.

---

## 5. Typography

### 5.1 Family

System font only:

```text
-apple-system, "SF Pro Text", "SF Pro Display", "PingFang SC", "Helvetica Neue", sans-serif
```

Display sizes may prefer SF Pro Display. Never bundle SF Pro, never install Inter, no third-party faces.

### 5.2 Scale

| Role | Size | Weight | Line height | Tracking |
|------|------|--------|-------------|----------|
| Invitation message | 27 | 650 | 1.38 | 0 |
| Recovery title / reflection emphasis | 23 | 650 | 1.35 | 0 |
| Reflection headline | 21 | 650 | 1.45 | 0 |
| Settings page title | 17 | 650 | 1.4 | 0 |
| Primary button label | 16 | 600 | 1.2 | 0.005em |
| Body / secondary | 13.5 | 400 | 1.65 | 0 |
| Settings row title | 13.5 | 600 | 1.4 | 0 |
| Nav item / menu item | 13.5 | 400–600 | 1.35 | 0 |
| Reflection body | 13 | 400 | 1.7 | 0 |
| Room label / chip | 12.5 | 400–650 | 1.45 | 0 |
| Settings row description | 12 | 400 | 1.5 | 0 |
| Meta / group label | 11.5 | 400–600 | 1.4 | 0.02em |
| Smallest caption | 11 | 400 | 1.5 | 0.02em |

Rules:

- **CJK display line height 1.35–1.45.** Never the Latin 1.0–1.2; Chinese glyphs fill the em box and lines will collide.
- **No negative tracking on CJK.** Display tracking is `0`.
- **No uppercase micro-labels.** Chinese has no case; do not fake an English eyebrow above every block.
- **Three weights only:** 400 read, 550–600 emphasize, 650 announce. Nothing above 650.
- **Tabular numerals** (`font-variant-numeric: tabular-nums`) for timers, break counts, dates, and clock text.
- Body copy never exceeds ~34 Chinese characters per line at these sizes; do not stretch a sentence across a 400 px card.

### 5.3 SwiftUI mapping

| Design | SwiftUI |
|--------|---------|
| 13.5 / 1.65 body | `.body` (macOS 13 pt) with `.lineSpacing(3)` |
| 16 / 600 button | `.callout.weight(.semibold)` or explicit `.system(size: 16, weight: .semibold)` |
| 21 / 650 headline | `.title2.weight(.semibold)` |
| 23 / 650 | `.system(size: 23, weight: .semibold)` |
| 12.5 / 11.5 meta | `.caption` / `.caption2` |
| Timers | `.monospacedDigit()` |

650 has no native SwiftUI weight; use `.semibold` (600) rather than inventing a custom face. Do not use Dynamic Type for the illustration-side captions; do allow it for Settings rows and feedback text.

---

## 6. Spacing, radius, elevation

### 6.1 Spacing

A 4/8 rhythm: `2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32 40 44 52`. No arbitrary values.

Recurring measures:

| Context | Value |
|---------|-------|
| Panel padding | 26–30 (large panels), 18–22 (cards) |
| Row padding | 14 vertical |
| Section gap | 18–24 |
| Control gap | 8–10 |
| Text gap (title → body) | 4–7 |
| Window inset | 40–52 from the scene edge |

### 6.2 Radius

| Token | Value | Use |
|-------|-------|-----|
| `r-lg` | 22 | Invitation card |
| `r-xl` | 26 | Recovery panel |
| `r-md` | 16 | Primary button, room CTA, sign, secondary button |
| `r-sm` | 12 | Popover menu, window |
| nested | 6–10 | Rows, chips, fields, segmented items |
| `pill` | 999 | Status chip, toast |

Nested radius: outer = inner + padding. **Not every element is a pill** — pills are reserved for transient status (chip, toast) and the status dot.

### 6.3 Elevation

| Token | Value |
|-------|-------|
| `shadow-sm` | `0 1px 2px rgba(63,58,53,.06), 0 2px 6px rgba(63,58,53,.05)` |
| `shadow-md` | `0 2px 6px rgba(63,58,53,.08), 0 10px 30px rgba(63,58,53,.12)` |
| `shadow-lg` | `0 6px 20px rgba(63,58,53,.14), 0 24px 60px rgba(63,58,53,.20)` |

Dusk shadows are black-based (`rgba(0,0,0,.24–.44)`). The only glow allowed is the 3 px status-dot halo. No glow on panels, no gradient chrome on controls.

### 6.4 Paper texture

Allowed only as an extremely subtle background grain: 120 px noise tile at **1.8 % opacity, multiply**. Never on text, cards, or controls.

---

## 7. Windows and layout

### 7.1 Geometry

| Surface | Size | Notes |
|---------|------|-------|
| Design canvas | 1440 × 900 | Desktop composition reference |
| Nest window (default) | 1080 × 720 | Min 880 × 560 |
| Settings | 200 sidebar + detail inside the nest window | Shares the 1080 × 720 window; no second window |
| Settings sidebar | 200 | Divider + detail |
| Invitation card | 400 wide | Anchored beside Joey |
| Recovery panel | 420 wide | Centred, top offset 100 |
| Reflection copy | 388 wide | Top-left, directly on the garden; no panel |

All layout derives from the live window size in code. The 1440 × 900 numbers describe proportion, not a fixed frame to hardcode.

### 7.2 Window chrome

- **Native macOS window**: real traffic lights, native title, native resize/move/key-inactive appearance. Never draw fake traffic lights.
- **No toolbar. No in-window tab bar. No navigation bar.** System chrome already provides the window frame.
- **One chrome control only:** a settings gear at the titlebar trailing edge. Nothing else lives in the titlebar.
- Titlebar height ~40 pt; content is full-bleed below it, with the illustrated room meeting the titlebar edge.
- Title text is real ("Joey 的家", "节奏回顾", "JoeyPet 设置"), because the reference shows it. If hidden mode is used, the title must still exist as window metadata for window management.

### 7.3 Navigation lives in the scene

The main window is **one room**, not a container of pages.

| Destination | Scene affordance | Return |
|-------------|------------------|--------|
| Rhythm reflection | Wall frame labelled 回顾 (hover: 回顾这周) | 回巢 button, bottom-right |
| Settings | Gear in the titlebar | Gear toggles back to the previous page |

- The scene affordance is a real hit target; hovering shows the 回顾这周 tooltip. Never draw a hover or focus outline around the scene area.
- Never add a second navigation layer (tab bar, segmented control, breadcrumb) to the room.
- Reflection and settings are **views inside the same window**, not separate windows. The window title changes while either is open.
- Settings returns to whichever page was open before the gear was pressed.

### 7.4 Safe area

Keep Joey, the primary action, and all text ≥ 40 px from the window edge. The invitation card and recovery panel must never cover Joey's face or the sign. Desktop Joey sits clear of the Dock and menu bar geometry.

### 7.5 Desktop composition

Layer order (back → front): wallpaper gradient + hills → menubar → windows/panels → desktop pet → chip / hint / menu → toast.

Wallpaper: warm ivory base with an apricot radial at the top-right and a sage radial at the left, plus three soft hills (sage → sage → clay). Dusk replaces the same layers with deep blue-grey values. This is desktop atmosphere, not an app background.

---

## 8. Components

### 8.1 Buttons

| Variant | Height | Radius | Fill / border | Label |
|---------|--------|--------|---------------|-------|
| Primary | 50 | 16 | `sage` fill, `sage-ink` text, soft inner highlight | 16 / 600 |
| Secondary | 40 (small 38) | 16 | transparent, 1 px `hairline-strong` | 13.5 / 400 |
| Quiet | 40 (small 38) | 16 | transparent, `muted` text | 13.5 / 400 |

Rules:

- **Exactly one primary action per state.** Secondary and quiet actions sit below or beside it.
- Hover: primary brightens 3 %; secondary fills `panel-2`; quiet text moves to `ink`. Never lighten text to grey on hover.
- Pressed: 1 px downward translate.
- Focus: sage ring, visible on keyboard focus. Mouse clicks show caret and selection only; text inputs never gain a blue outline.
- No icon in every button. Icons only where they speed recognition (play, home, gear).

### 8.2 Status chip

Pill, `popover` fill, 1 px hairline, 12.5 px, `7/13` padding, tabular numerals. Left mark is an 8 px sage leaf square rotated −45° (not an emoji, not a dot when it means growth). Appears only while a session is active; hides otherwise.

### 8.3 Toast

Pill at the top centre of the desktop, 13 px, `9/18` padding, `shadow-md`, 2.6 s dwell, 220 ms in / out. One short sentence, no action, no exclamation stacking.

### 8.4 Room label

Small in-scene information tag: `popover` fill, 1 px hairline, radius 9, `6/11` padding, 12.5 px / 1.45. The number is wrapped in a bold `sage-deep` span. Labels belong to objects (clock, notebook, plant); they are not floating KPI cards.

### 8.5 Progress ring

104 px, 8 px stroke, radius 46, track `panel-2`, progress `sage` with round caps, 1 s linear updates. Centre: `mm:ss` at 22 px / 650 tabular, with a 10.5 px / `muted` "剩余 N 秒" beneath. The ring never uses gradient or shadow.

### 8.6 Controls

| Control | Spec |
|---------|------|
| Switch | 36 × 21 track, 17 px knob, sage when on, 160 ms |
| Segmented | `panel-2` track, radius 8, 2 px inset, active item `panel` + `shadow-sm` |
| Time field | radius 8, 1 px hairline, `panel-2` fill, tabular numerals; caret and sage selection only |
| Textarea | radius 10, 1 px `hairline-strong`, 72 px min height; caret and sage selection only |
| Menu | radius 12, 6 px padding, 8 px row radius, 1 px divider, `shadow-lg` |

Controls follow macOS sizing and behavior. Custom styling is limited to fill, radius, and typography — not to interaction models.

### 8.7 Icons and illustration

- Icons: one family, 24 px grid, 1.6 px stroke, round caps and joins, currentColor. Filled icons never sit at the same hierarchy level as outlined ones.
- **No emoji as functional icons.**
- Joey, the room, the garden path, and all props are original vectors. Never substitute a stock illustration or a generated stand-in for Joey.
- Charts, paths, and diagrams are drawn, never photographed.

---

## 9. Illustration: Joey and the room

### 9.1 Character

Rounded, expressive, four-head-tall storybook creature. Canvas 320 × 400.

| Part | Value |
|------|-------|
| Body | `#F3E3CD`, belly shade `#EBD7BE` at 50 % |
| Inner ear | `#EFC8AA` |
| Paws / hand | `#F8ECDA`, arm shade `#EDDAC1` |
| Eye | `#3F3A35` with a 2.8 px white catchlight |
| Blush | `#EFAE7D` at 26 % |
| Nose | `#C98F6E` |
| Mouth | `#6F5F53`, 2.3 px stroke |
| Scarf | `#86A98A`, 9 px stroke |
| Contact shadow | `#3F3A35` at 8 %, radial |

Silhouette rules: no neck (head and body merge), long upright ears, round belly, short paws, one curled tail. Never add outline strokes to the body — the shape does the work.

### 9.2 Poses

| Pose | Reads as | Used in |
|------|----------|---------|
| `sit` | Quiet company, breathing | Idle, nest |
| `look` | Turned toward the user, attentive | Session active, nearly time to rest |
| `sign` | Holding a small handwritten sign | Rest invitation |
| `stretch` | Arms up, eyes closed, small mouth | Recovery demo |
| `happy` | Arc eyes, open smile, brighter blush | After a completed break |
| `sleep` | Curled, closed arc eyes, sage blanket line | Quiet hours, hidden attention |

Transition rules (0.3 s, ease-out, no bounce):

```text
sit → look       attention arrives (invitation 5 min away)
look → sign      invitation appears
sign → stretch   user accepts
stretch → happy  recovery completed
happy → sit      after ~2.6 s
sit → sleep      quiet hours begin
sleep → sit      quiet hours end / user returns
```

Never cross-fade through a full-body morph that loses the silhouette; switch pose at the body level and keep the contact shadow fixed.

### 9.3 Room

A single warm room, 1080 × 680: ivory wall, warm wood floor, one window with hills, a wall clock, a framed 回顾 picture, a potted plant, a woven nest with a sage cushion, and a small desk with a notebook, mug, and a tiny pot.

- **Information lives in objects:** clock = next invitation, notebook = today's companionship time, plant = today's completed breaks.
- **Growth is additive and non-regressive:** each completed break may add one leaf, sprout, or small object. Nothing is ever removed, wilted, or reset.
- No levels, XP, counters on the wall, trophy shelf, or scoreboard.
- Prop colours use the `room-*` token family (wall, floor, frame, sky, hill, nest, cushion, desk, paper, mug, leaf), so light and dusk swap in one place.

---

## 10. The six states

### 10.1 Desktop companionship

- Joey sits in the bottom-right corner of the desktop: 168 × 210, 40 px from the right, 92 px above the bottom, clear of the Dock.
- No window, no container, no card behind him. He is the interface.
- Idle breath 4.2 s, scale 1 → 1.012, origin at the base.
- While a session runs, a chip above him reads `陪伴中 · mm:ss`.
- Hover reveals `拖动换位置 · 点击打开菜单`; the cursor is a grab hand; dragging clamps to the screen with an 8 px margin and persists after drag end.
- Click opens a small menu: **结束陪伴** / **隐藏 Joey** / divider / **暂停一小时**.
- Quiet hours: pose becomes `sleep`; no chip, no menu prompt, no motion beyond breathing.

### 10.2 Rest invitation

- Joey emerges with a handwritten sign reading **坐久啦**.
- The card sits at his sign's height (not floating in the middle of the screen), 400 px wide, radius 22, `shadow-lg`, 26/28/24 padding, with a small clay tape strip at the top.
- Copy:

```text
坐久啦，
我们一起伸个懒腰？

不用走开，半分钟就够。

[ 休息一下 ]        ← primary
[ 稍后提醒 ] [ 暂停一会儿 ]
```

- It is an invitation from a pet, never an alert: no title bar, no icon-warning, no modal scrim over the whole screen, no system beep.
- Dismissing is always available and never punished. Toasts: `好，过一阵再问你。` / `先安静一会儿。`
- Only one reminder per interval; never re-prompt immediately.

### 10.3 30-second recovery

- Calm panel, 420 wide, radius 26, centred at 100 px from the top; Joey demonstrates the stretch to the right of it.
- Copy:

```text
望向远处
找个六米外的点，肩膀放松。

[ring 00:30 · 剩余 30 秒]   吸气四拍，呼气六拍
                            不用数得很准。

[ 好了 ]  [ 先跳过 ]
```

- Progress is honest: a real 30 s countdown drives the ring. No confetti, no score, no "achievement".
- Completing it increments today's break count and returns Joey to `happy` for ~2.6 s with the toast `好了。Joey 的窝里多了一片叶子。`
- Skipping exits silently. The product never claims a break was detected.

### 10.4 Nest home

The main window, and it should feel like entering Joey's home.

- Title: **Joey 的家**. Traffic lights, title, one gear.
- Room scene fills the content area; Joey breathes in the nest.
- Three object-bound facts, nothing else:
  - Clock label: `Joey 大约每 45 分钟来叫你一次`
  - Notebook label: `今天陪了 2 小时 10 分`
  - Plant label: `今天休息 2 次`
- Primary action centred near the floor: **开始一起工作**; while running it becomes **结束陪伴** with a status chip `陪伴中 · mm:ss` above it.
- While a session runs, Joey looks toward the user (`look`); at rest he sits (`sit`).
- No cards, no charts, no streaks, no "Today's productivity".

### 10.5 Rhythm reflection

A garden inside the same window, opened from the wall frame.

- A small path across seven days. Every day leaves something visible: 0 breaks shows a seed in the soil, 1 break a sprout, 2 a taller sprout, 3+ a small tree. No bars, no axes, no percentages.
- Copy (388 wide, top-left, directly on the garden): date range `11月16日 – 11月22日`, headline `这周我们一起休息了 6 次。`, sub `今天陪了 2 小时 10 分。周三没有记录。` No card, panel, border or shadow behind this text.
- Numbers are facts, not scores. Never say "only", "missed", "failed", or "keep it up".
- Return: **回巢**, bottom-right.
- Data must be self-consistent: today's breaks ≤ this week's total; if today has none, say so plainly.

### 10.6 Settings

Native, quieter, more functional than the room. No illustration, no hero copy, no sage hero blocks.

- Page title **JoeyPet 设置** inside the shared window; 200 px sidebar + detail.
- Sidebar is one flat list, no group headings: 节奏与提醒 · 安静时段 · 外观与位置 · 成长记录 · 关于 JoeyPet.
- Rows:

| Row | Control | Copy |
|-----|---------|------|
| 提醒节奏 | Segmented 45 / 60 / 90 分钟 | 两次邀请之间的安静时间 |
| 暂停一小时 | Switch | 到 16:24 自动恢复 |
| 安静时段 | Time-range field: two editable halves, centre dash, double-click selects all | 22:00 到 08:00，Joey 会安静下来 |
| 在桌面上显示 Joey | Switch | 停在屏幕右下角 |
| 反馈 | Button → textarea | 哪里觉得打扰，写在这里 |

- Section description: `只在你开始工作后提醒。` — this is a product rule, not marketing.
- Time inputs use direct typing. Focus shows a caret and sage selection, never a blue outline.
- Native `Form`/`Toggle`/`Picker`/`TextField` behavior; semantic system colours are acceptable here where native controls demand them, but the surface stays ivory/panel, never system-grey dashboard.

---

## 11. Copy voice

Chinese-first, short, warm, factual.

**Do**

- Speak as Joey or about Joey in the third person: `Joey 大约每 45 分钟来叫你一次`
- State facts plainly: `今天陪了 2 小时 10 分。周三没有记录。`
- Give one instruction at a time: `找个六米外的点，肩膀放松。`
- Let the user off the hook: `不用走开，半分钟就够。`
- Use everyday words: 休息, 陪你, 小窝, 好了, 先跳过.

**Don't**

- No exclamation piles, no `完成啦！`, no `太棒了！`
- No meta explanation of product principles (`不会连着催第二次`, `不需要做任何汇报`, `空白不是失败`).
- No triple-negation slogans (`不评分 · 不打卡 · 不追问感受`).
- No uppercase English eyebrows (`JOEY 想问你`, `REST TIME`).
- No productivity language: 效率, 产出, 达标, 连续打卡, 专注力提升.
- No guilt: 又没休息, 只完成了, 中断了.
- No invented metrics or fake personalisation.
- No "轻轻/悄悄/静静" stacked on every line; one gentle adverb per screen at most.

Length: invitation headline ≤ 12 characters per line; helper ≤ 18; toast ≤ 14.

---

## 12. Motion

| Event | Duration | Easing | Property |
|-------|----------|--------|----------|
| State enter | 300 ms | `cubic-bezier(.22,.61,.36,1)` | opacity 0→1, translateY 6→0 |
| Panel / card rise | 340–420 ms | same | opacity + 10 px rise |
| Menu open | 160 ms | same | opacity + scale .97→1 + 4 px |
| Chip / toast | 220–240 ms | same | opacity + 4–6 px |
| Hover | 120–180 ms | ease-out | background / colour / 1 px lift |
| Press | 120 ms | ease-out | translateY 1 px |
| Theme switch | 350 ms | ease | background / border / colour |
| Ring | 1 s linear per tick | linear | stroke-dashoffset |
| Breath | 4.2–6 s loop | ease-in-out | scale 1→1.012 |

Rules:

- Motion explains state change, hierarchy, or causality. It is never decoration.
- Exits run at ~65 % of entrance duration.
- No bounce, no spring overshoot, no parallax on data.
- **`prefers-reduced-motion` / Reduce Motion:** freeze breathing, drop transitions to 0.01 ms, park transitions at their end state, and keep the composition static. The information must survive with motion removed.
- Ambient loops pause when the window is hidden, minimised, occluded, or the app is inactive.
- Never animate a number that is not actually changing.

---

## 13. State and feedback

| Situation | Response |
|-----------|----------|
| No session | Chip hidden; CTA `开始一起工作`; Joey `sit` |
| Session running | Chip `陪伴中 · mm:ss`; CTA `结束陪伴`; Joey `look` |
| Invitation due | Joey `sign` + card; one invitation only |
| Invitation deferred | Toast, schedule one later invitation, no repeat nagging |
| Invitation paused | Toast `先安静一会儿。`, no further invitations until resume |
| Recovery running | Real countdown; no skip penalty |
| Recovery completed | Break count +1, Joey `happy` ~2.6 s, one leaf added |
| Recovery skipped | Return to desktop silently; count unchanged |
| Hidden Joey | Pet invisible but state preserved; Settings switch is the way back |
| Quiet hours | Joey `sleep`, no invitations, no motion beyond breath |
| Empty reflection day | Show a visible seed in the soil; never a zero-score or a "failure" |

Every feedback message states what happened in one sentence. Never a status code, never a machine voice.

---

## 14. Accessibility

| Area | Requirement |
|------|-------------|
| Contrast | Body ≥ 4.5:1, large text ≥ 3:1, essential graphics ≥ 3:1; audit dusk independently |
| Colour | Never the only channel; pair with text, icon, or shape |
| VoiceOver | One combined label for composite surfaces; decorative SVG hidden; every custom control named |
| Keyboard | Full Keyboard Access; visible sage focus ring; primary action as default button; menu reachable |
| Hit targets | ≥ 28 × 28 pt, never below 20 × 20 pt; ≥ 8 pt between adjacent targets; the hit region may exceed the glyph |
| Text scaling | Settings and feedback survive system text size; illustration-side captions may stay fixed |
| Motion | Reduce Motion honoured everywhere, including breathing and hover |
| Language | `lang="zh-CN"`; dates and numbers use Chinese formats (`11月21日 周六`, `2 小时 10 分`) |

Do not apply iOS 44 × 44 guidance to macOS controls.

---

## 15. SwiftUI / AppKit implementation notes

| Concern | Decision |
|---------|----------|
| Tokens | Create `macos/JoeyPet/Design/JoeyPetTheme.swift` (colors, type, spacing, radius, motion) before the first screen. Views reference tokens only. |
| Appearance | `Color` sets or a theme environment value for light/dusk; no per-view hex. |
| Windows | AppKit owns windows and panels (`NSWindow`, `NSPanel`, `NSStatusItem`). SwiftUI owns content. Do not migrate to SwiftUI `App`/`WindowGroup`. |
| Main window | Standard titled window, full-size content view, transparent titlebar, no toolbar, no titlebar separator. Native traffic lights. |
| Desktop pet | Borderless non-activating `NSPanel`, draggable, position persisted after drag end, clamped to visible screen. |
| Invitation | Panel anchored near the pet, not `NSAlert`. |
| Recovery | In-window or pet-adjacent panel with a real timer driven by the domain model. |
| Room / garden | SwiftUI `Canvas` or a static SpriteKit scene; keep drawing separate from state. Reuse `room-*` tokens for both appearances. |
| Settings | Native controls inside a standard window; no custom-chrome recreation of `Form`. |
| Copy | Centralise user-facing strings; no inline sentence fragments scattered across views. |

Do **not** port the HTML/CSS artifact into the app. It is a visual reference; the implementation is native.

---

## 16. Review checklist

Before marking any UI task done:

1. One primary action per state; secondary/quiet actions do not compete.
2. Every colour, size, radius, and duration comes from a token.
3. Light **and** dusk checked, separately.
4. CJK line height ≥ 1.35 on display text; no negative tracking on Chinese.
5. No uppercase micro-labels, no emoji icons, no pill-shaped everything.
6. Spacing follows the 4/8 rhythm; nothing overlaps the pet, the sign, or the CTA.
7. Copy passes the voice rules in §11 — factual, short, no praise, no guilt.
8. Numbers are self-consistent (today ≤ week; clock matches the "resume at" time).
9. Real states only; nothing simulated that the product cannot detect.
10. Reduce Motion and keyboard focus verified.
11. No toolbar, tab bar, or second navigation inside the main window.

---

## 17. Anti-patterns

- Building a dashboard, checklist, timer app, or system monitor inside JoeyPet.
- A KPI card grid, bar-chart analytics, or "efficiency score" on any surface.
- XP, levels, streaks, trophies, shops, leaderboards, loot.
- Guilt, failure states, or a scolding Joey.
- Inferred working time from uptime or screen activity.
- OS alerts, warning icons, or modal scrims for a rest invitation.
- Toolbar, segmented mode switch, tab bar, or global sidebar in the main window.
- Stitch-era Calm Space orb/dial canvas, dock, hover mode switch, or status block.
- Uppercase eyebrows, triple-negation slogans, sugar-coated `完成啦`, or meta explanations of the product's own kindness.
- Emoji used as icons; hand-drawn SVG people used as decoration.
- Hardcoded hex in views; a second palette that drifts from §4.
- Uppercase tracking on Chinese; negative tracking on Chinese; Latin display leading on Chinese headlines.
- Fake metrics, fabricated growth, or "we detected your rest".
- Copying the HTML reference's CSS into the app.

---

## 18. Legacy (do not implement)

Retired in the 2026-11 focus shift, kept for traceability only (archive branch `archive/mac-care-calm-space-2026-11`):

- Mac Care orb canvas, status block, floating dock, hover-expanding mode switch.
- Full Disk Access onboarding, disk cleanup and Trash flows, application uninstall.
- Calm Space three-stop gradient canvas, Work Rhythm dial, SpriteKit ambient scenes.
- Settings sections 电脑状态 / 工作状态.
- Stitch project JoeyPet as the design input (no longer the source; the frozen HTML in `docs/reference/` replaces it).

Git history and the archive branch explain why they were replaced.

---

## 19. References

| Topic | Document |
|-------|----------|
| V0 product scope | [`V0_FEATURE_SCOPE.md`](V0_FEATURE_SCOPE.md) |
| Handoff and next steps | [`开发交接文档.md`](开发交接文档.md) |
| Frozen UI design | [`docs/reference/joeypet-ui-v0.html`](docs/reference/joeypet-ui-v0.html) |
| Pet animation and state | [`docs/pet-runtime.md`](docs/pet-runtime.md) |
| Tech stack | [`docs/tech-stack.md`](docs/tech-stack.md) |
| Agent hard rules | [`AGENTS.md`](AGENTS.md) |
| UI intent triage | [`.agents/skills/joeypet-macos/references/ui-intent.md`](.agents/skills/joeypet-macos/references/ui-intent.md) |

---

## 20. Document history

| Date | Change |
|------|--------|
| 2026-09-25 | Rebuilt as the native Calm Space implementation contract. |
| 2026-10-27 | Introduced layered authority; documented dock + hover mode switch; Current/Legacy/Pending status. |
| 2026-11-22 | Replaced the Calm Space contract with the V0 desktop-companion design: new tokens (ivory / ink / sage / apricot / mist), single-room window with in-scene navigation, six states, copy voice, motion and review rules; frozen HTML reference added; Calm Space moved to Legacy. |
