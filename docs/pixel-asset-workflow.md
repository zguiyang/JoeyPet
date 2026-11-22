# Pixel Asset Workflow

How Joey sprite packages move from idea to a validated `pet.json` + spritesheet. Complements [character-design.md](character-design.md). The V0 package uses one 256 px HD frame per animation, a 6×1 sheet, and `displayPointSize: 128`.

## Pipeline

```
Concept
  → Character Reference
  → Pixel Conversion / Drawing
  → Pose
  → Animation Frames
  → Sprite Sheet
  → pet.json
  → Debug State / Package Validation
  → Runtime Validation
```

| Stage | Output | Notes |
|-------|--------|-------|
| Concept | Mood, role, silhouette sketches | May use AI for ideation; not final pixels |
| Character Reference | Turn / expression sheet at design resolution | Locks proportions, palette intent, antenna, eyes |
| Pixel Conversion / Drawing | True frame-grid pixels (32×32 or 64×64, etc.) | Manual draw or convert-then-cleanup; no soft AI downscale as final |
| Pose | Key poses per clip | Align feet / pivot across the set |
| Animation Frames | 2–4 frames typical | Integer-pixel deltas only |
| Sprite Sheet | Single PNG, row-major grid | Size = `columns × frameWidth` by `rows × frameHeight` |
| `pet.json` | `PetManifest` | Clip ids, fps, loop, fallback, layout fields |
| Debug Validation | Visual check | `-JoeyPetDebugAnimation <id>` and `-JoeyPetDebugBehavior <id>` (Debug only) |
| Runtime Validation | App playthrough | No restart flicker; fallback works; manifest filtering + display size |

## Display Model

```
Asset / Texel Grid  →  Logical Points  →  Physical / Backing Pixels
```

1. **Asset / Texel Grid** — authored PNG cells (`frameWidth` × `frameHeight`).
2. **Logical Points** — `frame × defaultScale` (integer). This is what SpriteKit / AppKit size in points.
3. **Physical / Backing Pixels** — logical points × `NSScreen.backingScaleFactor` (often 2.0 on Retina laptops; **not** a universal constant).

Do not collapse these layers. A sharp texel grid can still look soft if logical scale is fractional or filtering is linear.

## Pixel-perfect Rules

- Nearest-neighbor on pet textures.
- Integer logical `defaultScale` only for production / compare packages.
- No fractional production scales.
- No anti-alias / blur inside frames (opaque or fully transparent pixels only).
- When judging candidates, note current display `backingScaleFactor`; never assume “Retina = all screens.”
- Fair 2B-1 compare: **32×32 @ 4 = 128 pt** vs **64×64 @ 2 = 128 pt**. Do not evaluate 64@96 pt as production.

See [ADR 008](decisions/008-pixel-perfect-display-scaling.md).

## Production package

| Package ID | Status | Frames | Sheet | Display | Logical pt |
|------------|--------|--------|-------|---------|------------|
| `Joey` | Default shipping production package | 256×256 | 10×1 → 2560×256 | `displayPointSize: 128` | 128×128 |

Paths: `src/JoeyPet/Resources/Pets/<PackageID>/`.

Debug animation/behavior switches (Debug builds only; Release ignores them):

```text
-JoeyPetDebugAnimation idle
-JoeyPetDebugBehavior celebrating
```

## AI assistance vs human gate

AI **may** help with:

- Concept thumbnails and style exploration
- Pose / expression references
- Iteration on silhouette or prop ideas

AI **must not** be the last step for shipping frames. Every frame needs human review for:

1. **Pixel consistency** — same outline weight, no accidental anti-alias haze
2. **Silhouette** — readable at the intended integer nearest scale
3. **Frame alignment** — shared baseline / pivot; no bobbing from crop errors
4. **Palette** — stays within the character color budget (especially 32 vs 64 parity)
5. **Animation jitter** — loops without 1-pixel shakes or flashing holes

## Simple Pipeline (preferred for Phase 2A–2B)

Practical path without new repo tooling:

1. ChatGPT (or similar) image generation for concept / pose reference
2. Save references outside the shipping package (or docs scratch — not as final PNG in `Resources/` until cleaned)
3. Pixel-art conversion or redraw into the target frame grid
4. **Manual cleanup** — the required quality gate
5. Pack frames into `spritesheet.png` and update `pet.json`

## Advanced Pipeline (optional later)

Only if Simple Pipeline is insufficient — **not** set up in Phase 2A/2B-1:

- ComfyUI (or similar) with reference image + pose control / image editing
- Possibly a character LoRA for consistency

**Explicitly out of scope now:** install, deploy, host, or train ComfyUI, LoRAs, or other heavy local ML stacks. No new project dependencies. Revisit only with an ADR and explicit approval.

## Manifest & sheet checklist

Before calling an asset “done”:

- [ ] `frameWidth` / `frameHeight` match each cell
- [ ] PNG size equals `columns * frameWidth` × `rows * frameHeight`
- [ ] Every animation frame index is in-bounds
- [ ] `fallbackAnimation` exists and loops safely
- [ ] Display scale is valid: integer `defaultScale`, or positive `displayPointSize`
- [ ] Pixels are hard-edged (no partial alpha anti-alias)
- [ ] New clips needed by [character-design.md](character-design.md) Initial Animation Set are listed when producing V0 art
- [ ] No prop/attachment system; V0 has no in-frame utility props
- [ ] `PetManifestValidator` / package tests pass when assets change
- [ ] Debug animation/behavior pass + short runtime pass shows no flicker

## Production Sprite Checklist

- [ ] Master silhouette, head/body ratio, antenna, eyes and baseline stay consistent
- [ ] Shared locked palette only; no accidental colors
- [ ] Integer pixel alignment and no partial-alpha anti-aliasing
- [ ] No utility props; V0 clips stay character-only
- [ ] Verify the full Joey frame set at the display size
- [ ] Run every clip with `-JoeyPetDebugAnimation <id>`
- [ ] Run representative `-JoeyPetDebugBehavior <id>` clips through the runtime

## Phase boundaries

| Phase | Allowed |
|-------|---------|
| **2A** | Character design + workflow docs |
| **2B-1** | Idle 32/64 candidates, display model docs, Debug package override, tests |
| **2B-2** | Production `Joey` sprites, first reusable clip set, Debug animation/behavior override, asset tests |

Still forbidden without a separate task: pet picker UI, sensors, settings, multi-character product select, remote packs, sound, LLM features.

## Related docs

- [character-design.md](character-design.md)
- [pet-runtime.md](pet-runtime.md)
- [decisions/007-configurable-sprite-asset-package.md](decisions/007-configurable-sprite-asset-package.md)
- [decisions/008-pixel-perfect-display-scaling.md](decisions/008-pixel-perfect-display-scaling.md)
