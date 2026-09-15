# Pet Runtime — Agent Quick Reference

Full doc: [docs/pet-runtime.md](../../../../docs/pet-runtime.md).

## Every behavior rule should specify

| Field | Question to answer |
|-------|-------------------|
| Priority | Can this preempt idle/low states? |
| Cooldown | Min seconds before re-trigger |
| Hysteresis | Enter threshold vs exit threshold |
| Minimum duration | Min time state stays active |
| Interruption | Can a higher priority cut this short? |
| Fallback | State when signals clear (usually `idle`) |

## Anti-flicker

- Do not change `PetState` on every poll if severity unchanged
- Runtime rejects transitions that violate minimum duration unless interruption allows
- Same state → keep current clip playing; do not restart from frame 0

## Testing snippet (concept)

Given: `[signal events + timestamps]`
Expect: `[PetState sequence]` and `[AnimationClip ids]`

## Out of scope

Behavior Trees, ML clip picker, sensor → scene shortcuts
