# ADR 013: UI Skill Selection and Design Authority

## Status

Accepted — 2026-10-27 (project-level UI skill selection and governance for this phase).

## Context

The 2026-10-27 read-only audit found:

- The repo owns exactly one tracked skill, `joeypet-macos`. A second, generic SwiftUI skill
  (`swiftui-expert-skill`, from `avdlee/swiftui-agent-skill`) is installed locally but gitignored.
- `hallmark` (user-level, `nutlope/hallmark`) is an HTML/CSS web design skill with implicit
  invocation enabled; it has never been used in this repo but can match "design something new".
- No "Taste" skill exists in any reachable location.
- Stitch MCP is configured for Cursor/Codex/Orca but is not reachable from the DSH agent, while
  DESIGN.md declared "Stitch wins" over the repo's own contract. The top design source was therefore
  unenforceable and unreviewable.
- DESIGN.md had already drifted from the shipped Calm Space window (toolbar-era rules still present),
  and ADR 011 is the only recorded exception to default macOS window chrome.

Candidates compared for this decision (evidence: upstream repo content fetched 2026-10-27):

| Candidate | Evidence | Verdict |
|-----------|----------|---------|
| `avdlee/swiftui-agent-skill` (installed) | MIT; 33 refs; macOS scene/window/views refs; explicit `NSHostingController`/`NSHostingView` AppKit-host guidance; per-API macOS availability tables; Liquid Glass opt-in only | Keep |
| `twostraws/SwiftUI-Agent-Skill` (`swiftui-pro`) | MIT, active (6.4k★); 0 occurrences of "macOS" in the skill; SKILL.md states "iOS 27 … default deployment target" | Reject for JoeyPet |
| `openai/plugins` → `build-macos-apps` | Codex plugin, 11 skills; `swiftui-patterns` is scene-first; `window-management` self-declares macOS 15+; `liquid-glass` uses macOS 26 APIs with no `#available` guidance; Codex-specific build workflow; no LICENSE text | Defer |
| `justinwetch/HIGAgentSkills` | 686★, MIT + Apple-content notice; correct macOS/iOS split; 0.73 MB / 157 refs; ~27k-token tier-1 load; broad implicit trigger; current to Sept 2026 (ahead of the macOS 14 target) | Do not vendor |
| `thedaviddias/agent-forge` macOS guidelines | 3★, 29 rules; absolute prose ("never", "must", "all"); requires unified toolbar and forbids custom chrome → conflicts with ADR 011 | Reject |
| Apple HIG (official) | `https://developer.apple.com/design/human-interface-guidelines/<page>.md` fetches without login | Use as platform authority |

## Decision

1. **One workflow skill:** `joeypet-macos` remains the project workflow/dispatch skill and gains a
   short UI-work section (intent classification, authority lookup, native-first, AppKit window
   override, version gating, verification) plus compact HIG guardrails.
2. **One generic SwiftUI skill:** keep `avdlee/swiftui-agent-skill` locally. Do not install a second
   general SwiftUI skill. Its macOS scene-preference prose is advisory only; AGENTS.md's AppKit
   window ownership wins.
3. **No HIG skill vendored.** Official HIG pages are the platform authority; community HIG summaries
   are non-authoritative. Context cost, licence ambiguity for Apple-derived text, and snapshot drift
   ahead of the macOS 14 target outweigh the benefit of a corpus.
4. **Layered design authority** replaces the linear ranking in AGENTS.md and DESIGN.md:
   Platform (Apple HIG) / Product (DESIGN.md) / Exception (ADR) / External input (Stitch) /
   Engineering (AGENTS.md, tech-stack). Conflicts resolve by layer, not by one global order.
5. **Stitch is a retrievable input, not an unreviewable override.** Without a freeze screen or
   design-system artifact that can be reviewed, Stitch cannot override a committed decision;
   the gap is recorded instead of guessed.
6. **Hallmark is excluded project-wide.** `AGENTS.md` and the `joeypet-macos` skill forbid using it
   for JoeyPet UI. The user-level install is not modified, so web projects keep their access.

## Consequences

- Positive: one workflow skill + one SwiftUI skill; no new dependency in the repository; deterministic
  authority for conflicts; Hallmark cannot silently shape a native macOS screen; Stitch's absence no
  longer blocks UI work.
- Costs: `swiftui-expert-skill` stays machine-local and gitignored, so reproducibility depends on
  re-installing `avdlee/swiftui-agent-skill` (recorded in AGENTS.md). The HIG guardrails are a short
  checklist and may drift from Apple's pages — the official pages always win.
- Not changed: Swift/AppKit/SpriteKit code, DESIGN.md token/type/spacing sections, and any
  user-level skill installation. (Later: Phase 2 aligned the product acceptance criteria in
  `docs/product/feature-spec.md`; Phase 3 added the UI workflow and `references/ui-intent.md`
  to `joeypet-macos`.)
- Revisit when: the deployment target moves to macOS 15/26 (re-evaluate `build-macos-apps` /
  Liquid Glass), a cross-platform or iOS sibling project appears (re-evaluate `twostraws`), Stitch
  becomes reachable from the coding agent (archive freeze artifacts into the repo), or the selected
  SwiftUI skill needs vendoring for reproducibility.
