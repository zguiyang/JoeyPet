# Architecture

## Overview

JoeyPet splits **system sensing** from **pet presentation**. System code observes macOS; pet code expresses character and animation. Utilities sit behind an explicit safety gate.

The current product UI consumes the existing sensor pipeline through a
`SystemStatusSnapshot`; it does not create a second monitor. The V1 product
target also includes lightweight current metrics and short-term trends for
Overview; those data sources are not yet present in the current implementation
and must be planned in M1 without changing the pet reaction contract. Cleanup
uses a read-only `CleanupScanner` followed by an independently approved
`CleanupExecutor`, and product events reach the pet through `PetRuntime`.

## Data flow

```
SystemSensor
    ↓ SystemSignal
BehaviorEngine
    ↓ PetBehavior / PetState
PetRuntime
    ↓ AnimationClip
SpriteKit (render)
```

```mermaid
flowchart LR
    SS[System Sensors] --> SIG[SystemSignal]
    SIG --> BE[BehaviorEngine]
    BE --> PBS[PetBehavior / PetState]
    PBS --> PR[PetRuntime]
    PR --> SK[Animation / SpriteKit]
```

**Rule:** Sensors never control SpriteKit scenes directly.

## Layers

| Layer | Responsibility | Examples |
|-------|----------------|----------|
| System | Observe macOS, emit signals | `ThermalSensor`, `MemoryPressureSensor` |
| Domain | Types and rules, no UI | `SystemSignal`, `PetState`, `PetBehavior` |
| Behavior engine | Map signals → pet decisions | Priority, cooldown, hysteresis |
| Pet runtime | State machine, clip selection | Minimum duration, interruption, fallback |
| Presentation | Window, panel, sprites | AppKit `NSPanel`, SwiftUI chrome, SpriteKit scene |
| Utilities | User-approved actions | Trash move, folder scan (future phases) |

## UI model (concept)

- **Ambient UI** — pet visible on desktop; minimal chrome.
- **Quiet / non-intrusive** — no spam; batch or defer low-priority cues.
- **Attention budget** — conceptual cap on prompts per time window; no algorithm in V1 docs.

Implementation details: [pet-runtime.md](pet-runtime.md), [system-sensors.md](system-sensors.md).

## Persistence (V1)

User preferences and lightweight state via UserDefaults / `@AppStorage`. No database. See [decisions/004-no-database-in-v1.md](decisions/004-no-database-in-v1.md).

Daily-use state remains small and explicit: `PetPositionGeometry` is a pure
domain resolver, `PetPositionStore` persists only the user's drag-end record,
and `LaunchAtLoginManager` is the Apple `SMAppService` boundary. Ambient
movement never writes the saved position. `AppModel` persists only a
`CleanupExecutionSummary`, not candidate paths.

## Testing strategy

- Unit tests for signal → behavior mapping and runtime rules (Swift Testing).
- Manual runtime validation for SpriteKit and window behavior.
- No LLM or external service mocks required in V1.

## Related docs

- [domain-model.md](domain-model.md)
- [tech-stack.md](tech-stack.md)
- [project-structure.md](project-structure.md)
