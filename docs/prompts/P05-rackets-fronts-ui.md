# P05 — Rackets / fronts / laundering UI: surface the squeeze, give the player verbs

**Month:** 2 · **Brief:** §5.1 (commitment step), §7.2 (dirty/clean economy + economic tension)

## Why

P04 gave the player exactly one commitment verb (take a job). The Month-2 gate (brief §12) needs a
full Night Cycle that's *fun with cubes* — which needs a **second, standing commitment loop** the
player returns to between jobs. That loop is the economy.

The core tension already runs in code but is **invisible**: `economy_service.gd` computes
`unlaundered_overflow` every tick (`max(0, dirty_income - laundering_capacity)`, ~L39) and it feeds
heat via exposure — but nothing shows it. This is the same class of bug as P04b's clamped evidence:
the game's central squeeze is happening and the player can't see it or act on it. P05 makes the
squeeze **visible** and gives the player the brief §7.2 verbs to respond.

## The brief's prescribed verbs (§7.2) — these are the scope

Brief §7.2 lists the player's economic-tension choices explicitly: *tolerate exposure; buy another
front; pressure an existing front; temporarily stop a profitable racket; bribe an official; slow
expansion; tax a rival.* P05 implements the ones that are self-contained and need no other system:

1. **Surface the squeeze (mandatory, do this first).** On the HUD, show faction-level totals:
   `dirty income/tick`, `laundering capacity/tick`, and — when `dirty_income > laundering_capacity`
   — a clear **"UNLAUNDERED OVERFLOW: +N/tick → heat rising"** indicator. Read the values from
   `EconomyService` (it already emits `economy_settled(faction_id, dirty_delta, clean_gain, exposure)`
   ~L61; add a getter or cache the last settle if needed — do not recompute the economy in the HUD).

2. **Pause a racket.** Add `paused: bool` to `VenueData`. A paused racket yields 0 dirty income
   (gate it in `EconomyMath.compute_dirty_income` — return 0 when `venue.paused`, alongside the
   existing non-RACKET guard). Wire a "Pause / Resume" button on the venue panel for owned rackets.
   This is the player's direct lever on overflow: stop earning to cut exposure.

3. **Front control readout + pressure.** On the venue panel for owned fronts, show
   `laundering_capacity`, `front_efficiency`, `operating_cost`, and the front's clean/tick
   (`EconomyMath.compute_front_clean`). Add a **"Pressure front"** action that raises this front's
   `laundering_capacity` by a fixed step, spending **clean_capital** (per §7.2: clean pays for
   operations on the legitimate side). Clamp to a sane max. If clean_capital is insufficient, disable
   the button with a reason.

4. **Two-currency spending is honest.** Any spend deducts from the correct pool: pressuring a front
   spends clean; (buying a front is deferred — see below). Never let a spend drive a pool negative.

## Venue panel — where the verbs live

The venue panel doesn't exist yet as an interactive surface; `hud.gd.show_selection()` (~L67-77)
only prints a read-only blurb. P05 turns venue selection into an **interactive panel** with the
above buttons. Build it in code like the existing HUD/job panels (real theme is P11/P19). Selection
is already wired: `bootstrap.gd` L48 `city.venue_clicked → _on_venue_clicked → _hud.show_selection`.
Extend that path; keep authoritative state in `GameState`/`VenueData`, never in the panel.

## Deferred to P05b (do NOT build these here) — decided 2026-07-02

- **Operative pool + assignment.** The old P05 draft centered on assigning operatives to raise
  `operational_staff`. But **the brief §7.2 has no operative-assignment verb** — `operational_staff`
  is a formula input, and a finite operative pool is an inferred design extension, not spec. It's a
  whole sub-system (finite pool on the faction, assign/recall UI, staffing economics). Splitting it
  out keeps P05 a clean, gate-sized slice. `faction_data.gd` has **no operative-pool field** and
  `VenueData` has **no staffing-assignment surface** yet; P05b adds them deliberately. For P05,
  `operational_staff` stays whatever WorldSeed set it to.
- **Buy a new front** (acquiring a venue): needs ownership-transfer + placement logic. Defer to P05b
  alongside the pool, or its own slice.
- **Bribe an official / tax a rival:** depend on P07 (rivals) / P08 (officials). Not now.

## Out of scope (hard)

- Operative pool/assignment, buying fronts (→ P05b). Systemic job generation (→ P08). Rival
  reactions (→ P07). Central Pressure / evidence chains (→ P06/§7.3). Real art (Month 3).
- Do NOT touch `placeholder_jobs.gd` or the P04b resolution work.
- Do NOT recompute economy formulas in the UI — the HUD/panel read from `EconomyService`, they
  don't own the math (brief §13.2: sim is authoritative, presentation reads).

## Verify (headless is truth)

Unit tests under `tests/unit/` (run as `.tscn` scenes — `-s` skips autoloads, false-fails on
`GameState`/`EconomyService`; this bit us in P04):

- `EconomyMath.compute_dirty_income` returns 0 for a paused racket, and the pre-pause value when resumed.
- Pressuring a front raises its `laundering_capacity` and deducts the correct `clean_capital`;
  an insufficient-clean attempt is a no-op (no negative pool).
- With `dirty_income > laundering_capacity`, `EconomyService` still produces the positive
  `unlaundered_overflow` the HUD will display (regression guard on the value the indicator reads).

Then the standard chain:

```sh
GODOT="D:/Godot/Godot_v4.7-stable_win64_console.exe"
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . tests/unit/<new_test>.tscn --quit-after 300 2>&1 | grep -iE "PASS|FAIL"
"$GODOT" --headless --path . --quit-after 120 2>&1 | grep -iE "SCRIPT ERROR|ERROR:"   # empty = clean
```

Manual (editor F5, or MCP run): select an owned racket → Pause → HUD overflow indicator drops;
Resume → it climbs back. Select a front → Pressure → laundering capacity rises, clean_capital falls,
overflow shrinks. The player can *see and steer the squeeze*.

## Done when

- The HUD shows dirty-vs-laundering with a live overflow indicator.
- Pause/resume a racket and pressure a front both work and move the overflow.
- New unit tests green; full verify chain clean. Commit directly to `master` (no PR).
