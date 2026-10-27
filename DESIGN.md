# JoeyPet — Native macOS Design Implementation Contract

**Status:** Repository design source of truth for **native implementation** (SwiftUI, AppKit, SpriteKit).  
**Design input:** Stitch project **JoeyPet** (`projects/14486211155070464514`) — freeze screens + **JoeyPet macOS Native** design system, used when retrievable.  
**Not in scope here:** product acceptance rules ([`docs/product/feature-spec.md`](docs/product/feature-spec.md)), file safety ([`docs/safety.md`](docs/safety.md), [`docs/cleanup.md`](docs/cleanup.md)), pet runtime ([`docs/pet-runtime.md`](docs/pet-runtime.md)), pixel character production ([`docs/character-design.md`](docs/character-design.md)).

---

## Design Authority

Sources are layered, not ranked. Each layer answers a different question:

```text
Platform    Apple HIG — official macOS pages    → interaction, native behavior, accessibility
Product     This Design.md                      → JoeyPet visual language, layout, tokens, copy
Exception   docs/decisions/ ADRs                → one named deviation from Design.md or HIG
Input       Stitch project JoeyPet              → exploration and freeze screens, when retrievable
Engineering AGENTS.md, docs/tech-stack.md       → AppKit/SwiftUI/SpriteKit split, zero third-party deps
```

- **This file is the reviewable baseline.** It is what implementation is checked against.
- **Stitch is an input, not an unreviewable override.** A Stitch change wins only when its freeze screen or design-system artifact is retrievable and reviewable; record the change here in the same task.
- **When Stitch is unreachable** (no MCP/tool access, no exported artifact), do not guess its content: follow this file and existing patterns, and note the gap instead of inventing a new visual system.
- **Apple HIG governs platform behavior and accessibility.** Prefer the official pages (`https://developer.apple.com/design/human-interface-guidelines/<page>.md`); community HIG summaries are not authoritative.
- **ADR exceptions are narrow.** ADR 011 records the Calm Space deviation from default window chrome; it does not authorize custom chrome elsewhere.

### Stitch verification (2026-09-25 — historical record)

**Not normative any more** — kept only as the record of that audit; ADR 011 and the Current baseline govern today. Stitch was reachable and reviewed at that time. Re-checked via Stitch MCP **all freeze screens** (Mac Care states, Work Rhythm, Settings ×3, Applications, cleanup sheet, Optical Masters) and downloaded HTML for structure analysis. **Freeze screens override designMd** when they disagree: Mac Care home states use **full-width 800 pt content** under the toolbar—**not** a permanent global 320 pt Joey column. Joey Stage is a **reusable layout pattern** (feature- or state-local), not universal app shell chrome.

---

## Design Maintenance

Stitch is the upstream design **input**; this file is the committable source of truth.

**When a freeze screen changes (and its artifact is retrievable):**

1. Update implementation to match Stitch.
2. Update this file if reusable rules (tokens, patterns, IA) changed.

**When a new screen ships without a Stitch design:**

1. Follow this file + existing patterns (shell, stage, typography, controls).
2. If the surface becomes permanent, record it here; add an ADR when it deviates from platform or product rules.
3. Freeze it in Stitch when Stitch is available, and sync reusable rules back here.

```text
Stitch (input, when reachable) → ADR (exceptions) → Design.md → Implementation
```

---

## Current Baseline Status

This file describes the **shipped** UI. Every design statement below is one of three states:

| Status | Meaning | Examples |
|--------|---------|----------|
| **Current** | Implemented and confirmed by an effective ADR/product decision; this is the design of record | Calm Space two-page canvas; floating dock; hover-expanding mode switch; status block; Settings app page; desktop Joey panel; permission onboarding; disk cleanup page |
| **Legacy** | Replaced by an effective decision; kept only for history and traceability | Toolbar + segmented mode switch; persistent Joey Stage column; right Inspector; MacCareHomeView dashboard; UnifiedWindowNavigation |
| **Pending** | Confirmed intent or prototype that is not shipped; must not be described or implemented as current | Work Rhythm focus/rest timer + statistics; Applications/uninstall; Settings 电脑状态/工作状态 detail; Calm Space Stage prototype (DEBUG-only); activity slot, action chips, today-stats |

