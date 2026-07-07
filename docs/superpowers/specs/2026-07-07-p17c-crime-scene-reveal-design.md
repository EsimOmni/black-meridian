# P17c — Crime-scene reveal: walk into the frame, remove the evidence

**Date:** 2026-07-07 · **Author:** Claude (control tower) · **Executor:** Fable subagent · **Gate:** Claude
**Brief:** §6 pillar 4 ("walk through the consequence"), §7.7 (cinematic sequence types — this is the
**crime-scene inspection** type; P17b shipped the **private confrontation** type), §12.3 (scoped small),
§14.2/§19 (enter/resolve/persist round-trip, the P18 gate).
**Predecessor:** P17b (shipped) — the reveal scene + CinematicTransition round-trip. P17c adds the SECOND
sequence type on the same rails, the same way P08b added a second job variant: parallel structure, existing
deterministic verb, zero new sim logic.

---

## The one thing this proves

> A rival landing a frame/sabotage on the player's ground can be **walked into** as a constrained
> first-person crime-scene, the player's in-scene choice (remove the planted evidence, or leave it) routes
> through the EXISTING `EvidenceMath.remove_case` verb, changes persistent district state, and survives
> save/load — the same P18 gate P17b passed, for a new sequence type and a new sim consequence.

This is the crime-scene mirror of P17b's confrontation: there the verb was `reassure()`; here it is
`remove_case()`. Same rails (CinematicTransition), same first-person controller shape, same persistence
gate — a different trigger, target, and consequence.

---

## The trigger + target (design decision — read carefully)

- **Trigger:** `RivalDirector.rival_action_landed(faction, venue, action)` (already emitted, P07b) for a
  SABOTAGE or FRAME on a PLAYER-OWNED venue, WHEN the venue's district has at least one open
  `evidence_case`. The HUD surfaces a "Walk the scene" affordance; the player chooses to enter (never
  automatic — pillar 4 is that the player elects to walk the consequence).
- **Target:** the district's **strongest** open evidence case (`EvidenceMath.strongest_case(district)`) —
  that is the "planted evidence" the crime-scene is built around. This is the box the player inspects.
- **DO NOT change FRAME/SABOTAGE landing behavior.** P07b is shipped and gated: FRAME bumps `local_heat`,
  SABOTAGE arms `sabotage_disruption`. P17c does NOT make them deposit a case. It binds to whatever
  evidence cases ALREADY exist in the district (deposited by the P06b job/evidence flow). If the district
  has no open case, the affordance simply doesn't appear — no crime-scene without evidence to find. This
  keeps P17c purely additive: it reads existing state and calls an existing verb.

Rationale: `remove_case` is the exact `reassure`-equivalent — an existing, tested, deterministic verb
(`evidence_math.gd:80`, already used by the "Bury the Case" job at `job_director.gd:149`). Binding to
existing cases (not inventing a new deposit on FRAME) means ZERO new sim logic and ZERO change to any
shipped slice.

---

## Hard invariants (the gate checks these)

1. **ZERO new simulation logic.** The scene READS district/case state and CALLS
   `EvidenceMath.remove_case(district, case_id)` through a thin transition method. Removing the evidence is
   the ONLY sim write; leaving calls nothing. No new deposit, no heat write, no formula change.
2. **ZERO RNG.** No `randf`/`randi`/`randomize`/`RandomNumberGenerator` in the new files. Source-scanned.
3. **No sim state in scene nodes** (brief §13.2). The crime-scene holds presentation + the district id +
   the target case id (both ids, re-resolved via GameState/EvidenceMath). It owns no case/district object.
4. **Save-additive.** `remove_case` mutates `district.evidence_cases` (already persisted — the P06b case
   list round-trips). NO new persisted field. SAVE_VERSION stays 1. (Verify evidence_cases encode/decode
   in save_codec before relying on it.)
5. **Ownership + precondition gated.** The affordance and enter only fire for a player-owned venue whose
   district has ≥1 open case. Entering with no case is a clean no-op (leave path only).
6. **P17b untouched in behavior.** `reveal_scene.gd` and the character path of CinematicTransition are NOT
   modified (P17b is shipped/gated — minimal footprint). P17c adds a PARALLEL path, it does not refactor
   the confrontation path. (A tiny shared helper is fine ONLY if it doesn't force edits to reveal_scene's
   logic — prefer a 3-line copy of the walk-controller over reopening the green file.)

---

## Files

### New
- `scenes/cinematic/crime_scene.gd` + `.tscn` (+ `.uid` from `--import`) — the crime-scene reveal:
  loads the proxy splat (same GDGS setup as reveal_scene/splat_bench), a first-person walk-only controller
  (WASD + mouse-look, hard AABB clamp, NO jump/combat, ESC frees cursor + click recaptures — copy P17b's
  proven input block), a **crate/evidence proxy** (a box) the player walks to and inspects (E), then ONE
  decision: **[R] Remove the evidence** (calls the transition verb → `remove_case`) or **[Q] Leave** (the
  case stands; the sweep keeps coming — a real consequence). Emits
  `crime_scene_resolved(district_id, case_id, removed: bool)`. On-screen text shows the case label +
  district under pressure; after removal, "the scene is clean" then Q to leave.

