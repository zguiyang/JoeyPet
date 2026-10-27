# UI Intent Reference

Turn a plain-language interface request into the right interaction pattern and the simplest
stable implementation. This is a project lookup, **not** a design textbook:

- Visual rules and Current/Legacy/Pending status → [DESIGN.md](../../../../DESIGN.md)
- Platform behaviour and accessibility → Apple HIG official pages
- API correctness and availability → `swiftui-expert-skill`
- This file → intent, ambiguity triage, implementation choice, common misreads

Read this for intent-level UI requests. Skip it for a single known value/copy/spacing tweak.
Do not quote it back as a report.

## 1. Intent vocabulary (user phrasing → concept)

| Category | User might say | Likely concept | Verify against |
|----------|----------------|----------------|----------------|
| Layout / hierarchy | “很乱”, “挤在一起”, “太空”, “重点不突出” | visual density, grouping, spacing, primary/secondary hierarchy | Design.md layout + a real screenshot at the reported window size |
| Navigation | “切换页面”, “从右边滑进来”, “展开/收起”, “返回” | page transition, spatial continuity, navigation state, back routing | `CalmSpaceRootView`, `CalmSpacePageTransition`, `AppShellView`, `AppShellState` |
| Motion | “动一下”, “淡一点”, “弹一下”, “慢慢呼吸” | transition vs ambient loop vs micro-feedback; Reduce Motion fallback | Design.md Motion + `CalmSpaceOrbScene` / `CalmSpaceRhythmScene` |
| Component state | “放上去展开”, “点了变一下”, “不能点” | hover / pressed / disabled / focus state, interaction feedback | the existing control (`CalmSpaceModeSwitchView`, `CalmSpaceDockView`, Settings form kit) |
| Platform / a11y | “像苹果软件”, “键盘能用”, “读屏能读” | macOS conventions, Full Keyboard Access, VoiceOver labels, target size | Design.md Accessibility + HIG pages |
| Feedback | “加载中”, “空的”, “失败了”, “成功了” | loading / empty / error / success state | Design.md State & Feedback |

One phrase may span several categories. Translate to the concept first, then confirm the
concept against the shipped code — **do not implement from the phrase directly.**

Terminology is for the Agent's reasoning, not for the user. Never ask the user to define
“transition”, “hover”, “hierarchy”, or similar.

## 2. Ambiguity triage

| Outcome | When | Example |
|---------|------|---------|
| **Act** | Intent is clear and the existing structure already answers “how” | “切换时整屏左右滑” → reuse the shipped Calm Space paging model |
| **Assume (state once)** | Minor ambiguity that cannot change the outcome | “展开顺滑一点” → keep the existing 0.22 s ease-out unless a value is requested |
| **Ask — decision** | The choice changes product behaviour, navigation model, window architecture, or the interaction outcome | “把设置移到顶栏” (IA), “窗口改成分页” (navigation model), “重做首页/换主色” (product visual decision) |
| **Ask — evidence** | You cannot inspect the result and grounding it is needed (which page, window size, screenshot) | “这个页面很乱” → check local captures and window size first; if still unclear, ask for the one missing item (page/capture), not a bundle |

Rules:

- Check code, ADR, DESIGN.md, and existing QA captures before asking — the answer is often already there.
- A decision ask offers 2–3 concrete options; an evidence ask asks for a screenshot/size. One question, then proceed.
- Aesthetic complaints (“别扭”, “不高级”, “不像苹果软件”) are **evidence-first**: inspect the screen and captures. Only a named visual redesign (“换主色”, “重做首页”) is a decision ask.
- Do not enter analysis mode for every UI task; ordinary tweaks go straight to implementation.
- Do not ask the user to learn UI vocabulary; translate their words into the project's terms.
- Do not silently redefine a product rule from a one-off request. If a request changes a fact the docs
  name (e.g. a dock label), update that doc line in the same task — a documentation update, not a redesign.
- Classify against DESIGN.md Current/Legacy/Pending before implementing:
  - **Current** = implemented. Verify the **effect** against the request (input behaviour and perceived
    continuity, not only code values); implemented ≠ meets the need.
  - **Pending** = confirmed but not delivered. DESIGN.md's "must not be implemented as current" means
    "do not present it as shipped", not "never build it". This is a backlog state, not a permanent ban: a
    direct request to build/deliver it **is** the authorization (do not ask again); you may then design,
    prototype, build and deliver it. Prototype/trial or not-yet-merged work → keep Pending; user-visible
    and merged to shipping → update DESIGN.md/feature spec in the same task.
  - **Legacy** = deprecated. Do not restore it by default. If the user explicitly asks to re-adopt it,
    surface the conflict with the current ADR/design and resolve it (new or superseding ADR) first.

