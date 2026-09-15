# ADR 004: No Database in V1

## Status

Accepted

## Context

V1 needs only user preferences, last window position, and ephemeral runtime state. A database adds migration, backup, and privacy surface without clear benefit.

## Decision

**No database in V1.** Use UserDefaults and `@AppStorage` for `PetPreferences` and lightweight flags. Scan results are computed on demand, not stored long-term in SQL.

## Consequences

- No Core Data / SQLite schema in early phases.
- History features (e.g. cleanup logs over months) deferred or redesigned as file export if needed later.
- Adding a database requires a new ADR.