Anything not labelled **Current** is not part of the shipped design: **Legacy** must not be implemented, and **Pending** is a confirmed requirement that is not yet implemented. When code and this document disagree, do not refactor code to match the document: determine which is authoritative (ADR/product decision vs stale text) and fix the document first.

---

## Product Visual Language

JoeyPet is a **small, native macOS utility** with a desktop pet as the **state and interaction layer**.

| Keyword | Meaning |
|--------|---------|
| **Native** | macOS patterns and system components; not a web dashboard. |
| **Clear** | Users grasp state without reading paragraphs. |
| **Visual** | Encode proportion, progress, severity, and outcome when it aids understanding. |
| **Calm** | Quiet at rest; no decorative motion. |
| **Alive** | Joey and purposeful motion explain change—not decoration. |
| **Honest** | Show only real states. A capability that is not implemented says so instead of showing mock data, fake progress, or placeholder metrics. |

**JoeyPet is not:** Electron shell, SaaS KPI wall, dense toolbox app, Apple.com marketing page, or iPad-style card stacks with heavy shadows.

**Visualization ≠ dashboard:** few important metrics with strong encoding beats many labels and repeated badges. No fake trends, percentages, or progress.

**Primary UI language:** Simplified Chinese (V1). Layout and controls must tolerate longer English later.

---

## Stitch → Native Translation (historical input)

These mapping rules were written when Stitch freeze screens were the primary input. They apply **only when reconciling a retrievable Stitch artifact**; they are not a license to reintroduce web tokens. The shipped Calm Space canvas is defined by the sections below.

### Typography

| Stitch | Native implementation |
|--------|------------------------|
| `Inter`, `headline-lg` … `label-sm` | **System font** — SF Pro via `.font(.headline)`, `.title2`, `.body`, `.callout`, `.caption`, `.caption2` |
| `mono-data` | `.monospacedDigit()` on numeric metrics and timers |
| Web letter-spacing | Use system text styles; avoid custom tracking unless HIG allows |

Do **not** bundle SF Pro or install Inter.

### Colors

Stitch semantic hues (`#007AFF`, `#34C759`, `#FF9500`, `#FF3B30`) express **intent**. Prefer SwiftUI/AppKit semantic colors for system surfaces:

| Role | Prefer |
|------|--------|
| Accent / primary action | `accentColor`, `.borderedProminent` |
| Healthy / success | `Color(NSColor.systemGreen)` |
| Focus / caution | `Color(NSColor.systemOrange)` |
| Critical / destructive emphasis | `Color(NSColor.systemRed)` |
| Text | `primary`, `secondary`, `tertiary` |
| Chrome | `separator`, `windowBackgroundColor`, `controlBackgroundColor` |

Fixed hex is allowed for **brand/marketing** and inside an **ADR-approved tuned palette** (ADR 011 Calm Space). Native chrome, Settings, and onboarding stay semantic for Light/Dark and Increase Contrast.

### Controls & dimensions

| Stitch CSS | Native implementation |
|------------|------------------------|
| 22px / 28px button heights | `Button`, `Button(.bordered)`, `Button(.borderedProminent)`, default control sizes |
| Custom segmented chrome | `Picker` with `.pickerStyle(.segmented)` — **superseded for the main window** by ADR 011's mode switch; still valid for conventional Settings/forms |
| Toggle / checkbox mockups | `Toggle`, native checkbox in `Form` |
| Sheet layouts | `.sheet` / `NSWindow` sheet with system chrome |
| Destructive batch actions | `confirmationDialog` / `NSAlert` + copy per [`docs/safety.md`](docs/safety.md) |

Preserve **interaction intent** (one primary action, disabled while busy, confirm before Trash).

### Materials

Use system materials (`background(.ultraThinMaterial)` / `NSVisualEffectView`) for **system surfaces** — Settings, sheets, popovers, panels. The Calm Space canvas is intentionally opaque and gradient-based per ADR 011: **do not add vibrancy or material stacks there.**

---

## Main Window (Calm Space)

### Geometry and chrome

