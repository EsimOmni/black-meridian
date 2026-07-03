extends Node
## P10 unit test — loyalty motive network + telegraphed, preventable betrayal (§7.6).
## Run as a scene, NOT via -s (-s skips autoloads):
##   Godot --headless --path . res://tests/unit/test_loyalty.tscn

var _failures := 0
var _rs: RelationshipService
var _telegraphs := 0
var _defused := 0
var _committed := 0
var _committed_venue: VenueData

func _ready() -> void:
	_rs = RelationshipService.new()
	add_child(_rs)
	_rs.betrayal_telegraphed.connect(func(_c): _telegraphs += 1)
	_rs.betrayal_defused.connect(func(_c): _defused += 1)
	_rs.betrayal_committed.connect(func(_c, v): _committed += 1; _committed_venue = v)
	_test_no_rng_in_loyalty()
	_test_pressure_alone_does_not_telegraph()
	_test_opportunity_alone_does_not_telegraph()
	_test_both_gates_telegraph_then_land_after_window()
	_test_reassure_defuses_within_window()
	_test_removing_opportunity_defuses()
	_test_determinism()
	_test_council_gates_new_telegraph_open_one_lands()
	_test_open_intent_survives_save_load()
	if _failures == 0:
		print("[PASS] all loyalty tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d loyalty assertion(s) failed" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("  assertion failed: ", msg)

func _fresh_world() -> CharacterData:
	WorldSeed.build()
	TimeService.set_speed(BM.Speed.PAUSED)
	TimeService.tick_index = 0
	JobDirector.active_jobs = []
	JobDirector.pending_followups = []
	# Neutralize the rival deterministically (scores fall below COMMIT_THRESHOLD) so
	# its sabotage/intents never inject opportunity into these controlled scenarios.
	var corvine := GameState.get_faction(&"corvine")
	corvine.aggression = 0.0
	corvine.cunning = 0.0
	_telegraphs = 0
	_defused = 0
	_committed = 0
	_committed_venue = null
	return GameState.get_character(&"bengal_lt")

func _pump(n: int) -> void:
	for i in n:
		TimeService._do_tick()

## pressure = 0.9 + 0.9 + 0.5 + 0 - 0.1 - 0 - 0.2 = 2.0  (>= threshold band 1.4)
func _arm_pressure_strong(c: CharacterData) -> void:
	c.ambition = 0.9
	c.grievance = 0.9
	c.rival_leverage = 0.5
	c.public_trust = 0.1

## pressure = 0.7 + 0.85 + 0.4 + 0 - 0.25 - 0 - 0.2 = 1.5 — clearly over the 1.4 band
## (never sit exactly on a float threshold), and one reassure (-0.3) drops it to 1.2.
func _arm_pressure_mild(c: CharacterData) -> void:
	c.ambition = 0.7
	c.grievance = 0.85
	c.rival_leverage = 0.4
	c.public_trust = 0.25

func _open_opportunity() -> DistrictData:
	var d := GameState.get_district(&"glass_wharf")
	d.inspection_ticks = 500  # the faction is visibly pinned — opportunity 0.35 >= 0.3
	d.inspection_armed = false
	return d

## House style: betrayal is never a dice roll (§7.6) — no randomness in the machine.
func _test_no_rng_in_loyalty() -> void:
	for path in ["res://src/simulation/loyalty_scoring.gd",
			"res://src/simulation/relationship_service.gd"]:
		var text := FileAccess.get_file_as_string(path)
		_check(text != "", "%s readable" % path)
		_check(not ("randf" in text) and not ("randi" in text) and not ("randomize" in text),
			"%s contains no RNG calls" % path)

func _test_pressure_alone_does_not_telegraph() -> void:
	var bengal := _fresh_world()
	_arm_pressure_strong(bengal)
	_check(bengal.pressure_exceeds_threshold(), "setup guard: pressure is over the threshold")
	_check(LoyaltyScoring.betrayal_opportunity(bengal, GameState.districts, GameState.factions)
		< LoyaltyScoring.OPPORTUNITY_THRESHOLD, "setup guard: no opportunity present")
	_pump(30)
	_check(_telegraphs == 0, "pressure without opportunity NEVER telegraphs (got %d)" % _telegraphs)

func _test_opportunity_alone_does_not_telegraph() -> void:
	var bengal := _fresh_world()
	_open_opportunity()
	_check(not bengal.pressure_exceeds_threshold(), "setup guard: seeded pressure is below threshold")
	_check(LoyaltyScoring.betrayal_opportunity(bengal, GameState.districts, GameState.factions)
		>= LoyaltyScoring.OPPORTUNITY_THRESHOLD, "setup guard: opportunity present")
	_pump(30)
	_check(_telegraphs == 0, "opportunity without pressure NEVER telegraphs (got %d)" % _telegraphs)

func _test_both_gates_telegraph_then_land_after_window() -> void:
	var bengal := _fresh_world()
	_arm_pressure_strong(bengal)
	_open_opportunity()
	_pump(10)  # first rival tick
	_check(_telegraphs == 1, "both gates held -> telegraph on the first rival tick (got %d)" % _telegraphs)
	_check(_committed == 0, "nothing lands on the telegraph tick")
	_check(bengal.betrayal_ticks_until_land == LoyaltyScoring.TELEGRAPH_LEAD_RIVAL_TICKS,
		"the defusal window opened at the full lead")
	_pump(50)  # five of the six lead rival ticks
	_check(_committed == 0, "still inside the window: no landing")
	_pump(10)  # the sixth — the lead elapses
	_check(_committed == 1, "the betrayal lands exactly when the lead elapses (got %d)" % _committed)
	_check(_telegraphs == 1, "no re-telegraph during the window")
	_check(_committed_venue != null and _committed_venue.id == &"gw_contraband",
		"the deterministic target: the first player racket")
	_check(_committed_venue.control_state == BM.ControlState.CONTESTED,
		"the landed effect: the lieutenant's ground defects to CONTESTED")
	_check(bengal.betrayal_ticks_until_land == -1, "the intent closed after landing")
	_check(bengal.grievance == 0.0 and bengal.rival_leverage == 0.0,
		"the act discharges the motives that drove it")
	_pump(60)  # a full further window
	_check(_committed == 1 and _telegraphs == 1,
		"discharged motives: the crisis does not instantly re-arm")

func _test_reassure_defuses_within_window() -> void:
	var bengal := _fresh_world()
	_arm_pressure_mild(bengal)
	_open_opportunity()
	_pump(10)
	_check(_telegraphs == 1, "mild-pressure setup telegraphs")
	var pf := GameState.player_faction()
	var clean_before := pf.clean_capital
	_check(_rs.reassure(bengal), "the reassure verb succeeds with enough clean capital")
	_check(pf.clean_capital == clean_before - LoyaltyScoring.REASSURE_COST_CLEAN,
		"reassure costs clean capital")
	_pump(10)  # the next gate re-check
	_check(_defused == 1, "raised trust/shared_success -> the intent DEFUSES (got %d)" % _defused)
	_check(bengal.betrayal_ticks_until_land == -1, "the window closed cleanly")
	_pump(100)
	_check(_committed == 0, "a defused betrayal never lands")

func _test_removing_opportunity_defuses() -> void:
	var bengal := _fresh_world()
	_arm_pressure_strong(bengal)
	var d := _open_opportunity()
	_pump(10)
	_check(_telegraphs == 1, "setup telegraphs")
	d.inspection_ticks = 0  # the inspectors leave — the opening is gone
	_pump(10)
	_check(_defused == 1, "opportunity removed -> the intent DEFUSES despite high pressure")
	_pump(100)
	_check(_committed == 0, "no landing without the opening, ever")

func _test_determinism() -> void:
	var bengal := _fresh_world()
	_arm_pressure_strong(bengal)
	_open_opportunity()
	_pump(40)
	var first := [_telegraphs, _committed, bengal.betrayal_ticks_until_land]
	bengal = _fresh_world()
	_arm_pressure_strong(bengal)
	_open_opportunity()
	_pump(40)
	var second := [_telegraphs, _committed, bengal.betrayal_ticks_until_land]
	_check(first == second, "same state + same ticks -> same decision (%s vs %s)" % [first, second])

func _test_council_gates_new_telegraph_open_one_lands() -> void:
	var bengal := _fresh_world()
	_arm_pressure_strong(bengal)
	_open_opportunity()
	GameState.phase = BM.Phase.COUNCIL
	_pump(30)
	_check(_telegraphs == 0, "no NEW betrayal telegraph opens mid-Council (got %d)" % _telegraphs)
	GameState.phase = BM.Phase.OPERATIONS
	_pump(10)
	_check(_telegraphs == 1, "the telegraph opens once OPERATIONS begins")
	GameState.phase = BM.Phase.COUNCIL  # the promise stays deterministic (§7.6)
	_pump(60)
	_check(_committed == 1, "an already-open intent still counts down and lands in Council")

func _test_open_intent_survives_save_load() -> void:
	var bengal := _fresh_world()
	_arm_pressure_strong(bengal)
	_open_opportunity()
	_pump(10)
	_check(bengal.betrayal_ticks_until_land == LoyaltyScoring.TELEGRAPH_LEAD_RIVAL_TICKS,
		"setup guard: an intent is open")
	_check(SaveService.save_game("p10_test"), "save mid-window")
	bengal.betrayal_ticks_until_land = -1
	bengal.grievance = 0.0
	_check(SaveService.load_game("p10_test"), "load")
	var restored := GameState.get_character(&"bengal_lt")  # load rebuilds the instances
	_check(restored.betrayal_ticks_until_land == LoyaltyScoring.TELEGRAPH_LEAD_RIVAL_TICKS,
		"the open intent round-trips (got %d)" % restored.betrayal_ticks_until_land)
	_check(restored.grievance == 0.9, "motive floats round-trip exactly")
	_pump(60)  # the machine continues against the restored state
	_check(_committed == 1, "the restored intent lands on the same deterministic schedule")
