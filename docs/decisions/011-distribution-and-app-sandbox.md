# ADR 011: Distribution and App Sandbox

## Status

Accepted for V0

## Context

JoeyPet V0 is a local-first desktop pet. It does not scan the filesystem,
monitor system metrics, clean files, or request Full Disk Access. Distribution
is direct during development and MVP use.

## Decision

- App Sandbox is disabled for the current direct-distribution build.
- JoeyPet operates with the current user's normal permissions.
- JoeyPet does not inspect user files or attempt to bypass macOS privacy controls.
- Distribution is assumed to be direct macOS distribution during development and MVP use.
- Any future filesystem or system-monitoring feature requires a new ADR and product approval.

## Consequences

- The V0 app needs no privacy onboarding or FDA flow.
- A future Mac App Store release would require the sandbox and distribution strategy to be reconsidered.
- Adding cleanup, sensors or broader filesystem access would require revisiting this decision.
