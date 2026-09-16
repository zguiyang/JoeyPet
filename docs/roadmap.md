# Roadmap

Phases only — **no date commitments**. Scope stays macOS-native; no Windows, 3D pet, or LLM runtime in near-term phases.

## Phase 0 — Project Foundation

- Product and architecture documentation
- Agent rules (`AGENTS.md`, joeypet-macos skill)
- ADRs for platform, stack, runtime, persistence, sensors, LLM exclusion
- Minimal Xcode app shell (existing)

## Phase 1 — Desktop Pet Runtime Spike

End-to-end spike: desktop pet window, SpriteKit presentation, read-only sensors, and basic state transitions. See [architecture.md](architecture.md), [pet-runtime.md](pet-runtime.md), [system-sensors.md](system-sensors.md).

**Window**

- Transparent pet window
- Borderless
- Always-on-top
- Draggable
- Click-through

**Presentation**

- SpriteKit scene hosting
- Placeholder animations

**System awareness (read-only)**

- Thermal
- Memory pressure
- Storage

**Runtime**

- Signal → state → animation transitions (spike-level rules)
- Low idle resource usage

## Phase 2A — Joey Character Design Foundation

Design-only: lock Joey as the default Pixel Robot without shipping final sprites.

- [character-design.md](character-design.md) — role, personality, visual language, proportions, expression, animation principles, initial clip set, asset rules
- [pixel-asset-workflow.md](pixel-asset-workflow.md) — concept → sheet → `pet.json` → debug / runtime validation
- Respect existing package contract (`32×32`, integer `defaultScale`, silhouette-first); runtime stays character-agnostic
- No production `spritesheet.png` / `pet.json` replacement in this phase

## Phase 2B — Production Sprite Assets

Art production follow-up on 2A — still no new runtime architecture.

- Draw and pack the initial animation set (~10 clips) into the JoeyRobot package
- Manual pixel QA (consistency, silhouette, alignment, palette, jitter)
- Update `pet.json` clip entries to match the sheet; validate via manifest tests and debug states
- Props limited to in-frame Trash Can / Broom; no attachment system

## Phase 2 — System Awareness Hardening / Refinement

Follow-up on Phase 1 sensors and signal pipeline — no duplicate spike scope. Can proceed in parallel with 2A/2B.

- Idle / active duration sensor
- Threshold tuning, debouncing, and hysteresis on sensor inputs
- Stable `SystemSignal` delivery into behavior engine
- Logging and manual debug overlay (dev-only)
- Manual validation against edge cases (sleep/wake, rapid pressure changes)

## Phase 3 — Behavior Engine & Pet Runtime

- Rule system: priority, cooldown, hysteresis, minimum duration, interruption, fallback
- Pet states and `AnimationClip` mapping (sweating, tired, etc.)
- Swift Testing for rule tables

## Phase 4 — Ambient UX

- Quiet notifications; attention budget (conceptual limits in product behavior)
- Break reminders; non-intrusive prompts

## Phase 5 — Utilities (Safety-Gated)

- Read-only scans (cache, large files, desktop clutter)
- Explain → recommend → approve → act → feedback
- Move to Trash workflows only unless user explicitly opts into stronger actions

## Phase 6 — Polish & Release Prep

- Performance pass, asset polish, onboarding
- App notarization and distribution (out of scope until this phase)

## Explicitly not in near-term roadmap

- Windows / Linux ports
- 3D or Live2D avatars
- LLM / chat companion features
- Server backend or sync service
- Database-backed history

## Related docs

- [product.md](product.md)
- [development.md](development.md)
- [character-design.md](character-design.md)
- [pixel-asset-workflow.md](pixel-asset-workflow.md)
