# Joey Character Design

V0 production definition for Joey — the default built-in desktop companion. It locks the first reusable Joey sprite set and the six V0 animation clips.

**Runtime note:** Joey is the V0 built-in character (`Resources/Pets/Joey/`). Runtime remains **character-agnostic** — load any valid `pet.json` + spritesheet package; do not hard-code Joey-specific branches in Swift.

Current packages:

| Package | Role | Frame | Display size | Logical size |
|---------|------|-------|--------------|--------------|
| `Joey` | Shipping production package / default | `256` × `256` | `displayPointSize: 128` | **128** × **128** pt |

The current Joey package uses a 10×1 sheet of 256 px HD frames and displays at
128 pt. Pixel-grid packages may instead use an integer `defaultScale`. Do not
treat mismatched fractional scales as production configurations.

Sheet contract: `columns` × `rows`, row-major; `fallbackAnimation: idle`; integer `defaultScale` or positive `displayPointSize`; manifest-selected filtering ([ADR 007](decisions/007-configurable-sprite-asset-package.md), [ADR 008](decisions/008-pixel-perfect-display-scaling.md)).

## Display Model

Joey is authored on an **asset / texel grid**, shown in **logical points**, and finally rasterized to **physical / backing pixels**.

```
Asset / Texel Grid  →  Logical Points  →  Physical / Backing Pixels
(frameWidth×Height)    (× defaultScale)   (× NSScreen.backingScaleFactor)
```

| Layer | Meaning |
|-------|---------|
| Asset / Texel Grid | Source PNG cell size (`frameWidth` × `frameHeight`) |
| Logical Points | On-screen SpriteKit / AppKit size = frame × integer `defaultScale`, or `displayPointSize` |
| Physical / Backing Pixels | What the display lights; depends on `backingScaleFactor` (often 2.0 on Retina, not guaranteed) |

`CharacterNode` applies the manifest display scale. Textures use the manifest filtering mode (current Joey uses smooth HD frames). See [pet-runtime.md](pet-runtime.md) and [ADR 008](decisions/008-pixel-perfect-display-scaling.md).

## Pixel-perfect Rules

- Use nearest filtering for pixel-grid assets; HD packages may opt into smooth through the manifest.
- **Integer** logical `defaultScale` for pixel-grid packages; HD packages use `displayPointSize`.
- No unintended fractional production scales.
- No anti-alias or soft blur inside authored frames.
- Account for `NSScreen.backingScaleFactor` when judging sharpness; do not assume every display is Retina / 2×.
- Compare candidates at equal logical points (128 pt), not mismatched scales.

## Role

- Desktop companion first; always a pet, never a system assistant.
- Expresses care and work rhythm through character gestures — never as metric readouts.
- Quiet presence; does not compete with the user’s work.

## Personality

| Trait | On-screen meaning |
|-------|-------------------|
| Helpful | Gently invites a break; never monitors or judges |
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
4. Eyes as primary expression vehicle (readable at the current 256 px frame size).
5. No props or attachment/socket system in V0.

## Color System

The production palette is locked for the first Joey V0 sprite set:

| Role | Guidance |
|------|----------|
| Primary | Body / armor — 1 dominant hue |
| Secondary | Accents (antenna base, joints, panel lines) |
| Tertiary | Face plate or under-detail (optional) |
| Status accents | Few colors for sleep Z’s, notify blink, antenna light |
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

Map pet-facing states to readable face / body cues. State names stay **pet-centric**.

| Cue | Examples |
|-----|----------|
| Eyes open / closed | idle blink, sleep |
| Eye shape | celebrating (happy arcs) |
| Antenna light | idle soft, notifying pulse |
| Body posture | upright idle, bounce celebrate |
| Props in-frame | none in V0 |

Do not encode system metric names into art filenames or animation ids (`cpuHigh`, etc.).

## Animation Principles

