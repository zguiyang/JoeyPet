# Pet Runtime Rule Checklist

V0 runtime: `AppDelegate → PetCoordinator → AmbientBehaviorScheduler → PetRuntime → PetScene`.

## Responsibilities

- `PetRuntime` owns the active transient behavior and maps it to an animation id.
- `PetScene` only plays animation ids; it does not select behaviors or read app state.
- `PetStateAnimationMapping` is the only place that maps `PetState` → animation id.
- Callers never call `SKScene.run` directly for behavior changes.

## Ambient scheduling

- Random interval in 12–35 seconds, clamped.
- One event per interval; no polling and no display link.
- Stop on system sleep and app teardown; resume at most once after wake.
- Ambient behavior is dropped while a transient is active.

## Transient behavior

- `PetTransientBehavior` is the allowlist of runtime behaviors.
- Each behavior has an animation id, `isAmbient`, and duration.
- Completion returns the pet to `idle`.
- Re-applying the same animation id must not restart playback from frame 0.

## Frame-rate and efficiency

- SpriteKit renders on demand; no high-frequency timer.
- Hidden mode pauses the scene.
- Do not add sensors, metric-driven states, cleanup hooks or LLM calls.

## Verification

- Unit-test pure timing/selection rules.
- Manual: drag position restore, hide/show, sleep/wake, no animation flicker.
- Build and test after runtime changes.