| Attribute | Rule |
|-----------|------|
| Default content size | **800 × 560 pt** |
| Frame minimum | **680 × 512 pt** (content minimum **680 × 480 pt**) |
| Titlebar | Native titled window with `.fullSizeContentView`, **transparent titlebar**, hidden title, no titlebar separator, **no toolbar** |
| Traffic lights | **Native**, always visible and functional; never redrawn or hidden |
| Movement | Window is movable by background; standard resize/minimise/zoom preserved |
| State restoration | **Not implemented** (no frame autosave/restoration) — Pending |

The immersive window is a **supported NSWindow configuration**, not custom window UI. ADR 011 authorizes the full-bleed canvas; it does not authorize fake window frames, fake traffic lights, or custom window controls. The window must still preserve native window behaviour: key/main/inactive appearance, resize and move, minimum size, Reduce Motion, and Increase Contrast. **Current gaps:** the canvas palette does not yet differentiate key/inactive appearance, and no Increase Contrast variant exists; both are Pending, not compliant.

### Brand

JoeyPet wordmark is **not** rendered in window chrome: identity comes from the app icon, window content, Joey, and macOS context. The window title remains as metadata for window management but is hidden in the titlebar.

### Canvas composition

The main presentation is a single full-window canvas, drawn in layers:

1. **Background** — a three-stop vertical gradient plus ambient radial washes, a mode tint, and a closing vignette (five layers total).
2. **Ambient render** — one SpriteKit layer, 30 FPS, transparent and non-interactive: the Mac Care orb or the Work Rhythm dial.
3. **Status block** — dot, headline, detail, meta line, relative update time, inside a reserved band.
4. **Floating controls** — dock at bottom-leading, mode switch at bottom-trailing.

There are **no cards, panels, dividers, or card stacks on the canvas**. The canvas uses `.ignoresSafeArea()` and derives every position from the live window size; nothing is pinned to a screenshot.

---

## Navigation

### Shipped information architecture

```text
App
├── Permission onboarding        (first run / needed Full Disk Access state)
├── Main — Calm Space            (default presentation)
│   ├── Mac Care page            (default mode)
│   │   ├── 磁盘管理             (real cleanup page: scan → select → Trash)
│   │   └── 应用管理             (placeholder: 尚未开放)
│   └── Work Rhythm page         (placeholder mode: no timer yet)
├── Settings                      (full app-level page, not a mode)
└── Outside the window
    ├── Desktop Joey             (separate panel, hidden by default)
    ├── Status bubble
    └── Status-bar menu
```

There is **no toolbar and no global navigation bar**. The window is a single hosting surface: `presentation` switches between onboarding, Calm Space, and Settings; `mode` switches Mac Care ↔ Work Rhythm; `MacCareRoute` switches home ↔ feature pages.

### Mode switch

- One hover-expanding capsule at **bottom-trailing**, not a toolbar segment.
- Collapsed it is a circular button; on hover it grows toward the leading edge and reveals the destination label.
- One click writes `mode` with a single animated transition; **re-entry is ignored while a transition is in flight**.
- Copy names the destination (“切换至工作模式” / “切换至 Mac Care”).
- This is an **ADR 011 custom control**, not a native `Picker(.segmented)`.

### Dock

- Floating pill at **bottom-leading**; flat fill + 1 pt hairline, no material stack, no gradient.
- Entries depend on mode:
  - Mac Care: 磁盘管理, 应用管理, 系统设置.
  - Work Rhythm: 专注, 休息 (disabled, 尚未开放), 系统设置.
- Compact layout makes entries icon-only; labels are hidden.
- Dock and mode switch never overlap: the layout reserves the switch's expanded width as trailing space.

### Feature pages

- 磁盘管理 and 应用管理 **replace the whole canvas**: orb, dock, and mode switch disappear; the SpriteKit scene stops.
- Back is an in-page header row (`‹ Mac Care`) that returns to the Calm Space home; there is no global back button.
- Content is capped and laid out per page; no second navigation bar.

### Settings

- A **full app-level page** inside the same window, not a sheet, popover, or third mode.
- Layout: fixed **200 pt sidebar** + divider + detail (detail max width 520 pt).
- Back is the **first sidebar row** (`‹ 返回`), restoring the previous mode and route.
- Sections: **通用** (implemented), **电脑状态** (placeholder), **工作状态** (placeholder).
- Settings stays semantic/system-coloured; it does not use the Calm Space palette.

