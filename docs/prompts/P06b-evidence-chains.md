# P06b — Evidence chains (heat gets roots the player can attack)

**Runs on: Fable 5** (primary model — see `docs/FABLE.md`). Control tower (this chat) wrote this
spec + owns the gate; Fable executes; Cem accepts. **Month:** 2 (deferred slice) · **Brief:**
§7.3 (police pressure), §7.5 (consequences), §6 pillar 1 (problem architect — vs the *law* this time),
§7.6 (deterministic + telegraphed, no rolls). Depends on: P06 (heat + inspection beat), P08 (job
generation), the single-writer settle discipline.

## The gap this closes

Heat is a **flat number**. `evidence_generated` (a signed per-job axis) folds straight into
`district.local_heat` in `job_lifecycle.apply_outcome` (lines 80–81) and then vanishes — no persistent
trace. The inspection fires purely on the `local_heat >= HEAT_INSPECTION_THRESHOLD` latch
(`economy_service._update_district_heat`, line 138). So the player's only levers on police pressure are
"pause the racket" and "wait the timer out." There is nothing *between* the flow and the number to
attack. `job.known_evidence` (a `String[]`) is cosmetic flavour with no mechanical teeth.

P06b inserts a **discrete, persistent evidence layer**: heat gains *roots* (evidence cases) that pin
the inspection, and the player gets two ways to burn a case down. Heat stops being a timer and becomes a
puzzle — *find and destroy the things pinning you.* This is the police-side parallel to P07c's rival
feud: after P06b, both external pressures (rival + law) are things you actively fight, not numbers you
endure.

## The one rule (unchanged)

**Deterministic + telegraphed, zero RNG.** Cases accrue/erode by signed flow only; the inspection latch
becomes case-weight-driven but stays a pure threshold; the burn job is telegraphed like every other job.
No `randf`/`randi`/`randomize` anywhere in the new code — add the same source-scan guard the rival test
uses (`test_rival_ai._test_no_rng_in_ai_files`) over the new files.

## The model

### 1. EvidenceCase — a new persistent data type

`src/core/evidence_case_data.gd`, `class_name EvidenceCaseData extends Resource`. A discrete root of
police attention in a district:

- `id: StringName` — stable, generated: `case@<district>@<kind>@<tick>` (parseable, like job ids).
- `kind: BM.EvidenceKind` — a new enum (MANIFEST, FOOTAGE, WITNESS, PHYSICAL — 4 is enough; each just
  flavours the display name + which cover-up erodes it best; mechanics are weight-driven).
- `weight: float` 0..1 — how much this case pins the district. Sum of a district's case weights is the
  **case pressure**.
- `label: String` — human string (reuse the `known_evidence` phrasings so cases read like the flavour
  that already exists).
- Save-additive; see codec below.

Cases live on the district: add `@export var evidence_cases: Array[EvidenceCaseData] = []` to
`DistrictData`.

### 2. Accrual — the positive flow spawns/grows cases (single writer)

In `job_lifecycle.apply_outcome`, where `evidence_generated` currently only bumps heat: when
`evidence_generated > 0`, **also** deposit that weight into the district's case list. Pure rule, no roll:

- If the district has fewer than `MAX_CASES` (say 4) active cases, spawn a new `EvidenceCaseData` with
  `weight = evidence_generated` and a kind chosen deterministically (e.g. by `hash(job.id) % 4` — a
  hash, not RNG, same discipline as P07c variation).
- Else grow the **oldest** case's weight by `evidence_generated` (clamp 1). Bounded case count keeps it
  legible.
- `evidence_generated <= 0` does NOT spawn a case here — negatives are the *destroy* path (below). Heat
  still moves exactly as it does today (do not change the heat line — cases are additive to it, not a
  replacement).

### 3. The inspection reads case pressure (the roots pin the sweep)

`economy_service._update_district_heat`, the inspection latch (line 138). Today:
`inspection_armed and local_heat >= HEAT_INSPECTION_THRESHOLD`. Change the trigger to fire on the
**combined pressure** — heat OR case pressure crossing the bar:

- Define `case_pressure(district) = clampf(sum of case weights, 0, 1)` (a pure helper, put it on
  `DistrictData` or an `EvidenceMath` static class so it unit-tests headless like `EconomyMath`).
