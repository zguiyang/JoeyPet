# ADR 005: Read-Only Sensors by Default

## Status

Accepted

## Context

System awareness must not become silent automation. Users trust JoeyPet when sensing stays observational until they approve actions.

## Decision

All V1 **sensors are read-only**. They emit `SystemSignal` values only. File changes, process kills, and settings changes happen only in the utility layer after the safety pipeline (Explain → Recommend → Approve → Act → Feedback).

## Consequences

- Sensor modules have no write APIs to disk, processes, or system preferences.
- Behavior engine and runtime react to signals; they do not perform destructive side effects.
- New sensors must document data source, frequency, and permissions in [system-sensors.md](../system-sensors.md).
