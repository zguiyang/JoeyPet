# Project Structure

Current layout and suggested growth. **Do not create empty placeholder directories** until a phase needs them.

## Current (Phase 0)

```
JoeyPet/
├── AGENTS.md
├── README.md
├── README.zh-CN.md
├── JoeyPet.xcodeproj/
├── .agents/
│   └── skills/
│       └── joeypet-macos/
│           ├── SKILL.md
│           └── references/
├── docs/
│   ├── product.md
│   ├── architecture.md
│   ├── domain-model.md
│   ├── pet-runtime.md
│   ├── system-sensors.md
│   ├── safety.md
│   ├── tech-stack.md
│   ├── project-structure.md
│   ├── development.md
│   ├── roadmap.md
│   └── decisions/
├── src/
│   └── JoeyPet/
│       ├── JoeyPetApp.swift
│       ├── ContentView.swift
│       └── Assets.xcassets/
└── tests/
    └── JoeyPetTests/
        └── JoeyPetTests.swift
```

## Suggested future layout (implement when needed)

```
src/JoeyPet/
├── App/                 # App entry, lifecycle
├── UI/                  # SwiftUI views, NSPanel wiring
├── Pet/
│   ├── Runtime/         # State machine, clip selection
│   ├── Sprite/          # SpriteKit scene, nodes
│   └── Assets/          # Sprite atlases (may stay in Assets.xcassets early on)
├── System/
│   └── Sensors/         # Thermal, memory, storage, idle/active
├── Domain/              # SystemSignal, PetState, rules (pure Swift)
├── Behavior/            # BehaviorEngine, mappings
└── Utilities/           # Approved cleanup / organize actions
```

SPM packages (e.g. `JoeyPetCore`) may be extracted later if the app target grows; not required in Phase 0.

## Conventions

- Production code under `src/JoeyPet/`.
- Tests mirror module names under `tests/JoeyPetTests/`.
- Product and design docs under `docs/`.
- Agent skill under `.agents/skills/joeypet-macos/`.

## Related docs

- [development.md](development.md)
- [architecture.md](architecture.md)
