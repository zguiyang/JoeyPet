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

## Phase 2 — System Awareness Hardening / Refinement

Follow-up on Phase 1 sensors and signal pipeline — no duplicate spike scope.

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
