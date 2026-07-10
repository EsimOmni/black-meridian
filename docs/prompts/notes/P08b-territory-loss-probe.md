# P08b territory-loss — full-cycle probe

**Date:** 2026-07-10 · **Verdict: TERRITORY LOSS CLOSES.**

The territory-loss origin ("Contested Ground") is wired end to end and self-feeding. Proven by
`tests/unit/test_territory_cycle_p08b.tscn` (ticks the real TimeService/RivalDirector/JobDirector
against the real WorldSeed — no hand-mocking):

1. **Seed ships neutral bait.** `gw_saltworks` seeds neutral (`owner_faction == &""`, CONTESTED).
2. **Rival takes it.** After ~60 strategic ticks the rival telegraphs + lands an EXPAND on the
   neutral lot → `owner_faction == &"corvine"`, INFLUENCED.
3. **A job is offered.** JobDirector's EXPAND arm fires → a `TERRITORY_LOSS` "Contested Ground" job
   (`gen@contested@gw_saltworks@corvine@<tick>`) lands in `active_jobs`.
4. **Resolving it reclaims the ground.** With `objective_achieved >= 0.5` the reclaim branch returns
   the venue to the player as CONTESTED — disputed, not fully controlled, so the loop stays alive.

## Game-feel check (separate probe, run + discarded)

Concern: does the permanent neutral seed skew the rival to EXPAND forever? **No.** A hand-probe of
`RivalScoring.choose_move` showed: calm seed → EXPAND saltworks; **after saltworks is taken, calm →
WAIT** (the rival returns to waiting once free ground is gone); simmering district → FRAME returns;
reclaimed (player/CONTESTED) → PROBE. The neutral ground is **transient** — it drives the first-loop
inciting incident, then normal rival variety resumes. The bait is not a permanent priority skew.

## Two arms, one job

The same "Contested Ground" job is offered from two sources (both verified wired):
- **EXPAND arm** — rival takes neutral ground (this probe).
- **Betrayal arm** — a turncoat lieutenant hands a venue to the rival it was recruited to
  (`RelationshipService.betrayal_committed` → `_on_betrayal_committed`), covered by the P10 loyalty
  tests (now asserting owner → rival + INFLUENCED) plus the JobDirector betrayal subscription.

## Regression

Full unit suite green after the change (12 tests): economy, evidence, heat_consequence,
job_generation, job_variety_p08b, loyalty, loyalty_p10b, night_cycle, central_pressure, rival_ai,
rival_ai_p07b, territory_loss_p08b — plus save round-trip and boot smoke clean. The rival-AI tests
were updated to drop the seeded neutral bait in `_fresh_world` (they baseline a calm world with no
free ground); the game seed keeps the bait.
