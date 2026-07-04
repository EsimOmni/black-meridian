# P06d — Evidence bootstrap (the feud feeds the police line)

**Runs on: Fable 5** (primary model — see `docs/FABLE.md`). Control tower (this chat) wrote this
spec + owns the gate; Fable executes; Cem accepts. **Month:** 2 (gate-fix slice) · **Brief:**
§7.3 (police pressure), §7.4 (rival war), §7.5 (consequences), §7.6 (deterministic + telegraphed).
Depends on: P06b (evidence cases), P06c (central pressure), P07c (rival feud), P08 (job generation).

## Why this slice exists (the long-session gate caught it)

The Month-2 long-session gate (`docs/prompts/notes/month2-longsession-gate.md`) auto-played a full
1800-tick Night Cycle through the real settle path under two policies. Finding: **the loop is alive
(the rival feud self-sustains 36 jobs across all phases) but P06b evidence cases and P06c central
alert NEVER fire in real play — 0 cases form, central never reaches the 0.60 bar, under either a clean
or an aggressive policy.**

Root cause, verified in `job_templates.gd` (not inferred):

- ~95% of the pipeline is **RIVAL_PROVOCATION** ("Answer in Kind") retaliation jobs — the P07c feud
  feeding itself. Their evidence ceiling is **net 0.0**: the loudest route is `appr_mirror` (+0.1)
  + `cover_flaunt` (−0.1) = 0.0; every other combination is negative.
- Every other origin's positive approach is cancelled by its mandatory cover-up, and the only
  positive-leaning origin (FAILED_RACKET) barely spawns (1–2 per cycle).

So **no rational resolution ever nets positive `evidence_generated`** → the first case never deposits
→ `combined_pressure == raw heat` forever → the whole P06b→P06c chain has nothing to stand on. The
unit tests/probes passed only because they inject the first case by hand (`EvidenceMath.deposit`); the
real job flow never does. Green tests, stillborn subsystem — exactly what a long-session gate is for.

## The fix: route the evidence bootstrap through the feud

The retaliation loop is what's actually alive, so **feed the police line from it** rather than adding
a new origin that shares FAILED_RACKET's never-spawns problem. This is thematically correct: a
*visible* rival war draws institutional heat — answer loud in the street and the inspectors notice;
answer quietly and you stay clean. It couples the two pressure systems (rival ↔ police) that P07c and
P06b/P06c built in parallel but never connected.

**The mechanic: make the retaliation job's LOUD routes net-positive on evidence, keep the QUIET
routes net-negative.** The player choice becomes a real fork — *hit back visibly and the case builds,
or answer quietly and stay clean but read as soft.* That is the "answer too loud and the city answers
back" line the job's own `visible_stakes` already promises (`job_templates.gd:89`) but the numbers
never delivered.

### 1. Rebalance the "Answer in Kind" retaliation template (the core change)

`src/jobs/job_templates.gd`, `retaliation(...)`. Adjust ONLY this template's evidence numbers so at
least one full **loud** lifecycle nets clearly positive and the **quiet** lifecycle stays negative.
Keep every other axis (objective_achieved, rival_suspicion, public_fear, relationship_change) exactly
as authored — this is an evidence-tuning pass, not a rewrite.

Target shape (tune to taste, but the invariants below are the gate):
- **Loud approach** (`appr_mirror` — the symmetric public hit): raise its `evidence_generated` so that
  paired with the loudest cover-up (`cover_flaunt`) the lifecycle nets **≥ +0.25** (currently 0.0).
  E.g. `appr_mirror` +0.3, `cover_flaunt` −0.05 → net +0.25. A visible reprisal leaves a trail.
- **Quiet approaches** (`appr_feed_inspectors`, `appr_absorb`) + suppressive cover-ups (`cover_deny`
  −0.3, `cover_broker` −0.2): keep the lifecycle **net-negative** so a careful answer still stays
  clean. Do not touch these unless needed to preserve the negative net.
- The prep_actions already trend negative (`prep_trace_crew` −0.1, `prep_stage_alibis` −0.2) — leave
  them; a player who preps hard can still claw back toward clean even after a loud hit. That is the
  intended tension (prep = the lever that trades effort for a smaller trail).

**Invariant the gate checks:** `argMAX(approach.evidence) + argMAX(coverup.evidence)` for the
retaliation template must be **≥ +0.25**; `argMIN(approach) + argMIN(coverup)` must stay **≤ −0.3**.
Loud builds a case, quiet burns it down — both reachable from the same job.

### 2. Confirm the accrual path already carries it (likely zero code)

