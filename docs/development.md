# Development

Workflow for humans and agents building JoeyPet V0.

## Prerequisites

- macOS with Xcode
- No extra package installs required

## Agent checklist

1. Read [AGENTS.md](../AGENTS.md), [V0_FEATURE_SCOPE.md](../V0_FEATURE_SCOPE.md) and [DESIGN.md](../DESIGN.md).
2. Confirm the task fits V0 scope and [tech-stack.md](tech-stack.md).
3. Load `.agents/skills/joeypet-macos/SKILL.md` when implementing.
4. Keep the pet panel AppKit-owned; do not migrate window ownership to SwiftUI scenes.

## Implementation

- Smallest diff that satisfies the task.
- App/lifecycle code in `macos/JoeyPet/App/`, scheduling in `Behavior/`, domain types in `Domain/`, runtime in `Pet/Runtime/`, SpriteKit nodes in `Pet/Sprite/`, panel and input in `UI/`.
- Use Swift Concurrency; avoid blocking the main thread.
- Log with `Logger`; no print debugging in committed code.

## Build

```bash
xcodebuild -project macos/JoeyPet.xcodeproj -scheme JoeyPet -destination 'platform=macOS' build
```

### Debug Dev install

Debug builds use bundle ID `com.zguiyang.JoeyPet.dev` and product name **JoeyPet Dev**. Set your Team ID first:

```bash
export JOEYPET_DEVELOPMENT_TEAM=YOUR_TEAM_ID
./macos/scripts/build_joeypet_dev.sh
```

The script builds into `macos/.derived-data/joeypet-dev` and installs the Dev app locally. It does not modify system privacy settings or user data.

## Test

```bash
xcodebuild -project macos/JoeyPet.xcodeproj -scheme JoeyPet -destination 'platform=macOS' test
```

`JoeyPetTests` uses the App target as the test host. Prefer Swift Testing (`@Test`, `#expect`) for new tests.

## Runtime validation

After behavior, panel or asset changes:

1. Run the app from Xcode or open the built product.
2. Verify drag, cross-screen position restoration, hide/show, and menu bar actions.
3. Verify sleep/wake stops and resumes ambient behavior.
4. Verify the same animation does not restart when re-applied unchanged.
5. Check console for unexpected errors.

### Layered pose preview

Debug builds can render the twelve V0.1 poses from the manifest without switching the runtime:

```bash
open -n ~/Applications/'JoeyPet Dev.app' --args -JoeyPetDebugPoses
```

Poses render in atlas order, top-left to bottom-right. Keys `1` / `2` / `3` switch the `s` / `m` / `l` size tier.

## Diff review

Before marking done:

- [ ] No forbidden dependencies ([tech-stack.md](tech-stack.md))
- [ ] No system sensors, Mac Care or cleanup scope added
- [ ] Pet states use pet-centric names, not metric names
- [ ] Tests added or updated for pure rule logic when applicable
- [ ] Build and tests pass

## New dependency process

1. Default: **reject** — V0 has zero third-party runtime dependencies.
2. If truly needed: draft an ADR in `docs/decisions/`, get explicit approval, update [tech-stack.md](tech-stack.md).

## Related docs

- [pet-runtime.md](pet-runtime.md)
