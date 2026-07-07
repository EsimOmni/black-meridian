extends Node
## P05b unit test — finite operative pool + assign/recall (the §7.2 staffing lever).
## Run as a scene, NOT via -s (-s skips autoloads):
##   Godot --headless --path . res://tests/unit/test_operative_pool_p05b.tscn

var _failures := 0

func _ready() -> void:
	_test_assign_moves_from_pool()
	_test_assign_clamps_to_free_pool()
	_test_recall_returns_to_pool()
	_test_ownership_gated()
	_test_income_follows_staffing()
	_test_pool_survives_save_load()
	_test_no_rng_in_operative_sources()
	if _failures == 0:
		print("[PASS] all P05b operative-pool tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d P05b assertion(s) failed" % _failures)
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

func _venue(id: StringName) -> VenueData:
	for district in GameState.districts:
		for v in district.venues:
			if v.id == id:
				return v
	return null

## The conservation invariant: assigned + free == pool total, and the total never moves.
func _check_conserved(f: FactionData, expected_total: int, label: String) -> void:
	_check(f.operative_pool == expected_total,
		"%s: pool total invariant (%d != %d)" % [label, f.operative_pool, expected_total])
	var assigned := OperativeMath.assigned_sum(f, GameState.districts)
	var free := OperativeMath.free_pool(f, GameState.districts)
	_check(assigned + free == f.operative_pool,
		"%s: assigned(%d) + free(%d) == pool(%d)" % [label, assigned, free, f.operative_pool])
	_check(free >= 0, "%s: free pool never negative (%d)" % [label, free])
	_check(assigned <= f.operative_pool,
		"%s: assigned(%d) <= pool(%d)" % [label, assigned, f.operative_pool])

func _test_assign_moves_from_pool() -> void:
	_fresh_world()
	var pf := GameState.player_faction()
	var v := _venue(&"gw_protection")
	# Seed check: Compact assigns 3+2+2 = 7, pool = 7 + FREE_RESERVE(2) = 9, free = 2.
	_check(pf.operative_pool == 9, "seeded pool = assigned_sum + FREE_RESERVE (got %d)" % pf.operative_pool)
	var total := pf.operative_pool
	var staff_before := v.operational_staff
	var free_before := EconomyService.free_operatives(pf)
	_check(free_before == WorldSeed.FREE_RESERVE, "seeded free pool == FREE_RESERVE")
	var got := EconomyService.assign_operatives(v, pf, 2)
	_check(got == 2, "assign(2) returns 2 (got %d)" % got)
	_check(v.operational_staff == staff_before + 2, "venue staff rose by 2")
	_check(EconomyService.free_operatives(pf) == free_before - 2, "free pool fell by 2")
	_check_conserved(pf, total, "assign")

func _test_assign_clamps_to_free_pool() -> void:
	_fresh_world()
	var pf := GameState.player_faction()
	var v := _venue(&"gw_gaming")
	# Shrink the pool so exactly 1 operative is free.
	pf.operative_pool = OperativeMath.assigned_sum(pf, GameState.districts) + 1
	var total := pf.operative_pool
	var got := EconomyService.assign_operatives(v, pf, 5)
	_check(got == 1, "assign(5) with free=1 assigns only 1 (got %d)" % got)
	_check(EconomyService.free_operatives(pf) == 0, "free pool exhausted to 0")
	var staff_after := v.operational_staff
	got = EconomyService.assign_operatives(v, pf, 5)
	_check(got == 0, "assign on an empty pool is a no-op returning 0 (got %d)" % got)
	_check(v.operational_staff == staff_after, "no phantom operatives appeared")
	_check_conserved(pf, total, "clamp")

func _test_recall_returns_to_pool() -> void:
	_fresh_world()
	var pf := GameState.player_faction()
	var v := _venue(&"gw_contraband")  # seeded staff 3
	var total := pf.operative_pool
	var free_before := EconomyService.free_operatives(pf)
	var got := EconomyService.recall_operatives(v, pf, 2)
	_check(got == 2, "recall(2) returns 2 (got %d)" % got)
	_check(v.operational_staff == 1, "venue staff fell to 1")
	_check(EconomyService.free_operatives(pf) == free_before + 2, "free pool rose by 2")
	got = EconomyService.recall_operatives(v, pf, 5)
	_check(got == 1, "recall beyond current staff clamps to what was there (got %d)" % got)
	_check(v.operational_staff == 0, "venue emptied, never negative")
	got = EconomyService.recall_operatives(v, pf, 1)
	_check(got == 0, "recall from an empty venue is a no-op returning 0 (got %d)" % got)
	_check_conserved(pf, total, "recall")

