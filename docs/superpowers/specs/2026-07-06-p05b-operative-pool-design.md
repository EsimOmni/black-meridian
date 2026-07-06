# P05b — Operative pool + assign/recall (the finite-labor strategic lever)

**Date:** 2026-07-06 · **Author:** Claude (control tower) · **Executor:** Fable subagent · **Gate:** Claude
**Brief:** §7.2 (dirty-income formula) · **Predecessor:** P05 (shipped), which explicitly deferred this
(P05 spec lines 52-62): "Operative pool + assignment … a whole sub-system (finite pool on the faction,
assign/recall, staffing economics)."

---

## Design note — this is a deliberate design EXTENSION, not a brief transcription

The brief §7.2 has `operational_staff` as a **formula input** to DirtyIncome but **no operative-assignment
verb**. A finite operative pool is an inferred design extension (P05 flagged this). So the shape below is a
control-tower design decision, chosen for minimality + determinism + gate-ability — NOT lifted from spec.
The one thing it must honor from §7.2: `operational_staff` already multiplies DirtyIncome
(`economy_math.gd:22-24`), so making it player-controllable is a real strategic lever with an existing,
tested economic effect. We are wiring a verb to an input that already works — not inventing new economics.

---

## The one thing this proves

> The player commands a **finite** pool of operatives and must decide **where to spend it** — assigning
> more staff to a venue raises its dirty income (through the existing §7.2 multiplier), but the pool is
> scarce, so every assignment is a trade-off. Deterministic, save-persistent, no negative pool ever.

Today `operational_staff` is whatever WorldSeed stamped and the player cannot change it — a dead lever.
P05b makes it a live decision bounded by a finite faction pool.

---

## The model (minimal, deterministic)

- **`FactionData.operative_pool: int`** (NEW) — the faction's TOTAL operatives. WorldSeed sets it (see
  seeding rule below).
- **`VenueData.operational_staff: int`** (EXISTING) — operatives currently assigned to this venue; already
  the §7.2 income multiplier.
- **Free pool** = `operative_pool - sum(operational_staff over all venues this faction owns)`. Derived,
  never stored (single source of truth = pool total + per-venue assignments).

### Two verbs (pure logic + a thin service call)

Put the RULES in a pure `class_name OperativeMath extends RefCounted` (testable headless like
EconomyMath/RivalScoring), and a thin wrapper on a service the HUD calls. Prefer adding the wrapper to the
EXISTING `EconomyService` (staffing is economics) OR a small bootstrap-wired `OperativeService` node —
Fable picks the cleaner; do NOT add a new autoload without flagging it (project.godot churn risk).

- **`assign(faction, venue, n) -> int`** — move up to `n` operatives from the free pool onto the venue.
  Returns the number actually assigned (clamped to free pool; `0` if pool empty — a no-op, never negative).
  Only the venue's OWNER faction can staff it (assigning to a venue you don't own is a no-op).
