# P04 — Month 1 gate: a playable 15-minute greybox loop

**Month:** 1 (gate) · **Brief:** §19 Month 1 gate

## The gate

> A 15-minute greybox loop must be playable.

This slice integrates P00–P03 into a coherent, playable-for-15-minutes experience using cubes and
placeholder UI. No new systems — this is **integration, tuning and feel**.

## What "playable for 15 minutes" means here

Across ~15 minutes of real play (with pause + speed), the player should:
1. **Detect a change** — heat rises, a rival nudges a venue, or a fixer job appears (P03).
2. **Inspect context** — click a venue / open the job, read its state (HUD).
3. **Make one commitment** — assign staff / fund / pick a job approach / delay.
4. **Watch the city react** — the proxy reflects it (marker tint, heat readout, cash flow).
5. **Absorb the consequence** — state changes; a new problem can appear (not everything resolves).

## Scope

- Tune the economy + heat constants so 15 minutes has real tension (dirty cash should usually exceed
  safe laundering capacity — the brief's intended economic squeeze, §7.2).
- Make the placeholder fixer job (P03) appear during play and matter.
- Add a tiny "first decision within 3 minutes" onboarding nudge (brief §17.5 refund design starts here).
- Confirm save/load (P02) survives mid-loop.
- Confirm the splat/mesh provider decision (P01) is wired even if the cinematic isn't triggered yet.

## Verify

- A human can play ~15 minutes and hit all five loop beats without a script error.
- Headless smoke: run the bootstrap N ticks, assert cash/heat/job state evolve (integration test).
- Record a short note in `docs/prompts/notes/P04-month1-gate.md`: is it *interesting* yet? This is the
  honest read that decides whether Month 2 proceeds.
