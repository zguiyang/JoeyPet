# UI Intent Reference

Turn a plain-language interface request into the right interaction pattern and the simplest
stable implementation. This is a project lookup, **not** a design textbook:

- Visual rules, tokens, the six V0 surfaces and Agreed/Pending/Legacy status → [DESIGN.md](../../../../DESIGN.md)
- Frozen visual target → [docs/reference/joeypet-ui-v0.html](../../../../docs/reference/joeypet-ui-v0.html)
- Platform behaviour and accessibility → Apple HIG official pages
- API correctness and availability → `swiftui-expert-skill`
- This file → intent, ambiguity triage, implementation choice, common misreads

Read this for intent-level UI requests. Skip it for a single known value/copy/spacing tweak.
Do not quote it back as a report.

## 1. Intent vocabulary (user phrasing → concept)

| Category | User might say | Likely concept | Verify against |
|----------|----------------|----------------|----------------|
| Layout / hierarchy | “很乱”, “挤在一起”, “太空”, “重点不突出” | visual density, grouping, spacing, primary/secondary hierarchy | DESIGN.md §7 layout + a real screenshot at the reported window size |
| Navigation | “切换页面”, “回顾”, “回巢”, “返回” | scene affordance vs a second nav layer, view transition, back routing | DESIGN.md §7.3 — navigation lives in the room, never a tab bar |
| Motion | “动一下”, “淡一点”, “慢慢呼吸” | transition vs ambient loop vs micro-feedback; Reduce Motion fallback | DESIGN.md §12 Motion; Joey pose transitions in §9.2 |
| Component state | “悬停展开”, “点了变一下”, “不能点” | hover / pressed / disabled / focus state | DESIGN.md §8 components (button, chip, ring, controls) |
| Platform / a11y | “像苹果软件”, “键盘能用”, “读屏能读” | macOS conventions, Full Keyboard Access, VoiceOver labels, target size | DESIGN.md §14 Accessibility + HIG pages |
| Feedback | “加载中”, “空了”, “失败了”, “成功了”, “提示一下”, “加句说明” | loading / empty / error / success; whether copy is needed at all | DESIGN.md §13 + **§11.1** (delete-first; state beats toast) |

One phrase may span several categories. Translate to the concept first, then confirm the
concept against DESIGN.md and the frozen reference — **do not implement from the phrase directly.**

Terminology is for the Agent's reasoning, not for the user. Never ask the user to define
“transition”, “hover”, “hierarchy”, or similar.

## 2. Ambiguity triage

| Outcome | When | Example |
|---------|------|---------|
| **Act** | Intent is clear and DESIGN.md already answers “how” | “回顾的返回按钮放右下” → follow §7.3 回巢, bottom-right |
| **Assume (state once)** | Minor ambiguity that cannot change the outcome | “展开顺滑一点” → keep the documented duration unless a value is requested |
| **Ask — decision** | The choice changes product behaviour, navigation model, window architecture, or the interaction outcome | “把设置移进房间” (IA), “加一个底部标签栏” (navigation model), “换主色/重做首页” (product visual decision) |
| **Ask — evidence** | You cannot inspect the result and grounding it is needed (which surface, window size, screenshot) | “这个页面很乱” → check captures and window size first; if still unclear, ask for the one missing item, not a bundle |

Rules:

- Check code, ADRs, DESIGN.md, and existing captures before asking — the answer is often already there.
- A decision ask offers 2–3 concrete options; an evidence ask asks for a screenshot/size. One question, then proceed.
- Aesthetic complaints (“别扭”, “不高级”, “不像苹果软件”) are **evidence-first**: inspect the surface and captures. Only a named visual redesign (“换主色”, “重做首页”) is a decision ask.
- Do not enter analysis mode for every UI task; ordinary tweaks go straight to implementation.
- Do not ask the user to learn UI vocabulary; translate their words into the project's terms.
- Do not silently redefine a product rule from a one-off request. If a request changes a fact the docs
  name (e.g. a label), update that doc line in the same task — a documentation update, not a redesign.
