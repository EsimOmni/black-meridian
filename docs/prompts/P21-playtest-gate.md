# P21 — Playtest gate (Month 5 gate)

**Month:** 5 (gate) · **Brief:** §19 Month 5 gate

## The gate

> Three external players must complete the slice **without developer instruction** and correctly explain:
> - how money is cleaned;
> - why heat increased;
> - why the rival acted;
> - why the loyalty crisis occurred.

This validates that the systems are *legible* — the whole "problem architect" fantasy depends on the
player understanding cause→effect.

## Scope

1. Prepare a clean playtest build (no dev hints, autosave + manual save working).
2. Run 3 external playtests. Observe silently; do not coach.
3. After each, ask the four questions above. Record answers verbatim.
4. **Triage failures by cause**: if players can't explain a system, the fix is usually *telegraphing /
   UI legibility*, not adding mechanics. Apply targeted legibility fixes, re-test.

## Verify

- `docs/prompts/notes/P21-playtest.md`: 3 players, their answers to the 4 questions, pass/fail per
  player, and the fixes applied. **Gate passes only when the explanations are correct unaided.**
