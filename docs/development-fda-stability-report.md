# FDA / TCC development stability report

This document records the permission and test-isolation changes for Mac Care storage work. It does **not** claim manual validation unless explicitly noted as performed.

## Problem (confirmed prior behavior)

| Area | Old behavior | Risk |
|------|----------------|------|
| App identity (Debug) | `com.zguiyang.JoeyPet` (same as Release) | FDA/TCC entries tied to unstable dev identity; resets when rebuilding from Xcode |
| Unit tests | `TEST_HOST` → `JoeyPet.app` | Tests ran inside the app host; permission probes and storage paths executed in production bundle context |
| `StorageAnalyzerV3DiagnosticTests` | Opt-in via `JOEYPET_STORAGE_V3_DIAG=1` under XCTest | Full-machine V3 scan from unit test path; bypassed stable dev workflow |
| `AppModel` storage refresh | V3 via `StorageAnalyzer.analyze(fullDiskAccessStatus:)`; V2 via `StorageCategoryEstimator.estimate(fullDiskAccessStatus:)` | No caller-supplied `MacCareAccessLevel.full` or bare `Bool` bypass |
| FDA probe | Listed `~/Library/Safari` and `~/Library/Messages` | Acceptable for FDA; expanded surface vs minimal canary |
| Storage estimator tests | Temp dirs under `NSTemporaryDirectory()` | Fine for fixtures; real-home diagnostic mixed with unit tests |

### Why Music / Photos / Documents prompts appeared

- **Files & Folders (TCC)** protects user-visible locations (`Desktop`, `Documents`, `Downloads`, `Music`, `Pictures`, etc.). Touching them during classification or probes triggers system prompts.
- **Full Disk Access** is separate; deep `Library` paths (e.g. Safari) are used only as read-only FDA canaries.
- Running storage logic from the **test host app** or with **hard-coded `fullDiskAccessGranted: true`** caused protected traversal without a single explicit FDA gate.

## Unified gate (current)

| `FullDiskAccessStatus` | `MacCareAccessLevel` | Protected storage / V3 scan |
|------------------------|----------------------|-----------------------------|
| `.granted` | `.full` | Allowed (`MacCareCapability.allowsProtectedStorageWork` + `StorageAnalyzer` entry guard) |
| `.notGranted` | `.limited` | Blocked — V2 estimator / baseline cleanup only |
| `.unknown` | `.limited` | Blocked — conservative, no “probe by scanning” |

FDA detection: read-only listing on `~/Library/Safari` only (`FullDiskAccessProbe`). No `TCC.db`, no private API, no Desktop/Documents/Downloads/Music/Pictures/Photos paths.

## Stable Debug identity

| Setting | Debug | Release (unchanged) |
|---------|-------|---------------------|
| Bundle ID | `com.zguiyang.JoeyPet.dev` | `com.zguiyang.JoeyPet` |
| Product name | JoeyPet Dev | JoeyPet |
| Signing | `Apple Development` + `DEVELOPMENT_TEAM = $(JOEYPET_DEVELOPMENT_TEAM)` | Project defaults |

**Prerequisite:** export `JOEYPET_DEVELOPMENT_TEAM` with your Apple Development Team ID before Debug build or `scripts/build_joeypet_dev.sh`. The repo does not embed a Team ID.

Grant FDA in System Settings for **JoeyPet Dev** (`com.zguiyang.JoeyPet.dev`), not only the Release app.

## Unit tests vs real integration

| Kind | How | FDA / filesystem |
|------|-----|------------------|
| Unit (`JoeyPetTests`) | XCTest-hosted by the App target only for `@testable import`; no FDA diagnostic tests | Fakes: `FixedFullDiskAccessProbe`, `RecordingDirectoryAccess`, temp fixtures |
| Real V3 diagnostic | **Not** in XCTest | Run `scripts/run_storage_v3_diagnostic.sh` (wraps `scripts/build_joeypet_dev.sh`) or invoke the build script directly |

Legacy XCTest `StorageAnalyzerV3DiagnosticTests` and `.storage-v3-diag` marker flows were removed. The test host is a module-loading detail, not the FDA integration identity; FDA is never granted to or tested through that host.

## Manual test checklist (for humans — not auto-verified here)

1. Set `JOEYPET_DEVELOPMENT_TEAM`, then run `./scripts/build_joeypet_dev.sh` or `./scripts/run_storage_v3_diagnostic.sh` (same outcome: build → in-place `ditto` to `~/Applications/JoeyPet Dev.app` → open).
2. Launch **JoeyPet Dev**; confirm no immediate Music/Photos/Documents prompts on home refresh without FDA.
3. Without FDA: storage shows limited pipeline (V2); deep cleanup defers to baseline.
4. Grant FDA to **JoeyPet Dev**; re-check permissions in Settings → re-check in app; V3 may run when status is `.granted`.
5. Run `xcodebuild test` — the App host is only for Swift module loading; no full-disk diagnostic test runs.
6. With FDA ON, quit JoeyPet Dev, rebuild/update the same `~/Applications/JoeyPet Dev.app`, relaunch, and confirm the probe remains `.granted`.
7. Turn FDA OFF, launch JoeyPet Dev, and confirm there are no Music/Photos/Documents prompts; the UI remains limited and deep work stays blocked.

## Files touched (permission stability scope)

- `AppModel.swift` — passes `FullDiskAccessStatus` into V2/V3 storage entry points
- `MacCareCapability.swift` — `allowsProtectedStorageWork`
- `FullDiskAccessProbe.swift` — minimal Safari canary
- `StorageAnalyzer.swift` — `analyze(fullDiskAccessStatus:)` entry gate (algorithms unchanged)
- `StorageCategoryEstimator.swift` — `estimate(fullDiskAccessStatus:)` entry gate (walk/plans unchanged)
- `JoeyPetTests.swift` — FDA gate unit tests; no machine diagnostic
- `project.pbxproj` — Debug Dev identity; test host has no FDA role
- `scripts/build_joeypet_dev.sh` — fixed `~/Applications/JoeyPet Dev.app`; in-place `ditto` (no recursive delete)
- `scripts/run_storage_v3_diagnostic.sh` — delegates to Dev build/install/launch script
- `docs/permissions.md`, `docs/development.md`

## Limitations

- `unknown` FDA remains limited until user grants FDA and probe returns `.granted`.
- Release bundle ID unchanged; FDA must be granted separately for production builds.
- Debug build fails without valid `JOEYPET_DEVELOPMENT_TEAM` and Apple Development identity on the machine.
- In-place Dev install merges with an existing `JoeyPet Dev.app`; stale files inside the bundle are not explicitly pruned (no `rm -rf`).
- Automated verification in this pass: `xcodebuild test` passed with 114 tests; Dev build script and manual FDA persistence/prompt checks were not run because this machine has no Apple Development identity or Team ID.
