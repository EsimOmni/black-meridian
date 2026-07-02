# P06 — Give heat a consequence: close the Night-Cycle loop

**Month:** 2 · **Brief:** §7.3 (Local Heat effects)

## Why

P05 made the laundering squeeze visible and gave the player verbs (pause/pressure). But heat is
still a **write-only number**: `local_heat` climbs from economy exposure (`economy_service.gd:97`,
`+ exposure*0.05`) and from job outcomes (`job_lifecycle.gd:75-76`), and **nothing reads it to
change anything** (confirmed: only writers + HUD display + save). So the loop doesn't close — the
player can ignore the squeeze forever and nothing happens. That fails the Month-2 gate (brief §12:
a full Night Cycle must be *fun with cubes*), because tension with no consequence isn't tension.

This is the same shape as P04b (clamped evidence) and P05 (hidden overflow): the mechanism is
already half-wired and just needs to be connected. Here, the hook is **`disruption`** — venue income
already multiplies by `(1 - disruption)` (`economy_math.gd:23-25`), but nothing writes `disruption`
from heat. `venue_data.gd:31-32` even comments "heat/raids reduce yield" as an unimplemented intent.
P06 connects heat → disruption → income, and adds a legible inspection/raid beat at a threshold.

## Scope — heat's consequence only

1. **Heat disrupts operations.** Per tick, drive each owned venue's `disruption` from its district's
   `local_heat` (e.g. `disruption = f(local_heat)` — a simple curve; high heat → higher disruption →
   lower dirty income). Keep the math in `EconomyMath` (pure, testable), applied by `EconomyService`
   at settle. This makes ignoring the squeeze *cost income*, closing the loop.

2. **Heat decays slowly** when exposure is low, so the player can recover by backing off (pause a
   racket, pressure fronts). A small per-tick decay toward 0 when the district's tick exposure is
   below a floor. Decay must be slower than the rise so causality stays legible (brief §7.3).

3. **A threshold beat — the inspection/raid.** When a district's `local_heat` crosses a threshold
   (e.g. 0.7), fire a telegraphed event: a HUD warning as heat approaches, then at the threshold an
   **inspection** that bites (e.g. temporarily spikes `disruption` on that district's venues, or
   freezes a racket's yield for K ticks). Deterministic and telegraphed — NO hidden roll (brief §7.6
   pillar: consequences are legible, never a surprise dice throw). Emit a signal the HUD/job panel
   can surface ("Glass Wharf: INSPECTION — yields disrupted").

4. **Wire job evidence into heat honestly (closes the P04b debt).** `evidence_generated` is a signed
   net axis (negative = suppressed; `JobResolution.SIGNED_DIMENSIONS`). It already nudges heat at
   `job_lifecycle.gd:76`. Confirm the sign is right end-to-end: a suppressed job (negative evidence)
   should *lower* heat contribution, an exposed job should *raise* it. **Decision on the P04b deferral:
   do NOT split into production-vs-suppression axes.** The net axis is the correct signal for heat —
   net trace left is exactly what police attention responds to. Record this decision in a comment
   where evidence feeds heat, and remove the "decide in P06" note. (If, wiring it, you find the net
   axis genuinely can't express a needed case, stop and flag it — don't silently split.)

## Deferred (do NOT build here) — decided 2026-07-02

- **Evidence Chains** (`evidence_data.gd` + `EvidenceService`, named investigations with
  remove/redirect/discredit/frame verbs) → **P06b.** This is a whole new data type + service + four
  manipulation verbs + UI — its own gate-sized slice. For P06, evidence stays a scalar feeding heat;
  no chain structure.
- **Central Pressure / Civic Integrity Directorate** (campaign-wide meter, asset freezes, raids,
  informants, defections, special investigators, endgame) → **P06c.** The brief gives no numeric
  thresholds (§7.3 is qualitative) — this is Month-3+ calibration work, not a Month-2 slice.

## Out of scope (hard)

- Evidence chains, Central Pressure (→ P06b/P06c). Operative pool, buy-front (→ P05b). Job generation
  (→ P08). Rival reactions (→ P07). Real art (Month 3).
- Do NOT recompute economy in the UI (brief §13.2: sim authoritative, presentation reads).
- Do NOT touch `placeholder_jobs.gd` authored numbers or the P04b clamp set beyond confirming the
  heat sign.
- The inspection beat must be deterministic + telegraphed — no `randf()` gate (brief §7.6).

## Verify (headless is truth)

Unit tests under `tests/unit/` (run as `.tscn` scenes — `-s` skips autoloads, false-fails on
`GameState`/`EconomyService`; this bit us in P04):

- High `local_heat` raises a venue's `disruption` and measurably lowers `compute_dirty_income`
  vs. the same venue at zero heat (the loop-closing regression).
- Heat decays toward 0 over N low-exposure ticks, and decay is slower than the rise.
- Crossing the heat threshold fires the inspection signal exactly once (not every tick above it),
  and it is deterministic (same state → same fire, no RNG).
- Regression guard: P05 pause/pressure and P04b resolution tests still pass.

Then the standard chain:

```sh
GODOT="D:/Godot/Godot_v4.7-stable_win64_console.exe"
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . tests/unit/<new_test>.tscn --quit-after 300 2>&1 | grep -iE "PASS|FAIL"
"$GODOT" --headless --path . --quit-after 120 2>&1 | grep -iE "SCRIPT ERROR|ERROR:"   # empty = clean
```

Manual (F5 or MCP run): run a racket without laundering → heat climbs → HUD warns → income visibly
drops from disruption → at threshold an inspection fires → pause the racket → heat decays → income
recovers. The player can *feel* that ignoring the squeeze has a price and that backing off relieves it.

## Done when

- Ignoring the squeeze visibly costs income (heat → disruption → lower dirty income).
- Heat decays when the player backs off; the inspection beat fires deterministically at threshold.
- The P04b evidence-sign debt is resolved and documented (net axis, no split).
- New unit tests green; P04b + P05 regressions green; full chain clean. Commit to `master` (no PR).
