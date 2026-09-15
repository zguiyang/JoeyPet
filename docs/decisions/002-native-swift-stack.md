# ADR 002: Native Swift Stack

## Status

Accepted

## Context

JoeyPet must be lightweight, native, and privacy-friendly on the desktop. Web shells and cross-platform frameworks add memory overhead and weaken integration with macOS sensors.

## Decision

Build V1 with **Swift**, **SwiftUI**, **AppKit**, **SpriteKit**, **Swift Concurrency**, and Apple frameworks first. Use SPM and Xcode project; persist settings with UserDefaults / `@AppStorage`; log with OSLog / `Logger`; test with Swift Testing.

Do not use Electron, Tauri, KMP, Avalonia, CocoaPods, Tuist, or XcodeGen.

## Consequences

- Team must be comfortable with Apple platform releases and Xcode.
- Third-party UI and architecture frameworks (Redux, TCA, heavy Clean Architecture, third-party DI) are out of scope unless a new ADR approves them.
- **V1 runtime third-party dependencies remain 0.**
