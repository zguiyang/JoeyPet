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

## Documentation map

| Topic | Doc |
|-------|-----|
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

## Before finishing a task

1. Stay within scope; no speculative architecture or new dependencies without ADR.
2. Match existing conventions; minimal diff.
3. Build and run tests when code changed.
4. Do not commit unless the user asks.
