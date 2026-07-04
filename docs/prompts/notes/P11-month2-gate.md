# Month-2 gate re-confirmation (P11-B): cycle integrity

**Gate (brief §12/§19):** a full Night Cycle must be a coherent, compelling episode — the green light
for Month-3 asset production. Recorded 2026-07-04.

## Decision: PROCEED to Month 3

The Month-2 feel gate passed earlier (short session, commit `f700fe6`: "fun, stress, very good"). That
verdict predated P09 (phases) and P10 (betrayal). Cem is not replaying, so the re-confirmation for the
*full* systemic cycle is **mechanical, not a play verdict** — Claude drove a complete Night Cycle
(1800 ticks) with every system live and instrumented each link of the chain.

## Cycle-integrity probe — the chain is INTACT and self-feeding

An independent probe ran one full Night Cycle on the real WorldSeed world (economy, heat, rival AI,
job generation, phase machine all active) and asserted every link fired AND that systems feed each
other, not run as independent meters:

```
money → overflow          : YES   (WorldSeed's +257/tick squeeze)
overflow → heat rose       : YES
heat → inspection fired    : YES   (latched threshold beat)
rival telegraphed          : YES (33)
rival landed (sabotage)    : YES (33)   — telegraph count == land count
gen@ job offered FROM sim  : YES (49)   — rival sabotage spawns jobs; the loop refeeds
phases advanced            : OPERATIONS → CRISIS → RECKONING → COUNCIL (full cycle + rollover)
=== FULL CHAIN money→heat→inspection→rival→job→phases: INTACT ===
```

The decisive result is the **coupling**: rival sabotage generates jobs (49 systemic `gen@` jobs
offered across the cycle), heat drives inspection which weakens venues that the rival then reads as
targets. This is an episode of interacting systems, not a dashboard of separate numbers — exactly what
brief §5.2 asks ("a complete dramatic episode occurred").

Loyalty/betrayal (P10) was independently verified separately (preventability probe: both-gates rule,
reassure defuses, deterministic land) — its telegraph fires from the same rival-tick spine, gated by
Council like the rival, so it composes into the same cycle.

## A probe-methodology lesson (recorded to lessons.md)

First two probe passes reported the chain "broken" — a **measurement artifact, not a sim bug**: the
probe spawned a *second* `RivalDirector` while it is a project autoload, so two directors raced the
per-faction intent state (one telegraphed, the other landed) and the job-offer listener was bound to
the wrong instance. Connecting to the `RivalDirector` autoload singleton (the real wiring) showed the
chain intact. Lesson: when probing, use the actual autoload singletons; never instantiate a second
copy of an autoload node.

## Verify state at gate

- P11-A theme: presentation-only, commit `bfb2596`; full suite (9 unit + 2 integration) + boot green,
  independently re-run after the theme — zero regression, no `src/` sim/save touch.
- All Month-2 systems (P05–P10) independently probed green across prior slices.

## Green light: Month 3 (asset production) may begin

Per brief §12, a passing Month-2 gate authorizes asset work — under the existing discipline: proxy
first, Sketchfab license-gated, no GLB replaces a validated mechanic, AI 90 / human 10.
