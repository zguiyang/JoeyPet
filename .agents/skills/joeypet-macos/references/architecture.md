# Architecture — Agent Quick Reference

Use before wiring new code. Full doc: [docs/architecture.md](../../../../docs/architecture.md).

## Allowed flow

```
Sensor → SystemSignal → BehaviorEngine → PetState → PetRuntime → AnimationClip → SpriteKit
```

## Checklist

- [ ] Sensor module has no SpriteKit import
- [ ] No `@Published` sensor metric bound directly to `SKScene`
- [ ] Pet states named for character (`tired`), not metrics (`memoryHigh`)
- [ ] Utilities live outside sensor and runtime layers
- [ ] Preferences via UserDefaults / `@AppStorage` only (V1)

## UI concepts (no algorithm in V1)

- Ambient UI — pet on desktop, minimal chrome
- Quiet / non-intrusive — defer low-priority prompts
- Attention budget — limit how often the pet interrupts

## ADRs to respect

001 macOS-only · 002 native Swift · 003 2D SpriteKit · 004 no DB · 005 read-only sensors · 006 no LLM
