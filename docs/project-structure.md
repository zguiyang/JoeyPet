# Project Structure

Current layout and suggested growth. **Do not create empty placeholder directories** until a phase needs them.

## Current (Phase 1.5)

```
JoeyPet/
├── AGENTS.md
├── JoeyPet.xcodeproj/
├── .agents/skills/joeypet-macos/
├── docs/
├── src/JoeyPet/
│   ├── App/                 # AppDelegate, PetCoordinator, debug/sleep-wake
│   ├── Domain/              # SystemSignal, PetState, PetManifest, AnimationClip, BehaviorEngine
│   ├── Pet/
│   │   ├── Runtime/         # PetRuntime, PetAssetLoader, state→animation mapping
│   │   └── Sprite/          # PetScene, CharacterNode, PetRootNode
│   ├── System/Sensors/      # Thermal, memory, storage (read-only)
│   ├── UI/                  # PetPanel, PetSpriteView
│   ├── Resources/
│   │   └── Pets/
│   │       └── JoeyRobot/   # pet.json + spritesheet.png (built-in package)
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
