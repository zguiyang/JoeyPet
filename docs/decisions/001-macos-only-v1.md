# ADR 001: macOS-Only V1

## Status

Accepted

## Context

JoeyPet is a desktop pet tied to macOS system APIs (thermal state, memory pressure, workspace idle, volume capacity). Shipping on multiple platforms would dilute focus and duplicate sensor layers.

## Decision

V1 targets **macOS only**. No Windows, Linux, iOS, or web client in V1.

## Consequences

- Use AppKit, SpriteKit, and Apple-specific APIs without abstraction layers for other OSes.
- Documentation and agent rules assume macOS paths and conventions.
- Cross-platform requests deferred until a future ADR explicitly revisits platform scope.
