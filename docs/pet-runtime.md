# Pet Runtime

The V0 pet runtime turns a small set of ambient and explicit behaviors into
stable on-screen animation. It sits between `PetCoordinator` and SpriteKit.

Domain semantics (states, poses, clips, timers, conflict rules) are defined in
[pet-domain-model.md](pet-domain-model.md). This file covers runtime mechanics only;
when they disagree, the domain model wins.

Expression direction for anti–paper-cutout motion (sequence clips, multi-display
scaling, Design-AI prompts) lives in
[pet-animation-pipeline-2d.md](pet-animation-pipeline-2d.md). Runtime still selects
behavior/`clipId`; clip frame packs land when art is accepted.

## Responsibilities

- Hold the current `PetState` and active pose.
- Map `PetPose` → layered pose inside `JoeyDesktopScene` (single source of truth).
- Forward pose requests to `JoeyDesktopScene`; never interpret manifest business rules in the scene.
- Keep animation playback stable when the same behavior is re-applied.
- Complete one-shot and timed clips, then restore `idle`.
- Stop cleanly on system sleep and app teardown.

## Asset loading

- `JoeyAssetPackage` reads `Resources/Pets/Joey/joey_manifest.json` plus the 1x PNGs under `layers/png/` and `poses/png/`.
- It validates the manifest version, required layers, required poses, and the presence of every referenced PNG.
- Missing pose or clip falls back to `pose_sit` / `idle_sit` in `JoeyCharacterNode`.
- Release logs a load failure and uses `EmptyPoseRenderer`, which keeps the runtime alive without placeholder art.

## V0 behaviors

| Behavior | Kind | Runtime rule |
|---|---|---|
| `idle` | Sustained state | Default fallback |
| `blink` | Ambient transient | In-node random blink; suppressed in `sign`, `stretch`, `happy`, `sleep`, `groom`, `yawn`, `peek` |
| `carrying` | Explicit transient | `carry` for 3.6 s after a break completes and `happy` ends; skipped when hidden, quiet, DND or Reduce Motion |
| `sleeping` | Ambient transient | Timed session, then returns to idle |
| `celebrating` | Explicit transient | One-shot positive feedback; reserved for V0 recovery completion |
| `notifying` | Explicit transient | One-shot attention cue; reserved for V0 break invitation |
| `greeting` | Explicit transient | `happy` for 2.8 s when the user taps the nest; allowed while the desktop pet is hidden |

Ambient micro-motion uses in-node blink/ear loops with manifest ranges — never
polling or a display link. Idle breath follows
[joeypet-idle-breathing-frames-v0.html](reference/joeypet-idle-breathing-frames-v0.html):
`scaleY` up to the manifest `breathe.scale` (1.046) over `loopMs` (4800), foot
anchored, with a ±1.2° tilt and a stronger synced tail (±12°). V0 does **not**
include ambient walking or a `step` pose.

The runtime also exposes `onRenderedPoseChanged` after every real pose switch,
transients included. `PetCoordinator` forwards it to `CompanionStatus.pose`. The
nest hosts the same layered `JoeyDesktopScene` and `JoeyAssetPackage` as the
desktop pet and feeds it that pose, so faces, props, breathing and blinks are
identical instead of running a separate day loop.

Edge docking and `peek` are deferred from V0: the panel stays where the user
drops it, and `peek` is not reachable yet.

An in-flight ambient transient is cut immediately when a pose with higher
priority appears (hidden, drag, menu, quiet, dozing, yawn or any session), so
invitations and recovery are never painted over a carrying frame.

`PetRuntime.perform(_:)` is the entry point for ambient and explicit transient
behaviors; callers do not play animation ids directly. If a transient is already
active, the new request is dropped rather than queued.

## Anti-flicker

- Do not re-trigger animation restart when the requested pose is unchanged.
- Same pose → keep the current layer animation running; do not restart from frame 0.
- Keep one-shot clips short and readable.
- Respect Reduce Motion for any UI-level motion; ambient sprite playback remains low-frequency.

## Sprite presentation

- `JoeyDesktopScene` hosts a single `JoeyCharacterNode` built from eight layers (back to front): shadow → tail → body → ears → backArm → face → frontArm → prop.
- Scene does not create sensors, read system state, or interpret product rules.
- Layer and pose textures use **linear** filtering.
- The 320×400 canvas is displayed at 132×165 / 168×210 / 216×270 points, so the scale is fractional by design.
- **Points vs backing pixels:** logical points are AppKit / SpriteKit units. Physical pixels also depend on `NSScreen.backingScaleFactor`.
- Pose playback swaps textures; Reduce Motion freezes breathing, blinking and prop loops at their end state.
- Debug builds may request `-JoeyPetDebugAnimation <id>`, `-JoeyPetDebugBehavior <id>`, `-JoeyPetDebugSession` or `-JoeyPetDebugPoses`. Release ignores them.

See [ADR 013](decisions/013-hd-layered-rendering.md).

## Out of scope (V0)

- System sensors, Mac Care reactions and metric-driven animation.
- Behavior Trees, GOAP, or ML-driven animation selection.
- Direct scheduler → scene wiring.

## Testing

- Pure logic tests for delay bounds and position restoration.
- Manual: verify sleep/wake cancellation, drag persistence, hide/show, and animation stability.

## Related docs

- [pet-domain-model.md](pet-domain-model.md)
- [tech-stack.md](tech-stack.md)
