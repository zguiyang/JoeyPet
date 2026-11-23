# ADR 009: Separate Sustained State from Transient Behavior

## Status

Superseded by [ADR 012](012-four-layer-pet-domain.md). Kept for historical context.

## Context

`PetState` expresses a sustained mode such as `idle` or `sleeping`. The
production animation set also contains short-lived reactions such as `blink`
and explicit product hooks such as `celebrating`. Treating every animation as
a state would blur meaning, make ambient behavior compete with explicit cues,
and make one-shot completion incorrectly fall back to `idle`.

## Decision

Keep `PetState` for sustained pet state. Represent short-lived ambient and
explicit actions as `PetTransientBehavior`. Route both through `PetRuntime`,
where explicit requests may be dropped if a transient is active, and completion
resumes `idle`.

Ambient scheduling remains a small low-frequency task with no queue. The
product definition permits `walking` to move the desktop panel a short
distance. Explicit cues such as `notifying` and `celebrating` are runtime hooks
until V0 supplies a real approved product event.

## Consequences

- State names remain pet-centric and animation mapping stays in `PetStateAnimationMapping`.
- Production animations can have clear semantics without expanding `PetState`.
- Runtime tests can cover completion and idle restore independently.
- No generic behavior graph, queue, settings system, or sensor is needed.
