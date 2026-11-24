# JoeyPet · 2D Clip Animation Pipeline (V0→V1)

> Status: Agreed direction for expression clips when packs land.  
> Scope: Expression layer only. Does **not** change `PetRuntime` / companionship product rules.  
> Design-AI prompts: delivered in chat only — do not store prompt packs under `docs/`.

## 1. Decision

**Primary expression path:** full-character **baked sequence frames (spritesheet or numbered PNGs) driven by a wall-clock clip timeline** for large actions that layered static poses cannot carry.

| Keep | Change eventually |
|------|-------------------|
| `PetRuntime` → `clipId` / pose selection | Add clip packs for expression-heavy one-shots when needed |
| 320×400 canvas, foot anchor `(160, 388)` | Add `clips[]` metadata: `id`, `fps`, `loop`, `frames` |
| `@1x / @2x / @3x` PNG + linear filtering ([ADR 013](decisions/013-hd-layered-rendering.md)) | Prefer **whole-character frames** for large actions |
| Storybook 2D (no 3D, no pixel art, no Live2D) | Layered PNG remains OK for **blink / tiny idle** |

**V0 note:** Ambient **walking / `step` was removed** (weak product meaning; walk art broke Joey identity). Do not reintroduce locomotion clips without a new product decision and identity-locked art from the same layered atlas.

**Not chosen now:** SceneKit/RealityKit 3D, Spine/Live2D, Lottie/Rive (third-party runtime), “image-to-3D from every frame”.

## 2. Display & scaling contract

Three layers (same as ADR lineage):

1. **Asset texel** — art at 320×400 @1x; also 640×800 @2x, 960×1200 @3x (or equivalent sheet cell sizes).  
2. **Logical points** — panel sizes stay `132×165` / `168×210` (default) / `216×270`.  
3. **Backing pixels** — per-screen `backingScaleFactor`; never hardcode “Retina = 2”.

Rules:

- Clocks are **wall time**, not “one advance per vsync”.  
- Character size is capped by the highest prepared scale (do not unlimited-zoom bitmap past @3x for default art).  
- Filtering for HD storybook art: **linear** (ADR 013).  
- Cross-screen drag: logical origin persists; texture scale follows the **destination** screen.

## 3. Clip inventory (build order)

| Priority | Clip id | Kind | Suggested frames / fps | Notes |
|----------|---------|------|------------------------|-------|
| P0 | `idle_sit` | loop | 10 @ 12fps | Breath + micro sway (layered breath may remain primary) |
| P0 | `sleep` | loop | 8 @ 10fps | Standing or curl — pick one and stick; breath visible |
| P1 | `notify_sign` | one-shot + hold | 16 @ 12fps | Blank wooden sign (no glyphs) |
| P1 | `recover_stretch` | loop or short | 12 @ 12fps | Matches recovery UI |
| P1 | `complete_happy` | one-shot | 16 @ 12fps | Ends back toward sit |
| P2 | `doze` | loop | 6–8 @ 10fps | Lighter than sleep |
| P2 | `yawn` / `groom` | one-shot | 12 @ 12fps | Ambient only when idle |

## 4. Delivery layout (for packs landing in repo)

```text
Resources/Pets/Joey/clips/
  idle_sit/
    meta.json          # { "fps": 12, "loop": true, "frameCount": 10 }
    png/1x/000.png … 009.png
    png/2x/…
    png/3x/…
```

`meta.json` is the source of truth for fps/loop; engineering wires it when implementing playback.

## 5. Acceptance (agent / human)

When reviewing Design-AI output, reject if any fail:

1. **Identity** — same Joey as model sheet (ears, snout, proportions, line weight).  
2. **Canvas** — 320×400 cells; feet on bottom center; full body in frame; transparent BG.  
3. **No UI junk** — no text, watermark, bubble, second character.  
4. **Style** — storybook 2D; not 3D/CGI, not pixel, not neon.  
5. **Loop** — first↔last frame continuous for loop clips.  
6. **Density** — @2x/@3x readable on Retina and 4K (soft, not mushy; no 1x-only soft upscale).  
7. **Palette** — ivory / warm gray-beige / sage `#86A98A` accents / apricot blush `#EFAE7D` / ink `#3F3A35`.

## 6. Related docs

- [DESIGN.md](../DESIGN.md) — visual language  
- [ADR 013](decisions/013-hd-layered-rendering.md) — canvas / scales / linear filter  
- [pet-runtime.md](pet-runtime.md) — behavior → clip mapping  
- [pet-domain-model.md](pet-domain-model.md) — poses / conflicts  
- [V0_FEATURE_SCOPE.md](../V0_FEATURE_SCOPE.md) — product scope  