- **`recall(faction, venue, n) -> int`** — move up to `n` operatives from the venue back to the free pool.
  Returns actually recalled (clamped to the venue's current `operational_staff`; `0` if none).

Both are pure state moves: `operative_pool` total is invariant (assign lowers free by raising venue staff;
recall raises free by lowering venue staff). The pool total only changes if a future slice adds
recruitment/injury — OUT OF SCOPE here.

### Seeding rule (WorldSeed)

WorldSeed currently stamps each venue's `operational_staff` directly. P05b sets each faction's
`operative_pool` to **`sum(operational_staff of that faction's venues) + FREE_RESERVE`** where
`FREE_RESERVE` is a small authored slack (e.g. 2-3) so the player starts with SOME free operatives to
assign — otherwise the lever is frozen at start (everyone fully committed). Pick FREE_RESERVE so the
opening board has a real choice but isn't flush. Document the number.

---

## Hard invariants (the gate checks these)

1. **ZERO RNG.** Assign/recall are pure clamped arithmetic. No `randf`/`randi`/`randomize`/
   `RandomNumberGenerator`. Source-scanned by the test.
2. **No negative pool, no over-assignment, no phantom operatives.** Free pool is always ≥ 0; sum of a
   faction's assigned staff is always ≤ its `operative_pool`; the pool total is invariant under
   assign+recall. These are the core assertions.
3. **Save-additive.** `operative_pool` decodes via `d.get("operative_pool", 0)`; SAVE_VERSION stays 1; old
   saves load. NOTE (verified): `operational_staff` is ALREADY encoded (save_codec.gd:86) and decoded
   (:208) — no gap there, do NOT re-add it. The ONLY new persisted field is `operative_pool` on the
   faction. (decode_faction uses `d.get(...)` for additive fields like grudge/intents_committed — follow
   that exact pattern; do NOT use `d["operative_pool"]` which would break old saves.)
4. **Ownership-gated.** You can only staff/recall venues your faction owns (checked in the verb).
5. **Economic effect is real and unchanged in shape.** After assign, `EconomyMath.compute_dirty_income`
   reads the new `operational_staff` and income rises; after recall it falls. P05b does NOT touch the
   income formula — it only changes the input the player controls. (A test asserts income moves the right
   direction after assign/recall.)
6. **Minimal footprint.** No injury→pool wiring, no recruitment, no buying fronts, no UI polish beyond a
   greybox affordance. Those are later slices (P05 deferred buying-fronts here too — still deferred).

---

## Files

### Modified
- `src/core/faction_data.gd` — add `@export var operative_pool: int = 0` (documented).
- `src/core/world_seed.gd` — set each faction's `operative_pool = assigned_sum + FREE_RESERVE`.
- `src/save/save_codec.gd` — encode/decode `operative_pool` (faction) AND `operational_staff` (venue,
  closing the existing gap). Additive, SAVE_VERSION unchanged.
- `scenes/ui/hud.gd` — a GREYBOX affordance on the selected venue: show "Staff: N (free pool: M)" and
  buttons/keys to assign +1 / recall -1 (or a small stepper). Minimal — this is the lever made visible,
  not a designed panel. Route through the service verb; refresh on change.

### New
- `src/simulation/operative_math.gd` — pure `OperativeMath` with `assign`/`recall` (or `free_pool`,
  `can_assign`, and the clamped move helpers). Static, RefCounted, no engine singletons.
- The service wrapper (in EconomyService or a small OperativeService node — Fable's call, flagged).
- `tests/unit/test_operative_pool_p05b.gd` + `.tscn` + `.uid` — the gate test (run via `.tscn`).

### NOT touched
- `economy_math.gd` (the income formula is correct — we only feed it a player-controlled input).
- No new autoload in project.godot without flagging.

---

## The GATE test (test_operative_pool_p05b.gd) — Claude re-runs this

Run via `.tscn`. Exit 0 only if all pass. Assertions:

1. **`_test_assign_moves_from_pool`**: free pool F, venue staff S. `assign(f, v, 2)` → venue staff S+2,
   free pool F-2, pool total invariant. Returns 2.
2. **`_test_assign_clamps_to_free_pool`**: free pool = 1, `assign(f, v, 5)` → assigns only 1, free pool 0,
   returns 1. A second `assign(f, v, 5)` → returns 0, no-op, pool still ≥ 0 (never negative).
3. **`_test_recall_returns_to_pool`**: venue staff S≥2, `recall(f, v, 2)` → venue S-2, free pool +2, total
   invariant, returns 2. `recall` beyond current staff clamps (returns only what was there).
4. **`_test_ownership_gated`**: `assign`/`recall` on a venue owned by the RIVAL faction → no-op, returns 0,
   nothing mutated.
5. **`_test_income_follows_staffing`**: seed a RACKET venue; record `compute_dirty_income`; `assign(+2)`;
   assert income rose; `recall(-2)`; assert it returned to baseline. Proves the lever actually drives §7.2.
6. **`_test_pool_survives_save_load`**: assign some staff, `SaveService.save` → scramble live
   pool/staff → `load` → assert `operative_pool` AND every venue's `operational_staff` restored exactly
   (closes the save gap). Scramble before load so it's not a tautology.
7. **`_test_no_rng_in_operative_sources`**: source-scan `operative_math.gd` (+ the service file) for RNG →
   none.

Also run existing suites for regression: `test_economy` (income formula untouched), and a boot smoke.

---

## Out of scope (do not add)

- Operative injury → pool depletion (job `operative_injury` outcome stays grievance-only for now).
- Recruitment / growing the pool.
- Buying fronts / venue acquisition (P05 deferred it; still deferred).
- Per-operative identity, morale, or skill (the pool is a fungible integer).
- Designed staffing UI (greybox affordance only).

---

## Verify (Claude's gate — I re-run all of it; green-by-claim is not green)

```sh
GODOT="D:/Godot/Godot_v4.7-stable_win64_console.exe"
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . tests/unit/test_operative_pool_p05b.tscn     # new gate (exit 0)
"$GODOT" --headless --path . tests/unit/test_economy.gd                   # income formula intact (-s ok — no autoload dep; verify)
"$GODOT" --headless --path . --quit-after 120 2>&1 | grep -iE "SCRIPT ERROR|ERROR:|Nonexistent"
grep -rnE "randf|randi|randomize|RandomNumberGenerator" src/simulation/operative_math.gd
```

Plus I READ operative_math.gd + the service wrapper + the save_codec diff: confirm the pool total is
invariant under assign+recall (no leak/duplication of operatives), the save gap is actually closed (both
fields round-trip), ownership is checked, and the income effect flows through the untouched §7.2 formula.
I also confirm the HUD affordance routes through the verb (no direct field poke that bypasses the clamp).