### Modified
- `src/presentation/cinematic_transition.gd` — add a PARALLEL crime-scene path:
  `enter_crime_scene(district_id)` (mirrors `enter`: pause sim, hide city + hud_layers, instance
  crime_scene, setup, connect resolve), `try_remove_evidence(district_id, case_id) -> bool` (thin
  delegation to `EvidenceMath.remove_case` on the looked-up district; returns false if district/case gone),
  and `resolve_crime_scene(district_id, case_id, removed)` (free scene, restore city/hud/camera/speed,
  emit a `crime_scene_resolved` signal). Reuse the existing `_reveal`/`_prev_camera` swap fields (only one
  cinematic is ever resident — brief §7.7). Keep the character path exactly as-is.
- `scenes/bootstrap/bootstrap.gd` — connect `rival_action_landed`; on a SABOTAGE/FRAME landing on a
  player-owned venue whose district has an open case, expose the "Walk the scene" affordance (greybox: a
  HUD button, like P17b's Confront). Also a DEBUG key (e.g. **N**) that arms a case on Glass Wharf and
  enters the crime-scene directly, mirroring the P17b **B** debug key (F-keys are swallowed by the editor
  debugger — use a letter). Route through `enter_crime_scene`.
- `scenes/ui/hud.gd` — the "Walk the scene — <case label>" affordance when the trigger condition holds
  (greybox, minimal), targeting the strongest case's district. Route through `transition_node`.

### NOT touched
- `reveal_scene.gd`, `evidence_math.gd`, `rival_director.gd`, `rival_scoring.gd`, `save_codec.gd` (unless a
  verified evidence_cases save gap — check; P06b shipped so it should already round-trip), `project.godot`,
  `theme.tres`, `.agents/`, `.godot_user/`, `screenshots/`.

---

## The GATE test (test_crime_scene_persistence_p17c.gd + .tscn + .uid) — Claude re-runs this

Run via `.tscn` (autoloads must load). Exit 0 only if all pass. Drives the SIM-EFFECT path
(`try_remove_evidence` + save/load), NOT 3D node instancing (city_root null → headless no-op). Structure:

1. **`_test_remove_writes_persistent_state`**: seed a district with an evidence case (via
   `EvidenceMath.deposit`). Confront + remove. Assert the case is gone from `district.evidence_cases` and
   `EvidenceMath.combined_pressure` dropped (the latch eased). Proves the choice changes persistent state.
2. **`_test_persist_survives_save_load_AFTER`**: after removal, `SaveService.save` → scramble live
   evidence_cases (re-add a junk case) → `load` → assert the removed case is STILL gone and any untouched
   cases are intact. Core P18 assertion.
3. **`_test_persist_survives_save_load_BEFORE`**: seed the case, save BEFORE, load, remove on the loaded
   state, save AFTER, load again → consistent throughout (case present before, gone after). Brief §19.
4. **`_test_leave_keeps_case`**: enter + leave (no remove call). Assert the case is untouched and
   `combined_pressure` unchanged — leaving is a real non-choice (the sweep keeps coming).
5. **`_test_remove_missing_case_is_noop`**: `try_remove_evidence` with a case id that isn't there → returns
   false, nothing mutated (the scene can't corrupt state if the case was already burned by a job first).
6. **`_test_no_rng_in_scene_sources`**: source-scan `crime_scene.gd` + `cinematic_transition.gd` → no RNG.

Also run for regression (shared files touched): `test_evidence`, `test_reveal_persistence_p17b`,
`test_job_variety_p08b`, and a boot smoke.

---

## Out of scope (do not add)

- Changing FRAME/SABOTAGE to deposit a case (P07b stays as shipped; P17c reads existing cases).
- A second interaction / multiple crates / choosing WHICH case (always the strongest — one decision).
- Real Marble crime-scene world (proxy bench PLY only — Month-4 asset work).
- Reworking reveal_scene.gd into a shared mode (parallel scene instead — minimal footprint).
- LUT/grading polish (P19).

---

## Verify (Claude's gate — I re-run all of it myself; green-by-claim is not green)

```sh
GODOT="D:/Godot/Godot_v4.7-stable_win64_console.exe"
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . tests/unit/test_crime_scene_persistence_p17c.tscn   # new gate (exit 0)
"$GODOT" --headless --path . tests/unit/test_evidence.tscn                       # remove_case/latch intact
"$GODOT" --headless --path . tests/unit/test_reveal_persistence_p17b.tscn        # P17b path untouched
"$GODOT" --headless --path . tests/unit/test_job_variety_p08b.tscn               # shared save/hud intact
"$GODOT" --headless --path . --quit-after 120 2>&1 | grep -iE "SCRIPT ERROR|ERROR:|Nonexistent"
grep -rnE "randf|randi|randomize|RandomNumberGenerator" scenes/cinematic/crime_scene.gd src/presentation/cinematic_transition.gd
```

Plus I READ crime_scene.gd + the new transition methods end to end: confirm the scene owns no sim state,
the ONLY sim write is remove_case (leave writes nothing), the character path of CinematicTransition is
byte-unchanged, and the save round-trip asserts real persistence (scramble-before-load, not a tautology).
Manual F5 feel walk-through is deferred to Cem.
