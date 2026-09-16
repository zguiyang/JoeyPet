---
name: joeypet-macos
description: Implement and review JoeyPet on macOS — native Swift desktop pet, system sensors, behavior runtime, SpriteKit, and safety-gated utilities. Use when editing JoeyPet Swift code, adding sensors or pet behaviors, validating architecture boundaries, or running build/test for this repo.
---

# JoeyPet macOS Skill

Use when working on JoeyPet implementation or review. **Do not duplicate [AGENTS.md](../../../AGENTS.md)** — follow it; this skill adds workflow and layering.

## When to use

- Adding or changing Swift code under `src/JoeyPet/`
- New sensor, behavior rule, pet state, or animation clip
- Utility that touches files, processes, or settings
- Build/test/runtime verification before marking a task done
- Evaluating whether a new dependency is allowed

## Layering (implement in this order)

| Layer | Path (when created) | Must not |
|-------|---------------------|----------|
| System | `System/Sensors/` | Import SpriteKit; write to disk |
| Domain | `Domain/` | UI or AppKit |
| Behavior | `Behavior/` | Direct scene updates |
| Pet runtime | `Pet/Runtime/` | Call `FileManager` delete APIs |
| Presentation | `UI/`, `Pet/Sprite/` | Parse raw `ProcessInfo` in views |
| Utilities | `Utilities/` | Run without approval gate |

Pipeline: `SystemSensor → SystemSignal → BehaviorEngine → PetBehavior/PetState → PetRuntime → AnimationClip → SpriteKit`

## Add a new sensor

1. Document in [docs/system-sensors.md](../../../docs/system-sensors.md) (API, frequency, permissions, output signal).
2. Implement read-only observer; emit `SystemSignal` only.
3. Map to pet states in behavior engine — use character names (`sweating`), not `cpuHigh`.
4. Add tests for signal normalization and severity mapping.
5. Verify no flicker with [pet-runtime.md](../../../docs/pet-runtime.md) rules.

## Add a new behavior / pet state

1. Define `PetState` in domain terms ([domain-model.md](../../../docs/domain-model.md)).
2. Add behavior rule: priority, cooldown, hysteresis, minimum duration.
3. Add animation id entry in `PetStateAnimationMapping` (single mapping file).
4. Add clip to `Resources/Pets/JoeyRobot/pet.json` and frames to `spritesheet.png`.
5. Wire through `PetRuntime` — not directly from sensor.
6. Table-test transitions; manually validate animation stability.

## Add or change a sprite animation (Phase 1.5)

1. Edit `src/JoeyPet/Resources/Pets/JoeyRobot/spritesheet.png` — keep row-major layout matching `columns` × `rows` in `pet.json`.
2. Add or update an entry under `animations` in `pet.json` (`frames`, `fps`, `loop`).
3. If the animation maps to a `PetState`, update `PetStateAnimationMapping.swift` only — do not scatter animation id strings elsewhere.
4. Run `PetManifestValidator` tests (dimensions, in-bounds frames, fallback).
5. Build and verify in app; use `-JoeyPetDebugState <state>` in Debug for quick checks.
6. Confirm same animation id does not restart when state is re-applied unchanged.

## Safety verification

Any utility path:

`Observe → Detect → Explain → Recommend → Approve → Act → Feedback`

- Confirm dialog or explicit approve control.
- Deletes → Move to Trash only; never `rm -rf`.
- Kill process / Login Items / system prefs → confirm each time.

See [references/safety.md](references/safety.md).

## Performance checks

- Sensors: prefer notifications over tight polling; document interval if polling.
- Main thread: no blocking I/O; SpriteKit updates on main actor as appropriate.
- Avoid restarting animations when `PetState` unchanged.

## Build & test

```bash
xcodebuild -project JoeyPet.xcodeproj -scheme JoeyPet -destination 'platform=macOS' build
xcodebuild -project JoeyPet.xcodeproj -scheme JoeyPet -destination 'platform=macOS' test
```

Run app for SpriteKit and panel behavior after UI/runtime changes.

## New dependency decision

1. Default: **reject** (V1 third-party runtime deps = 0).
2. If essential: write ADR in `docs/decisions/`, update `docs/tech-stack.md`, get user approval.

## References (short ops guides)

- [references/architecture.md](references/architecture.md) — boundaries checklist
- [references/pet-runtime.md](references/pet-runtime.md) — runtime rule checklist
- [references/safety.md](references/safety.md) — approval gate checklist

Full specs live under `docs/` — link, do not copy wholesale.
