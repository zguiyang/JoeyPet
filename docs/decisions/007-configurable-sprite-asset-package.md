# ADR 007: Configurable Sprite Asset Package

## Status

Accepted

## Context

Phase 1 used programmatic `SKShapeNode` placeholders. Phase 1.5 needs real sprite animations without hard-coding frame sizes, layout, or character-specific branches in runtime code.

## Decision

Ship pets as **bundled asset packages** under `Resources/Pets/<PackageID>/` containing `pet.json` (strongly typed `PetManifest`) and a spritesheet PNG. `PetAssetLoader` loads, validates, and caches manifest data, frame textures, and `AnimationClip` definitions. `PetRuntime` maps `PetState` to animation IDs in one place; `PetScene` plays clips via SpriteKit only.

## Consequences

- Art changes are manifest + PNG updates; no runtime code changes for new clips on the same pet.
- V1 ships one built-in package: `JoeyRobot`.
- Plugin/download/import systems remain out of scope until a future ADR.
- Invalid packages log and fall back in Release; no crash.
