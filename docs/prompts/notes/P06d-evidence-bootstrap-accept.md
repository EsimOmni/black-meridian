# P06d — Evidence bootstrap (the feud feeds the police line): ACCEPTED

**Accepted:** 2026-07-04 · **Built by:** Fable 5 (commit `831ef58`). **Gated by:** control tower —
every check re-run here, the diff read by hand, the instrument-fix honesty flag verified. This closes
the Month-2 long-session gate's FAIL item (`docs/prompts/notes/month2-longsession-gate.md`): P06b/P06c
were stillborn in real play; now the evidence chain bootstraps from the feud.

## What shipped

**One source change** — the "Answer in Kind" retaliation template's evidence numbers, so the *loud*
answer to a rival leaves a trail and the *quiet* one stays clean:

- `src/jobs/job_templates.gd` — `appr_mirror` evidence `0.1 → 0.35`, `cover_flaunt` `-0.1 → -0.05`.
  Loud lifecycle nets **+0.30** (bar ≥ +0.25 ✓); quiet stays **-0.3** (≤ -0.3 ✓, untouched). The
  invariant is written into the template's doc comment and guarded by a test, so a future edit that
  re-breaks the bootstrap fails CI.

Nothing else in game source. The accrual path carried it with **zero code** exactly as the spec
predicted — `EvidenceMath.deposit` is origin-agnostic, so a retaliation job resolved loud now lands
positive and deposits a `case@<district>@<kind>@<tick>` case the burn path targets unchanged.

## The gap this closed

The long-session gate proved the dominant flow (retaliation, ~95% of jobs) capped at net 0.0 evidence,
so no case ever formed → `combined_pressure == raw heat` forever → the whole P06b→P06c chain had
nothing to stand on. Coupling the feud to the police line (a visible reprisal draws institutional
heat) is both the minimal fix and the thematically right one — it connects the two pressure systems
P07c and P06b/P06c built in parallel but never joined.

## Gate — every check re-run here (diff + probe + honesty flag verified)

| Check | Result |
|---|---|
| Source scope | **only** `job_templates.gd` (+7/-3); probe fixes confined to `tools/validation/` — no other game source touched |
| Diff invariant | loud +0.30 (≥ +0.25), quiet -0.3 (≤ -0.3); invariant embedded in template comment + test |
| `test_evidence` | **[PASS]** — +3 assertions driven through the **real** JobDirector path (begin→approach→coverup→apply_outcome), **no hand-built outcome dict** (the P06b test blind spot, not repeated) |
| Regression (central/rival/heat) | all **[PASS]** |
| Full suite (14 unit + 2 integration) | green; save roundtrip ok |
| RNG scan | `src/` **0** occurrences |
| **Acceptance bar: aggressive full-cycle probe (re-run by control tower)** | cases **3 (peak 4)**, inspections **6 (5 case-driven)**, central peak **0.886**, alert **fired**, EVIDENCE_CHAIN **5**, plateau **0/15** → **EVIDENCE BOOTSTRAPS FROM THE FEUD** |
| Instrument-fix honesty | verified: the probe's cooling-reflex fix derives its unpause mark from the **real** `HEAT_INSPECTION_REARM` (0.30) constant — a measurement-tool fix, not a mechanic change; cases form from the template edit alone |
| Boot smoke | **0** script errors |

## Before / after (the real acceptance metric, not a unit test)

| | BEFORE (gate FAIL) | AFTER (P06d) |
|---|---|---|
| Evidence cases end / peak | 0 / 0 | 3 / 4 |
| Inspections | 1 (pure heat) | 6 (5 case-driven recurrence) |
| Central peak | 0.454 (alert NO) | 0.886 (alert YES, repeatedly) |
| Bury-case (EVIDENCE_CHAIN) jobs | never spawned | 5 (first ever from real play) |
| Pressure plateau | 8/15 → LOOP FLAT | 0/15 → LOOP ALIVE |

The fork is real: aggressive (loud) play grows the case and pulls the city onto you ($2.5k dirty in
pocket); quiet play stays clean ($246k dirty) but reads soft in the P07c feud. Rival ↔ police now feed
each other.

## The discipline that caught this (recorded)

Green unit tests and acceptance probes passed for P06b/P06c because they injected the first case by
hand. The *real job flow* never did. A green test is not acceptance when the failing signal was a
long-session probe — so the acceptance bar for P06d was explicitly the probe, not the test. This is
why the long-session gate exists before asset production, and why "prove it through the real flow"
is the standing rule. Lesson recorded in `tasks/lessons.md`.

## Out of scope (held)

No rebalance of any other job template's evidence. No FAILED_RACKET spawn-frequency change. **Runaway
economy** (clean capital still high, though pressure now bites it $1.12M → $593k) remains a separate
balance slice. Rival-provocation dominance as a possible single-district-seed artifact stays noted,
not investigated. No new origin/enum/signal/save change.

## Status: Month-2 gate FAIL item CLOSED

The police-pressure line (P06 → P06b → P06c → P06d) is now reachable and self-feeding in real play.
Next control-tower decision: re-run the full long-session gate end to end for a clean pass, then the
asset-production (P12) hold can lift.