- Inspection arms when `local_heat + CASE_PRESSURE_WEIGHT * case_pressure >= HEAT_INSPECTION_THRESHOLD`
  (tune `CASE_PRESSURE_WEIGHT` so a couple of strong cases can trigger a sweep even as raw heat decays —
  that's the point: cases *persist* the threat after the heat flow stops). Keep it a pure latch, zero
  randomness. Re-arm logic mirrors: only re-arms when the *combined* pressure falls below `REARM`.
- This makes cases matter: you can cool `local_heat` by pausing rackets, but if 3 cases sit at high
  weight, the sweep still comes — you must burn the cases.

### 4. Destroy path A — passive erosion (cover-ups already produce negatives)

In the same `apply_outcome` spot: when `evidence_generated < 0` (cover-ups already emit these — see
`job_templates` coverup choices at -0.1..-0.5), erode the **strongest** (highest-weight) case by
`abs(evidence_generated)`; remove any case whose weight hits 0. This is the existing cover-up choices
gaining teeth — no new content. Heat still lowers as today (the signed line is unchanged); cases erode
*in addition*.

### 5. Destroy path B — the dedicated burn job ("Bury the Case")

A new generated job that targets ONE named case:

- `JobTemplates.bury_case(case_label, district_name) -> JobData`, `origin = BM.JobOrigin.EVIDENCE_CHAIN`
  (new enum value). Apparent problem/stakes phrased around the specific case. Its resolution outcome
  carries a strong negative `evidence_generated` (e.g. approaches at -0.4..-0.6) so a *successful* burn
  removes the targeted case; a botched one can even ADD (a clumsy cover-up leaves more trace — the
  signed axis already supports this).
- `JobGenerator.bury_case_job(case, district, tick)` with id `gen@burycase@<district>@<caseid>@<tick>`
  (parseable; `rehydrate` gains a `burycase` arm, mirroring `retaliation`/`followup`).
- **Trigger (JobDirector):** when `inspection_started` fires (the signal already exists,
  `economy_service.gd:7`) OR case_pressure crosses a telegraph bar, offer a `bury_case` job for the
  district's strongest case. Reuse `_try_offer` (dedupe + concurrency cap already there). This is P08
  trigger-style wiring — one new `_on_inspection_started` handler connected in `JobDirector._ready`.
- On resolve, the burn removes the specific targeted case (identify it from the job id, like
  `_provocateur_of` identifies the rival in P07c). Path A erodes the *strongest*; path B removes the
  *targeted* one — the two coexist (A is passive/ambient, B is the player's aimed strike).

### 6. Save

`save_codec.gd` — encode/decode `district.evidence_cases` (array of `{id, kind, weight, label}`), and
the new `EVIDENCE_CHAIN` job origin survives the existing job save path. All additive
(`.get(…, default)`), old saves load with empty case lists.

## Files (Fable's build list)

- `src/core/enums.gd` — add `enum EvidenceKind {MANIFEST, FOOTAGE, WITNESS, PHYSICAL}`; add
  `EVIDENCE_CHAIN` to `enum JobOrigin`.
- `src/core/evidence_case_data.gd` — new `EvidenceCaseData` Resource.
- `src/core/district_data.gd` — `evidence_cases: Array[EvidenceCaseData]`; a `case_pressure()` helper
  (or put the math in a new `src/simulation/evidence_math.gd` `class_name EvidenceMath` for headless
  unit-testing — preferred, matches `EconomyMath`).
- `src/jobs/job_lifecycle.gd` — accrual (positive) + passive erosion (negative) in `apply_outcome`.
- `src/simulation/economy_service.gd` — inspection latch reads combined heat + case pressure.
- `src/jobs/job_templates.gd` — `bury_case` template.
- `src/jobs/job_generator.gd` — `bury_case_job` + `rehydrate` arm.
- `src/jobs/job_director.gd` — `_on_inspection_started` trigger + case-targeted removal on burn resolve.
- `src/save/save_codec.gd` — persist cases + new origin.
- `tests/unit/test_evidence.gd` (+ `.tscn`) — the gate (below).

## Gates — Done when (control tower verifies each headless)

- `--import` clean; **new `test_evidence` green**; **full prior suite green** (12 existing tests — cases
  are additive; economy/heat/rival/loyalty/job/save must not regress).
- **RNG source scan** over the new files passes (zero `randf`/`randi`/`randomize`).
- **Save roundtrip green** — a district mid-case (2–3 cases at various weights) survives save/load; the
  new job origin rehydrates.
- Boot smoke clean.
- **Acceptance probe** (`tools/validation/evidence_probe.tscn`, throwaway like `feud_probe`): drive the
  loop and print it — a job deposits evidence → cases accrue → case_pressure pins an inspection *even as
  raw heat decays* → a cover-up erodes the strongest case → a "Bury the Case" job burns the targeted one
  → pressure drops below the bar → the sweep lifts. Verdict line `EVIDENCE CHAIN CLOSES` on success.

### test_evidence must assert

1. Positive `evidence_generated` spawns a case; a 2nd positive on a full list grows the oldest (bounded
   count).
2. `case_pressure` = clamped sum of weights; pure and deterministic (N identical calls, identical value).
3. The inspection fires on case pressure with raw heat *below* the old threshold (cases persist the
   threat) — and does NOT fire when combined pressure is below the bar.
4. Passive erosion: a negative outcome reduces the strongest case; a case at weight 0 is removed.
5. Active burn: resolving a `bury_case` job removes the *targeted* case (by id), not merely the strongest.
6. Save/load: cases survive; `EVIDENCE_CHAIN` origin rehydrates.
7. RNG source scan clean.

## Out of scope (P06b stays tight)

- No evidence *linking across districts* (single-district cases only — the slice ships one district).
- No witness-flip / informant subsystem (a case is a weight + a label, not an NPC). No evidence UI beyond
  reusing the existing job/known_evidence surfacing (a HUD case list is a later polish slice).
- No change to how heat itself rises/decays (cases are additive to the existing heat line, never a
  replacement — do not refactor the P06 heat math). No new rival/loyalty coupling. No Central Pressure
  (P06c). No Fable reasoning echoed into output (per `docs/FABLE.md` — hard refusal trigger).

## Handoff note to Fable

This is the same *shape* as the P07c win: an existing signed signal (`evidence_generated`) that today
only moves an aggregate number is made to act on **discrete, persistent, attackable state**. Build in
dependency order (enum → data type → math → accrual/erosion → inspection trigger → burn job → save →
tests → probe). Prove it end-to-end with the probe through the *real* settle/resolve paths, not
shortcuts (that's what caught the loop closing in P07c). Headless is the truth — `--import`, unit test
exit 0, boot smoke clean before you call it done. On any `stop_reason: "refusal"`, fall back to Opus for
that one call and continue.
