# P16 — NarrativeDirector + authored jobs + evidence chain + loyalty crisis

**Month:** 4 · **Brief:** §13.2 (NarrativeDirector), §12.1 (slice content), §7.6 (loyalty crisis)

## Why

Month 4 layers authored drama on top of the systemic engine. The slice needs a spine: 3 authored jobs,
a complete evidence chain, and the first loyalty crisis — all changing persistent state.

## Scope

1. **`NarrativeDirector`** (`src/narrative/narrative_director.gd`): evaluates narrative conditions after
   material state changes (brief §13.2 tick model) and fires authored beats. Data-driven via
   `data/narrative/` (typed Resources / JSON).
2. **3 authored fixer jobs** (brief §12.1): hand-written intake/stakes/branches, woven into the Glass
   Wharf situation (Compact vs Corvine). Each runs the four-stage lifecycle (P03) with authored content.
3. **One complete evidence chain** (P06) tied to a real incident in the slice — fully manipulable
   (remove link / redirect / discredit / frame).
4. **First loyalty crisis** (P10): the Bengal lieutenant's grievance crosses toward betrayal — telegraphed,
   preventable, causally understandable (a Month-2/5 acceptance criterion).
5. **5 systemic job templates** (P08) running alongside for texture.

## Verify

- Integration test: the authored chain of conditions fires the loyalty crisis only when its telegraphed
  pressure is met; the evidence chain resolves into a persistent state change.
- Manual: the 3 authored jobs play through with legible stakes and consequences.
