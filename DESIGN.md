# JoeyPet — Native macOS Design Implementation Contract

**Status:** Repository design source of truth for **native implementation** (SwiftUI, AppKit, SpriteKit).  
**Upstream:** Stitch project **JoeyPet** (`projects/14486211155070464514`) — freeze screens + **JoeyPet macOS Native** design system.  
**Not in scope here:** product acceptance rules ([`docs/product/feature-spec.md`](docs/product/feature-spec.md)), file safety ([`docs/safety.md`](docs/safety.md), [`docs/cleanup.md`](docs/cleanup.md)), pet runtime ([`docs/pet-runtime.md`](docs/pet-runtime.md)), pixel character production ([`docs/character-design.md`](docs/character-design.md)).

---

## Design Source Priority

When sources conflict, **higher wins**:

```text
1. Stitch — JoeyPet freeze screens + JoeyPet macOS Native Design System
2. This Design.md
3. Apple HIG / native macOS behavior
4. Engineering preference (only when 1–3 are silent)
```

- **When Stitch and Design.md conflict, Stitch wins.** Update this file after Stitch changes.
- **When Stitch has no corresponding screen or explicit rule,** use Design.md and existing Stitch patterns.
- **When neither Stitch nor Design.md defines the behavior,** use Apple HIG and native macOS conventions. Do not invent a new visual system because a screen is missing.

### Stitch verification (2026-09-25 — full layout audit)

Re-checked via Stitch MCP **all freeze screens** (Mac Care states, Work Rhythm, Settings ×3, Applications, cleanup sheet, Optical Masters) and downloaded HTML for structure analysis. **Freeze screens override designMd** when they disagree: Mac Care home states use **full-width 800 pt content** under the toolbar—**not** a permanent global 320 pt Joey column. Joey Stage is a **reusable layout pattern** (feature- or state-local), not universal app shell chrome.

---

## Design Maintenance

Stitch is the upstream design source.

**When a freeze screen changes:**

1. Update implementation to match Stitch.
2. Update Design.md if reusable rules (tokens, patterns, IA) changed.

**When a new screen ships without a Stitch design:**

1. Follow Design.md + existing Stitch patterns (shell, stage, typography, controls).
2. If the surface becomes permanent, add and freeze it in Stitch.
3. Sync reusable rules back into Design.md.

```text
Stitch → Design.md → Implementation
```

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

**JoeyPet is not:** Electron shell, SaaS KPI wall, dense toolbox app, Apple.com marketing page, or iPad-style card stacks with heavy shadows.

**Visualization ≠ dashboard:** few important metrics with strong encoding beats many labels and repeated badges. No fake trends, percentages, or progress.

**Primary UI language:** Simplified Chinese (V1). Layout and controls must tolerate longer English later.

---

## Native macOS Translation Rules

Stitch uses web-oriented tokens (Inter, hex colors, CSS px). **Do not copy them literally into Swift.**

### Typography

| Stitch | Native implementation |
|--------|------------------------|
| `Inter`, `headline-lg` … `label-sm` | **System font** — SF Pro via `.font(.headline)`, `.title2`, `.body`, `.callout`, `.caption`, `.caption2` |
| `mono-data` | `.monospacedDigit()` on numeric metrics and timers |
| Web letter-spacing | Use system text styles; avoid custom tracking unless HIG allows |

Do **not** bundle SF Pro or install Inter.

### Colors

Stitch semantic hues (`#007AFF`, `#34C759`, `#FF9500`, `#FF3B30`) express **intent**. Prefer SwiftUI/AppKit semantic colors:

| Role | Prefer |
|------|--------|
| Accent / primary action | `accentColor`, `.borderedProminent` |
| Healthy / success | `Color(NSColor.systemGreen)` |
| Focus / caution | `Color(NSColor.systemOrange)` |
| Critical / destructive emphasis | `Color(NSColor.systemRed)` |
| Text | `primary`, `secondary`, `tertiary` |
| Chrome | `separator`, `windowBackgroundColor`, `controlBackgroundColor` |

Use fixed hex only when Stitch locks a **brand** element (e.g. marketing); app UI stays semantic for Light/Dark and Increase Contrast.

### Controls & dimensions

