# P18 — Cinematic integration: the persistence loop (Month 4 gate)

**Month:** 4 (gate) · **Brief:** §14.2 (runtime sequence), §19 Month 4 gate

## The gate

> The splat sequence must **change persistent strategic state** and **survive save/load** before and
> after entry. A visually attractive but non-persistent scene does NOT pass.

## Why

The cinematic only earns its cost if its choices ripple back into the management sim. This slice wires the
full round-trip.

## Scope

Implement the runtime sequence (brief §14.2):

1. **Trigger conditions** (brief §7.7): chapter threshold / Aiko personally intervenes in a major job /
   a loyalty state crosses a permanent boundary / boss confrontation / critical evidence scene.
2. **Enter**: pause strategic sim → save a transition checkpoint → unload/hide the city scene → load the
   isolated `CinematicWorld` (P17) → apply scene LUT + character lighting → limit player to the validated
   camera volume.
3. **Resolve**: interactions → **write narrative consequences into GameState** → unload the splat world →
   restore the city → resume the sim.
4. **Persistence**: the consequences must be real (cash/control/evidence/loyalty/narrative state) and must
   survive save/load both before AND after the cinematic (uses P02).

## Verify

- Integration test: trigger → enter → resolve → assert a persistent GameState change; save before entry,
  load, re-enter, resolve, save after, load → state consistent throughout. **This is the gate.**
- Manual: the slice's one cinematic fires from its trigger, its choice changes the management state, and a
  load mid-sequence restores cleanly.
