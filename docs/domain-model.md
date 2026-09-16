# Domain Model

Conceptual model only. **No Swift types or SQL in this phase** — use these names consistently in design and implementation.

## System domain

### SystemSignal

Normalized observation from a sensor (e.g. thermal pressure elevated, memory warning, storage threshold crossed, long active session).

Fields (conceptual): source sensor id, severity, timestamp, optional payload (metrics as read-only facts).

### SignalSeverity

Ordered urgency for routing and behavior priority, e.g. `info`, `notice`, `warning`, `critical`.

## Pet domain

Pet vocabulary is **character-based**, not system-metric-based.

### PetState

Current **sustained** expressive mode of the pet. The Phase 3 system mappings
use `idle`, `sweating`, `tired`, and `carryingTrash`.

**Do not name states** `cpuHigh`, `diskLow`, `memoryHigh`, or similar system labels. Map system signals to pet states in the behavior engine.

### PetBehavior

The sustained reaction decision produced by the behavior engine: when certain
signals (with severity and hysteresis) apply, propose a `PetState` and optional
utility hook. Includes priority, cooldown, and minimum duration.

### PetTransientBehavior

A short-lived behavior that is not a sustained state. `blink`, `walking`, and
`sleeping` are ambient behaviors; `cleaning`, `celebrating`, and `notifying`
are explicit behaviors. All enter the runtime through the same arbitration
point and resolve to an existing animation id.

### AnimationClip

Strongly typed, `Codable` animation definition used by `PetManifest`:

| Field | Type | Purpose |
|-------|------|---------|
| `frames` | `[Int]` | Row-major sprite sheet frame indices |
| `fps` | `Double` | Playback rate |
| `loop` | `Bool` | Repeat when true |

Clips are keyed by animation id inside the manifest. `PetRuntime` resolves the clip for the current `PetState` via a centralized state → animation mapping.

### PetManifest

Strongly typed, `Codable` pet package definition (`pet.json`):

| Field | Purpose |
|-------|---------|
| `id`, `name` | Package identity |
| `spriteSheet` | Spritesheet filename in the package folder |
| `frameWidth`, `frameHeight` | Per-frame pixel size (may differ) |
| `columns`, `rows` | Sheet layout (row-major, left-to-right, top-to-bottom) |
| `defaultScale` | Integer display scale (nearest filtering) |
| `fallbackAnimation` | Clip id used when a requested animation is missing |
| `animations` | Map of animation id → `AnimationClip` |

V1 ships one built-in package: `JoeyRobot` under `Resources/Pets/JoeyRobot/`.

### PetPreferences

User settings: enabled sensors, quiet hours, utility opt-in, position memory. Stored via UserDefaults / `@AppStorage` in V1.

## Relationships

```
SystemSignal ──► BehaviorEngine ──► PetBehavior ──► PetState
                                                      │
                             PetTransientBehavior ────┤
                                                      ▼
                                              PetRuntime ──► AnimationClip
```

System-backed sustained states have priority over ambient and explicit
transient behaviors. A transient behavior may be dropped while a system state
is active; when a transient clip completes, the runtime resumes its current
underlying sustained state rather than assuming `idle`.

## Related docs

- [architecture.md](architecture.md)
- [pet-runtime.md](pet-runtime.md)
- [system-sensors.md](system-sensors.md)
