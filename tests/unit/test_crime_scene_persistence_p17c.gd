extends Node
## P17c GATE test — the crime-scene's choice (remove the planted evidence) routes
## through the EXISTING EvidenceMath.remove_case verb, writes persistent district
## state, and survives save/load before AND after the scene (the same P18 gate P17b
## passed, for the second sequence type). Drives the SIM-EFFECT path
## (CinematicTransition.try_remove_evidence + save/load) — never the 3D node swap
## (city_root stays null → clean headless no-op). Run as a scene, NOT via -s
## (-s skips autoloads):
##   Godot --headless --path . res://tests/unit/test_crime_scene_persistence_p17c.tscn

var _failures := 0
var _ct: CinematicTransition

func _ready() -> void:
	_ct = CinematicTransition.new()
	add_child(_ct)  # city_root stays null — headless: enter/resolve only pause the sim
	_test_remove_writes_persistent_state()
	_test_persist_survives_save_load_AFTER()
	_test_persist_survives_save_load_BEFORE()
	_test_leave_keeps_case()
	_test_remove_missing_case_is_noop()
	_test_no_rng_in_scene_sources()
	if _failures == 0:
		print("[PASS] all P17c crime-scene persistence tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d P17c assertion(s) failed" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("  assertion failed: ", msg)

func _fresh_world() -> void:
	WorldSeed.build()
	TimeService.set_speed(BM.Speed.PAUSED)
	TimeService.tick_index = 0
	JobDirector.active_jobs = []
	JobDirector.pending_followups = []
	# Neutralize the rival deterministically (same as test_reveal_persistence_p17b) —
	# no rival intents or sabotage mutate districts under these controlled scenarios.
	var corvine := GameState.get_faction(&"corvine")
	corvine.aggression = 0.0
	corvine.cunning = 0.0

## Seed a case exactly as the P06b job flow deposits one. Distinct ticks guarantee
## distinct case ids (id = case@district@kind@tick) regardless of the hashed kind.
func _seed_case(d: DistrictData, weight: float, source: StringName,
		tick: int) -> EvidenceCaseData:
	return EvidenceMath.deposit(d, weight, source, tick)

## 1. The in-scene choice changes persistent strategic state (brief §19): the case
## is gone from district.evidence_cases and the combined-pressure latch eased.
func _test_remove_writes_persistent_state() -> void:
	_fresh_world()
	var d := GameState.get_district(&"glass_wharf")
	var c := _seed_case(d, 0.6, &"p17c_seed", 1)
	_check(c != null, "setup: the seeded case exists")
	var pressure0 := EvidenceMath.combined_pressure(d.local_heat, d.evidence_cases)
	_ct.enter_crime_scene(&"glass_wharf")
	var ok := _ct.try_remove_evidence(&"glass_wharf", c.id)
	_ct.resolve_crime_scene(&"glass_wharf", c.id, ok)
	_check(ok, "remove_case succeeds on an open case")
	_check(EvidenceMath.find_case(d, c.id) == null, "the case is gone from the district")
	_check(EvidenceMath.combined_pressure(d.local_heat, d.evidence_cases) < pressure0,
		"combined pressure dropped — the latch eased")
	_check(TimeService.speed == BM.Speed.PAUSED,
		"the sim is restored to PAUSED — the player resumes deliberately")

## 2. The core P18 assertion: the removal survives save→load (scramble-before-load,
## no tautology), and an untouched case comes through intact.
func _test_persist_survives_save_load_AFTER() -> void:
	_fresh_world()
	var d := GameState.get_district(&"glass_wharf")
	var a := _seed_case(d, 0.6, &"p17c_a", 1)
	var b := _seed_case(d, 0.3, &"p17c_b", 2)
	var b_weight := b.weight
	_ct.enter_crime_scene(&"glass_wharf")
	_check(_ct.try_remove_evidence(&"glass_wharf", a.id), "remove case A before saving")
	_ct.resolve_crime_scene(&"glass_wharf", a.id, true)
	_check(SaveService.save_game("p17c_after"), "save AFTER the crime-scene")
	# Scramble live state so the load has to do the actual work (no tautology):
	# re-add a junk case AND distort the survivor's weight.
	_seed_case(d, 0.9, &"p17c_junk", 99)
	b.weight = 0.01
	_check(SaveService.load_game("p17c_after"), "load")
	var rd := GameState.get_district(&"glass_wharf")
	_check(EvidenceMath.find_case(rd, a.id) == null,
		"the removed case is STILL gone after save/load")
	var rb := EvidenceMath.find_case(rd, b.id)
	_check(rb != null, "the untouched case survives save/load")
	_check(rb != null and is_equal_approx(rb.weight, b_weight),
		"the untouched case's weight survives save/load")
	_check(rd.evidence_cases.size() == 1, "the junk scramble case did not survive the load")

## 3. Brief §19: survive save/load BEFORE the scene too — save mid-pressure, load,
## remove on the LOADED state, save again, load again; consistent throughout.
func _test_persist_survives_save_load_BEFORE() -> void:
	_fresh_world()
	var d := GameState.get_district(&"glass_wharf")
	var c := _seed_case(d, 0.5, &"p17c_before", 1)
	var cid := c.id
	var c_weight := c.weight
	_check(SaveService.save_game("p17c_before"), "save BEFORE any walk-through")
	# Scramble: wipe the live case list so the load has to restore it.
	d.evidence_cases = [] as Array[EvidenceCaseData]
	_check(SaveService.load_game("p17c_before"), "load the pre-scene save")
	var rd := GameState.get_district(&"glass_wharf")
	var rc := EvidenceMath.find_case(rd, cid)
	_check(rc != null, "the seeded case survives the before-save")
	_check(rc != null and is_equal_approx(rc.weight, c_weight),
		"the case weight survives the before-save")
	_ct.enter_crime_scene(&"glass_wharf")
	_check(_ct.try_remove_evidence(&"glass_wharf", cid), "remove on the LOADED state")
	_ct.resolve_crime_scene(&"glass_wharf", cid, true)
	_check(SaveService.save_game("p17c_before2"), "save AFTER the removal on loaded state")
	_seed_case(GameState.get_district(&"glass_wharf"), 0.7, &"p17c_junk2", 50)  # scramble again
	_check(SaveService.load_game("p17c_before2"), "load again")
	var rd2 := GameState.get_district(&"glass_wharf")
	_check(EvidenceMath.find_case(rd2, cid) == null,
		"the removal stays consistent throughout")
	_check(rd2.evidence_cases.is_empty(), "no scramble residue after the final load")

## 4. Leaving is a real non-choice: nothing is called, the case stands, the sweep
## keeps coming (combined pressure unchanged).
func _test_leave_keeps_case() -> void:
	_fresh_world()
	var d := GameState.get_district(&"glass_wharf")
	var c := _seed_case(d, 0.6, &"p17c_leave", 1)
	var weight0 := c.weight
	var pressure0 := EvidenceMath.combined_pressure(d.local_heat, d.evidence_cases)
	_ct.enter_crime_scene(&"glass_wharf")
	_ct.resolve_crime_scene(&"glass_wharf", c.id, false)  # leave: NO verb call
	var rc := EvidenceMath.find_case(d, c.id)
	_check(rc != null, "the case stands after leaving")
	_check(rc != null and is_equal_approx(rc.weight, weight0), "the case weight is untouched")
	_check(is_equal_approx(
		EvidenceMath.combined_pressure(d.local_heat, d.evidence_cases), pressure0),
		"combined pressure is unchanged — the sweep keeps coming")
	_check(TimeService.speed == BM.Speed.PAUSED, "the sim is restored to PAUSED")

## 5. A missing case (already burned by a job) is a clean no-op — the scene cannot
## corrupt state it can no longer find. Same for a missing district.
func _test_remove_missing_case_is_noop() -> void:
	_fresh_world()
	var d := GameState.get_district(&"glass_wharf")
	var c := _seed_case(d, 0.6, &"p17c_noop", 1)
	var weight0 := c.weight
	var heat0 := d.local_heat
	_check(not _ct.try_remove_evidence(&"glass_wharf", &"case@glass_wharf@0@777"),
		"a case id that isn't there returns false")
	_check(not _ct.try_remove_evidence(&"no_such_district", c.id),
		"a district that isn't there returns false")
	_check(d.evidence_cases.size() == 1, "nothing was removed")
	_check(is_equal_approx(c.weight, weight0), "the open case is untouched")
	_check(is_equal_approx(d.local_heat, heat0), "district heat is untouched")

## 6. House style (§7.6): no RNG anywhere in the new scene sources.
func _test_no_rng_in_scene_sources() -> void:
	for path in ["res://scenes/cinematic/crime_scene.gd",
			"res://src/presentation/cinematic_transition.gd"]:
		var text := FileAccess.get_file_as_string(path)
		_check(text != "", "%s readable" % path)
		_check(not ("randf" in text) and not ("randi" in text)
			and not ("randomize" in text) and not ("RandomNumberGenerator" in text),
			"%s contains no RNG calls" % path)
