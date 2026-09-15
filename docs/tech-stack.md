# Tech Stack

Fixed direction for JoeyPet V1. Deviations require a new ADR and explicit approval.

## Core

| Area | Choice |
|------|--------|
| Language | Swift |
| UI shell | SwiftUI + AppKit (e.g. `NSPanel`, menu extras as needed) |
| Pet rendering | SpriteKit (2D sprites) |
| Concurrency | Swift Concurrency (`async`/`await`, actors where appropriate) |
| Frameworks | Apple first: Foundation, Combine only if needed |
| Persistence | UserDefaults, `@AppStorage` |
| Logging | OSLog / `Logger` |
| Package manager | Swift Package Manager (SPM) |
| Tests | Swift Testing (preferred over XCTest for new tests) |
| Project | Xcode project (`JoeyPet.xcodeproj`) |

## V1 dependency policy

**Runtime third-party dependencies: 0.**

No CocoaPods, Carthage, or bundled non-Apple libraries in the shipping app.

## Explicitly excluded

Do not introduce:

- Electron, Tauri, KMP, Avalonia
- Live2D, 3D engines, Unity
- Database (SQLite, Core Data for V1 product data, etc.)
- LLM runtime, LangChain, AI SDK
- Redux, TCA, heavy Clean Architecture templates
- Third-party DI containers
- Third-party UI design systems
- CocoaPods, Tuist, XcodeGen

## Rationale pointers

- [decisions/002-native-swift-stack.md](decisions/002-native-swift-stack.md)
- [decisions/003-2d-sprite-runtime.md](decisions/003-2d-sprite-runtime.md)
- [decisions/004-no-database-in-v1.md](decisions/004-no-database-in-v1.md)
- [decisions/006-no-llm-runtime-in-v1.md](decisions/006-no-llm-runtime-in-v1.md)

## Related docs

- [architecture.md](architecture.md)
- [development.md](development.md)
