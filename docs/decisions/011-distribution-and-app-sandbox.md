# ADR 011: Distribution and App Sandbox

## Status

Accepted for MVP

## Context

The Cleanup MVP needs access to explicitly supported paths under the current
user's Library. The current MVP does not request Full Disk Access and does not
use sudo.

## Decision

For the current MVP:

- App Sandbox is disabled.
- Cleanup remains limited to explicit allowlisted roots.
- JoeyPet operates with the current user's normal filesystem permissions.
- Permission failures are skipped or reported.
- JoeyPet does not attempt to bypass macOS privacy controls.
- Distribution is currently assumed to be direct macOS distribution during
  development and MVP use.

This decision does not authorize broader filesystem scanning.

## Consequences

- The MVP can inspect supported Library cleanup locations.
- A future Mac App Store release would require the sandbox and file-access
  strategy to be reconsidered.
