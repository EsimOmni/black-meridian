extends Node
## P09 unit test — Night Cycle phase machine (brief §5.2/§13.2).
## Run as a scene, NOT via -s (-s skips autoloads):
##   Godot --headless --path . res://tests/unit/test_night_cycle.tscn

var _failures := 0
var _nc: NightCycle
var _advances: Array = []  # [cycle, phase] per night_cycle_advanced emit
var _telegraphs := 0

func _ready() -> void:
	GameState.night_cycle_advanced.connect(func(c, p): _advances.append([c, p]))
	RivalDirector.rival_intent_telegraphed.connect(func(_f, _v, _a): _telegraphs += 1)
	_nc = NightCycle.new()
	add_child(_nc)
	_test_no_rng_in_phase_machine()
	_test_cycle_starts_at_council()
	_test_phase_budget_boundaries()
	_test_full_cycle_advances_and_rolls_over()
	_test_same_tick_count_same_phase()
	_test_council_gates_rival_commits_operations_resumes()
	_test_economy_still_settles_in_council()
	_test_phase_state_survives_save_load()
	if _failures == 0:
		print("[PASS] all night cycle tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d night cycle assertion(s) failed" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("  assertion failed: ", msg)

func _fresh_world() -> DistrictData:
	WorldSeed.build()
	TimeService.set_speed(BM.Speed.PAUSED)
	TimeService.tick_index = 0
	JobDirector.active_jobs = []
	JobDirector.pending_followups = []
	_nc.start_cycle()
	_advances.clear()
	_telegraphs = 0
	return GameState.get_district(&"glass_wharf")

func _pump(n: int) -> void:
	for i in n:
		TimeService._do_tick()

## House style: no randomness in phase advancement — same ticks -> same phase.
func _test_no_rng_in_phase_machine() -> void:
	var text := FileAccess.get_file_as_string("res://src/simulation/night_cycle.gd")
	_check(text != "", "night_cycle.gd readable")
	_check(not ("randf" in text) and not ("randi" in text) and not ("randomize" in text),
		"night_cycle.gd contains no RNG calls")

func _test_cycle_starts_at_council() -> void:
	_fresh_world()
	_check(GameState.phase == BM.Phase.COUNCIL and GameState.phase_ticks == 0,
		"a cycle starts at COUNCIL with a zeroed phase clock")

func _test_phase_budget_boundaries() -> void:
	_fresh_world()
	_pump(NightCycle.phase_budget(BM.Phase.COUNCIL) - 1)
	_check(GameState.phase == BM.Phase.COUNCIL, "one tick short of the budget: still COUNCIL")
	_pump(1)
	_check(GameState.phase == BM.Phase.OPERATIONS and GameState.phase_ticks == 0,
		"COUNCIL -> OPERATIONS exactly on its %d-tick budget" % NightCycle.phase_budget(BM.Phase.COUNCIL))
	_pump(NightCycle.phase_budget(BM.Phase.OPERATIONS) - 1)
	_check(GameState.phase == BM.Phase.OPERATIONS, "still OPERATIONS one tick short")
	_pump(1)
	_check(GameState.phase == BM.Phase.CRISIS, "OPERATIONS -> CRISIS on budget")

func _test_full_cycle_advances_and_rolls_over() -> void:
	_fresh_world()
	var total := 0
	for phase in NightCycle.PHASE_ORDER:
		total += NightCycle.phase_budget(phase)
	_pump(total)
	_check(GameState.night_cycle == 2, "a full %d-tick episode rolls into Night Cycle 2" % total)
	_check(GameState.phase == BM.Phase.COUNCIL, "the new cycle convenes at COUNCIL")
	var expected := [
		[1, BM.Phase.OPERATIONS], [1, BM.Phase.CRISIS], [1, BM.Phase.RECKONING],
		[2, BM.Phase.COUNCIL],
	]
	_check(_advances == expected,
		"night_cycle_advanced fired at each transition in order (got %s)" % [_advances])

func _test_same_tick_count_same_phase() -> void:
	_fresh_world()
	_pump(700)
	var first := [GameState.night_cycle, GameState.phase, GameState.phase_ticks]
	_fresh_world()
	_pump(700)
	var second := [GameState.night_cycle, GameState.phase, GameState.phase_ticks]
	_check(first == second, "same tick count -> same phase state (%s vs %s)" % [first, second])
	_check(second == [1, BM.Phase.OPERATIONS, 700 - NightCycle.phase_budget(BM.Phase.COUNCIL)],
		"700 ticks map to the expected point in OPERATIONS")

func _test_council_gates_rival_commits_operations_resumes() -> void:
	var d := _fresh_world()
	d.inspection_ticks = 200  # strong, visible weakness — would commit in OPERATIONS
	d.inspection_armed = false
	_pump(30)  # three rival ticks, all inside COUNCIL
	_check(_telegraphs == 0, "no NEW telegraph opens mid-Council (got %d)" % _telegraphs)
	_pump(NightCycle.phase_budget(BM.Phase.COUNCIL) - 30)  # cross into OPERATIONS
	_check(GameState.phase == BM.Phase.OPERATIONS, "crossed into OPERATIONS")
	d.inspection_ticks = 200  # re-arm the weakness (it decayed during the fast-forward)
	d.inspection_armed = false
	_pump(10)  # one rival tick in OPERATIONS
	_check(_telegraphs == 1, "the rival resumes committing in OPERATIONS (got %d)" % _telegraphs)

func _test_economy_still_settles_in_council() -> void:
	_fresh_world()
	var pf := GameState.player_faction()
	var dirty_before := pf.dirty_cash
	_pump(5)  # all inside COUNCIL
	_check(pf.dirty_cash > dirty_before,
		"per-tick income still accrues during COUNCIL (P09 architectural rule)")
	_check(int(_nc.summary()["dirty_earned"]) > 0, "the cycle summary tallies settled income")

func _test_phase_state_survives_save_load() -> void:
	_fresh_world()
	_pump(NightCycle.phase_budget(BM.Phase.COUNCIL) + 37)  # 37 ticks into OPERATIONS
	_check(SaveService.save_game("p09_test"), "save mid-phase")
	GameState.phase = BM.Phase.COUNCIL
	GameState.phase_ticks = 0
	GameState.night_cycle = 9
	_check(SaveService.load_game("p09_test"), "load")
	_check(GameState.night_cycle == 1 and GameState.phase == BM.Phase.OPERATIONS
		and GameState.phase_ticks == 37,
		"night_cycle + phase + phase clock round-trip through meta (got cycle %d, phase %d, ticks %d)"
		% [GameState.night_cycle, GameState.phase, GameState.phase_ticks])
