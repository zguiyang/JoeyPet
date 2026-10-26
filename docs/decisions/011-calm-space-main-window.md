# ADR 011: Calm Space Immersive Main Window

## Status

Accepted — implemented on branch `feature/calm-space-main-window`.

## Context

The main window had grown into a dashboard of equal-weight cards (storage donut, memory
chart, thermal card, cleanup CTA, applications row). That reads as a system-monitor tool,
not as JoeyPet's own quiet, native design language. The product direction for this phase
is an immersive, calm, subtly alive main-window canvas while preserving every existing
Mac Care / Settings entry and all safety-gated cleanup behaviour.

## Decision

The `.main` presentation of the main window becomes a single full-bleed **Calm Space**
canvas:

- AppKit owns the window (`fullSizeContentView`, transparent titlebar, hidden title,
  native traffic lights, movable by background).
- SwiftUI owns the layout, status copy, floating dock, expanding mode switch and the
  Mac Care ↔ Work Rhythm transition.
- One transparent SpriteKit scene at 30 FPS renders the ambient background and the
  central orb (breathing, slow rotation, orbit particles, sparse stars, cached Core
  Graphics textures). No shader, no live blur, no 3D engine, no new dependency.
- Light and dark are independently tuned palettes driven by the system appearance.
- Health status reuses `SystemStatusSnapshot` and the existing Mac Care presentation
  logic; semantic states are normal / attention / critical / unknown. Raw memory usage
  or Swap size alone never creates an alert.
- The scene pauses when the window is hidden, miniaturised or occluded. Reduce Motion
  freezes all loops.
- Layout is derived from the window size in `CalmSpaceLayout`; `CalmSpaceLayoutTests`
  assert orb clamping and no status/controls collision for compact, regular, wide-short
  and narrow-tall windows.
- Settings and feature pages (disk management, applications placeholder) remain
  conventional pages; the immersive scene is not rendered there.

## Consequences

- The old Mac Care dashboard view (`MacCareHomeView`) is no longer presented by the
  shell. It is retained for reference and can be removed in a follow-up cleanup.
- `MainWindowChrome` no longer manages a unified toolbar; main and settings presentations
  have no titlebar/toolbar navigation. Settings keeps its page-level back row.
- Work Rhythm still has no timer/focus implementation. The mode switch and visual
  language exist, but the Work Rhythm status and dock explicitly describe the feature as
  not yet available. No business state is fabricated.
- Minimum window size is 680 × 512 pt. The 512 pt frame minimum comes from the native
  titlebar chrome above a 480 pt content minimum; 680 × 480 and 720 × 500 test samples
  are therefore clamped by AppKit.
- Business logic for cleanup, disk scanning, application management and settings was not
  changed in this phase.
