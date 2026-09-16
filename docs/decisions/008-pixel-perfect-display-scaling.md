# ADR 008: Pixel-Perfect Display Scaling

## Status

Accepted

## Context

JoeyPet renders config-driven pixel pets via SpriteKit. Frame art lives on an asset texel grid, while AppKit / SpriteKit size the node in **logical points**, and macOS finally maps those points to **backing pixels** using each screen’s `backingScaleFactor`. Phase 2B-1 must compare 32×32 and 64×64 candidates fairly without inventing a display manager, baking in “Retina = 2”, or allowing fractional production scales that blur nearest-neighbor art.

## Decision

1. Treat display as three layers: **asset/texel grid → logical points → physical/backing pixels**.
2. `PetManifest.defaultScale` is a **positive integer** logical multiplier applied by `CharacterNode.setScale` (not a backing-pixel scale).
3. Pet textures keep **nearest-neighbor** filtering; no linear filtering for character sprites.
4. Production (and compare) packages must not use fractional `defaultScale`.
5. Do **not** assume a fixed backing scale; screens may differ and can change.
6. Fair resolution comparison uses equal logical size — Phase 2B-1: **32×32 @ 4** and **64×64 @ 2** both target **128×128 points**.

## Consequences

- Art and docs reason in points vs backing pixels separately; sharpness checks must consider the active `NSScreen.backingScaleFactor`.
- Invalid `defaultScale <= 0` remains rejected by `PetManifestValidator`.
- Debug-only `-JoeyPetDebugPet` can load idle candidates without a product pet picker; Release stays on default `JoeyRobot`.
- No `DisplayScaleManager` / Retina engine abstraction in V1; revisit only if multi-screen scale handling becomes a real runtime requirement.