| Stitch CSS | Native implementation |
|------------|------------------------|
| 22px / 28px button heights | `Button`, `Button(.bordered)`, `Button(.borderedProminent)`, default control sizes |
| Custom segmented chrome | `Picker` with `.pickerStyle(.segmented)` |
| Toggle / checkbox mockups | `Toggle`, native checkbox in `Form` |
| Sheet layouts | `.sheet` / `NSWindow` sheet with system chrome |
| Destructive batch actions | `confirmationDialog` / `NSAlert` + copy per [`docs/safety.md`](docs/safety.md) |

Preserve **interaction intent** (one primary action, disabled while busy, confirm before Trash).

### Materials

Stitch describes `NSVisualEffectView` sidebar/window vibrancy. Use SwiftUI `background(.ultraThinMaterial)` / AppKit `NSVisualEffectView` with **sidebar** or **windowBackground** materials—not flat mockup grays.

---

## Global Window Shell

### Window geometry (global)

| Attribute | Rule |
|-----------|------|
| Default size | **800 × 560 pt** (Stitch); minimum **680 × 480 pt** |
| Titlebar | Unified toolbar; **title visibility hidden** in chrome |
| Brand in global nav | **Do not** show **JoeyPet** in the toolbar/titlebar unless a future Stitch freeze screen explicitly does. App identity = icon, window, Joey, macOS context. |
| Structure | **Not** permanent 320 Joey + 480 content; **not** legacy three-sidebar product IA |

### Presentations

```text
MainWindow
├── UnifiedWindowNavigation (configuration varies)
└── PresentationContainer
    ├── MainPresentation → MacCareRoot | WorkRhythmRoot
    └── SettingsPresentation → SettingsRoot (sidebar + detail body)
```

`AppMode` (Mac Care / 工作节奏) applies only while `presentation == .main`. Settings is **not** a third mode.

## Unified Global Navigation

One toolbar host for the whole main window: `UnifiedWindowNavigation` on `AppShellView`. Presentation content does not add a second toolbar, navigation title, or sidebar toggle.

| Configuration | Leading | Center | Trailing |
|---------------|---------|--------|----------|
| **Main** (`presentation = main`) | Traffic lights only | Segmented **Mac Care \| 工作节奏** | Settings gear |
| **Settings** (`presentation = settings`) | Traffic lights only | **设置** | Empty |

Main must not show JoeyPet, Back, a sidebar toggle, or a page title in this bar. Settings must not show JoeyPet, the mode switch, the gear, a sidebar toggle, or a second toolbar row.

Entering Settings hides the mode switch and settings gear. **返回** is the **first row of the Settings sidebar navigation** (same row metrics as section items, `chevron.left` + label, normal label color—not a toolbar/link header), followed by a divider, then section rows. It is not a `SettingsSection` selection. It restores the previous `AppMode` and routes without recreating the window. Settings stays a full app-level page (not a sheet, popover, or modal).

## Brand

JoeyPet brand text is not rendered in the current global navigation. The name may still exist as the app name, window metadata (`NSWindow.title`), About, and the bundle display name.

## Settings

The Settings sidebar belongs to the page body, under the single global toolbar:

```text
SettingsRootView
├── Sidebar
│   ├── 返回
│   ├── divider
│   └── 工作状态 / 电脑状态 / 通用
└── Detail
```

It is not part of Global Navigation. Do not use a navigation container that inserts a sidebar toggle or a toolbar tracking separator.

## Detail Navigation

Feature back / breadcrumb belongs to page content, not the global navigation. Applications and Statistics keep Main global navigation (mode switch + gear). **‹ Mac Care** / **‹ 工作节奏** and the page title live inside the feature body (`FeaturePageNavigationHeader`).

### Body layout ownership

| Owner | Layout |
|-------|--------|
| Mac Care | Full-width containers; per-route (home, scan, results, apps, detail) |
| Work Rhythm | Character- or stats-oriented layouts per screen |
| Settings | Sidebar ~200 pt + detail (body only; sidebar toggle not in global nav) |
| Joey Stage | **Screen/feature pattern** when Stitch includes it—not a global column |

### Layout matrix (freeze-screen derived)