### Entry routing

| Entry | Behaviour |
|-------|-----------|
| App launch | Main window; permission onboarding when needed, otherwise Calm Space Mac Care |
| Status-bar menu | 打开 JoeyPet / 快速清理 / 扫描并查看… / 设置… / 退出 (⌘Q) |
| Dock icon reopen | Restores the main window |
| Window close | Closes the window; app and desktop Joey keep running |

### Legacy navigation (do not implement)

Toolbar with segmented **Mac Care | 工作节奏** and a Settings gear, a persistent 320 pt Joey Stage column, a right-hand Inspector, and the `Overview | Cleanup | Settings` three-sidebar IA are **superseded** (ADR 011). Their view types may remain temporarily as dead code; they are not design requirements.

---

## Calm Space Dual-Mode Design

### Shared language

- Full-bleed canvas, native traffic lights, floating dock and mode switch; no card stacks.
- Two **independently tuned** palettes (dark/light), not an inverted pair.
- Chinese-first copy; unavailable features are stated honestly.
- The two modes share the shell but **not** a body template: Mac Care is organic and text-led; Work Rhythm is geometric and instrument-led.

### Mac Care page (Current)

- **Visual subject:** SpriteKit orb — soft, asymmetric lighting, slow breathing and orbit, no hard-edged decoration.
- **Status block:** 7 pt status dot + headline + detail + meta line + relative update time. The band has a reserved height so it can never collide with the bottom controls.
- **States:** `normal` / `attention` / `critical` / `unknown`.
  - `unknown` is used when no sensor snapshot has arrived; it never masquerades as normal.
  - `critical` requires memory-critical, storage-critical, or thermal-critical; raw usage alone never raises an alert.
  - Status is never conveyed by colour alone — always dot + text.
- **Meta line:** memory/storage/thermal summary; appends 有限磁盘分析 when Full Disk Access is not granted.
- **Bottom controls:** dock (quick actions) and mode switch.
- **Not in the shipped canvas:** activity slot, action chips, “N 项需要关注”, today-stats (prototype-only).

### Work Rhythm page (Pending — placeholder shipped)

- **Shipped:** same shell with a dial instead of the orb; an honest status block (“专注与休息提醒正在准备中…”); dock entries 专注/休息 disabled with “尚未开放”.
- The dial shows **no numerals, hands, countdown, or progress**; its phase is hard-coded to idle.
- **Pending:** focus/rest timer, session state, countdown/progress, statistics. These must not be simulated.
- Prototype design notes live in [`docs/calm-space-stage-design.md`](docs/calm-space-stage-design.md); the prototype is **DEBUG-only** (`-JoeyPetQAStagePrototype`) and is **not** the shipped design.

### Transition between modes

- Both pages are laid out side by side in one clipped viewport; the incoming page slides horizontally over the outgoing one.
- Single animated write; the destination page is on top; a one-shot settle task clears the re-entry guard.
- Reduce Motion: both pages park at zero offset and cross-fade instead of sliding.
- SpriteKit scenes stay active for both pages while a transition is in flight, so neither freezes.

---

## Layout & Responsive Rules

All values derive from the live window size. The single source for geometry is `CalmSpaceLayout`; change it there, not in this document.

| Rule | Value |
|------|-------|
| Compact condition | width < **760** or height < **520** |
| Horizontal margin | compact **22**; otherwise clamp(5% width, **30**, **48**) |
| Top / bottom inset | **30/18** compact, **34/24** regular |
| Dock height | **36/38** |
| Mode switch | **32/34** diameter, expands to **154/178** |
| Status band reserved height | **100/108** |
| Orb → status gap | **20/30** |
| Status width | min(available, **520/560**), floor **240** |
| Orb diameter | clamp(min(30% width, 80% available height), **140**, min(**280/330**, width − 2·margin)) |
| Orb placement | block sits slightly above optical centre; surplus space becomes bottom breathing room |
| Invariant | status band and bottom controls **never overlap** (geometry is unit-tested) |
| Feature page | content max **880**; side padding clamp(4.5% width, 28, 56); top **38** / bottom **28** |

Resizing re-derives this layout; the SpriteKit layer only forwards the new size (no scene rebuild, no texture re-bake).