`job_lifecycle.apply_outcome` (line 89–93) already deposits positive `evidence_generated` into a case
via `EvidenceMath.deposit(district, evidence, job.id, tick)` and erodes on negative. A
RIVAL_PROVOCATION job resolved loud will now land positive and **deposit a case with no further
change** — the P06b machinery is origin-agnostic. Verify this end-to-end; do NOT special-case the
origin in the lifecycle (the whole point is that the existing signed axis now simply lands positive).

The one thing to check: the `bury_case` job's targeting parses ids of the form `case@…`; a case
deposited by a retaliation job gets a `case@<district>@<kind>@<tick>` id from `EvidenceMath.deposit`
regardless of what job created it, so the burn path is unaffected. Confirm, don't assume.

### 3. Nothing else changes

No new origin, no new enum, no new signal, no save change (cases already persist from P06b). This
slice is a **data rebalance + a verification that the existing chain now bootstraps**. If it needs
more than the retaliation template's evidence numbers to make cases form in real play, STOP and report
back — that would mean the accrual path has a bug P06b's manual-injection tests masked, and we spec
that separately.

## Files (Fable's build list)

- `src/jobs/job_templates.gd` — retaliation template evidence rebalance (the only source change
  expected).
- `tests/unit/test_evidence.gd` — add an assertion (below) that a realistic **loud retaliation
  lifecycle** (not a hand-injected outcome) deposits a case; and that a **quiet** one does not.
- `tools/validation/full_cycle_probe*.tscn` already exist (uncommitted, from the gate) — Fable may
  re-run them to confirm, but the acceptance requirement is the new test + a fresh probe read (below).

## Gates — Done when (control tower verifies each headless)

- `--import` clean; **`test_evidence` green incl. the new loud/quiet bootstrap assertions**; **full
  prior suite green** (13 tests — this is a data tune, nothing structural should regress; especially
  `test_heat_consequence`, `test_rival_ai`, `test_central_pressure`).
- **RNG source scan** still clean (no new code paths, but re-run the guard).
- **The real-play proof (the actual acceptance bar):** re-run the full-cycle probe (aggressive policy)
  and show that **cases now accrue from the retaliation flow** (glass wharf ends with ≥1 case, peak
  ≥1), that at least one **inspection recurs from case pressure** (not just the single pure-heat one),
  and that central pressure now climbs meaningfully higher than the old 0.45 ceiling (ideally crosses
  the 0.60 alert bar in a sufficiently loud run). Print the before/after. Verdict line
  `EVIDENCE BOOTSTRAPS FROM THE FEUD` on success. **A green test alone is NOT acceptance — the
  long-session probe is what failed, so the long-session probe is what must now pass.**
- Boot smoke clean.

### test_evidence must add

1. A **loud** retaliation lifecycle (real `retaliation()` template → argMAX approach + argMAX cover-up,
   driven through `apply_outcome`, NOT a hand-built outcome dict) deposits a case (district gains ≥1
   case, weight > 0).
2. A **quiet** retaliation lifecycle (argMIN approach + argMIN cover-up) deposits NO case and, if a
   case exists, erodes it (net-negative preserved).
3. The retaliation evidence invariants hold: `argMAX+argMAX ≥ +0.25`, `argMIN+argMIN ≤ −0.3` (assert
   directly off the template so a future edit that re-breaks the bootstrap fails the test).

## Out of scope (P06d stays a tuning slice)

- No rebalance of any OTHER job template's evidence (only retaliation — that's the dominant flow; the
  others are a separate balance pass if ever needed). No change to FAILED_RACKET spawn frequency (a
  different lever, deferred). No new job origin. No touch to how heat/central rise/decay. No fix to the
  **runaway economy** ($1.1M/cycle — flagged in the gate note as a separate balance question, NOT this
  slice). No multi-district reseed (the feud-dominance-as-seed-artifact question is noted but separate).
  No Fable reasoning echoed into output (per `docs/FABLE.md`).

## Handoff note to Fable

This is the smallest possible fix for a real gap: the long-session gate proved P06b/P06c are unreachable
in play because no job nets positive evidence, and the dominant job (retaliation) caps at net 0.0. The
fix is to make the *loud* answer to a rival actually leave a trail — coupling the feud to the police
line, which is both the minimal change and the thematically right one. **The acceptance bar is NOT the
unit test — it's the full-cycle probe now showing cases forming from real play.** Green tests are what
hid this bug in the first place (they injected the case by hand); do not repeat that. Prove it through
the real flow. On any `stop_reason: "refusal"`, fall back to Opus for that one call and continue.
