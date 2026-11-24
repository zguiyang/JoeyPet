# AGENTS.md

Hard rules for agents working on JoeyPet. Read this before any code change.

## Current product scope (V0 — takes precedence over legacy docs)

Read [`开发交接文档.md`](开发交接文档.md), [`V0_FEATURE_SCOPE.md`](V0_FEATURE_SCOPE.md), [`DESIGN.md`](DESIGN.md), and [`docs/pet-domain-model.md`](docs/pet-domain-model.md) before planning or changing this repository.

- macOS-only native desktop pet for gentle work rhythm and recovery companionship.
- Joey is a pet, never a Mac Care tool or productivity supervisor.
- Keep the product lightweight, native, privacy-friendly, local-first and quiet.
- Do not add cleanup, uninstall, system monitoring, Todo, task management, MCP/CLI integrations, cloud accounts, chat, LLM runtime or a database without an explicit new product decision.
- Legacy Mac Care / Calm Space documents exist only for historical reference; do not restore their scope or architecture from them.

## Repository layout

- macOS implementation: `macos/JoeyPet/`
- macOS tests: `macos/JoeyPetTests/`
- macOS Xcode project: `macos/JoeyPet.xcodeproj/`
- macOS-only scripts: `macos/scripts/`
- Future platforms: sibling directories such as `windows/`; create them only when implementation starts
- Shared product, design and ADR docs: `docs/`
- Repository-level agent skills: `.agents/`

## Allowed stack

Swift, SwiftUI, AppKit, SpriteKit, Swift Concurrency, Apple frameworks first, Foundation, UserDefaults / `@AppStorage`, OSLog / `Logger`, SPM, Swift Testing (preferred).

**V1 runtime third-party dependencies = 0.**

## Forbidden (do not introduce)

Electron, Tauri, KMP, Avalonia, Live2D, 3D, Unity, database, LLM runtime, LangChain, AI SDK, Redux, TCA, heavy Clean Architecture, third-party DI, third-party UI systems, CocoaPods, Tuist, XcodeGen.

## Architecture boundaries

```
AppDelegate → PetCoordinator → AmbientBehaviorScheduler → PetRuntime → JoeyDesktopScene
```

- AppKit owns the panel, status item and lifecycle; do not migrate window ownership to SwiftUI scenes.
- Callers request behaviors through `PetRuntime`; never let a scheduler or view drive `SKScene` directly.
- Pet state names stay pet-centric (`idle`, `sleeping`), never system metric names.

## Safety (non-negotiable)

Pipeline for any action that changes user data:

**Observe → Detect → Explain → Recommend → Approve → Act → Feedback**

- Destructive actions require explicit user confirmation.
- Prefer **Move to Trash** over permanent delete. **Never** use `rm -rf` or equivalent.

## Runtime rules

Ambient behavior stays low-frequency, is interrupted by system sleep, and returns to `idle` after each session. If more behaviors are added, define priority, cooldown, minimum duration, interruption rules and fallback explicitly; keep them simple, predictable and testable. Do not add Behavior Trees in V0.

## UI / UX implementation

Design authority is layered. Each layer answers a different question; resolve conflicts by layer, not by one global ranking.

| Layer | Source | Governs | Does not govern |
|-------|--------|---------|-----------------|
| Platform | **Apple HIG** — official macOS pages (`https://developer.apple.com/design/human-interface-guidelines/<page>.md`) | macOS interaction, native behavior, accessibility, system conventions | JoeyPet product visuals |
| Product | **[DESIGN.md](DESIGN.md)** — *V0 Design Contract* | JoeyPet visual language, layout, tokens, components, copy voice, motion, the six states | behavior Apple already defines |
| Reference | **[docs/reference/joeypet-ui-v0.html](docs/reference/joeypet-ui-v0.html)** | the frozen high-fidelity visual target (six states, light + dusk) | product rules, implementation |
| Exception | **[ADRs](docs/decisions/)** | one named, recorded deviation from DESIGN.md or HIG | unrecorded redesigns |
| Engineering | This file, [docs/tech-stack.md](docs/tech-stack.md) | AppKit/SwiftUI/SpriteKit split, zero third-party deps, build workflow | visual taste |

Conflict rules:

1. **Accessibility and native behavior are hard constraints** unless an ADR records a justified exception for a named surface.
2. **DESIGN.md is the reviewable baseline; the frozen HTML reference resolves visual ambiguity only.** If they disagree, DESIGN.md wins — and fix the HTML artifact in the same task when it is wrong. There is no longer a Stitch source of truth.
3. **An ADR exception is narrow.** The legacy Calm Space ADR is retired and lives only in the archive branch; it does not license custom chrome on any V0 surface. Every custom surface must follow DESIGN.md §7.
4. **Engineering constraints win over generic skill advice.** Windows stay AppKit-owned (`AppDelegate`/`NSWindow`/`NSPanel`/`NSStatusItem`); do not migrate to SwiftUI `App`/`WindowGroup`/`MenuBarExtra`.

Skill dispatch — see [Agent skill](#agent-skill):

- `joeypet-macos` — workflow, layering, verification; load first.
- `swiftui-expert-skill` (local, from `avdlee/swiftui-agent-skill`) — SwiftUI API correctness, availability gating, accessibility patterns. Its macOS scene prose is advisory, not project architecture.
- **Web design skills are out of scope.** `hallmark` is an HTML/CSS skill with implicit invocation enabled: never use it for JoeyPet UI, ignore it if it auto-loads, and do not edit the user-level install from this repo.

Do not use deleted legacy UI specs (`docs/product/ui-spec.md`), the old three-sidebar IA (`Overview` / `Cleanup` / `Settings`), or the legacy Calm Space shell as design truth. Build UI only against DESIGN.md and the six agreed V0 surfaces; anything not listed there is out of scope until a new product decision.

## Documentation map

| Topic | Doc |
|-------|-----|
| V0 product scope | [V0_FEATURE_SCOPE.md](V0_FEATURE_SCOPE.md) |
| Handoff and next steps | [开发交接文档.md](开发交接文档.md) |
| UI / UX (native) | [DESIGN.md](DESIGN.md) (V0 design contract; authority rules in this file) |
| Frozen UI design | [docs/reference/joeypet-ui-v0.html](docs/reference/joeypet-ui-v0.html) |
| Nest animation spec | [docs/reference/joeypet-nest-animations-v0.html](docs/reference/joeypet-nest-animations-v0.html) |
| Idle sit breath frames | [docs/reference/joeypet-idle-breathing-frames-v0.html](docs/reference/joeypet-idle-breathing-frames-v0.html) |
| Look pose frames | [docs/reference/joeypet-look-frames-v0.html](docs/reference/joeypet-look-frames-v0.html) |
| Stretch pose frames | [docs/reference/joeypet-stretch-frames-v0.html](docs/reference/joeypet-stretch-frames-v0.html) |
| Happy pose frames | [docs/reference/joeypet-happy-frames-v0.html](docs/reference/joeypet-happy-frames-v0.html) |
| Wave pose spec | [docs/reference/joeypet-wave-pose-v0.html](docs/reference/joeypet-wave-pose-v0.html) |
| Pet domain & state model | [docs/pet-domain-model.md](docs/pet-domain-model.md) (engineering contract for states, poses, clips, timers) |
| Audio catalog (V0.x) | [docs/audio-catalog-v0.md](docs/audio-catalog-v0.md) (ambient + cue pickers; mute under DND / quiet hours) |
| Pet runtime | [docs/pet-runtime.md](docs/pet-runtime.md) |
| 2D clip animation pipeline | [docs/pet-animation-pipeline-2d.md](docs/pet-animation-pipeline-2d.md) |
| Tech stack | [docs/tech-stack.md](docs/tech-stack.md) |
| Workflow | [docs/development.md](docs/development.md) |
| ADRs | [docs/decisions/](docs/decisions/) |

## Agent skill

Use `.agents/skills/joeypet-macos/SKILL.md` for implementation workflow, layering, and verification steps.

One generic SwiftUI skill is expected locally at `.agents/skills/swiftui-expert-skill` (`avdlee/swiftui-agent-skill`, MIT). It is gitignored and machine-local like the rest of `.agents/skills/**` except `joeypet-macos`; do not vendor a second general SwiftUI skill or a HIG corpus into the repo.

## Before finishing a task

1. Stay within scope; no speculative architecture or new dependencies without ADR.
2. Match existing conventions; minimal diff.
3. Build and run tests when code changed.
4. Do not commit unless the user asks.
- If using MobileBuildMCP, use the installed MobileBuildMCP skill before calling MobileBuildMCP tools.