---

## Color

### Calm Space canvas (Current)

- One palette shape, **27 roles**, with **two hardcoded, independently tuned tables** (dark / light) selected by the system appearance.
- Role groups: background (3), ambient (2) + stars (1); orb (7) + orbit (2); severity accents (4); text (4); control fill/stroke and hover variants (4).
- The status block's third line uses the dedicated `statusMetaText` role; measured on-screen contrast is **dark 5.5–5.7:1, light 4.6–4.8:1** (both ≥4.5:1). All other roles stay **Pending** — not yet measured.
- Severity accents: `normal` teal-green, `attention` amber, `critical` coral, `unknown` grey-blue. Orb materials change per state by blending, not by a global hue rotation.
- Work Rhythm blends its dial toward indigo and uses a separate small dial palette.
- Values live in `CalmSpaceTheme.swift` as literal colours. **There is no asset-catalog or shared colour-token layer for the canvas** — do not describe it as one.
- **Pending:** Increase Contrast variants and measured contrast ratios. Do not claim contrast compliance without measurement.

### System surfaces (Current)

Settings, onboarding, dialogs, and panels use **semantic/system colours** (`Color(nsColor:)`, `.primary`/`.secondary`/`.tertiary`, `.accentColor`), so Light/Dark and system appearance adapt automatically.

### Safety/severity colours

The pet bubble and sprite use the system severity colours (`StatusColor`). The Calm Space palette is a separate presentation palette and must not be reused as a safety signal.

---

## Typography

### Current implementation

- The Calm Space chrome uses a **fixed point scale**, not semantic text styles and not Dynamic Type:
  - Status: headline **26 / 23 compact** (semibold, tracking −0.3), detail **14 / 12.5**, meta **11 / 10.5**.
  - Dock: label **11**, icon **14**; labels hidden in compact.
  - Mode switch: label **11**, glyph **12**.
  - Feature page: title **24** (semibold), subtitle **12.5**, back label **12**.
  - Settings: page title **20**, section title **11**, row title **13**, row description **11**, sidebar **12**.
- Conventional pages (disk cleanup) use **semantic styles** (`.title2`, `.headline`, `.callout`, `.caption`), so the app is currently a **hybrid** type system.
- System font only; no bundled SF Pro, no Inter, no custom fonts. Avoid Thin/Light weights for UI chrome.
- No Dynamic Type or semantic-style scaling in the Calm Space chrome; only the status meta line uses `.minimumScaleFactor`.

### Intent for new work

- Conventional pages and controls: prefer semantic styles.
- Calm Space chrome: keep the fixed scale unless the canvas itself is redesigned (ADR 011 governs).
- Do not bulk-convert the canvas to semantic styles as a “documentation alignment” — that is a UI change and needs its own task.

---

## Spacing, Surfaces, Elevation

- **Canvas:** no cards, panels, or dividers. Controls are flat fill + hairline stroke; no material stack, no gradient chrome.
- **Dock:** pill radius = half the dock height (18/19; compact 10), internal spacing 8/10, horizontal padding 11 (0 in compact).
- **Mode switch:** capsule, 1 pt stroke.
- **Feature cards / wells:** radius 16 continuous, 0.5 pt stroke; padding 20–24.
- **Permission card:** radius 10, 1 pt stroke at 0.08 opacity.
- **Settings:** sidebar 200 pt, row height 34 pt, row radius 6 pt, detail max 520 pt.
- **Elevation:** the only glow is the status dot. No drop shadows on the canvas; popovers/tooltips may use the system shadow.
- The Stitch spacing scale (4/8/12/16/24/20) is **not implemented as tokens**; use it only as guidance for conventional pages. Per-surface values live in `CalmSpaceLayout`, `SettingsMetrics`, and inline view code.

---

## Controls

| Need | Current implementation |
|------|------------------------|
| Mode switch | Custom hover-expanding capsule (ADR 011) — **not** a segmented `Picker` |
| Dock entries | Custom plain `Button`s with pill fill/stroke |
| Primary / secondary actions | Native `.borderedProminent` / `.bordered` (Settings, onboarding) |
| Toggles, pickers | Native `Toggle` in `Form`, native `Picker` where needed |
| Dialogs | Native `confirmationDialog` / `NSAlert`; copy says **移到废纸篓** |
| Progress | Native `ProgressView` (disk page) |
| Lists / tables | Native `List` / `Table` for apps and scan results when implemented (Pending) |
| Charts | **Swift Charts is not adopted.** The only chart lives in dead `MacCareHomeView`. Do not cite it as current. |
| Materials | System materials on system surfaces only; none in Calm Space |