| Screen (examples) | Global top nav | Page back | Sidebar | Main body |
|-------------------|----------------|-----------|---------|-----------|
| Mac Care Normal | Mode + gear | — | — | Full width |
| Mac Care Applications | Mode + gear | ‹ Mac Care (in content) | — | Full width |
| Work Rhythm Statistics | Mode + gear | ‹ 工作节奏 (in content) | — | Full width |
| Settings 通用/电脑/工作 | 设置 | — | 返回 + Settings list | Detail |
| Cleanup confirm | Parent nav + sheet | — | — | Sheet |

---

## App Shell

### Outside main window

| Surface | Role |
|---------|------|
| Desktop Joey | Primary presence; transparent sprite window |
| Status Bubble | Short message near Joey |
| Context Menu | Stable daily actions |

Pet-first: users are not required to open the main window for basic feedback.

---

## Layout System

### Spacing scale (map Stitch → pt)

| Token | pt | Use |
|-------|-----|-----|
| `space-xs` | 4 | Tight inline gaps |
| `space-sm` | 8 | Icon–label, compact stacks |
| `space-md` / `gutter` | 12 | Column gutter, grouped row padding |
| `space-lg` | 16 | Section internal padding |
| `space-xl` | 24 | Section separation |
| `margin` | 20 | Outer content inset from inspector edges |

Stack on **system** `Form` / `List` spacing; do not import apple.com 80 px marketing sections.

### Corner radius

| Surface | pt |
|---------|-----|
| Window | ~10 (system window) |
| Grouped cards / wells | **8** |
| Buttons, segments, inputs | System default (~5–6) |
| Status beads | Circle |

### Elevation

Depth via **material tiers** and hairline borders—not saturated drop shadows. Popovers/tooltips may use subtle system shadow (Stitch Level 2); main shell cards stay flat/inset.

---

## Color System

### Semantic severity (shared with Joey reactions)

| Semantic | Use | Native color |
|----------|-----|--------------|
| `normal` | All clear | Secondary text + green accent sparingly |
| `notice` | Worth knowing | Blue accent |
| `warning` | Action soon | Orange + symbol + text |
| `critical` | Urgent | Red + symbol + text |

**Never status by color alone** — combine label, symbol, and layout (HIG).

### Mac Care vs Work Rhythm accents

- **Mac Care / diagnostics:** blue accent for selection and primary scan/clean paths.
- **Work Rhythm / rest:** green for rest/break; orange for focus intervals and gentle reminders (Stitch `overrideSecondaryColor` / `overrideTertiaryColor` intent).

Destructive file actions use warning copy and confirmation—not red decorative chrome. See [`docs/safety.md`](docs/safety.md).

---

## Typography

| Role | SwiftUI (preferred) | Typical use |
|------|---------------------|-------------|
| Window / section title | `.title2` / `.title3` + `.semibold` | Inspector headers |
| Card title | `.headline` | Metric card titles |
| Body | `.body` / `.callout` | Explanations |
| Secondary | `.subheadline` + `.secondary` | Hints, footnotes |
| Labels / toolbar | `.caption` / `.caption2` | Badges, meta |
| Metrics | `.body` + `.monospacedDigit()` | CPU %, timers, sizes |

Avoid Thin/Light weights for UI chrome. Dynamic Type: prefer semantic styles over fixed point sizes.

---

## Spacing

- Inspector content: **20 pt** horizontal margin unless a `Form` edge aligns to system inset.
- Card internal padding: **12–16 pt**.
- Between stacked cards: **12 pt**.
- Joey Stage: center pet with breathable padding; vitals along bottom or side per Stitch freeze frame—do not crowd the sprite.

---

## Surfaces / Dividers

- **Level 0:** window material / `windowBackground`.
- **Level 1:** grouped cards — `controlBackground` or light inset fill + `separator` outline (Stitch grouped card).
- **Level 2:** sheets, popovers — system sheet background + standard shadow.

Dividers: `Divider()` or `separator` color; 1 px logical. No gradient rules between sections.

---

## Controls

| Need | Use |
|------|-----|
| Mode switch (Mac Care / Work Rhythm) | `Picker` + `.segmented` in toolbar |
| Primary action | `.borderedProminent` — **one** per screen state |
| Secondary | `.bordered` or plain |
| Settings toggles | `Toggle` in `Form` |
| Lists (apps, scan results) | `List` / `Table` with native selection |
| Progress | `ProgressView` — indeterminate unless real per-item progress exists |
| Charts / sparklines | **Swift Charts** when Stitch shows trends |
| Destructive confirm | Sheet or alert; copy **移到废纸篓** |