func _test_ownership_gated() -> void:
	_fresh_world()
	var pf := GameState.player_faction()
	var rival := GameState.get_faction(WorldSeed.CORVINE)
	var theirs := _venue(&"gw_clinic")      # Corvine-owned
	var ours := _venue(&"gw_protection")    # Compact-owned
	var their_staff := theirs.operational_staff
	var our_staff := ours.operational_staff
	var pf_free := EconomyService.free_operatives(pf)
	_check(EconomyService.assign_operatives(theirs, pf, 2) == 0, "assign to a rival venue is a no-op")
	_check(EconomyService.recall_operatives(theirs, pf, 2) == 0, "recall from a rival venue is a no-op")
	_check(EconomyService.assign_operatives(ours, rival, 2) == 0, "a rival cannot staff OUR venue")
	_check(EconomyService.recall_operatives(ours, rival, 2) == 0, "a rival cannot recall OUR staff")
	_check(theirs.operational_staff == their_staff and ours.operational_staff == our_staff,
		"nothing mutated by the gated calls")
	_check(EconomyService.free_operatives(pf) == pf_free, "player free pool untouched")

func _test_income_follows_staffing() -> void:
	_fresh_world()
	var pf := GameState.player_faction()
	var v := _venue(&"gw_contraband")
	var d := GameState.get_district(&"glass_wharf")
	var demand := d.district_demand()
	var baseline := EconomyMath.compute_dirty_income(v, demand)
	_check(baseline > 0, "baseline income is live (got %d)" % baseline)
	_check(EconomyService.assign_operatives(v, pf, 2) == 2, "assign +2 for the income probe")
	var boosted := EconomyMath.compute_dirty_income(v, demand)
	_check(boosted > baseline, "income rises with staff (%d -> %d)" % [baseline, boosted])
	_check(EconomyService.recall_operatives(v, pf, 2) == 2, "recall -2")
	var restored := EconomyMath.compute_dirty_income(v, demand)
	_check(restored == baseline, "income returns to baseline after recall (%d vs %d)" % [restored, baseline])

func _test_pool_survives_save_load() -> void:
	_fresh_world()
	var pf := GameState.player_faction()
	var v := _venue(&"gw_protection")
	_check(EconomyService.assign_operatives(v, pf, 1) == 1, "stage a non-seed staffing before saving")
	var saved_pool := pf.operative_pool
	var saved_staff := {}
	for district in GameState.districts:
		for venue in district.venues:
			saved_staff[venue.id] = venue.operational_staff
	_check(SaveService.save_game("p05b_test"), "save")
	# Scramble the live state so the load is proven to restore, not a tautology.
	pf.operative_pool = 999
	for district in GameState.districts:
		for venue in district.venues:
			venue.operational_staff = 77
	_check(SaveService.load_game("p05b_test"), "load")
	var restored := GameState.get_faction(WorldSeed.COMPACT)
	_check(restored.operative_pool == saved_pool,
		"operative_pool round-trips (%d vs %d)" % [restored.operative_pool, saved_pool])
	for district in GameState.districts:
		for venue in district.venues:
			_check(venue.operational_staff == saved_staff[venue.id],
				"%s operational_staff round-trips" % venue.id)
	# Additivity: a pre-P05b faction dict (no operative_pool key) decodes to the default 0.
	var legacy := SaveCodec.encode_faction(restored)
	legacy.erase("operative_pool")
	var old := SaveCodec.decode_faction(legacy)
	_check(old.operative_pool == 0, "pre-P05b saves load with operative_pool = 0 (additive)")

## House style: staffing is never a dice roll — no randomness in the verbs or their service.
func _test_no_rng_in_operative_sources() -> void:
	for path in ["res://src/simulation/operative_math.gd",
			"res://src/simulation/economy_service.gd"]:
		var text := FileAccess.get_file_as_string(path)
		_check(text != "", "%s readable" % path)
		_check(not ("randf" in text) and not ("randi" in text) and not ("randomize" in text)
			and not ("RandomNumberGenerator" in text),
			"%s contains no RNG calls" % path)
