# ADR 009: Separate Sustained State from Transient Behavior

## Status

Accepted

## Context

`PetState` expresses a sustained mode such as `sweating` or `tired`. The
production animation set also contains short-lived reactions such as `blink`
and explicit product hooks such as `celebrating`. Treating every animation as
a state would blur system meaning, make ambient behavior compete with warnings,
and make one-shot completion incorrectly fall back to `idle`.

## Decision

Keep `PetState` for sustained system-backed state. Represent short-lived
ambient and explicit actions as `PetTransientBehavior`. Route both through
`PetRuntime`, where system state has priority, transient requests may be
dropped, and completion resumes the latest underlying sustained state.

Ambient scheduling remains a small low-frequency task with no queue and no
window locomotion. Explicit utility behaviors are runtime hooks only until a
future feature supplies a real approved product event.

## Consequences

- State names remain pet-centric and system mapping stays in `BehaviorEngine`.
- Production animations can have clear semantics without expanding `PetState`.
- Runtime tests can cover preemption, completion, and resume independently.
- No generic behavior graph, queue, settings system, or new sensor is needed.
