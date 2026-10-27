# AGENTS.md

Hard rules for agents working on JoeyPet. Read this before any code change.

## Product scope (V1)

- macOS-only native Swift desktop pet and lightweight system resource assistant.
- **Usually a pet, when needed a tool** — playful presence first; utilities only when useful.
- Qualities: lightweight, native, privacy-friendly, local-first, system-aware, quiet, useful.
- No AI companion, chatbot, LLM runtime, or database in V1.

## Allowed stack

Swift, SwiftUI, AppKit, SpriteKit, Swift Concurrency, Apple frameworks first, Foundation, UserDefaults / `@AppStorage`, OSLog / `Logger`, SPM, Swift Testing (preferred).

**V1 runtime third-party dependencies = 0.**

## Forbidden (do not introduce)

Electron, Tauri, KMP, Avalonia, Live2D, 3D, Unity, database, LLM runtime, LangChain, AI SDK, Redux, TCA, heavy Clean Architecture, third-party DI, third-party UI systems, CocoaPods, Tuist, XcodeGen.

## Architecture boundaries

```
SystemSensor → SystemSignal → BehaviorEngine → PetBehavior / PetState → PetRuntime → AnimationClip → SpriteKit
```

- System domain and pet domain are separate.
- Sensors emit signals only. **Never** let a Sensor drive a SpriteKit scene directly.
- Pet state names must be pet-centric (e.g. `sweating`, `tired`), not system metric names (`cpuHigh`, `memoryHigh`).

## Safety (non-negotiable)

Pipeline for any action that changes the system or user data:

**Observe → Detect → Explain → Recommend → Approve → Act → Feedback**

- Sensors are **read-only by default**.
- Delete, move, kill process, change system settings or Login Items, touch important directories, or any operation that may lose data → **explicit user confirmation**.
- Prefer **Move to Trash** over permanent delete. **Never** use `rm -rf` or equivalent.

## Runtime rules

Behavior selection must support: priority, cooldown, hysteresis, minimum duration, interruption rules, fallback.

Keep rules simple, predictable, and testable. Do not add Behavior Trees in V1.

## UI / UX implementation

Design authority is layered. Each layer answers a different question; resolve conflicts by layer, not by one global ranking.

| Layer | Source | Governs | Does not govern |
|-------|--------|---------|-----------------|
| Platform | **Apple HIG** — official macOS pages (`https://developer.apple.com/design/human-interface-guidelines/<page>.md`) | macOS interaction, native behavior, accessibility, system conventions | JoeyPet product visuals |
| Product | **[Design.md](DESIGN.md)** | JoeyPet visual language, layout, tokens, copy, state presentation | behavior Apple already defines |
| Exception | **[ADRs](docs/decisions/)** (e.g. 011 Calm Space) | one named, recorded deviation from Design.md or HIG | unrecorded redesigns |
| External input | **Stitch** project JoeyPet | exploration and freeze screens **only when a retrievable artifact exists** | anything when Stitch is unreachable |
| Engineering | This file, [docs/tech-stack.md](docs/tech-stack.md) | AppKit/SwiftUI/SpriteKit split, zero third-party deps, build workflow | visual taste |

Conflict rules:

1. **Accessibility and native behavior are hard constraints** unless an ADR records a justified exception for a named surface.
2. **Design.md is the reviewable baseline.** Stitch cannot override a committed decision unless a freeze screen or design-system artifact is retrievable and reviewable; otherwise follow Design.md and record the gap.
3. **An ADR exception is narrow.** ADR 011 covers the Calm Space main window only; it does not license custom chrome elsewhere.
4. **Engineering constraints win over generic skill advice.** Windows stay AppKit-owned (`AppDelegate`/`NSWindow`/`NSPanel`/`NSStatusItem`); do not migrate to SwiftUI `App`/`WindowGroup`/`MenuBarExtra`.

Skill dispatch — see [Agent skill](#agent-skill):

- `joeypet-macos` — workflow, layering, verification; load first.
- `swiftui-expert-skill` (local, from `avdlee/swiftui-agent-skill`) — SwiftUI API correctness, availability gating, accessibility patterns. Its macOS scene prose is advisory, not project architecture.
- **Web design skills are out of scope.** `hallmark` is an HTML/CSS skill with implicit invocation enabled: never use it for JoeyPet UI, ignore it if it auto-loads, and do not edit the user-level install from this repo.

Do not use deleted legacy UI specs (`docs/product/ui-spec.md`) or the old three-sidebar IA (`Overview` / `Cleanup` / `Settings`) as design truth.

## Documentation map

| Topic | Doc |
|-------|-----|
| UI / UX (native) | [Design.md](DESIGN.md) (reviewable baseline; authority rules in this file) |
| Product | [docs/product.md](docs/product.md) |
| Architecture | [docs/architecture.md](docs/architecture.md) |
| Domain model | [docs/domain-model.md](docs/domain-model.md) |
| Pet runtime | [docs/pet-runtime.md](docs/pet-runtime.md) |
| System sensors | [docs/system-sensors.md](docs/system-sensors.md) |
| Safety | [docs/safety.md](docs/safety.md) |
| Tech stack | [docs/tech-stack.md](docs/tech-stack.md) |
| Project layout | [docs/project-structure.md](docs/project-structure.md) |
| Workflow | [docs/development.md](docs/development.md) |
| Roadmap | [docs/roadmap.md](docs/roadmap.md) |
| ADRs | [docs/decisions/](docs/decisions/) |

## Agent skill

Use `.agents/skills/joeypet-macos/SKILL.md` for implementation workflow, layering, and verification steps.

One generic SwiftUI skill is expected locally at `.agents/skills/swiftui-expert-skill` (`avdlee/swiftui-agent-skill`, MIT). It is gitignored and machine-local like the rest of `.agents/skills/**` except `joeypet-macos`; do not vendor a second general SwiftUI skill or a HIG corpus into the repo. See [ADR 013](docs/decisions/013-ui-skill-and-design-authority.md).

## Before finishing a task

1. Stay within scope; no speculative architecture or new dependencies without ADR.
2. Match existing conventions; minimal diff.
3. Build and run tests when code changed.
4. Do not commit unless the user asks.
- If using MobileBuildMCP, use the installed MobileBuildMCP skill before calling MobileBuildMCP tools.
