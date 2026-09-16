# Joey Character Design

Phase **2B-2** production definition for Joey — the default built-in Pixel Robot. Phase 2A established the character direction and Phase 2B-1 validated display density; this phase locks the first reusable Joey sprite set.

**Runtime note:** Joey is the V1 built-in character (`Resources/Pets/JoeyRobot/`). Runtime remains **character-agnostic** — load any valid `pet.json` + spritesheet package; do not hard-code Joey-specific branches in Swift.

Current packages:

| Package | Role | Frame | `defaultScale` | Logical size |
|---------|------|-------|----------------|--------------|
| `JoeyRobot` | Shipping production package / default | `32` × `32` | `4` | **128** × **128** pt |

The production decision is **32@4** (128 pt). Do **not** treat 64@96 pt (e.g. scale 1.5) as a production configuration. The 2B-1 candidates were comparison-only and are not shipped.

Sheet contract: `columns` × `rows`, row-major; `fallbackAnimation: idle`; integer `defaultScale`; nearest filtering ([ADR 007](decisions/007-configurable-sprite-asset-package.md), [ADR 008](decisions/008-pixel-perfect-display-scaling.md)).

## Display Model

Joey is authored on an **asset / texel grid**, shown in **logical points**, and finally rasterized to **physical / backing pixels**.

```
Asset / Texel Grid  →  Logical Points  →  Physical / Backing Pixels
(frameWidth×Height)    (× defaultScale)   (× NSScreen.backingScaleFactor)
```

| Layer | Meaning |
|-------|---------|
| Asset / Texel Grid | Source PNG cell size (`frameWidth` × `frameHeight`) |
| Logical Points | On-screen SpriteKit / AppKit size = frame × integer `defaultScale` |
| Physical / Backing Pixels | What the display lights; depends on `backingScaleFactor` (often 2.0 on Retina, not guaranteed) |

`CharacterNode` applies `manifest.defaultScale` via `setScale`. Textures use nearest filtering. See [pet-runtime.md](pet-runtime.md) and [ADR 008](decisions/008-pixel-perfect-display-scaling.md).

## Pixel-perfect Rules

- Nearest-neighbor filtering only (no linear blur on pet sprites).
- **Integer** logical `defaultScale` only in production packages.
- No fractional production scales (e.g. 1.5×, 2.5×).
- No anti-alias or soft blur inside authored frames.
- Account for `NSScreen.backingScaleFactor` when judging sharpness; do not assume every display is Retina / 2×.
- Compare candidates at equal logical points (128 pt), not mismatched scales.

## Role

- Desktop companion first; lightweight system assistant only when useful.
- Expresses macOS conditions as **character metaphors** (sweat, tired, trash motif) — never as metric readouts.
- Quiet presence; does not compete with the user’s work.

## Personality

| Trait | On-screen meaning |
|-------|-------------------|
| Helpful | Notices clutter or pressure; offers tools only after explain → approve |
| Quiet | Prefers small loops and soft state changes over constant motion |
| Playful | Short celebration / notify beats; never chaotic |
| Stoic-cute | Robot body, readable face; emotions are clear but not melodramatic |
| Local-first | Feels like a desk buddy, not a cloud agent or chatbot |

## Visual Language

- **Medium:** Classic pixel art, silhouette-first.
- **Readability:** At candidate compare size (128×128 pt) and at shipping 32×3 (96×96 pt), the outline must remain recognizable.
- **Silhouette first:** Shape reads before detail; avoid noisy interior pixels.
- **Proportions:** Big head, small body (chibi robot). Keep the same head/body ratio across 32 and 64 candidates.
- **Face:** Simple 1–2 px eyes (scaled appropriately at 64); expression from eye shape/offset and small mouth changes.
- **Signature:** Short antenna with a status light (mood / alert cue).
- **Style lock:** Flat pixel fills, hard edges, no anti-aliased blur, no soft gradients inside frames.
- **64 density:** Extra texels only where they help silhouette or face; do not explode palette, gradients, or mechanical micro-detail.

## Signature Features

1. Rounded or blocky robot head (dominant mass).
2. Compact torso / stubby limbs.
3. Short antenna + status light (color may shift with state; keep light small).
4. 1–2 px eyes as primary expression vehicle (at 32; slightly denser at 64 without changing character).
5. Optional first-wave props: **Trash Can**, **Broom** (drawn into frames; no attachment/socket system in V1).

## Color System

The production palette is locked for the first Joey V1 sprite set:

| Role | Guidance |
|------|----------|
| Primary | Body / armor — 1 dominant hue |
| Secondary | Accents (antenna base, joints, panel lines) |
| Tertiary | Face plate or under-detail (optional) |
| Status accents | Few colors for sweat, sleep Z’s, notify blink, antenna light |
| Outline | Single dark outline or high-contrast edge for silhouette |

**Palette:**

| Role | HEX |
|------|-----|
| Outline / eye | `#162030` |
| Body base | `#46749E` |
| Body shadow | `#234360` |
| Face panel | `#BEDCE8` |
| Calm / bright lamp | `#E4B84E` |
| Heat accent | `#DF7E63` |
| Dim lamp | `#7589A3` |

Transparent pixels are fully transparent; no semi-transparent edge pixels are used. Reuse this palette across every production clip.

## Proportions

- Canvas: per-package `frameWidth` × `frameHeight`; character anchored to a consistent baseline / feet position across poses.
- Head ≈ 40–55% of character height; body and legs share the rest.
- Keep a few transparent margin pixels so scaled nearest-neighbor display does not clip.
- Horizontal facing: pick one default facing (e.g. slight 3/4 or side) and stay consistent unless a clip explicitly turns.

