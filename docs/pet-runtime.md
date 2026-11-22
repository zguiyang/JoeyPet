# Pet Runtime

The V0 pet runtime turns a small set of ambient and explicit behaviors into
stable on-screen animation. It sits between `PetCoordinator` and SpriteKit.

## Responsibilities

- Hold the current `PetState` and active animation id.
- Map `PetState` → animation id via `PetStateAnimationMapping` (single source of truth).
- Forward animation requests to `PetScene`; never interpret manifest business rules in the scene.
- Keep animation playback stable when the same behavior is re-applied.
- Complete one-shot and timed clips, then restore `idle`.
- Stop cleanly on system sleep and app teardown.

## Asset loading

- `PetAssetLoader` reads bundled `pet.json` + spritesheet from `Resources/Pets/<PackageID>/`.
- Validates JSON, sheet dimensions, layout, non-empty clips, in-bounds frame indices, and fallback animation.
- Caches manifest, sliced frame textures, and clips after first load.
- Release logs and falls back on load failure; it never crashes.
- Unknown animation ids resolve to `fallbackAnimation` from the manifest.

## V0 behaviors

| Behavior | Kind | Runtime rule |
|---|---|---|
| `idle` | Sustained state | Default fallback |
| `blink` | Ambient transient | Random ambient pick, most frequent |
| `walking` | Ambient transient | Moves the panel 40–120 pt inside the visible screen, then returns to idle |
| `sleeping` | Ambient transient | Timed session, then returns to idle |
| `celebrating` | Explicit transient | One-shot positive feedback; reserved for V0 recovery completion |
| `notifying` | Explicit transient | One-shot attention cue; reserved for V0 break invitation |

Ambient scheduling waits one randomized interval (12–35 seconds, clamped) per
event. It does not poll, use a display link, or run a high-frequency timer. The
scheduler stops on system sleep and restarts at most once after wake.

`PetRuntime.perform(_:)` is the entry point for ambient and explicit transient
behaviors; callers do not play animation ids directly. If a transient is already
active, the new request is dropped rather than queued.

## Anti-flicker

- Do not re-trigger animation restart when the requested animation id is unchanged.
- Same animation id → keep the current `SKAction` running; do not restart from frame 0.
- Keep one-shot clips short and readable.
- Respect Reduce Motion for any UI-level motion; ambient sprite playback remains low-frequency.

## Sprite presentation

- `PetScene` hosts `PetRootNode` → `CharacterNode` (`SKSpriteNode`); optional `EffectNode` children.
- Scene does not create sensors, read system state, or interpret product rules.
- Frame textures use **nearest** filtering.
- `defaultScale` from the manifest is an **integer logical multiplier**: `CharacterNode` applies it with `setScale(CGFloat(defaultScale))`.
- **Points vs backing pixels:** logical points are AppKit / SpriteKit units. Physical pixels also depend on `NSScreen.backingScaleFactor`.
- Animation playback uses `SKAction.animate` (no per-frame timers or display links).
- Debug builds may hold a manifest clip via `-JoeyPetDebugAnimation <id>` or request `-JoeyPetDebugBehavior <id>`. Release ignores both.

See [ADR 008](decisions/008-pixel-perfect-display-scaling.md) and [character-design.md](character-design.md).

## Out of scope (V0)

- System sensors, Mac Care reactions and metric-driven animation.
- Behavior Trees, GOAP, or ML-driven animation selection.
- Direct scheduler → scene wiring.

## Testing

- Pure logic tests for delay bounds and position restoration.
- Manual: verify sleep/wake cancellation, drag persistence, hide/show, and animation stability.

## Related docs

- [character-design.md](character-design.md)
- [pixel-asset-workflow.md](pixel-asset-workflow.md)
- [tech-stack.md](tech-stack.md)
