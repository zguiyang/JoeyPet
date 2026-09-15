# ADR 003: 2D Sprite Runtime

## Status

Accepted

## Context

The pet must animate on the desktop with low GPU/CPU cost. 3D engines and Live2D add asset pipeline complexity and binary size.

## Decision

Render the pet with **2D sprites via SpriteKit**. Animation is clip-based (`AnimationClip` per `PetState`). No Unity, 3D scenes, or Live2D in V1.

## Consequences

- Art pipeline is sprite sheets / texture atlases.
- `PetRuntime` selects clips; SpriteKit scene does not subscribe to sensors directly.
- 3D or skeletal animation requires a future ADR and roadmap phase.
