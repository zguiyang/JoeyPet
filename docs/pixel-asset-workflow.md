# Pixel Asset Workflow

How Joey sprite packages move from idea to a validated `pet.json` + spritesheet. Complements [character-design.md](character-design.md). **Phase 2A** stops at design and workflow; **Phase 2B** produces production frames.

## Pipeline

```
Concept
  → Character Reference
  → Pixel Conversion / Drawing
  → Pose
  → Animation Frames
  → Sprite Sheet
  → pet.json
  → Debug State Validation
  → Runtime Validation
```

| Stage | Output | Notes |
|-------|--------|-------|
| Concept | Mood, role, silhouette sketches | May use AI for ideation; not final pixels |
| Character Reference | Turn / expression sheet at design resolution | Locks proportions, palette intent, antenna, eyes |
| Pixel Conversion / Drawing | True **32×32** frames | Manual draw or convert-then-cleanup |
| Pose | Key poses per clip | Align feet / pivot across the set |
| Animation Frames | 2–4 frames typical | Integer-pixel deltas only |
| Sprite Sheet | Single PNG, row-major grid | Size = `columns × frameWidth` by `rows × frameHeight` |
| `pet.json` | `PetManifest` | Clip ids, fps, loop, fallback, layout fields |
| Debug State Validation | Visual check per state | e.g. Debug `-JoeyPetDebugState <state>` |
| Runtime Validation | App playthrough | No restart flicker; fallback works; nearest + integer scale |

## Current package contract (JoeyRobot)

Verify against `src/JoeyPet/Resources/Pets/JoeyRobot/`:

- Frames: **32×32**
- Example sheet: **4×3** → **128×96** PNG when that layout is used
- `defaultScale`: **3**
- `fallbackAnimation`: `idle`
- Animation ids and frame indices must stay consistent with the sheet

Do not ship concept renders as the spritesheet. Placeholder art in-repo remains placeholder until Phase 2B replaces it deliberately.

## AI assistance vs human gate

AI **may** help with:

- Concept thumbnails and style exploration
- Pose / expression references
- Iteration on silhouette or prop ideas

AI **must not** be the last step for shipping frames. Every **32×32** sprite needs human review for:

1. **Pixel consistency** — same outline weight, no accidental anti-alias haze
2. **Silhouette** — readable at 3× nearest scale
3. **Frame alignment** — shared baseline / pivot; no bobbing from crop errors
4. **Palette** — stays within the character color budget
5. **Animation jitter** — loops without 1-pixel shakes or flashing holes

## Simple Pipeline (preferred for Phase 2A–2B)

Practical path without new repo tooling:

1. ChatGPT (or similar) image generation for concept / pose reference
2. Save references outside the shipping package (or docs scratch — not as final PNG in `Resources/` until cleaned)
3. Pixel-art conversion or redraw into **32×32** (editor of choice)
4. **Manual cleanup** — the required quality gate
5. Pack frames into `spritesheet.png` and update `pet.json` (Phase **2B** only)

This phase documents the pipeline; it does **not** install services, edit shipping assets, or change loaders.

## Advanced Pipeline (optional later)

Only if Simple Pipeline is insufficient — **not** set up in Phase 2A:

- ComfyUI (or similar) with reference image + pose control / image editing
- Possibly a character LoRA for consistency

**Explicitly out of scope now:** install, deploy, host, or train ComfyUI, LoRAs, or other heavy local ML stacks. No new project dependencies. Revisit only with an ADR and explicit approval.

## Manifest & sheet checklist

Before calling an asset “done”:

- [ ] `frameWidth` / `frameHeight` match each cell
- [ ] PNG size equals `columns * frameWidth` × `rows * frameHeight`
- [ ] Every animation frame index is in-bounds
- [ ] `fallbackAnimation` exists and loops safely
- [ ] New clips needed by [character-design.md](character-design.md) Initial Animation Set are listed when producing Phase 2B art
- [ ] Props (Trash Can, Broom) are in-frame pixels — no attachment system
- [ ] `PetManifestValidator` / package tests pass when assets change
- [ ] Debug state pass + short runtime pass (idle → stressed → idle) shows no flicker

## Phase boundaries

| Phase | Allowed |
|-------|---------|
| **2A** | This workflow + character design docs; references and process only |
| **2B** | Production sprites, sheet packing, `pet.json` clip updates for the initial set |

Still forbidden without a separate task: runtime Swift changes unrelated to assets, sensors, settings, multi-character select, remote packs, sound, LLM features.

## Related docs

- [character-design.md](character-design.md)
- [domain-model.md](domain-model.md)
- [pet-runtime.md](pet-runtime.md)
- [decisions/007-configurable-sprite-asset-package.md](decisions/007-configurable-sprite-asset-package.md)
- [roadmap.md](roadmap.md)
