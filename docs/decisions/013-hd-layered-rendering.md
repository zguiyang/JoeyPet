# ADR 013: Layered HD Pet Rendering and Fractional Display Scale

## Status

Accepted. Supersedes [ADR 008](008-pixel-perfect-display-scaling.md) for the HD
layered pet art introduced by the V0.1 state atlas.

## Context

ADR 008 assumed pixel-art frames, integer logical multipliers and
nearest-neighbor filtering. The V0.1 atlas defines a 320×400 vector character
with 8 layers, 12 poses, 8 faces and 16 blink frames, displayed at 132×165,
168×210 (default) or 216×270 points.

`168 / 320 = 0.525` and `210 / 400 = 0.525`; the scale is intentionally
fractional. The art is HD SVG/PNG rather than a pixel grid, so nearest-neighbor
filtering produces aliasing instead of crisp edges.

## Decision

1. Use a logical canvas of **320×400** with anchor **(160, 388)** and an 8 px
   safe margin.
2. Render in eight layers, back to front:
   `shadow → tail → body → ears → backArm → face → frontArm → prop`.
3. Keep named anchors: breath `(160, 340)`, head `(160, 240)`, ear `(160, 150)`,
   tail `(250, 286)`, shoulders `(230, 254)` / mirrored `(90, 254)`.
4. Display at **132×165 / 168×210 (default) / 216×270** points. Scale is
   `displayWidth / 320`; it is fractional by design.
5. Export PNG at **1x / 2x / 3x** (plus SVG source). Use **linear** filtering.
6. `emotion` is baked into `face` in V0; no separate emotion node.
7. Missing pose/clip falls back to `pose_sit` / `idle_sit`; unknown manifest
   versions are rejected.

## Consequences

- ADR 008's nearest-neighbor and integer-multiplier rules apply only to legacy
  pixel packages; they are retired for the V0 HD Joey.
- `CharacterNode` becomes a layered composition with named anchors instead of a
  single sprite node.
- The manifest owns canvas, sizes, anchors and layer order; views must not
  hardcode them.
- Visual QA must check 200% scaling for pixel steps and 1 px seams, which the old
  pixel pipeline did not need.
- The old 6-frame spritesheet and `joey-front/side/back` sources were removed
  in PR6 (2026-11-23) after the layered path was verified.
