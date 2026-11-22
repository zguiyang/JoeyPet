# JoeyPet for macOS

Native Swift/AppKit/SpriteKit implementation of JoeyPet.

## Layout

```text
macos/
├── JoeyPet.xcodeproj/
├── JoeyPet/                 # App source, Assets.xcassets, Resources/Pets
├── JoeyPetTests/
└── scripts/                 # Dev build, icon and sprite asset tools
```

## Build

From the repository root:

```bash
xcodebuild -project macos/JoeyPet.xcodeproj -scheme JoeyPet -destination 'platform=macOS' build
```

## Test

```bash
xcodebuild -project macos/JoeyPet.xcodeproj -scheme JoeyPet -destination 'platform=macOS' test
```

## Debug Dev install

```bash
export JOEYPET_DEVELOPMENT_TEAM=YOUR_TEAM_ID
./macos/scripts/build_joeypet_dev.sh
```

This builds into `macos/.derived-data/joeypet-dev` and installs **JoeyPet Dev** into `~/Applications`.

## Related docs

- [V0 feature scope](../V0_FEATURE_SCOPE.md)
- [Design contract](../DESIGN.md)
- [Development workflow](../docs/development.md)
- [Pet runtime](../docs/pet-runtime.md)