Disable duplicate scan/clean while a job is in progress (menu + in-window).

---

## Navigation

### Information architecture (current product)

```text
App (main window)
├── Main presentation
│   ├── Toolbar: Mac Care | Work Rhythm + Settings entry
│   ├── Mac Care — full-width routes (normal, notice, scan, results, clean, apps, detail…)
│   └── Work Rhythm — character-first layouts (normal, approaching, break, statistics)
│
└── Settings presentation (app page, not a mode)
    └── Sidebar: 通用 · 电脑状态 · 工作状态 + detail

Non-window
├── Desktop Joey
├── Bubble
└── Context Menu
```

**Deprecated IA (do not implement):** `Overview | Cleanup | Settings` as three sidebar destinations. Legacy code names may remain until refactored.

### Settings navigation

Stitch freeze screens:

- **Settings — 通用** (launch at login, general prefs)
- **Settings — 电脑状态** (monitoring / Mac-related prefs)
- **Settings — 工作状态** (Work Rhythm prefs)
- **Settings Sidebar Item — Component States** (list row hover/selected/disabled)

Use a **leading sidebar list** inside the Settings surface + detail `Form`—not the main window’s left pane.

### Entry routing

| Entry | Behavior |
|-------|----------|
| Open JoeyPet | Show main window; default **Mac Care** normal |
| Scan and View | Mac Care → scan flow |
| Settings | Open Settings surface |
| Quick Clean | Confirm + execute safe set (product rules in feature spec) |

---

## Joey Stage / Character States

### Stage (layout pattern—not global shell)

- **Joey Stage is a layout pattern, not a universal app shell column.** Stitch Mac Care normal / attention / results / applications use **full-width** content with no permanent left habitat.
- **Work Rhythm** freeze screens center or embed Joey (e.g. **128 pt** optical master in Normal)—character-first within the feature.
- **Habitat well:** recessed, calm background; Joey rendered via SpriteKit in the stage region when that pattern is used.
- **Vitals:** compact summary when the pattern includes them—not a full metrics dashboard.
- Stage reflects **pet-centric** state names (`idle`, `sweating`, `tired`, etc.) — mapping from sensors lives in behavior docs, not here.

### Optical Master (Stitch freeze assets)

Reference poses for marketing and stage composition—not separate product pages:

| Stitch screen | Intent |
|---------------|--------|
| Joey — Focused Companion | Default attentive pose |
| Joey — Relaxed Resting | Break / rest rhythm |
| Joey — Gentle Reminder | Soft nudge before break |

Runtime animation clips: [`docs/character-design.md`](docs/character-design.md), [`docs/pet-runtime.md`](docs/pet-runtime.md).

### Desktop Joey (outside shell)

Same character language; smaller hit target; bubble and menu per feature spec. Do not duplicate main-window card UI on the desktop sprite.

---

## Mac Care Patterns

Align to Stitch freeze screens (titles abbreviated):

| Screen | Design intent |
|--------|----------------|
| 正常状态 (含应用卸载) | Summary cards: storage, caches, applications entry; notice/normal encoding |
| 注意状态 | Warning semantics without alarmist copy |
| 扫描状态 / 扫描中 | Full-page or dominant progress; hide stale results |
| Scan Results | Safe vs review grouping; one obvious primary CTA |
| 清理确认 (Sheet) | Scope summary before Trash |
| 正在清理 | Indeterminate progress; disable duplicate actions |
| 清理完成 / Success / Partial Success | Outcome counts, next step—not toast-only |

### Applications & uninstall

Stitch includes **Applications** list and **App Uninstall Detail** (associated files). UI follows list + detail inspector pattern; **safety and scope** follow product/feature specs and ADRs—confirmation before any move to Trash.

### Cleanup UI vs safety rules

Visual pattern only: destructive actions need clear scope, confirmation, and **移到废纸篓** wording. Allowlist, Safe/Review, and executor boundaries: [`docs/cleanup.md`](docs/cleanup.md), [`docs/safety.md`](docs/safety.md).