Rule of thumb: **native controls first**; custom chrome only where an ADR names the surface. Disable duplicate scan/clean while a job is in progress.

---

## Desktop Joey, Bubble, Status Bar

| Surface | Role |
|---------|------|
| Desktop Joey | Separate borderless floating panel; **hidden by default**; toggled by Settings → 通用 → 显示桌宠; hiding pauses rendering |
| Status bubble | Short message near Joey; short text, at most one action; auto-dismiss |
| Status-bar menu | 打开 JoeyPet / 快速清理 / 扫描并查看… / 设置… / 退出 (⌘Q) |

Pet-first: users are not required to open the main window for basic feedback. Desktop Joey is **not** a column or panel inside the main window; do not reintroduce a persistent Joey Stage in the canvas.

Character/pose references remain in [`docs/character-design.md`](docs/character-design.md) and [`docs/pet-runtime.md`](docs/pet-runtime.md). The old “Joey Stage” freeze-screen layout matrix is **Legacy**.

---

## Mac Care Patterns

| Surface | Status | Design intent |
|---------|--------|----------------|
| Calm Space home | **Current** | Orb + status block + dock; state semantics normal/attention/critical/unknown; no cards |
| 磁盘管理 (disk cleanup) | **Current** | Conventional page: scan → selection → native confirmation → Move to Trash; real progress and result states |
| 应用管理 (applications) | **Pending** | Honest placeholder today (“应用卸载尚未开放”); list + detail when implemented; confirmation before any move to Trash |
| Scan / results / cleanup screens | **Pending** | Feature spec requirements remain; not shipped in the Calm Space shell |
| Equal-card dashboard (old home) | **Legacy** | Replaced by ADR 011; do not restore |

Safety and scope always follow [`docs/cleanup.md`](docs/cleanup.md) and [`docs/safety.md`](docs/safety.md). Visual pattern only: destructive actions need clear scope, confirmation, and **移到废纸篓** wording.

---

## Work Rhythm Patterns

| Surface | Status | Design intent |
|---------|--------|----------------|
| Placeholder page | **Current** | Dial + honest “尚未开放” status + disabled dock entries; no fake timer |
| Focus / rest timer | **Pending** | Session state, countdown, progress — only when real timing exists |
| Statistics | **Pending** | Compact session summary; not an analytics wall |
| Stage prototype | **Pending (DEBUG-only)** | `docs/calm-space-stage-design.md`; not shipped |

---

## Settings Patterns

- Full app-level page inside the same window; sidebar 200 pt + detail; back is the first sidebar row.
- Sections: **通用** (Current: 显示桌宠, Full Disk Access status, 重置 Joey 位置), **电脑状态** (Pending placeholder), **工作状态** (Pending placeholder).
- Native `Form` components; **no** charts, hero cards, or decorative Joey in Settings.
- Toggle takes effect immediately; errors appear adjacent to the control (e.g. login item failure).
- Settings uses semantic/system colours, not the Calm Space palette.

### Permissions (Full Disk Access)

- **Onboarding:** First-launch **app-level page** (not alert/sheet). Explains **完全磁盘访问** for Full Mac Care; primary **打开系统设置**, secondary **稍后设置**. Completion is persisted separately from FDA grant state.
- **Settings → 通用 → 权限与访问:** Status row + **打开系统设置** / **前往设置**—never an in-app ON/OFF toggle. States: **已开启** (green), **未开启** (neutral), **未确认** (attention + **重新检查**).
- **Mac Care Limited:** without verified FDA, Calm Space keeps baseline metrics and the status meta appends **有限磁盘分析**; do not spam per-folder permission prompts.
- Copy: accurate local processing only—no exaggerated privacy claims.

---

## State & Feedback

