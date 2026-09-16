# Pet Runtime

The pet runtime turns `PetState` decisions into stable on-screen behavior. It sits between the behavior engine and SpriteKit.

## Responsibilities

- Hold current `PetState` and active animation id.
- Map `PetState` → animation id via `PetStateAnimationMapping` (single source of truth).
- Forward animation requests to `PetScene`; do not parse manifest business rules in the scene.
- Apply timing and stability rules so the pet does not flicker when sensors update frequently.
- Enforce interruption and fallback when higher-priority behaviors arrive.

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
- Debug builds may inject a package via `-JoeyPetDebugPet` (`PetPanelController` → `PetRuntime`); Release ignores the flag and keeps bundled `JoeyRobot`.

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
