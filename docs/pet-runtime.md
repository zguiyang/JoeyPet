# Pet Runtime

The pet runtime turns sustained `PetState` decisions and short-lived
`PetTransientBehavior` requests into stable on-screen behavior. It sits between
the behavior engine and SpriteKit.

## Responsibilities

- Hold current `PetState` and active animation id.
- Map `PetState` → animation id via `PetStateAnimationMapping` (single source of truth).
- Forward animation requests to `PetScene`; do not parse manifest business rules in the scene.
- Apply timing and stability rules so the pet does not flicker when sensors update frequently.
- Enforce interruption and fallback when higher-priority behaviors arrive.
- Keep the underlying sustained state while a transient animation is playing.
- Complete non-looping clips and restore the current underlying state.

## Asset loading (Phase 1.5)

- `PetAssetLoader` reads bundled `pet.json` + spritesheet from `Resources/Pets/<PackageID>/`.
- Validates JSON, sheet dimensions, layout, non-empty clips, in-bounds frame indices, and fallback animation.
- Caches manifest, sliced frame textures, and clips after first load.
- Release: log + fallback on load failure; never crash.
- Unknown animation ids resolve to `fallbackAnimation` from the manifest.

## Required rule dimensions

| Dimension | Purpose |
|-----------|---------|
| **Priority** | Higher-priority states (e.g. safety-related utility prompt) can preempt lower ones |
| **Cooldown** | Minimum time before the same behavior can trigger again |
| **Hysteresis** | Enter threshold ≠ exit threshold (avoid oscillation at boundaries) |
| **Minimum duration** | A state stays visible at least N seconds once entered |
| **Interruption rules** | Which states may be cut short; which must finish a clip segment |
| **Fallback** | Default `idle` (or safe neutral) when signals clear or conflict |

## State transition (conceptual)

```
Signals in → BehaviorEngine evaluates rules → proposed PetState
    → Runtime checks priority / cooldown / min duration
    → Accept or defer → select AnimationClip → SpriteKit plays clip
```

## Phase 3 behavior arbitration

`BehaviorEngine` owns sustained system state. `AmbientBehaviorScheduler` emits
low-frequency ambient requests only while the sustained state is `idle`.
`PetRuntime.perform(_:)` is the entry point for ambient and explicit transient
behaviors; callers do not play animation ids directly.

Priority is predictable:

```
system warning/critical > explicit transient > ambient > idle
```

In the current V1 runtime, transient requests are dropped when any sustained
system state is active. A system state arriving during a transient immediately
preempts it. A completed one-shot returns to the latest underlying state; no
generic behavior queue is retained.

Ambient scheduling waits one randomized interval (12–35 seconds, clamped) per
event. It does not poll, use a display link, or run a high-frequency timer.
The scheduler is stopped on system sleep and on runtime teardown, and started
at most once after wake when the sustained state is eligible.

`walking` is an ambient transient that may move the panel a short distance
inside the visible screen area. It must remain low-frequency and can be
interrupted by a system warning. The product decision supersedes the older
in-place-only example; state/behavior separation remains unchanged.

## Anti-flicker

- Debounce or hysteresis at the behavior layer; runtime enforces minimum duration.
- Do not re-trigger animation restart on every sensor poll if state unchanged.
- Same animation id → keep current `SKAction` running; do not restart from frame 0.

## Sprite presentation (Phase 1.5+)

- `PetScene` hosts `PetRootNode` → `CharacterNode` (`SKSpriteNode`); optional `EffectNode` children.
- Scene does not read system signals, create sensors, or interpret behavior rules.
- Frame textures use **nearest** filtering.
- `defaultScale` from the manifest is an **integer logical multiplier**: `CharacterNode` applies it with `setScale(CGFloat(defaultScale))`. Logical on-screen size in points is approximately `frameWidth × defaultScale` by `frameHeight × defaultScale` (see `PetManifest.logicalPointSize()`).
- **Points vs backing pixels:** logical points are AppKit / SpriteKit units. Physical pixels on the glass also depend on `NSScreen.backingScaleFactor` (commonly 2.0 on Retina, not guaranteed and not fixed in code). Do not treat `defaultScale` as a Retina or backing-pixel factor.
- Animation playback uses `SKAction.animate` (no per-frame timers or display links).
- Debug builds may directly hold a manifest clip via `-JoeyPetDebugAnimation <id>` (`PetCoordinator` → `PetRuntime` → `PetScene`) without changing `PetState` or `PetStateAnimationMapping`; Release ignores the flag. `-JoeyPetDebugState <state>` remains the independent state-chain check. Unknown animation ids use the manifest fallback.
- Debug builds may request `-JoeyPetDebugBehavior <id>` for transient/ambient
  runtime checks. `DebugState`, `DebugBehavior`, and `DebugAnimation` remain
  separate entry points; Release ignores all three overrides.

See [ADR 008](decisions/008-pixel-perfect-display-scaling.md) and [character-design.md](character-design.md).

## Out of scope (V1)

- Behavior Trees, GOAP, or ML-driven animation selection.
- Direct sensor → scene wiring.

## Testing

- Table-driven tests: given signal sequence + time, expect state sequence and clip ids.
- Manual: run app with simulated or real sensor pressure; confirm no rapid state flashing.

## Related docs

- [domain-model.md](domain-model.md)
- [architecture.md](architecture.md)
- [system-sensors.md](system-sensors.md)