## Expression System

Map pet-facing states to readable face / body cues. State names stay **pet-centric** (see [domain-model.md](domain-model.md)).

| Cue | Examples |
|-----|----------|
| Eyes open / closed | idle blink, sleep |
| Eye shape | tired (half-lid), celebrating (happy arcs) |
| Antenna light | idle soft, notifying pulse, sweating warm |
| Body posture | upright idle, slumped tired, bounce celebrate |
| Props in-frame | trash can for `carryingTrash`, broom for `cleaning` |

Do not encode system metric names into art filenames or animation ids (`cpuHigh`, etc.).

## Animation Principles

- Prefer **2–4 frames** per clip (looping ambient states). Phase 2B-1 candidates were **idle-only** comparison assets (≤2 frames) and are no longer shipped.
- **Integer pixel** motion only — no subpixel offsets, no interpolated soft moves in source art.
- Hold silhouette stability across frames; change a few pixels for life (blink, antenna, sweat drops).
- Avoid animation jitter: locked pivot, aligned feet, shared outline where pose allows.
- Looping clips must tile cleanly (last → first without a pop).
- One-shot beats (`celebrating`, `notifying`) may still be short loops in V1 if the runtime only plays looping `AnimationClip`s; keep them short and readable.
- Match runtime: nearest filtering, integer `defaultScale`.

## Initial Animation Set

Target ~10 clips for Phase 2B production. Ids below align with package / mapping vocabulary (`carryingTrash` matches current `pet.json`).

| Animation id | Intent | Typical frames |
|--------------|--------|----------------|
| `idle` | Default breathing / presence | 2 |
| `blink` | Occasional eye close (or short idle variant) | 2 |
| `walking` | Soft locomotion on desk | 2–4 |
| `sleeping` | Rest / quiet hours metaphor | 2–3 |
| `sweating` | Thermal / heat metaphor | 2–4 |
| `tired` | Memory pressure / sluggish metaphor | 2–3 |
| `carryingTrash` | Storage / clutter motif | 2–4 |
| `cleaning` | Cleanup utility mood (broom) | 2–4 |
| `celebrating` | Positive feedback after approved action | 2–4 |
| `notifying` | Gentle attention / break reminder cue | 2–3 |

Phase 2B-2 delivers the first production set in `JoeyRobot`: all ten clips below, with props composited into their frames. The runtime remains manifest-driven and does not gain animation-specific business branches.

### Phase 3 runtime semantics

The ten production clips are intentionally split by runtime meaning:

| Animation id | Runtime meaning |
|--------------|-----------------|
| `idle` | Sustained neutral fallback |
| `blink` | Ambient transient, most frequent |
| `walking` | Ambient in-place transient; no window movement |
| `sleeping` | Rare ambient session |
| `sweating` | Sustained thermal system state |
| `tired` | Sustained memory-pressure system state |
| `carryingTrash` | Sustained low-storage system state |
| `cleaning` | Explicit utility behavior hook; no cleanup utility in V1 |
| `celebrating` | Explicit transient success feedback |
| `notifying` | Explicit transient attention cue; never random ambient behavior |

System states may preempt transient behavior. Transient completion resumes the
latest sustained state, and ambient behavior is discarded rather than queued
when a warning is active.

## Asset Rules

- Package layout: `Resources/Pets/<PackageID>/pet.json` + spritesheet PNG ([ADR 007](decisions/007-configurable-sprite-asset-package.md)).
- Frames: fixed size per manifest (`frameWidth` / `frameHeight`).
- Sheet: row-major, left-to-right, top-to-bottom; `columns` × `rows` must match PNG pixel size.
- `animations`: each clip has `frames`, `fps`, `loop`; indices must stay in-bounds.
- `fallbackAnimation` must exist (Joey: `idle`).
- Display: integer scale only; nearest-neighbor ([ADR 008](decisions/008-pixel-perfect-display-scaling.md)).
- Props (Trash Can, Broom): composite into sprite frames for now — **no** separate attachment, bone, or layered prop runtime.
- Concept / AI reference images are **not** shipping sprites until manually pixel-checked (see [pixel-asset-workflow.md](pixel-asset-workflow.md)).

## Anti-Patterns

- Subpixel animation, motion blur, or soft anti-alias inside frames.
- High-detail faces, tiny unreadable ornaments, or busy backgrounds in the frame cell.
- Metric-named states or clips (`cpuHigh`, `memoryHigh`).
- Hard-coding Joey art paths or clip ids throughout runtime (keep mapping centralized).
- Complex attachment / equipment systems in V1.
- Live2D, 3D, skeletal meshes, or non-pixel styles.
- Treating unconfirmed concept art as final `spritesheet.png`.
- Expanding into multi-character select, remote asset download, sound, or LLM “personality chat” in this phase.
- Comparing 32@4 to 64 at a different logical size and calling it a resolution decision.

## Out of scope (Phase 2B-2)

- Pet picker UI, sensors/settings/utilities changes.
- Installing or training ComfyUI / LoRA pipelines.

## Related docs

- [pixel-asset-workflow.md](pixel-asset-workflow.md)
- [domain-model.md](domain-model.md)
- [pet-runtime.md](pet-runtime.md)
- [product.md](product.md)
- [roadmap.md](roadmap.md)
- [decisions/007-configurable-sprite-asset-package.md](decisions/007-configurable-sprite-asset-package.md)
- [decisions/008-pixel-perfect-display-scaling.md](decisions/008-pixel-perfect-display-scaling.md)
