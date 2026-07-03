# P09 — Night Cycle phase machine: turn the flat tick stream into a dramatic episode

**Month:** 2→3 boundary · **Brief:** §5.2 (the 25–35 min Night Cycle), §13.2 (phase boundaries)

## Why

The systems all run (economy P05, heat P06, rival P07, jobs P08) but time is a **flat, endless tick
stream** — `night_cycle` is hardcoded to 1, `phase` hardcoded to OPERATIONS, and nothing advances
them. Brief §5.2 wants one session to feel like *a complete dramatic episode*: four phases,
25–35 min, "stop after one Night Cycle and feel that a complete dramatic episode occurred." P09 gives
the loop that container.

**The scaffolding already exists — this is a "connect the pre-wired hook" slice, like P04b–P08:**

- `BM.Phase` enum already defined (`enums.gd:93-98`): `COUNCIL` (3–5 min), `OPERATIONS` (15–20 min),
  `CRISIS` (5–8 min), `RECKONING` (2–3 min) — verbatim from the brief, with duration comments.
- `GameState.night_cycle:int = 1` (`game_state.gd:19`), `GameState.phase = BM.Phase.OPERATIONS` (:20),
  and signal `night_cycle_advanced(cycle, phase)` (:8) — **all declared, the signal never emitted.**
- Save already carries `night_cycle`/`phase` in `meta` (`save_service.gd:18-19,65-66`), additive,
  SAVE_VERSION stays 1.

P09 builds the machine that drives this scaffolding; it does NOT invent the phase concept.

## The one architectural rule — DO NOT break the verified per-tick systems

**Decided 2026-07-03:** keep per-tick settlement. Economy/heat/rival/jobs keep running every tick
exactly as verified in P05–P08 — do NOT move settlement to the Reckoning boundary. Brief §13.2 says
"economic settlement: phase boundary," but P05–P08's balance (heat coupling ×5, overflow, inspection
threshold 0.45, rival scoring) was all **calibrated and independently probed per-tick**. Moving to
boundary-settlement would invalidate that calibration and force a full re-verify. Instead, **phases
MODULATE the per-tick systems, they don't replace the tick.** Reckoning shows a *summary/preview*
beat over already-settled state — the drama is in the framing, not in relocating the math. If a future
slice genuinely needs boundary settlement, that's a deliberate re-calibration, not P09.

## Scope — a thin slice: the phase machine + transitions + HUD, content later

Create `src/simulation/night_cycle.gd` (a node wired at bootstrap, or an autoload — keep any pure
advancement logic testable, split a static if it helps like `EconomyMath`). Driven by
`TimeService.strategic_tick`.

1. **Deterministic phase advancement.** Each phase has a tick budget derived from its brief minutes
   (map minutes→ticks via the strategic tick rate; a phase advances when its elapsed ticks reach its
   budget). Order: COUNCIL → OPERATIONS → CRISIS → RECKONING → (next cycle) COUNCIL, incrementing
   `night_cycle`. **Zero RNG** — same tick count → same phase, house style. The cycle **starts at
   COUNCIL** (currently the default is OPERATIONS — set it explicitly at cycle start).

2. **Emit the pre-wired signal.** On every phase change and cycle rollover, set `GameState.phase` /
   `GameState.night_cycle` and emit `night_cycle_advanced(cycle, phase)`. This is the hook the HUD and
   (later) city react to.

3. **Phases MODULATE existing systems (light touch, no rewrites).** The verified systems keep ticking;
   phases gate/flavor them:
   - **Council:** a setup beat — pause rival *commits* (RivalDirector shouldn't open a new telegraph
     mid-Council) and let the player read state. Economy still settles per tick (income accrues).
   - **Operations:** everything fully active (this is the current behavior — the 15–20 min core).
   - **Crisis:** heighten — allow the state-driven crisis framing (the actual crisis *content* /
     splat is a later slice; P09 just marks the phase and lets systems run hot).
   - **Reckoning:** a summary/preview beat — surface what settled this cycle (income, heat delta,
     rival intent) and preview the next. No new settlement math; it reads already-settled state.
   Wire these as minimal guards keyed on `GameState.phase`, not as rewrites of P05–P08.

4. **HUD shows the phase + a phase clock.** Replace the static "Night Cycle 1" with the live phase
   name + progress (e.g. "Night Cycle 1 · OPERATIONS (12:04 / 18:00)" or a tick-based readout). The
   Reckoning summary can be a short HUD panel. Reuse the existing HUD pattern (code-built, greybox).

## Deferred (do NOT build here) — decided 2026-07-03

- **Rich phase content** → later slices. Council's lieutenant-assignment / priority-selection UI,
  Crisis's actual state-driven crisis + cinematic splat transition (Month 4), Reckoning's loyalty-change
  visualization — P09 marks the phases and modulates flow; it does not build their interiors.
- **Boundary settlement** (moving economy settle to Reckoning) → not now; would re-open P05–P08
  calibration (see the architectural rule above).
- Aiko personal intervention, district-objective selection, evidence chains (P06b), Central Pressure
  (P06c), operative pool (P05b), rival noise/memory (P07b/c), extra job origins (P08b) — all deferred.

## Out of scope (hard)

- NO `randf()`/`randi()` in phase advancement (house style — same ticks → same phase).
- Do NOT move economy/heat/rival/job settlement off the per-tick path (protects verified calibration).
- Do NOT rewrite P05–P08 systems; phase modulation is minimal guards keyed on `GameState.phase`.
- Do NOT break the save version — phase-elapsed state rides in `meta` additively with defaults
  (like P06/P07/P08), SAVE_VERSION stays 1.

## Verify (headless is truth)

Integration/unit tests (run as `.tscn` scenes — `-s` skips autoloads, false-fails on GameState):

- **Full cycle:** driven headless, the machine advances COUNCIL → OPERATIONS → CRISIS → RECKONING →
  COUNCIL, incrementing `night_cycle` from 1 to 2, emitting `night_cycle_advanced` at each transition
  (assert the emit count + order).
- **Deterministic:** same tick count → same phase, every run. No RNG.
- **Phase budgets:** each phase lasts its mapped tick budget (assert a phase change happens at the
  expected tick, not before/after).
- **Modulation is non-destructive:** economy still settles every tick during all phases (a
  regression guard that P05's per-tick income still accrues in, say, Council); rival does not open a
  new telegraph during Council but resumes in Operations.
- **Save/load:** phase + phase-elapsed + night_cycle round-trip through `meta` (SAVE_VERSION unchanged).
- **Regression:** P04b/P05/P06/P07/P08 tests all still pass (nothing rewired underneath).

Then the standard chain:

```sh
GODOT="D:/Godot/Godot_v4.7-stable_win64_console.exe"
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . tests/integration/<new_cycle_test>.tscn --quit-after 600 2>&1 | grep -iE "PASS|FAIL"
"$GODOT" --headless --path . --quit-after 120 2>&1 | grep -iE "SCRIPT ERROR|ERROR:"   # empty = clean
```

Manual (F5 or MCP run): watch the HUD advance through the four named phases over a cycle; rival stays
quiet in Council and acts in Operations; at Reckoning a summary of the cycle appears; then Night Cycle
2 begins at Council. The session reads as a bounded episode, not an endless stream.

## Done when

- The four phases advance deterministically on a tick budget, emitting `night_cycle_advanced`.
- The HUD shows the live phase + clock; Reckoning surfaces a cycle summary.
- Per-tick systems are untouched and still verified; phases only modulate + frame.
- New tests green; P04b–P08 regressions green; full chain clean. Commit to `master` (no PR).
