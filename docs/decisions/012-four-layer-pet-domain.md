# ADR 012: Four-Layer Pet Domain Model

## Status

Accepted. Supersedes [ADR 009](009-state-and-behavior-separation.md).

## Context

ADR 009 separated `PetState` from `PetTransientBehavior`, which was enough for a
single `idle` state and five transient behaviors. The V0.1 state atlas now defines
7 desktop states, 5 companion substates, 12 poses, 9 ambient events and 5 behavior
buckets. The old two-layer model cannot express the difference between:

- what is happening (`companion`, `quiet`, `snoozed`),
- what Joey looks like (`sit`, `look`, `sign`),
- which runtime bucket and clip play (`notifying/notify_sign`),
- which small motion overlays the pose (`breathe`, `blink`, `ear`).

It also let one behavior id carry multiple poses (`peek → notifying`,
`doze → sleeping`, `stretch/groom/yawn/carry → idle`), so the runtime could not
reliably distinguish them.

## Decision

Adopt four explicit layers, defined in
[docs/pet-domain-model.md](../pet-domain-model.md):

1. **State** — `DesktopState` (7) and `CompanionSubstate` (5).
2. **Situation** — a `PetSituation` value that holds the active state, companion
   substate, pose and timer deadlines. It is the single source of truth.
3. **Pose** — `PetPose` (12). One pose at a time; clip ids are stable.
4. **Runtime key** — `BehaviorBucket + ClipID` (5 buckets). The scene never
   derives or interprets product rules.

Rules:

- State changes only through `PetStateMachine` events and a pure reducer.
- Higher-priority states override pose and visible elements only; they do not
  destroy lower-priority timers, counters or sessions.
- Ambient and invitation requests are dropped, not queued.
- `PetStateAnimationMapping` becomes the single lookup from pose to runtime key.
- The scene and scheduler never read system state or decide priority.

## Consequences

- One state machine can serve desktop states, companion substates and poses
  without a behavior tree or a generic state-machine library.
- Each pose has a unique clip id; `peek`, `doze`, `stretch`, `groom`, `yawn` and
  `carry` are no longer conflated with other behaviors.
- The manifest, domain model and tests must change together when a state, pose,
  event, guard or cooldown changes.
- PR1 delivers the model and pure tests; `PetRuntime` keeps its old path until
  PR3 switches over.