---

## Work Rhythm Patterns

| Screen | Design intent |
|--------|----------------|
| Normal (Focused Companion) | Timer/focus state; green/orange encoding per mode |
| Approaching Break | Gentle reminder; Joey Gentle Reminder master |
| Break (Relaxed & Resting) | Rest UI; reduced density |
| Statistics | Session summaries; charts compact, not analytics wall |

**Feature layout:** character-first (centered or stage + companion panel per screen)—**not** the Mac Care full-width dashboard. Mode switch in the main toolbar does **not** imply a shared two-column body.

---

## Settings Patterns

- `Form` + sidebar sections; **no** charts, hero cards, or decorative Joey in settings.
- Toggle immediate effect; errors adjacent to the control (e.g. login item failure).
- Groups match Stitch: **通用**, **电脑状态**, **工作状态**.

---

## State & Feedback

| Area | Loading | Empty | Normal | Warning | Error | Success | Disabled |
|------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Mac Care scan/clean | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Work Rhythm | ✓ | n/a | ✓ | ✓ | n/a | ✓ | per control |
| Settings | updating | n/a | ✓ | n/a | ✓ | n/a | per control |
| Bubble | — | — | ✓ | ✓ | — | ✓ | busy |
| Context menu | — | — | ✓ | — | — | — | busy actions |

Show real states only—no placeholder grids to “complete” a checklist.

---

## Motion

- **UI:** subtle, functional (segment slide, progress). Respect **Reduce Motion**.
- **Joey:** animation driven by pet runtime; no looping decorative UI chrome.
- Stitch 200 ms segment spring → approximate with short ease; do not block on custom spring physics.

### Mac Care Home (live monitoring)

Motion explains state—no decorative loops on static data.

| Pattern | Behavior |
|---------|----------|
| **Memory trend** | Real in-app samples only; ~250 ms easeOut morph when a new sample arrives; no fake waves while idle. |
| **Latest sample** | Very subtle pulse at the rightmost point (opacity / scale); disabled under Reduce Motion. |
| **Memory / badge color** | Short easeOut when pressure level changes; no idle badge pulse. |
| **Numeric labels** | Light `contentTransition` on memory, swap, storage totals when values change. |
| **Thermal fan** | Fan glyph rotates continuously at constant angular speed; circle background stays static; speed from **thermal state** (no fake RPM); green / orange / red semantic color with short transition; pause rotation only under Reduce Motion (color + text remain). Main window is AppKit-hosted—do not gate fan on SwiftUI `scenePhase`. |
| **Storage donut** | Static composition; hover + brief transition when classification or capacity updates only. |
| **Cleanup CTA** | Native button only on home; no idle breathe/glow. |
| **Last updated** | Text updates only; no clock animation unless an explicit refresh is in progress. |

---

## Light / Dark

Verify custom surfaces, charts, severity colors, and dividers in **Light** and **Dark**, and **Increase Contrast** when possible. Use semantic colors; preview in Xcode environment variants.

---

## Accessibility

| Area | Requirement |
|------|-------------|
| VoiceOver | Combined labels on overall status; readable row names; chart summaries |
| Keyboard | Logical focus order; activate primary actions |
| Color | Never alone for status |
| Contrast | Avoid faint tertiary for essential facts |
| Targets | ~44×44 pt minimum for custom hit regions |
| Charts | Accessibility chart descriptor or text summary |

---

## Implementation Rules

1. **Check Stitch** when implementing or changing a freeze screen.
2. **Read this file** for native translation and patterns.
3. **Fall back to HIG** when both are silent.
4. Do not add third-party UI kits or web views for product chrome.
5. Views must not read raw `ProcessInfo` for presentation—use domain models ([`AGENTS.md`](AGENTS.md)).
6. One obvious **primary action** per Mac Care state machine step.
7. Window close ≠ quit; lifecycle: [`docs/app-lifecycle.md`](docs/app-lifecycle.md).

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
- Second design doc competing with this file or Stitch

---

## References

| Topic | Document |
|-------|----------|
| Product behavior & acceptance | [`docs/product/feature-spec.md`](docs/product/feature-spec.md) |
| V1 scope | [`docs/product/mvp-scope.md`](docs/product/mvp-scope.md) |
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
