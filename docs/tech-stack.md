# Tech Stack

Fixed direction for JoeyPet V0. Deviations require a new ADR and explicit approval.

## Core

| Area | Choice |
|------|--------|
| Language | Swift |
| UI shell | SwiftUI + AppKit (e.g. `NSPanel`, menu extras as needed) |
| Pet rendering | SpriteKit (layered HD PNG atlas driven by `joey_manifest.json`, ADR 013) |
| Concurrency | Swift Concurrency (`async`/`await`, actors where appropriate) |
| Frameworks | Apple first: Foundation, Combine only if needed |
| Persistence | UserDefaults, `@AppStorage` |
| Logging | OSLog / `Logger` |
| Package manager | Swift Package Manager (SPM) |
| Tests | Swift Testing (preferred over XCTest for new tests) |
| Project | Xcode project (`macos/JoeyPet.xcodeproj`) |

## V0 dependency policy

**Runtime third-party dependencies: 0.**

No CocoaPods, Carthage, or bundled non-Apple libraries in the shipping app.

## Explicitly excluded

Do not introduce:

- Electron, Tauri, KMP, Avalonia
- Live2D, 3D engines, Unity
- Database (SQLite, Core Data for V0 product data, etc.)
- LLM runtime, LangChain, AI SDK
- Redux, TCA, heavy Clean Architecture templates
- Third-party DI containers
- Third-party UI design systems
- CocoaPods, Tuist, XcodeGen

## Rationale pointers

- [decisions/007-configurable-sprite-asset-package.md](decisions/007-configurable-sprite-asset-package.md)
- [decisions/008-pixel-perfect-display-scaling.md](decisions/008-pixel-perfect-display-scaling.md)

## Related docs

- [V0_FEATURE_SCOPE.md](../V0_FEATURE_SCOPE.md)
- [DESIGN.md](../DESIGN.md)
- [development.md](development.md)
- [pet-runtime.md](pet-runtime.md)