## 3. Implementation ladder

Stop at the first rung that satisfies the request:

0. **Already shipped** — the behaviour exists. Verify the **actual effect** against the request:
   exists ≠ meets the need. Compare code, screenshots/run evidence, and input behaviour (e.g. clicks
   dropped during a transition, continuity across both pages). "Matches" requires run/captured evidence
   of the requested feel, not just reading the shipped constant; if it matches, say so and stop; if not,
   name the gap and continue. Do not declare done on existence alone.
1. **Reuse** — find an existing project pattern or component
   (`CalmSpaceRootView` paging, dock, mode switch, status block, Settings form kit,
   `confirmationDialog` flows). Prefer extending it over inventing a parallel one.
2. **Native** — Apple controls and APIs: `Button`, `Toggle`, `Picker`, `List`/`Form`,
   `ProgressView`, sheets/alerts; AppKit for windows/panels/menu bar.
3. **Light custom** — only for the immersive canvas, a scoped ADR exception, or an already-shipped
   Current surface (e.g. desktop Joey panel, bubble); keep it local, state-light, and testable
   where the logic is pure. Do not extend custom chrome to a new surface without an ADR.
4. **Dependency** — reject by default; an ADR plus user approval is required.

For materially different options, weigh:

- effect fidelity to what the user asked for;
- **macOS 14** compatibility (`#available` + working fallback; Liquid Glass out of scope);
- fit with AppKit-owned windows / SwiftUI content / SpriteKit render-only;
- implementation and maintenance complexity;
- performance and state-management risk;
- Reduce Motion and accessibility;
- regression risk to the other Calm Space page and to Settings/onboarding.

Default to the simple, maintainable option, but **do not trade interaction correctness for
fewer lines of code.**

## 4. Common misreads

- “整张屏幕滑进来” ≠ `Carousel`, `TabView`, or a `ScrollView` pager. It is a page transition
  with spatial continuity; reuse the shipped transition model.
- “悬停展开” ≠ popover / menu / tooltip. It is a hover state plus an expansion animation on
  the existing custom control.
- “页面很乱” ≠ redesign. Diagnose density, hierarchy, spacing, and state noise first; if the
  screen cannot be inspected, ask for a screenshot and the window size.
- “让它更醒目” ≠ add shadows, gradients, or more colours; check Design.md anti-patterns.
- “放到工具栏” → ADR 011: the main window has **no toolbar**. The correct surface is the
  dock, status block, or a page-level header.
- “加个动画” → check Design.md Motion: purposeful only, Reduce Motion required, no decorative
  loops on static data.
- “顺手把这个也改了” ≠ permission to redesign neighbouring surfaces.
- A one-off request is **not** a product rule: do not edit DESIGN.md, tokens, or feature spec
  without an explicit product decision. Exception: when the request changes a fact those docs name
  (e.g. a dock label), updating that line **is** the requested change — do it in the same task.

## 5. Boundary with other skills

This file owns intent/triage/ladder. `swiftui-expert-skill` owns API correctness (its macOS
scene prose is advisory), [DESIGN.md](../../../../DESIGN.md) owns visual rules and status,
Apple HIG owns platform behaviour, and `joeypet-macos` owns project constraints.

## 6. Worked examples

**A. “两个页面切换时像一整张屏幕左右滑动”** — page transition + spatial continuity (not a
carousel). Rung 0: already shipped in `CalmSpaceRootView`/`CalmSpacePageTransition` (0.45 s
slide, re-entry guard, Reduce Motion cross-fade). Verify and say so; add nothing. Ask only if
the user means a *new* navigation model (e.g. more than two pages).

**B. “右下角切换按钮悬停展开、移走缩回”** — hover state + expansion (not popover/menu).
Rung 0: `CalmSpaceModeSwitchView` already ships hover/0.22 s/34 pt; tune only if asked. Known
gaps: hover motion is not Reduce-Motion gated (DESIGN.md Micro-motion), and the label is
hover-only — keyboard focus does not reveal it; do not hide the control or add a new component.

**C. “页面很乱、挤在一起，不像苹果软件”** — density/hierarchy/macOS conventions, not a
redesign. Check local QA captures (`calm-space-qa/screenshots/`, if present) and the window
size first; compact is the likely suspect (icon-only dock). If still unclear, ask one evidence
question. Fix within `CalmSpaceLayout`/status hierarchy; no palette/token/DESIGN.md edit without
explicit product confirmation.
