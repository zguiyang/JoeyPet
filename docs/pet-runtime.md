# Pet Runtime

The pet runtime turns `PetState` decisions into stable on-screen behavior. It sits between the behavior engine and SpriteKit.

## Responsibilities

- Hold current `PetState` and active `AnimationClip`.
- Apply timing and stability rules so the pet does not flicker when sensors update frequently.
- Enforce interruption and fallback when higher-priority behaviors arrive.

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