- Prefer **2–4 frames** per clip (looping ambient states). Phase 2B-1 candidates were **idle-only** comparison assets (≤2 frames) and are no longer shipped.
- **Integer pixel** motion only — no subpixel offsets, no interpolated soft moves in source art.
- Hold silhouette stability across frames; change a few pixels for life (blink, antenna).
- Avoid animation jitter: locked pivot, aligned feet, shared outline where pose allows.
- Looping clips must tile cleanly (last → first without a pop).
- One-shot beats (`celebrating`, `notifying`) may still be short loops if the runtime only plays looping `AnimationClip`s; keep them short and readable.
- Match runtime: manifest filtering, display scale, and frame timing.

## Initial Animation Set

V0 ships six clips. Ids below align with the package and mapping vocabulary in `pet.json`.

| Animation id | Intent | Typical frames |
|--------------|--------|----------------|
| `idle` | Default breathing / presence | 2 |
| `blink` | Occasional eye close (or short idle variant) | 2 |
| `walking` | Soft locomotion on desk | 2–4 |
| `sleeping` | Rest / low-activity metaphor | 2–3 |
| `celebrating` | Positive feedback after a completed recovery | 2–4 |
| `notifying` | Gentle break invitation cue | 2–3 |

The runtime remains manifest-driven and does not gain animation-specific business branches.

### V0 runtime semantics

| Animation id | Runtime meaning |
|--------------|-----------------|
| `idle` | Sustained neutral fallback |
| `blink` | Ambient transient, most frequent |
| `walking` | Ambient short-distance locomotion transient; window movement allowed |
| `sleeping` | Rare ambient session |
| `celebrating` | Explicit transient success feedback |
| `notifying` | Explicit transient break-invitation cue; never random ambient behavior |

Transient completion returns to `idle`. Ambient behavior is discarded rather than
queued while a transient is active.

## Asset Rules

- Package layout: `Resources/Pets/<PackageID>/pet.json` + spritesheet PNG ([ADR 007](decisions/007-configurable-sprite-asset-package.md)).
- Frames: fixed size per manifest (`frameWidth` / `frameHeight`).
- Sheet: row-major, left-to-right, top-to-bottom; `columns` × `rows` must match PNG pixel size.
- `animations`: each clip has `frames`, `fps`, `loop`; indices must stay in-bounds.
- `fallbackAnimation` must exist (Joey: `idle`).
- Display: integer scale only; nearest-neighbor ([ADR 008](decisions/008-pixel-perfect-display-scaling.md)).
- No separate prop, attachment, bone, or layered-equipment runtime in V0.
- Concept / AI reference images are **not** shipping sprites until manually pixel-checked (see [pixel-asset-workflow.md](pixel-asset-workflow.md)).

## Anti-Patterns

- Subpixel animation, motion blur, or soft anti-alias inside frames.
- High-detail faces, tiny unreadable ornaments, or busy backgrounds in the frame cell.
- Metric-named states or clips (`cpuHigh`, `memoryHigh`).
- Hard-coding Joey art paths or clip ids throughout runtime (keep mapping centralized).
- Complex attachment / equipment systems in V0.
- Live2D, 3D, skeletal meshes, or non-pixel styles.
- Treating unconfirmed concept art as final `spritesheet.png`.
- Expanding into multi-character select, remote asset download, sound, or LLM “personality chat” in V0.
- Comparing 32@4 to 64 at a different logical size and calling it a resolution decision.

## Out of scope (V0)

- Pet picker UI, sensors/settings/utilities changes.
- Installing or training ComfyUI / LoRA pipelines.

## Related docs

- [pixel-asset-workflow.md](pixel-asset-workflow.md)
- [pet-runtime.md](pet-runtime.md)
- [decisions/007-configurable-sprite-asset-package.md](decisions/007-configurable-sprite-asset-package.md)
- [decisions/008-pixel-perfect-display-scaling.md](decisions/008-pixel-perfect-display-scaling.md)