| Area | Loading | Empty | Normal | Warning | Error | Success |
|------|:---:|:---:|:---:|:---:|:---:|:---:|
| Calm Space home | `unknown` status while waiting | — | ✓ | ✓ | — | — |
| Disk management | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Work Rhythm | — | — | placeholder | — | — | — |
| Settings | updating | n/a | ✓ | n/a | ✓ | n/a |
| Bubble | — | — | ✓ | ✓ | — | ✓ |
| Status-bar menu | — | — | ✓ | — | — | — |
| Joey right-click menu | — | — | Pending (F05) | — | — | — |

Show real states only. A feature that is not implemented shows an explicit “尚未开放” state—never a placeholder grid, fake percentage, or simulated progress.

---

## Motion

### Page transition (Current)

- **0.45 s `.easeInOut`** horizontal slide; both pages live in one clipped viewport.
- Re-entry is ignored while a transition is in flight; a one-shot settle task clears the guard (no repeating timer).
- **Reduce Motion:** pages park at zero offset and cross-fade instead; the SpriteKit scenes stay active for both pages during the transition.

### Ambient motion (Current)

- One SpriteKit layer at 30 FPS, non-interactive, with no Metal/shader.
- Mac Care orb: slow breathing, drifting flow, orbit particles, sparse stars; Work Rhythm dial: one slow sweep plus a hairline arc.
- Loops pause when the window is hidden, minimised, occluded, or the app is not active; **Reduce Motion freezes them** and pins a static composition.
- Resize only reprojects; it never restarts or rebuilds the scene.

### Micro-motion (Current)

- Dock hover: 0.17 s ease-out + subtle scale.
- Mode switch hover: 0.22 s ease-out grow/fade.
- These hover effects are currently **not** gated by Reduce Motion — a known gap.

### Rules

- Motion explains state; it is never the only channel for information.
- No decorative looping chrome on static data; no fake progress animation.
- The old Mac Care home fan rotation / trend pulse motion belongs to dead `MacCareHomeView` and is **Legacy**.

---

## Light / Dark

- Calm Space uses **two independently tuned palettes** (dark/light), not an inverted pair; both are selected from the system appearance.
- Settings, onboarding, and dialogs use semantic system colours and adapt automatically.
- Verification today is screenshot-based only (dark/light captures in the local QA directory); **no automated contrast test** exists.
- **Pending:** Increase Contrast variants and measured contrast ratios. Until then, do not claim WCAG/HIG contrast compliance.

---

## Accessibility

| Area | Requirement | Current status |
|------|-------------|----------------|
| VoiceOver | Composite surfaces expose one combined label; decorative layers hidden; controls labelled | **Partial** — canvas status/dock/mode switch labelled; Settings rows are thin |
| Keyboard | Full Keyboard Access; visible focus ring; primary action as default button; app commands available from the menu bar | **Partial** — no explicit focus ring is defined for the canvas controls (`.buttonStyle(.plain)`); the app declares no `.commands`, so actions are not reachable from the menu bar |
| Colour | Never status by colour alone | **Implemented** — dot + text + glyph |
| Pointer targets | **≥ 28 × 28 pt** (macOS HIG default), **never below 20 × 20 pt**; keep ≥ 8 pt between adjacent targets; the hit region may be larger than the drawn glyph | **Partial** — canvas targets are 34/36 pt; settings rows 34 pt; spacing not verified |
| Contrast | 4.5:1 body text, 3:1 large text; Increase Contrast variant | **Not verified / not implemented** — see Light / Dark |
| Charts | Text summary/descriptor | Not applicable — no shipped chart |

**Do not apply iOS sizing guidance to macOS.** 44 × 44 pt is the iOS default control size; the macOS default is **28 × 28 pt** with a **20 × 20 pt** minimum. For pointer-driven macOS controls these are hit-target expectations, not the drawn glyph size.

---

## Implementation Rules

1. **Check Stitch** only when a freeze screen or design-system artifact is retrievable.
2. **Read this file** for native translation and patterns; note each surface's Current / Legacy / Pending status.
3. **Use Apple HIG** for platform behavior and accessibility; record deviations in an ADR.
4. Do not add third-party UI kits or web views for product chrome.
5. Views must not read raw `ProcessInfo` for presentation—use domain models ([`AGENTS.md`](AGENTS.md)).
6. One obvious **primary action** per state machine step.
7. Window close ≠ quit; lifecycle: [`docs/app-lifecycle.md`](docs/app-lifecycle.md).
8. **Do not refactor code to match this document.** If implementation and documentation disagree, decide which is authoritative (ADR/product decision vs stale text) and fix the document; code changes need their own task.
9. Keep the AppKit window architecture: windows/panels/menu-bar item are AppKit-owned; SwiftUI owns content.

