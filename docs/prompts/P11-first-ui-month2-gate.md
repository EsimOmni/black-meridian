# P11 — First-pass UI theme + Month 2 gate

**Month:** 2 (gate) · **Brief:** §19 Month 2 gate, §9.3 (2D allocation)

## The gate

> A complete 25–30 minute Night Cycle must be **fun with cubes and placeholder art.**
> If it is not compelling without final visuals, **do not enter asset production.**

This is the most important gate in the project. It decides whether Month 3 (expensive asset work)
begins at all.

## Scope

1. **First-pass UI theme** (still 2D/greybox-grade but coherent): operation cards, district overlay,
   character/relationship panel, job panel, phase indicator, economy/heat/pressure readouts. Readable at
   1080p and 1440p. This is the 2D layer the brief assigns to UI (§9.3) — NOT final art.
2. **Integrate everything** P05–P10 into one coherent Night Cycle: Council → Operations (rackets + jobs +
   rival + heat/evidence) → Crisis (the loyalty crisis) → Reckoning.
3. **Unit tests** for economy + rival scoring stay green (brief Month 2 deliverable).
4. **Tune for fun**: pacing, numbers, the economic squeeze, the legibility of cause→effect.

## The honest read

Write `docs/prompts/notes/P11-month2-gate.md`: Is the full Night Cycle *fun with cubes*? Can a player
explain why the rival acted and why the loyalty crisis happened? **If no — stop, fix the design, do not
start Month 3.** A passing gate is the green light for art production.

## Verify

- Integration test: a full 25–30 min Night Cycle completes headless with all systems interacting (not
  independent meters).
- 3 informal playtests (even self-playtests) of the cube build; record the verdict in the note.
