# P08b — Template variety within a job origin (deterministic hash pick)

**Date:** 2026-07-06 · **Author:** Claude (control tower) · **Executor:** Fable subagent · **Gate:** Claude
**Brief:** §7.5 (systemic job generation) · **Predecessor:** P08 (shipped). The P08b contract is already
declared in `job_generator.gd:7` — "template variety within an origin is P08b, as a deterministic hash —
still not randomness." This slice delivers exactly that, nothing more.

---

## The one thing this proves

> A single job origin can surface **more than one authored variant**, chosen by a **deterministic hash of
> the id-encoded targeting** — so the same trigger on the same sim state still rebuilds the byte-identical
> job on save/load, and the variety adds replay texture without a single RNG call.

Today each origin has exactly one template (retaliation → `JobTemplates.retaliation()`, bury_case → one
builder, etc.), so a repeated trigger always reads the identical text. P08b gives the two most-repeated
origins a **second variant each**, picked by the same splitmix64 avalanche hash P07b proved (String.hash
alone has near-zero avalanche — a +1 input barely moves the bucket, so it fails to spread).

---

## Scope (cut hard — two origins, one extra variant each)

- **RIVAL_PROVOCATION** (`retaliation`): add ONE sibling variant (a second "answer in kind" framing).
- **EVIDENCE_CHAIN** (`bury_case`): add ONE sibling variant (a second "bury the case" framing).
- **NOT touched:** `followup` and `intercepted_shipment` stay single-variant (scope discipline — two
  origins prove the mechanism; more is P16 authored-roster work).

