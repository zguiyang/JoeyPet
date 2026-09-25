# ADR 012: Full Disk Access for Full Mac Care

## Status

Accepted

## Context

JoeyPet targets **direct distribution** with **App Sandbox disabled**. Deep Mac Care (storage breakdown across protected Library areas, containers, application leftovers) cannot be honestly advertised without bypassing macOS TCC-protected locations. Separate **Files & Folders** prompts for Desktop, Documents, Downloads, and Music conflict with a unified maintenance story.

## Decision

- **Full Disk Access** is required for **Full Mac Care** capability.
- Without FDA, the product operates in **Limited Mac Care** (baseline cleanup, non-prompting storage estimates, gated deep scan routes).
- FDA capability is determined by **read-only probes** on FDA-protected canaries—not by reading `TCC.db` or private APIs.
- `unknown` probe results are treated as **Limited** until proven otherwise.
- In-app FDA onboarding UI is deferred; `SystemSettingsPrivacy.openFullDiskAccessSettings()` is provided for a later settings/onboarding phase.

## Consequences

- Engineering must gate deep scanners and classification scope via `MacCareCapability` / `PermissionService`.
- MVP allowlisted cleanup remains available without FDA.
- Manual FDA testing requires a stable code-signing identity for reliable TCC attribution during development.

## Supersedes

Clarifies product scope relative to ADR 010/011 statements that MVP cleanup does not *require* FDA for the **three allowlisted roots** only. Full Mac Care is a distinct capability tier.
