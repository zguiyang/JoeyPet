# Permissions (macOS)

JoeyPet is **direct-distribution**, **App Sandbox off**, and **local-first**. Permission state is expressed as **capabilities** inferred from read-only probes—not from reading the TCC database.

## Full Disk Access (FDA)

**Full Mac Care** (deep storage classification, containers / leftovers scanning, protected Library coverage) requires the user to grant **Full Disk Access** in **System Settings → Privacy & Security → Full Disk Access**.

Without FDA, JoeyPet runs in **Limited Mac Care**:

- Baseline cleanup allowlist (DerivedData, Logs, Caches) continues to work under normal user permissions.
- Storage composition skips media folders and other paths that would trigger separate **Files & Folders** prompts.
- Deep cleanup routes are gated; user-initiated “full” scans fall back to baseline scope.

FDA is **not** requested via an in-app modal; the system requires the user to add JoeyPet manually. A settings deep link helper exists for a future permission UI.

## Detection

`FullDiskAccessProbe` performs a **read-only** directory listing on FDA-protected canaries (`~/Library/Safari`, `~/Library/Messages`). Outcomes:

| Probe result | `FullDiskAccessStatus` |
|--------------|------------------------|
| Canary list succeeds | `granted` |
| Permission denied on canary | `notGranted` |
| No canaries / inconclusive errors | `unknown` |

`unknown` and `notGranted` both map to **Limited** Mac Care (conservative).

Refresh triggers: app launch, `applicationDidBecomeActive`, Settings **重新检查**, and scan preflight—not high-frequency timers.

## Onboarding vs grant state

| Key | Meaning |
|-----|---------|
| `hasCompletedPermissionOnboarding` | User finished or deferred the first-run permission page |
| `FullDiskAccessStatus` | Live capability from read-only probe |

First launch with FDA already granted auto-completes onboarding without blocking. **稍后设置** completes onboarding and enters Limited Mac Care; onboarding does not reappear on every launch.

DEBUG: `-JoeyPetResetPermissionOnboarding` clears onboarding completion for testing.

## Other capabilities (planned)

| Capability | V1 foundation | Authorization |
|------------|-----------------|---------------|
| Notifications | enum only | Work Rhythm phase |
| Accessibility | not used | — |

## Related

- [decisions/012-full-disk-access-mac-care.md](decisions/012-full-disk-access-mac-care.md)
- [decisions/011-distribution-and-app-sandbox.md](decisions/011-distribution-and-app-sandbox.md)
- [safety.md](safety.md)