---

## Anti-patterns

- Three-item sidebar IA (`Overview` / `Cleanup` / `Settings`) as the shipped shell
- Dashboard grids of equal hero cards
- Web-style fixed hex backgrounds ignoring Dark Mode
- Installing Inter or embedding SF Pro
- Mechanical CSS px on controls
- Permanent delete copy or silent Trash
- Fake CPU temperature or RPM from thermal enum
- Toast-only cleanup success without in-flow result
- Second design doc competing with this file or the authoritative ADRs
- Reintroducing the toolbar / Inspector / persistent Joey Stage column
- Documenting a Pending feature as Current
- Copying iOS 44 × 44 pt control targets into macOS guidance
- Adding vibrancy/material stacks or decorative gradients to the Calm Space canvas
- Treating the DEBUG-only Stage prototype as the shipped design

---

## Superseded Design (historical)

The following are kept for traceability only. They were replaced by [ADR 011](docs/decisions/011-calm-space-main-window.md) and must not be implemented:

- Unified toolbar (`UnifiedWindowNavigation`) with segmented **Mac Care | 工作节奏** and a Settings gear.
- Persistent Joey Stage column and right-hand Inspector.
- Mac Care home dashboard (`MacCareHomeView`): equal cards, storage donut, memory chart, fan/pulse motion.
- Freeze-screen-derived layout matrix with “global top nav” per screen.
- `Overview | Cleanup | Settings` three-sidebar product IA.
- The “~44 × 44 pt minimum custom hit region” rule (iOS guidance).

Git history and ADR 011 remain the source for why these were replaced.

---

## References

| Topic | Document |
|-------|----------|
| Product behavior & acceptance | [`docs/product/feature-spec.md`](docs/product/feature-spec.md) |
| V1 scope | [`docs/product/mvp-scope.md`](docs/product/mvp-scope.md) |
| Calm Space main-window decision | [`docs/decisions/011-calm-space-main-window.md`](docs/decisions/011-calm-space-main-window.md) |
| UI skill & design authority | [`docs/decisions/013-ui-skill-and-design-authority.md`](docs/decisions/013-ui-skill-and-design-authority.md) |
| Calm Space Stage prototype spec (Pending) | [`docs/calm-space-stage-design.md`](docs/calm-space-stage-design.md) |
| Cleanup allowlist & execution | [`docs/cleanup.md`](docs/cleanup.md) |
| Safety pipeline | [`docs/safety.md`](docs/safety.md) |
| Pet animation & state | [`docs/pet-runtime.md`](docs/pet-runtime.md), [`docs/domain-model.md`](docs/domain-model.md) |
| Character pixels | [`docs/character-design.md`](docs/character-design.md) |
| Architecture | [`docs/architecture.md`](docs/architecture.md) |
| Marketing web tokens (not app UI) | [`docs/reference/apple-web-design-reference.md`](docs/reference/apple-web-design-reference.md) |
| Agent hard rules | [`AGENTS.md`](AGENTS.md) |

---

## Document history

| Date | Change |
|------|--------|
| 2026-09-25 | Rebuilt as native implementation contract; Stitch > Design.md > HIG hierarchy; replaced legacy three-sidebar UI spec |
| 2026-10-27 | Replaced linear source priority with layered authority (platform / product / exception / external input / engineering); Stitch is a retrievable input, not an unconditional override; official HIG pages named as platform authority |
| 2026-10-27 | Aligned the contract with the shipped Calm Space implementation: removed toolbar/Inspector/Joey-Stage/segmented-switch rules from the current design, documented dock + hover mode switch + feature pages + Settings page, added Current / Legacy / Pending status, corrected macOS pointer-target guidance (28 × 28 / 20 × 20, not iOS 44 × 44), and marked Work Rhythm / Applications / Settings details as Pending |
