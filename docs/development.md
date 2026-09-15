# Development

Workflow for humans and agents building JoeyPet.

## Prerequisites

- macOS with Xcode (version aligned with project deployment target when set)
- No extra package installs required for Phase 0

## Agent checklist

1. Read [AGENTS.md](../AGENTS.md) and load `.agents/skills/joeypet-macos/SKILL.md` when implementing.
2. Confirm task fits [roadmap.md](roadmap.md) phase and [tech-stack.md](tech-stack.md).
3. Respect [architecture.md](architecture.md) boundaries (no sensor → scene shortcuts).
4. Apply [safety.md](safety.md) for any user-visible action.

## Design (minimal)

- Name types per [domain-model.md](domain-model.md).
- Sketch signal → behavior → state → clip before coding.
- No Behavior Tree, database schema, or LLM prompt design in V1.

## Implementation

- Smallest diff that satisfies the task.
- System code in `System/`, pet code in `Pet/`, shared types in `Domain/` (when directories exist).
- Use Swift Concurrency; avoid blocking main thread for sensor I/O.
- Log with `Logger`; no print debugging in committed code.

## Build

```bash
xcodebuild -project JoeyPet.xcodeproj -scheme JoeyPet -destination 'platform=macOS' build
```

Adjust scheme name if renamed in Xcode.

## Test

```bash
xcodebuild -project JoeyPet.xcodeproj -scheme JoeyPet -destination 'platform=macOS' test
```

Prefer Swift Testing (`@Test`, `#expect`) for new tests.

## Runtime validation

After behavior or UI changes:

1. Run app from Xcode or `open` built product.
2. Verify pet window/panel behavior and no console spam.
3. For sensors: confirm signals stable (no flicker); see [pet-runtime.md](pet-runtime.md).
4. For utilities: walk full safety pipeline manually.

## Diff review

Before marking done:

- [ ] No forbidden dependencies ([tech-stack.md](tech-stack.md))
- [ ] No sensor driving SpriteKit directly
- [ ] Pet states use character names, not metric names
- [ ] Destructive paths gated by approval; Trash over delete
- [ ] Tests added or updated for rule logic when applicable

## New dependency process

1. Default: **reject** — V1 target is zero third-party runtime deps.
2. If truly needed: draft ADR in `docs/decisions/`, get explicit approval, update [tech-stack.md](tech-stack.md).

## Related docs

- [project-structure.md](project-structure.md)
- [roadmap.md](roadmap.md)
