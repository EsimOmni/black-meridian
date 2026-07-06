# P17b — Splat Reveal Scene: the betrayal confrontation (first cinematic sequence)

**Date:** 2026-07-06 · **Author:** Claude (control tower) · **Executor:** Fable subagent · **Gate:** Claude
**Brief:** §6 pillar 4 ("walk through the consequence"), §7.7 (cinematic splat sequences), §12.3 (one splat
sequence only), §14.2 (runtime enter/resolve/persist), §19 Month-4 gate.
**Slices folded in:** P17 (cinematic world + first-person controller) + P18 (persistence round-trip),
scoped to the SMALLEST provable vertical slice. This is P17b: the minimum that proves the pillar and passes
the P18 gate, on a PROXY splat, with ZERO new sim logic.

---

## The one thing this proves

> A telegraphed betrayal (P10b) can be **walked into** as a constrained first-person splat scene, the
> player's in-scene choice writes back to authoritative `GameState`, and that change **survives save/load**
> before and after the scene. Visually attractive but non-persistent = FAIL (brief §19).

Everything else is cut. No combat, no jumping, no second character, no second interaction, no real Marble
world (proxy `bench_542k.ply`), no provider abstraction (splat renders TODAY via GDGS — proven; a
`CinematicWorldProvider` interface is overengineering until a mesh fallback is actually needed).

---

## Hard invariants (do not violate — the gate checks these)

1. **ZERO new simulation logic.** The scene READS `GameState` and CALLS the existing
   `RelationshipService.reassure(c)`. It writes NOTHING to sim state directly. All consequence flows
   through `reassure()`, which already mutates `public_trust`, `shared_success`, `clean_capital`,
   `motive_revealed` (relationship_service.gd:73-83). Walking away calls nothing — the intent stays open
   and lands on its normal countdown.
2. **ZERO RNG.** No `randf`/`randi`/`randomize`/`RandomNumberGenerator` anywhere in the new files. The
   scene is pure input→existing-deterministic-verb. The integration test source-scans for this.
3. **No sim state in scene nodes** (brief §13.2). The scene holds only presentation + which character id it
   is confronting. The character it confronts is passed in by id; it re-fetches via `GameState.get_character`.
4. **Save-additive.** No new persisted fields are required — `reassure()` mutates already-persisted
   CharacterData/FactionData fields. `SAVE_VERSION` stays 1. (If a "scene was entered" flag is wanted for
   telemetry, it is OPTIONAL and additive via `d.get(key, default)`; default OFF, skip it unless trivial.)
5. **One splat resident at a time** (brief §7.7). The scene loads exactly one PLY; the city scene is hidden
   (not freed — see round-trip) while it is up.
6. **Deterministic scene lighting** — the splat is baked; the lieutenant proxy + tell object are
   conventional 3D lit by scene lights. Fine for greybox (a capsule + a box).

---

## Files

### New
- `scenes/cinematic/reveal_scene.gd` + `.tscn` — the constrained first-person confrontation scene.
- `scenes/cinematic/reveal_controller.gd` — walk-only first-person controller (no jump, no combat),
  OR fold into reveal_scene.gd if it stays under ~60 lines. Prefer one file if small.
- `src/presentation/cinematic_transition.gd` — the enter/resolve round-trip helper (autoload OR a plain
  RefCounted invoked from bootstrap; see "Round-trip" — Fable picks the simplest that the test can drive
  headless). This is the P18 core.
- `tests/unit/test_reveal_persistence_p17b.gd` + `.tscn` + `.uid` — the GATE test (integration-style,
  headless, run via `.tscn`).

### Modified
- `scenes/bootstrap/bootstrap.gd` — wire the trigger: on `RelationshipService.betrayal_telegraphed`, expose
  a "Confront" affordance (a HUD button/label is fine — greybox); clicking it calls the transition helper.
  Also pause the strategic sim on enter, resume on resolve (`TimeService.set_speed(PAUSED)` / restore).