- Classify against DESIGN.md Agreed/Pending/Legacy before implementing:
  - **Agreed** = frozen V0 design. Build it as specified. “Pending” implementation is a backlog state,
    not a ban; a direct request to build it is the authorization (do not ask again), then update the
    status table when it ships.
  - **Legacy** = deprecated (Calm Space / Mac Care shell). Do not restore it by default. If the user
    explicitly asks to re-adopt it, surface the conflict with DESIGN.md and resolve it with a new or
    superseding ADR first.

## 3. Implementation ladder

Stop at the first rung that satisfies the request:

0. **Already shipped** — the behaviour exists. Verify the **actual effect** against the request:
   exists ≠ meets the need. Compare code, screenshots/run evidence, and input behaviour (e.g. hover
   ring, keyboard focus, transition continuity). “Matches” requires run/captured evidence, not just
   reading the constant; if it matches, say so and stop; if not, name the gap and continue.
1. **Reuse** — find an existing pattern or component and extend it over inventing a parallel one
   (button variants, status chip, room label, progress ring, settings controls).
2. **Native** — Apple controls and APIs: `Button`, `Toggle`, `Picker`, `List`/`Form`,
   `ProgressView`, sheets/alerts; AppKit for windows/panels/menu bar.
3. **Light custom** — only for the illustrated room, desktop Joey, or an already-Agreed custom
   surface; keep it local, state-light, and testable where the logic is pure. Do not add a second
   navigation layer or custom chrome beyond DESIGN.md §7.
4. **Dependency** — reject by default; an ADR plus user approval is required.

For materially different options, weigh:

- effect fidelity to what the user asked for;
- **macOS 14** compatibility (`#available` + working fallback; Liquid Glass out of scope);
- fit with AppKit-owned windows / SwiftUI content / SpriteKit render-only;
- implementation and maintenance complexity;
- performance and state-management risk;
- Reduce Motion and accessibility;
- regression risk to the other Agreed V0 surfaces.

Default to the simple, maintainable option, but **do not trade interaction correctness for
fewer lines of code.**

## 4. Common misreads

- “加个标签栏/分段控件切页面” ≠ the room. Navigation lives in the scene (§7.3): the 回顾 wall
  frame opens reflection, 回巢 returns. Never add a second navigation layer.
- “把设置放到工具栏” ≠ allowed. There is no toolbar; the only chrome control is the titlebar
  settings gear (§7.2).
- “悬停展开” ≠ popover / menu / tooltip. It is a hover state plus an expansion animation on the
  existing control, with a visible hover ring and keyboard focus.
- “页面很乱” ≠ redesign. Diagnose density, hierarchy, spacing, and state noise first; if the
  surface cannot be inspected, ask for a screenshot and the window size.
- “让它更醒目” ≠ add shadows, gradients, or more colours; check DESIGN.md §17 anti-patterns.
- “加个动画” → check DESIGN.md §12 Motion: purposeful only, Reduce Motion required, no decorative
  loops on static data, no bounce.
- “顺手把这个也改了” ≠ permission to redesign neighbouring surfaces.
- A one-off request is **not** a product rule: do not edit DESIGN.md, tokens, or feature spec
  without an explicit product decision. Exception: when the request changes a fact those docs name
  (e.g. a label), updating that line **is** the requested change — do it in the same task.

## 5. Boundary with other skills

This file owns intent/triage/ladder. `swiftui-expert-skill` owns API correctness (its macOS
scene prose is advisory), [DESIGN.md](../../../../DESIGN.md) owns visual rules and status,
the frozen HTML reference resolves visual ambiguity, Apple HIG owns platform behaviour, and
`joeypet-macos` owns project constraints.

## 6. Worked examples

**A. “回顾和房间之间切换像一整张画面淡入”** — view transition + spatial continuity inside one
window, not a second window or a carousel. Follow DESIGN.md §7.3 and §12; verify Reduce Motion
gives a cross-fade. Ask only if the user means a *new* navigation model.

**B. “设置齿轮放在标题栏右边”** — this is the Agreed §7.2 chrome: one gear at the titlebar
trailing edge, nothing else. Implement it there; do not add toolbar items or move it into the room.

**C. “页面很乱、挤在一起，不像苹果软件”** — density/hierarchy/macOS conventions, not a
redesign. Check local captures and the window size first (compact is the likely suspect).
If still unclear, ask one evidence question. Fix within layout/hierarchy; no palette/token/DESIGN.md
edit without explicit product confirmation.
