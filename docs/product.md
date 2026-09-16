# Product

## What JoeyPet is

JoeyPet is a **macOS-only V1** native Swift desktop pet and lightweight system resource assistant.

**Usually a pet, when needed a tool** — it lives quietly on the desktop, reacts to system conditions with character, and offers small utilities when they help.

## What it is not

- Not an AI companion, chatbot, or LLM assistant.
- Not a system monitor dashboard or menu-bar stats app.
- Not a cross-platform or web-wrapped desktop app.

## Core qualities

| Quality | Meaning |
|---------|---------|
| Lightweight | Low CPU, memory, and battery impact |
| Native | Swift, AppKit/SwiftUI, Apple APIs |
| Privacy-friendly | Local-first; no telemetry by default |
| System-aware | Reads macOS signals; does not silently act |
| Quiet | Non-intrusive; respects attention budget |
| Useful | Small chores: cleanup hints, organization, break reminders |

## User-facing behavior (examples)

- Thermal pressure rises → pet may look hot or sweat (visual metaphor, not a temperature readout).
- Memory pressure → pet looks tired or sluggish.
- Storage low or clutter detected → pet may appear with a trash motif; cleanup is offered, not forced.
- Long active session → gentle break reminder.

Utilities always follow the safety pipeline: explain, recommend, wait for approval, then act.

## Phase 4 MVP

The first usable slice adds a native Overview / Cleanup / Settings window,
short status bubbles, unified severity colors, low-frequency short desktop
movement, and a small safety-gated cleanup utility. Quick Clean only moves
explicitly classified safe candidates to Trash; review candidates require
selection in the Cleanup page.

## Phase 5 Daily-use productization

JoeyPet remembers the user's pet position, recovers safely when display
geometry changes, supports optional launch at login, and keeps Ambient
Behaviors, Proactive Bubbles, and the single Main Window lifecycle coherent.
Cleanup remembers only its last execution summary and does not cache candidate
paths across launches.

## V1 platform

macOS only. See [decisions/001-macos-only-v1.md](decisions/001-macos-only-v1.md).

## Related docs

- [architecture.md](architecture.md)
- [safety.md](safety.md)
- [roadmap.md](roadmap.md)