- `scenes/ui/hud.gd` — the "Confront <name>" affordance when a betrayal is telegraphed (greybox: a button
  that emits which character id to confront). Keep it minimal.
- `src/save/save_codec.gd` — ONLY if an optional telemetry flag is added (default: DO NOT touch it; the
  gate needs no new save field).

---

## The scene (reveal_scene.gd)

Entry contract: `setup(character_id: StringName)` before the scene is shown. It:
1. Loads `res://assets/splat/bench_542k.ply` as the splat resident (same GDGS setup as splat_bench.gd:24-36
   — GaussianSplatNode + the gaussian_compositor_effect compositor). This is the PROXY world.
2. Spawns a conventional-3D **lieutenant proxy** (a capsule mesh) at a fixed mark, and a **tell object**
   (a small box) near it — the physical "tell" the player inspects.
3. First-person camera constrained to a small validated volume (a hard AABB clamp in code — no anchors.json
   needed for the proxy; hardcode a ~4×4×4 box around the splat center, mirroring splat_bench's aabb math).
   Walk-only: WASD + mouse look, NO jump, NO gravity-fall-through, NO combat.
4. Re-fetches the character via `GameState.get_character(character_id)`. Reads `betrayal_driving_motive`,
   `motive_revealed`, `betrayal_ticks_until_land` for the on-screen tell text (e.g. "Ticks to betrayal: N",
   and after reveal, the driving motive).

Interaction (ONE decision, brief §12.3):
- Walk to the tell object → an "Inspect" prompt appears (proximity + a key, e.g. E).
- Inspecting surfaces the tell (the visible motive state; if `motive_revealed` is already true, show the
  driving motive; else show "something is off — sit down with them").
- Then ONE choice, two verbs:
  - **[Reassure]** → calls `RelationshipService.reassure(character)`. On success: `motive_revealed` flips
    true, trust/shared_success rise, clean_capital drops (the sit-down). The scene shows the now-revealed
    driving motive, then exits.
  - **[Walk away]** → exits with NO call. The intent stays open; it lands on its normal countdown in the
    sim after the scene closes. This is a real choice with a real consequence (the betrayal proceeds).
- Reassure must respect its cost gate: if `reassure()` returns false (not enough clean capital), show
  "can't afford the sit-down" and leave the choice open (player can still walk away).

The scene emits a signal `reveal_resolved(character_id, reassured: bool)` (or calls back into the
transition helper) so the round-trip can tear down and restore the city + resume the sim.

---

## The round-trip (cinematic_transition.gd) — the P18 core

This is the persistence loop (brief §14.2). Keep it headless-drivable (the test calls it without a real
window — so the actual node-swap must be guarded/injectable, but the STATE effects must run in the test).

`enter(character_id)`:
1. `TimeService.set_speed(BM.Speed.PAUSED)` — pause the strategic sim.
2. (Optional checkpoint save — the gate tests save/load explicitly, so an internal checkpoint is not
   required for the gate. Skip unless trivial.)
3. Hide (not free) the city scene; instance + show `reveal_scene.tscn`, call `setup(character_id)`.

`resolve(character_id, reassured)`:
1. The consequence is ALREADY written (reassure() ran inside the scene, or nothing ran on walk-away).
2. Free the reveal scene; un-hide the city scene.
3. Restore `TimeService` speed (to PAUSED — the player resumes deliberately, matching bootstrap's
   start-paused rule, brief §5.1).

**Separation for testability:** the pure state effect of "confront + reassure" is just
`RelationshipService.reassure(GameState.get_character(id))`. The test drives THAT + a save/load, and does
NOT need to instance the 3D scene. The transition node's job is only the presentation swap. So structure
`cinematic_transition.gd` such that the sim-effect path and the node-swap path are separable, and the test
exercises the sim-effect path. (If you make it an autoload, the node-swap must no-op cleanly when there is
no city scene / no window — headless.)

---

## The GATE test (test_reveal_persistence_p17b.gd) — THIS is what Claude re-runs

Run via `.tscn` (autoloads must load — the `-s` script path does NOT load them; that is a known trap).
Must exit 0 on pass. Structure (each `_test_*` prints PASS/FAIL, aggregate at the end):

1. **`_test_reveal_writes_persistent_state`**: seed a lieutenant with an open telegraphed intent + enough
   clean capital. Snapshot trust/shared_success/clean_capital/motive_revealed. Confront + reassure. Assert
   ALL four changed as reassure() specifies (trust↑, shared↑, capital↓, motive_revealed=true). Proves the
   scene's choice changes persistent strategic state (brief §19).
2. **`_test_persist_survives_save_load_AFTER`**: after the reassure above, `SaveCodec.encode` →
   `SaveCodec.decode` → new GameState. Assert the reassured character's revealed motive + raised
   trust/shared_success survive the round-trip. This is the core P18 assertion.
3. **`_test_persist_survives_save_load_BEFORE`**: seed the telegraphed intent, save BEFORE any confront,
   load, THEN confront+reassure on the loaded state, save AFTER, load again. Assert state consistent
   throughout (the telegraph survives the before-save; the reveal survives the after-save). Brief §19:
   "survive save/load both before AND after."
4. **`_test_walk_away_leaves_intent_open`**: confront + walk away (no reassure call). Assert
   `betrayal_ticks_until_land` unchanged (intent still open) and `motive_revealed` still false. Proves
   walk-away is a real, consequential non-choice.
5. **`_test_reassure_cost_gate_respected`**: lieutenant telegraphed, player faction with clean_capital <
   REASSURE_COST_CLEAN. Confront + attempt reassure. Assert it returns false, no state mutated, intent
   still open. Proves the scene can't dodge the sim's cost rule.
6. **`_test_no_rng_in_scene_sources`**: source-scan `reveal_scene.gd`, `reveal_controller.gd` (if separate),
   `cinematic_transition.gd` for `randf`/`randi`/`randomize`/`RandomNumberGenerator`. Assert none. (The
   existing test files do this pattern — copy it.)

The test drives the SIM-EFFECT path (reassure + save/load), NOT the 3D node instancing — so it runs clean
headless. If any assertion needs the scene node, guard it so headless still exits 0.

---

## Out of scope (explicit cuts — brief §12.3, do not add)

- Real Marble splat world (Month-4 asset production — proxy bench PLY only here).
- `CinematicWorldProvider` / mesh fallback interface (splat renders today; add the interface only when a
  fallback is actually built).
- anchors.json / collider.glb pipeline (hardcode the camera volume for the proxy).
- More than one interaction, one character, one tell object.
- Any second sequence type (crime-scene / walk-and-talk / council — brief lists them; the slice ships ONE).
- New save fields (unless a trivial optional telemetry flag; default: none).
- LUT / scene grading polish (P19 territory).

---

## Verify (Claude's gate — I re-run all of this myself; green-by-claim is not green)

```sh
GODOT="D:/Godot/Godot_v4.7-stable_win64_console.exe"
"$GODOT" --headless --path . --import                                    # parse/import clean
"$GODOT" --headless --path . tests/unit/test_reveal_persistence_p17b.tscn  # GATE (exit 0, all PASS)
"$GODOT" --headless --path . tests/unit/test_loyalty_p10b.tscn           # P10b still green (no regression)
"$GODOT" --headless --path . --quit-after 120 2>&1 | grep -iE "SCRIPT ERROR|ERROR:|Nonexistent"  # boot smoke (empty)
grep -rnE "randf|randi|randomize|RandomNumberGenerator" scenes/cinematic src/presentation/cinematic_transition.gd  # empty in new files
```

Plus: I READ `reveal_scene.gd` + `cinematic_transition.gd` end to end (no sim state owned by scene, all
consequence via reassure()), and confirm the save round-trip assertions actually assert persistence (not
tautologies). Manual editor F5 walk-through is deferred to Cem (feel), not part of the headless gate.
