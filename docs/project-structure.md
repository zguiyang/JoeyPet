# Project Structure

Current layout and suggested growth. **Do not create empty placeholder directories** until a phase needs them.

## Current (Phase 5)

```
JoeyPet/
├── AGENTS.md
├── JoeyPet.xcodeproj/
├── .agents/skills/joeypet-macos/
├── docs/
├── src/JoeyPet/
│   ├── App/                 # AppDelegate, AppModel, PetCoordinator, lifecycle adapters
│   ├── Domain/              # Signals, pet state, cleanup and position models
│   ├── Pet/
│   │   ├── Runtime/         # PetRuntime, PetAssetLoader, state→animation mapping
│   │   └── Sprite/          # PetScene, CharacterNode, PetRootNode
│   ├── System/Sensors/      # Thermal, memory, storage (read-only)
│   ├── UI/                  # PetPanel, Main Window, Bubble, PetSpriteView
│   ├── Utilities/           # Cleanup scanner/executor and position store
│   ├── Resources/
│   │   └── Pets/
│   │       └── JoeyRobot/              # default built-in production package (32@4)
│   └── Assets.xcassets/
└── tests/JoeyPetTests/
```

## Suggested future layout (implement when needed)

```
src/JoeyPet/
├── Behavior/            # Extracted behavior rules if engine grows
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
