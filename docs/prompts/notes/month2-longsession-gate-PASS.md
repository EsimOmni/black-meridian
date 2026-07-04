# Month-2 long-session gate — PASS (both policies, full cycle, no dead stretch)

**Ran:** 2026-07-05 · full 1800-tick Night Cycle (30 min, all 4 phases) auto-played through the real
settle + job-resolution path, both deterministic policies, re-run end to end by the control tower.
Supersedes the earlier FAIL (`month2-longsession-gate.md`), which P06d closed
(`P06d-evidence-bootstrap-accept.md`). This is the clean full-gate pass that lifts the P12 asset hold.

## Verdict: LOOP ALIVE under both policies — the two lines produce two different games

| Metric | CLEAN (min trace, lever @0.60) | AGGRESSIVE (max trace, lazy lever) |
|---|---|---|
| Verdict | LOOP ALIVE | LOOP ALIVE + EVIDENCE BOOTSTRAPS FROM THE FEUD |
| **Pressure plateau (dead-stretch)** | 3/15 (acceptable) | **0/15** |
| Jobs offered/resolved | 36/36 | 42/42 |
| Phase transitions | 4 clean (cycle → 2) | 4 clean (cycle → 2) |
| Evidence cases end/peak | 0/0 (deliberately clean) | 3/4 |
| Inspections | 1 (pure heat) | 6 (5 case-driven recurrence) |
| Central peak / alert | 0.42 / NO | **0.886 / YES (fired ~6×)** |
| EVIDENCE_CHAIN (bury) jobs | 0 | 5 |
| Grudge (feud) | 0 (clean never provokes) | oscillates 0 ↔ 0.20 |
| Dirty cash end | $246k (stayed clean, ran rich) | **$2.5k** (pressure bit it flat) |

## Why the pass is real (read the aggressive timeline, not just the summary)

The aggressive run is a **sawtooth, not a flat line** — the signature of a live pressure loop:

```
t480  combined 0.612  central 0.681  ALERT ON   dirty $70k->$3k   (pressure bites the wallet)
t600  combined 0.318  central 0.214  alert off                    (player burned the cases down)
t720  combined 0.765  central 0.689  ALERT ON   grudge 0.15       (feud climbs alongside)
t1320 combined 0.939  central 0.886  ALERT ON   grudge 0.20       (CRISIS phase peaks the ceiling)
t1440 combined 0.395  central 0.464  alert off                    (the wave passes)
```

Pressure accrues → hits the bar → alert + inspection + dirty-cash reset → player defuses → falls →
climbs again. Six inspections, central over the bar ~6×, bury jobs spawning from real play, grudge
oscillating with the feud. **No phase goes dead; plateau 0/15.**

The CLEAN run's 3/15 plateau is not a fault — it is the intended shape of playing optimally clean:
the player generates no trace, so the police line *correctly* stays quiet and the run is a rich, calm
economy game. The fork is the point: clean = quiet/rich/soft-in-the-feud; aggressive = loud/broke/
strong-in-the-street. Both keep the pipeline flowing and the phase machine clean.

## Standing flags (noted, NOT blocking the gate — tuning, not dead loop)

1. **Runaway economy is now conditional, not unconditional** — clean ends ~$1.12M, aggressive ~$593k
   (pressure now bites the economy). Still a candidate for a separate balance slice; not this gate's
   concern.
2. **Rival-provocation dominance** (36/42 jobs) may be a single-district-seed artifact (one district,
   one rival, grudge climbs fast, sabotage cap 3). Noted for a possible multi-district reseed check;
   separate slice, does not block.

## Decision: the Month-2 gate is PASSED — asset production (P12) is UNBLOCKED

Brief §12 satisfied: the full 25–30 min Night Cycle is proven to work with cubes and placeholder art,
under both play styles, with the full pressure architecture (rival feud P07c + police line
P06→P06b→P06c→P06d) reachable and self-feeding in real play. Asset production may begin under the
existing discipline (proxy first, Sketchfab license-gated, no GLB replaces a validated mechanic, AI
90 / human 10). The two standing flags are balance/tuning follow-ups, not gates.
