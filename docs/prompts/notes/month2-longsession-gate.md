# Month-2 long-session gate — MECHANICAL FAIL (evidence chain never bootstraps)

**Ran:** 2026-07-04 · full 1800-tick Night Cycle (30 min, all 4 phases) auto-played through the real
settle + job-resolution path, two deterministic policies (clean vs aggressive), each re-run by the
control tower byte-identical. Probe: `tools/validation/full_cycle_probe*.tscn` (throwaway, uncommitted).

## Verdict: the loop is ALIVE but two subsystems are STILLBORN in real play

The pipeline is healthy — the rival feud (P07c) self-sustains 36–37 jobs across all four phases under
both policies, cash and grudge move, phases transition clean, cycle reaches 2. **Nothing is dead.**

But the police-pressure line we just built and gated (P06b evidence cases, P06c central alert) **never
fires in a normally-played session.** Confirmed by re-running both variants myself and reading the job
data by hand:

| | CLEAN | AGGRESSIVE |
|---|---|---|
| Verdict | LOOP ALIVE (pipeline) | LOOP FLAT (pressure froze 8/15) |
| Jobs offered/resolved | 36/36 | 37/37 |
| **Evidence cases end / peak** | **0 / 0** | **0 / 0** |
| Net evidence (Σ resolved) | −11.0 | −0.1 |
| Peak central pressure | 0.42 (bar 0.60) | 0.45 (bar 0.60) |
| Central alert fired | NO | NO |
| Inspections fired | 1 (pure heat, ~t360) | 1 |
| Job origin mix | RIVAL_PROVOCATION 34 / FAILED_RACKET 2 | 36 / 1 |

## Root cause (verified in `job_templates.gd`, not inferred)

**No rational job resolution produces net-positive `evidence_generated`, so the first case never forms.**

1. The pipeline is ~95% **RIVAL_PROVOCATION** (retaliation) jobs — the P07c feud loop feeding itself.
   Those resolve **evidence-neutral** (net ~0.0 even at max-trace).
2. Every approach's positive evidence (`appr_force` +0.2, `appr_snatch` +0.2, `appr_quiet` +0.1) is
   paired in the same job with a **mandatory cover-up stage, all of which are negative** (−0.1 to
   −0.5). A full lifecycle = approach + cover-up, so the best achievable net for a trace-generating
   job is ≤ 0 (intercepted_shipment tops out at −0.1). The aggressive picker takes argMAX on both
   stages and *still* can't clear zero — this is a property of the authored data, not the probe.
3. The only positive-leaning origin, **FAILED_RACKET**, barely spawns (1–2 per cycle: the seed + a
   rare followup) and its +0.2 is cancelled by its own cover-up.

No positive evidence → no case ever deposits → `combined_pressure == raw heat` always → the inspection
latch fires once on pure heat, finds no case to bury, offers no EVIDENCE_CHAIN job → the whole P06b→P06c
chain has nothing to stand on. Central peaks at ~0.45, never reaches the 0.60 alert bar.

**The unit tests and acceptance probes passed because they inject the first case manually**
(`EvidenceMath.deposit(...)` / hand-built outcomes). The *real job flow* never does. Green tests, dead
subsystem in play — exactly the gap a long-session gate exists to catch.

## Decision: DO NOT enter asset production (P12) yet

Brief §12: no asset production until the full Night Cycle is proven to work with cubes. It works as a
*feud loop*, but the police-pressure half we spent three slices on is unreachable. Assets on top of a
stillborn subsystem is the §12 failure mode. Fix the bootstrap first.

## The fix (a P06d-shaped slice, spec next)

Give the evidence chain a way to bootstrap from the dominant flow. Options (pick in spec):
- **A botch/exposure path with teeth** — some fraction of resolutions (a loud approach, a failed skill
  check, a specific origin) must net *positive* evidence so cases actually form. The signed axis
  already supports it; the authored data just never lands positive.
- **Retaliation jobs leave trace** — the feud (already the pipeline's spine) deposits a small positive
  evidence on some resolutions, so the police line is fed by the rival line instead of a separate
  origin that never spawns. Couples the two pressure systems (thematically right: a visible rival war
  draws police heat).
- **Rebalance FAILED_RACKET frequency** so the positive-evidence origin actually recurs.

Preference (control-tower lean): couple it to the feud — the retaliation loop is what's actually alive,
so route the evidence bootstrap through it rather than adding a new origin that shares FAILED_RACKET's
never-spawns problem. To be specified as a Fable slice, gated here.

## Secondary flags (noted, not blocking)

- **Runaway economy** — clean capital ends ~$1.1M/cycle. Possibly a balance bug, possibly expected for
  the squeezed slice; not investigated (out of scope for a health probe). Flag for a later balance pass.
- **Rival-provocation dominance may be a single-district-seed artifact** — one district, one rival,
  grudge climbs fast, sabotage cap 3 → steady +3 jobs/sample. A multi-district world might dilute it.
  The probe only runs the seeded slice; can't tell.