Each origin therefore has a **variant set of size 2**, indexed 0/1, selected by a deterministic hash. The
variant text must be genuinely distinct (different apparent_problem / choices' flavour) but **mechanically
parallel** — same outcome-axis shape so balance invariants hold for BOTH variants (see below).

---

## Hard invariants (the gate checks these)

1. **Byte-identical rebuild.** Variant selection is a pure function of ONLY the id-encoded inputs. For
   `retaliation` the id is `gen@retaliation@<venue>@<rival>@<tick>`; the variant index MUST derive from
   those (e.g. `venue.id` + `tick`, or `rival.id` + `tick`) and NOTHING else (no live sim read, no counter,
   no external state). `rebuild()` re-runs the same builder with the same parsed inputs → recomputes the
   same index → same variant. **No new id segment is added** (the existing id already carries every input
   the hash needs; adding one would be a save-schema change — don't).
2. **Zero RNG.** No `randf`/`randi`/`randomize`/`RandomNumberGenerator`. The variant pick is
   `JobGenerator`'s own splitmix64-style avalanche of the id-encoded string, mod 2 (or mod variant-count).
   Copy the proven `_avalanche` from `rival_scoring.gd:74-77` (or factor a shared helper — see below).
   The existing `test_job_generation` source scan must stay green.
3. **Balance invariants hold for EVERY variant.** P06d guards (`test_evidence`): the retaliation origin's
   loudest route nets ≥ +0.25 evidence and its quietest ≤ -0.3. BOTH retaliation variants must satisfy
   this — the new variant is authored to the same envelope. Same discipline for any bury_case balance the
   tests assert. If a test reads a specific choice id (e.g. `appr_mirror`), the variant that test exercises
   must still produce it, OR the test is generalized to "the loudest approach of whichever variant" — check
   `test_evidence` first and keep it meaningful, don't just make it pass.
4. **Save-additive / no schema change.** `SAVE_VERSION` stays 1. No new persisted field. No new id segment.
   The variant is recomputed at rebuild time from the existing id — never stored.
5. **Same targeting contract.** The variant only changes AUTHORED content (text + choices). Sim-derived
   targeting (venue_id, involved ids, reward stamping) is applied by `JobGenerator` exactly as today,
   identically for both variants.

---

## Where the hash lives (avoid duplication cleanly)

`rival_scoring.gd` already has `_avalanche(x: int) -> int` (splitmix64 finalizer, proven in P07b). Two
options — Fable picks the cleaner, but state the reasoning:
- **(A)** Add a small `static func _variant_index(seed_str: String, count: int) -> int` to `JobGenerator`
  with its OWN private `_avalanche` copy. Pro: JobGenerator stays self-contained (it's a pure RefCounted
  like RivalScoring). Con: the avalanche constants exist in two files.
- **(B)** Factor `_avalanche` into a shared pure helper (e.g. a `Hashing` RefCounted in `src/core/`) that
  both RivalScoring and JobGenerator call. Pro: one source of truth. Con: touches P07b's proven file.

**Recommendation: (A).** P07b is shipped and gated; do not reopen `rival_scoring.gd` for a refactor (minimal
footprint, don't destabilize a green file). Three lines of avalanche duplicated is cheaper than a
cross-file refactor of proven code — this is the "three similar lines beats a premature abstraction" call.
The duplication is a deliberate, documented choice, not an oversight — comment it as such.

---

## The variant builders

Refactor each targeted origin's builder to dispatch on a variant index:
- `retaliation(venue_name, rival_name, variant: int)` → variant 0 = the existing "Answer in Kind"; variant
  1 = a new sibling (e.g. "The Message" — a colder, more calculated reprisal framing) with a parallel
  prep/approach/coverup shape and the same balance envelope.
- `bury_case(case_label, district_name, variant: int)` → variant 0 = existing "Bury the Case"; variant 1 =
  a new sibling (e.g. "Break the Chain" — targeting the case's people rather than the paper) parallel shape.

`JobGenerator.retaliation_job` / `bury_case_job` compute the index via the avalanche of the id-encoded
inputs and pass it to the builder. `rebuild()` recomputes the identical index from the parsed id and passes
it to the SAME builder → identical job.

The new variants must be genuinely different reading experiences (distinct title, apparent_problem, choice
flavour) — otherwise variety is cosmetic and the slice isn't worth it. But mechanically parallel so tests
and balance hold uniformly.

---

## Files

### Modified
- `src/jobs/job_templates.gd` — `retaliation` + `bury_case` take a `variant: int`; add the two new sibling
  builders' content (inline branch or a small per-variant helper, whichever reads cleaner).
- `src/jobs/job_generator.gd` — `retaliation_job` + `bury_case_job` compute the variant index from the
  id-encoded inputs and pass it through; `rebuild()` recomputes the same index. Add the private
  `_variant_index` + `_avalanche` (option A).

### New
- `tests/unit/test_job_variety_p08b.gd` + `.tscn` + `.uid` — the gate test (run via `.tscn`).

### NOT touched
- `save_codec.gd` (no schema change), `project.godot`, any P07b file, the other two origins.

---

## The GATE test (test_job_variety_p08b.gd) — Claude re-runs this

Run via `.tscn`. Exit 0 only if all pass. Assertions:

1. **`_test_variant_is_deterministic`**: same (venue, rival, tick) → `retaliation_job` twice → identical
   variant (same title/apparent_problem). No drift.
2. **`_test_rebuild_matches_generate`**: generate a job, take its id, `rebuild()` it → the rebuilt job's
   authored content (title, apparent_problem, choice ids) is byte-identical to the originally generated
   job. THE core P02 contract — do this for a case that lands on variant 0 AND a case that lands on
   variant 1 (pick venue/tick inputs that hash to each; if you can't find both, that's a red flag the hash
   doesn't spread — investigate, don't fudge).
3. **`_test_both_variants_reachable`**: across a spread of tick/venue inputs, BOTH variant 0 and variant 1
   are produced (the hash actually splits — not frozen to one variant like the pre-fix P07b jitter was).
   Assert count(v0) > 0 AND count(v1) > 0 over e.g. 32 inputs.
4. **`_test_variety_balance_invariant`**: for BOTH retaliation variants, the loudest approach nets ≥ +0.25
   evidence and the quietest ≤ -0.3 (P06d envelope). Proves the new variant didn't break the balance
   contract `test_evidence` guards.
5. **`_test_no_rng_in_job_sources`**: source-scan `job_generator.gd` + `job_templates.gd` for
   `randf`/`randi`/`randomize`/`RandomNumberGenerator` → none.

Also run the EXISTING suites that touch this area and assert no regression:
`test_job_generation`, `test_evidence`, `test_job_lifecycle`.

---

## Out of scope (do not add)

- Variants for `followup` / `intercepted_shipment` (single-variant stays).
- More than 2 variants per origin.
- Any new id segment or persisted field.
- Reopening/refactoring `rival_scoring.gd` (duplicate the 3-line avalanche instead — documented).
- Data-driven job resources (that's P16).

---

## Verify (Claude's gate — I re-run all of it; green-by-claim is not green)

```sh
GODOT="D:/Godot/Godot_v4.7-stable_win64_console.exe"
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . tests/unit/test_job_variety_p08b.tscn        # new gate (exit 0)
"$GODOT" --headless --path . tests/unit/test_job_generation.tscn          # no regression
"$GODOT" --headless --path . tests/unit/test_evidence.tscn                # P06d balance intact
"$GODOT" --headless --path . tests/unit/test_job_lifecycle.gd             # (-s ok: no autoload dep — verify this is still true)
"$GODOT" --headless --path . --quit-after 120 2>&1 | grep -iE "SCRIPT ERROR|ERROR:|Nonexistent"
grep -rnE "randf|randi|randomize|RandomNumberGenerator" src/jobs/
```

Plus I READ both modified files: confirm the variant index derives ONLY from id-encoded inputs (the
byte-identical-rebuild proof), the avalanche duplication is deliberate + commented, and the new variants are
genuinely distinct reading experiences (not cosmetic reskins). I also confirm `rebuild()`'s index math is
identical to `*_job()`'s (a divergence there is the classic save/load-desync bug — check it by eye, not
just by the test).
