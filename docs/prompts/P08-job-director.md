# P08 — JobDirector: systemic fixer-job generation

**Month:** 2 · **Brief:** §7.5 (jobs generated from simulation state)

## Why

P03 built the four-stage job *lifecycle* with one authored job. P08 makes jobs **emerge from the sim** so
they're never disconnected side-missions (brief §7.5).

## Scope

Extend `JobDirector` to spawn jobs from current state:

1. **Job origins** (brief §7.5): failed racket, compromised operative, intercepted shipment, disloyal
   lieutenant, witness, missing payment, rival provocation, police investigation, political request,
   family scandal. Each origin maps to a sim condition that triggers it.
2. **Generation cadence**: during the Operations phase, surface 4–6 rackets/jobs (brief §5.2). Don't
   flood — respect pacing.
3. **Job durations** (brief §7.5): minor systemic 60–90s, major 2–4 min, story job (cinematic) 5–10 min.
4. **Multi-dimensional resolution** already exists (P03) — ensure systemic jobs feed results back:
   objective, evidence generated, collateral, injury, rival suspicion, public fear, relationship change,
   new leverage, delayed consequence. **A new problem often spawns from a resolution** (loop never empties).
5. Mix: 3 authored + 5 systemic jobs available across the slice (brief §12.1).

## Verify

- Unit test: a failed racket reliably spawns a job of the right origin; resolving a job can create a
  delayed-consequence follow-up job.
- Manual: playing the Operations phase produces a varied, sim-grounded job queue.
