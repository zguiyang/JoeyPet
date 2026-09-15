# Safety

JoeyPet can suggest actions that touch files, processes, or settings. Safety is a product requirement, not an afterthought.

## Default posture

- **Sensors read-only by default** — observe and signal only.
- **No silent destructive actions** — ever.
- **Local-first** — no sending system state or file lists to remote services in V1.

## Action pipeline

Every utility that may change the system or user data must follow:

```
Observe → Detect → Explain → Recommend → Approve → Act → Feedback
```

| Step | Agent / app obligation |
|------|-------------------------|
| Observe | Sensor or scan gathers facts (read-only) |
| Detect | Rule identifies an issue worth mentioning |
| Explain | Plain language: what was found, why it matters |
| Recommend | Specific, reversible action when possible |
| Approve | Explicit user confirmation (dialog, checkbox, or dedicated approve control) |
| Act | Perform only the approved scope |
| Feedback | Show result; offer undo where feasible (Trash restore) |

## Actions requiring confirmation

Includes but is not limited to:

- Delete or move files
- Kill processes
- Change system configuration or Login Items
- Write outside app sandbox to important directories (Desktop, Documents, Downloads, etc.)
- Any operation that may cause **data loss**

## Deletion policy

- **Prefer Move to Trash** (`FileManager.trashItem` or Finder-equivalent).
- **Forbidden:** `rm -rf`, shell bulk delete, or permanent erase without separate explicit opt-in.

## Process termination

- Show process name and reason.
- Never kill system-critical processes automatically.
- User must confirm each batch.

## Sensor and utility boundaries

- Sensors do not enqueue destructive work.
- Utilities run only after approval; log actions with OSLog / `Logger` at appropriate privacy levels.

## Related docs

- [product.md](product.md)
- [system-sensors.md](system-sensors.md)
- [decisions/005-read-only-sensors-by-default.md](decisions/005-read-only-sensors-by-default.md)
