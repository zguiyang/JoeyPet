---
name: joeypet-macos
description: Implement and review JoeyPet on macOS — native Swift desktop pet, ambient behavior runtime and SpriteKit. Use when editing JoeyPet Swift code, adding pet behaviors or animation clips, changing the desktop panel or menu bar item, validating architecture boundaries, changing UI/UX (including plain-language interface requests), or running build/test for this repo.
---

# JoeyPet macOS Skill

Use when working on JoeyPet implementation or review. **Do not duplicate [AGENTS.md](../../../AGENTS.md)** — follow it; this skill adds workflow and layering.

**Scope:** V0 desktop companion only. Read [V0_FEATURE_SCOPE.md](../../../V0_FEATURE_SCOPE.md) and [DESIGN.md](../../../DESIGN.md) first. Mac Care, cleanup, system sensors and Calm Space are retired and live only in the archive branch.

## When to use

- Adding or changing Swift code under `macos/JoeyPet/`
- UI/UX request described in plain language
- New ambient behavior, pet state, or animation clip
- Desktop panel, drag, hide/show or menu bar changes
- Build/test/runtime verification before marking a task done
- Evaluating whether a new dependency is allowed

## Layering (implement in this order)

| Layer | Path | Must not |
|-------|------|----------|
| App | `App/` | Own SpriteKit animation details |
| Domain | `Domain/` | UI or AppKit |
| Behavior | `Behavior/` | Drive `SKScene` directly |
| Pet runtime | `Pet/Runtime/` | Own window or menu bar |
| Presentation | `UI/`, `Pet/Sprite/` | Play animation ids outside `PetRuntime` |
| Utilities | `Utilities/` | Bypass user approval for data changes |

Flow: `AppDelegate → PetCoordinator → AmbientBehaviorScheduler → PetRuntime → PetScene`

## UI work (intent → ambiguity → implementation)

For any interface request, read [references/ui-intent.md](references/ui-intent.md) first.

1. **Extract intent, not words.** Map the description to layout, navigation, motion, component state and platform/accessibility concepts.
2. **Triage ambiguity.** Act when intent is clear; state one assumption when it does not change the outcome. Ask only for a product decision or missing evidence.
3. **Choose the simplest stable implementation.** Ladder: shipped → existing project pattern → Apple-native API → light custom SwiftUI/AppKit → new dependency (reject by default).
4. **Respect authority and scope.** Apple HIG governs platform behaviour; `DESIGN.md` governs JoeyPet visuals and the six V0 surfaces; the frozen HTML reference resolves visual ambiguity only. Do not redesign a surface the user asked to tweak.
5. **Keep the interaction short.** Do the analysis privately; explain only real ambiguity, a product decision, or a material trade-off.
6. **Verify proportionally.** Build for UI changes; check Reduce Motion, keyboard/VoiceOver and compact window sizes where relevant.

Platform guardrails (official pages are `https://developer.apple.com/design/human-interface-guidelines/<page>.md`):

- macOS window states (main / key / inactive) must stay recognizable; AppKit owns the panel and status item.
- Menu-bar extras open a **menu**, not a popover.
- Motion is purposeful; always honor Reduce Motion.
- Every custom control needs a VoiceOver label and keyboard access.

**`hallmark` is a web/HTML design skill — never use it for JoeyPet UI.**

## Add or change an ambient behavior

1. Define the behavior in `PetTransientBehavior` with a pet-centric name.
2. Decide whether it is ambient or explicit-only (`isAmbient`) and its session duration.
3. Add the animation id to the Joey `pet.json` and frames to `spritesheet.png`.
4. Keep playback centralized in `PetRuntime`; callers never play animation ids directly.
5. Add focused tests for timing/selection logic where it is pure.
6. Verify sleep/wake cancellation and no animation restart when the id is unchanged.

## Add or change a sprite animation

1. Edit `macos/JoeyPet/Resources/Pets/Joey/spritesheet.png` — keep row-major layout matching `columns` × `rows` in `pet.json`.
2. Add or update an entry under `animations` (`frames`, `fps`, `loop`).
3. If it maps to a `PetState`, update `PetStateAnimationMapping.swift` only.
4. Run `PetManifestValidator` tests (dimensions, in-bounds frames, fallback).
5. Build and verify in the app; use `-JoeyPetDebugAnimation <id>` or `-JoeyPetDebugBehavior <id>` in Debug.
6. Confirm the same animation id does not restart when re-applied unchanged.

## Panel and lifecycle rules

- Keep the panel borderless, non-activating, floating and available on all spaces.
- Persist position only after drag end; restore safely when a display is gone.
- Hidden mode pauses SpriteKit; showing resumes it.
- Stop ambient scheduling on sleep and teardown; resume at most once after wake.

## Safety verification

- Destructive actions require explicit user confirmation.
- Deletes → Move to Trash only; never `rm -rf`.
- Do not add system sensors, cleanup, FDA or system-monitoring scope without a new product decision.

## Performance checks

- Ambient behavior stays low-frequency; no tight polling or display link for scheduling.
- No blocking I/O on the main thread.
- Avoid restarting animations when the behavior is unchanged.

## Build & test

```bash
xcodebuild -project macos/JoeyPet.xcodeproj -scheme JoeyPet -destination 'platform=macOS' build
xcodebuild -project macos/JoeyPet.xcodeproj -scheme JoeyPet -destination 'platform=macOS' test
```

Run the app for panel and SpriteKit behavior after runtime changes.

## New dependency decision

1. Default: **reject** (V0 third-party runtime deps = 0).
2. If essential: write an ADR in `docs/decisions/`, update `docs/tech-stack.md`, get user approval.

## References

- [references/pet-runtime.md](references/pet-runtime.md) — runtime rule checklist
- [references/ui-intent.md](references/ui-intent.md) — plain-language UI intent and implementation ladder
