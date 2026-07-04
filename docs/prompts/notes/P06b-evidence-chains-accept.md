# P06b — Evidence chains (heat gets roots the player can attack): ACCEPTED

**Accepted:** 2026-07-04 · **Built by:** Fable 5 (commit `961371b`). **Gated by:** control tower
(this chat) — every check re-run here, not trusted from the report. Spec: `docs/prompts/P06b-evidence-chains.md`.

## What shipped

Heat stops being a flat timer and gains **discrete, persistent, attackable roots** (evidence cases).
The signed `evidence_generated` axis — which used to fold into `local_heat` and vanish — now also
drives cases: it accrues them on positive flow, erodes them on negative, and the inspection latch
reads *combined* pressure so standing cases keep the sweep coming after the heat flow stops.

- `src/core/evidence_case_data.gd` — new `EvidenceCaseData` Resource (id `case@<district>@<kind>@<tick>`,
  `kind: BM.EvidenceKind`, `weight` 0..1, `label`). `src/core/enums.gd` — `EvidenceKind`
  {MANIFEST,FOOTAGE,WITNESS,PHYSICAL} + `EVIDENCE_CHAIN` job origin. `src/core/district_data.gd` —
  `evidence_cases: Array[EvidenceCaseData]`.
- `src/simulation/evidence_math.gd` — pure statics (the `EconomyMath` discipline, headless-testable):
  positive flow spawns under the cap / grows the **oldest** past it (kind by `hash`, zero RNG); negative
  flow erodes the **strongest**; a zeroed case is removed. `case_pressure` = clamped Σ weights.
- `src/simulation/economy_service.gd` — inspection latch reads `heat + 0.5 * case_pressure`; re-arm
  mirrors on the same combined value. **Heat's own rise/decay untouched** (spec's "additive, never a
  replacement").
- `src/jobs/job_lifecycle.gd` — accrual (positive) + passive erosion (negative) in `apply_outcome`.
- `src/jobs/job_templates.gd` + `job_generator.gd` — the `bury_case` burn job (`gen@burycase@…`,
  `rehydrate` arm). Every clumsy route nets **positive** — a botched burn leaves more trace, case stands.
- `src/jobs/job_director.gd` — `_on_inspection_started` auto-offers a burn against the strongest case
  (P08 trigger style, through `_try_offer` dedupe/cap); resolve removes the **targeted** case parsed
  from the id (`_provocateur_of` discipline).
- `src/save/save_codec.gd` — cases encode/decode on the district; old saves load empty; burn ids rehydrate.

## The gap this closed

Heat's only levers were "pause the racket" and "wait the timer out." There was nothing *between* the
flow and the number to attack; `known_evidence` was cosmetic. Now: **find and destroy the things
pinning you.** Police-side parallel to P07c's rival feud — after P06b both external pressures (rival +
law) are things you actively fight, not numbers you endure.

## Gate — every check re-run here (not trusted from the report)

| Check | Result |
|---|---|
| `--import` | clean — no parse/compile errors |
| `test_evidence` | **[PASS]** — 7 spec assertions + botched-burn / bystander-case-survives bonus |
| Full prior suite (11 unit) | all **[PASS]** — incl. `test_heat_consequence` (latch touched, no regression) |
| Integration (2) | `save_roundtrip` **byte-for-byte** (cases survive) + `bootstrap_smoke` green |
| RNG source scan | `evidence_math.gd` — **0 occurrences** of randf/randi/randomize |
| Acceptance probe | **EVIDENCE CHAIN CLOSES** — re-run here, report reproduced |
| Boot smoke | no `SCRIPT ERROR`/`Nonexistent`/`Parse Error`; the lone RID leaked-at-exit line is the
  dummy-rasterizer `GeometryInstance` teardown from P14's real meshes — predates this slice (recorded
  in `tasks/lessons.md`), not evidence code |

## The loop, proven end to end (probe re-run by control tower)

```
two exposed jobs (+0.5 each):  1 case, case_pressure 1.00
tick: heat 0.3300 -> 0.3294 (DECAYING), combined 0.83 -> inspection fires
  ^ the whole point: raw heat below the old bar, standing case still pins the sweep
bury-the-case auto-offered on inspection_started
cover-up (-0.2): strongest 1.00 -> 0.80          (path A, passive erosion)
burn played (net -0.65): targeted case REMOVED    (path B, aimed strike)
after the sweep: combined 0.258 (bar 0.45) -> one fire, no second
verdict: EVIDENCE CHAIN CLOSES
```

Accrues → pins the sweep as heat decays → auto-offers the burn → passive erosion + aimed removal both
bite → pressure drops below the bar → the sweep lifts. Deterministic, telegraphed, zero rolls.

## Fable's first accepted slice

P06b is the first slice built on the **primary model** and gated by the control tower — the intended
division of labour (Claude specs + gates, Fable executes, Cem accepts). Fable held the spec exactly:
heat math untouched (additive), two destroy paths coexisting, save additive, zero RNG. No refusal,
no Opus fallback needed.

## Out of scope (held)

No cross-district evidence linking (single-district). No witness-flip / informant NPC (a case is a
weight + a label). No evidence HUD beyond the existing job surfacing (later polish). No change to how
heat rises/decays. No Central Pressure (P06c). No new rival/loyalty coupling.
