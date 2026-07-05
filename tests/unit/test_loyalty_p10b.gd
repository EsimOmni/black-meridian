extends Node
## P10b unit test — multi-lieutenant betrayal + hidden motives (§7.6).
## Run as a scene, NOT via -s (-s skips autoloads):
##   Godot --headless --path . res://tests/unit/test_loyalty_p10b.tscn

var _failures := 0
var _rs: RelationshipService
var _telegraphs := 0
var _defused := 0
var _committed := 0
var _telegraphed_ids: Array = []
var _committed_venue_ids: Array = []

func _ready() -> void:
	_rs = RelationshipService.new()
	add_child(_rs)
	_rs.betrayal_telegraphed.connect(func(c): _telegraphs += 1; _telegraphed_ids.append(c.id))
	_rs.betrayal_defused.connect(func(_c): _defused += 1)
	_rs.betrayal_committed.connect(func(_c, v):
		_committed += 1
		_committed_venue_ids.append(v.id if v != null else &""))
	_test_no_rng_in_loyalty()
	_test_driving_motive_argmax()
	_test_cap_one_new_intent_per_rival_tick()
	_test_tie_breaks_to_authored_order()
	_test_two_intents_land_independently()
	_test_defuse_one_the_other_still_lands()
	_test_hidden_to_revealed_and_reset_on_new_telegraph()
	_test_save_roundtrip_p10b_fields()
	_test_determinism_multi()
	if _failures == 0:
		print("[PASS] all P10b loyalty tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d P10b assertion(s) failed" % _failures)
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
	# Neutralize the rival deterministically so its sabotage/intents never inject
	# opportunity into these controlled scenarios (same as test_loyalty).
	var corvine := GameState.get_faction(&"corvine")
	corvine.aggression = 0.0
	corvine.cunning = 0.0
	_telegraphs = 0
	_defused = 0
	_committed = 0
	_telegraphed_ids = []
	_committed_venue_ids = []

func _pump(n: int) -> void:
	for i in n:
		TimeService._do_tick()

## pressure = 0.9 + 0.9 + 0.5 - 0.1 - 0.2 = 2.0 (>= threshold band 1.4)
func _arm_strong(c: CharacterData) -> void:
	c.ambition = 0.9
	c.grievance = 0.9
	c.rival_leverage = 0.5
	c.public_trust = 0.1
	c.shared_success = 0.0
	c.fear = 0.2

## pressure = 0.7 + 0.85 + 0.4 - 0.25 - 0.2 = 1.5 — over the band; one reassure (-0.3) drops it under.
func _arm_mild(c: CharacterData) -> void:
	c.ambition = 0.7
	c.grievance = 0.85
	c.rival_leverage = 0.4
	c.public_trust = 0.25
	c.shared_success = 0.0
	c.fear = 0.2

func _venue(d: DistrictData, id: StringName) -> VenueData:
	for v in d.venues:
		if v.id == id:
			return v
	return null

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

func _test_driving_motive_argmax() -> void:
	var c := CharacterData.new()
	c.ambition = 0.2
	c.grievance = 0.9
	c.rival_leverage = 0.5
	c.survival_pressure = 0.1
	_check(LoyaltyScoring.driving_motive(c) == &"grievance",
		"the largest positive term drives (grievance)")
	c.survival_pressure = 0.95
	_check(LoyaltyScoring.driving_motive(c) == &"survival_pressure",
		"the largest positive term drives (survival_pressure)")
	c.ambition = 0.95  # exact tie with survival_pressure
	_check(LoyaltyScoring.driving_motive(c) == &"ambition",
		"ties resolve to the earlier term in the fixed order (ambition)")

func _test_cap_one_new_intent_per_rival_tick() -> void:
	_fresh_world()
	var bengal := GameState.get_character(&"bengal_lt")
	var regent := GameState.get_character(&"regent")
	_arm_strong(bengal)  # score 2.0 + 0.35 — opens first
	_arm_mild(regent)    # score 1.5 + 0.35 — opens on the NEXT rival tick
	_open_opportunity()
	_pump(10)  # first rival tick
	_check(_telegraphs == 1, "only ONE new telegraph per rival tick (got %d)" % _telegraphs)
	_check(bengal.betrayal_ticks_until_land == LoyaltyScoring.TELEGRAPH_LEAD_RIVAL_TICKS,
		"the higher score opens first")
	_check(regent.betrayal_ticks_until_land == -1, "the second candidate waits its tick")
	_pump(10)  # second rival tick
	_check(_telegraphs == 2, "the second lieutenant telegraphs on the next rival tick")
	_check(bengal.betrayal_ticks_until_land >= 0 and regent.betrayal_ticks_until_land >= 0,
		"BOTH intents are simultaneously open")
	_check(bengal.betrayal_ticks_until_land == regent.betrayal_ticks_until_land - 1,
		"each window counts down independently (staggered by one rival tick)")

func _test_tie_breaks_to_authored_order() -> void:
	_fresh_world()
	var bengal := GameState.get_character(&"bengal_lt")
	var regent := GameState.get_character(&"regent")
	_arm_strong(bengal)
	_arm_strong(regent)  # identical scores — authored order decides
	_open_opportunity()
	_pump(10)
	_check(_telegraphed_ids == [&"regent"],
		"equal scores tie-break to authored GameState order (regent precedes bengal_lt)")

func _test_two_intents_land_independently() -> void:
	_fresh_world()
	var bengal := GameState.get_character(&"bengal_lt")
	var regent := GameState.get_character(&"regent")
	_arm_strong(bengal)
	_arm_mild(regent)
	_open_opportunity()
	_pump(100)  # both open (ticks 1,2) and both land (ticks 7,8)
	_check(_telegraphs == 2, "two telegraphs, no re-arm after discharge (got %d)" % _telegraphs)
	_check(_committed == 2, "both intents land, each on its own schedule (got %d)" % _committed)
	_check(_committed_venue_ids == [&"gw_contraband", &"gw_protection"],
		"each landing takes the NEXT non-contested racket (got %s)" % str(_committed_venue_ids))
	var d := GameState.get_district(&"glass_wharf")
	_check(_venue(d, &"gw_contraband").control_state == BM.ControlState.CONTESTED
		and _venue(d, &"gw_protection").control_state == BM.ControlState.CONTESTED,
		"both defected venues read CONTESTED")

func _test_defuse_one_the_other_still_lands() -> void:
	_fresh_world()
	var bengal := GameState.get_character(&"bengal_lt")
	var regent := GameState.get_character(&"regent")
	_arm_strong(bengal)
	_arm_mild(regent)
	_open_opportunity()
	_pump(20)  # both open
	_check(bengal.betrayal_ticks_until_land >= 0 and regent.betrayal_ticks_until_land >= 0,
		"setup guard: both intents open")
	_check(_rs.reassure(regent), "reassure the mild-pressure lieutenant")
	_check(regent.motive_revealed, "the sit-down reveals the regent's driving motive")
	_check(not bengal.motive_revealed, "the OTHER lieutenant's motive stays hidden")
	_pump(10)  # regent's next gate re-check
	_check(_defused == 1, "the reassured intent defuses (got %d)" % _defused)
	_check(regent.betrayal_ticks_until_land == -1, "the regent's window closed")
	_check(bengal.betrayal_ticks_until_land >= 0, "bengal's intent is untouched by the defusal")
	_pump(70)
	_check(_committed == 1 and _committed_venue_ids == [&"gw_contraband"],
		"the un-defused intent still lands on its own schedule")

func _test_hidden_to_revealed_and_reset_on_new_telegraph() -> void:
	_fresh_world()
	var bengal := GameState.get_character(&"bengal_lt")
	bengal.ambition = 0.6
	bengal.grievance = 0.95
	bengal.rival_leverage = 0.5
	bengal.public_trust = 0.1  # pressure = 0.6+0.95+0.5-0.1-0.2 = 1.75
	_open_opportunity()
	_pump(10)
	_check(_telegraphs == 1, "setup telegraphs")
	_check(bengal.betrayal_driving_motive == &"grievance",
		"the driving motive is captured at telegraph time (argmax = grievance)")
	_check(not bengal.motive_revealed, "a new intent starts HIDDEN")
	_check(_rs.reassure(bengal), "reassure succeeds")
	_check(bengal.motive_revealed, "reassure reveals the driving motive")
	_check(bengal.betrayal_driving_motive == &"grievance", "the reveal does not rewrite the motive")
	# Post-reassure pressure = 1.75 - 0.3 = 1.45 — the gates still hold; the intent lands
	# and discharges grievance/rival_leverage.
	_pump(70)
	_check(_committed == 1, "the still-armed intent lands (got %d)" % _committed)
	# Re-arm on a DIFFERENT motive → the next telegraph recomputes and re-hides.
	bengal.ambition = 0.8
	bengal.rival_leverage = 0.9
	bengal.survival_pressure = 0.3
	bengal.public_trust = 0.1  # pressure = 0.8+0+0.9+0.3-0.1-0.15-0.2 = 1.55 (shared 0.15 from the reassure)
	_pump(10)
	_check(_telegraphs == 2, "the re-armed lieutenant telegraphs again")
	_check(bengal.betrayal_driving_motive == &"rival_leverage",
		"the new intent's driving motive is recomputed (rival_leverage)")
	_check(not bengal.motive_revealed, "every NEW intent starts hidden again")

func _test_save_roundtrip_p10b_fields() -> void:
	_fresh_world()
	var bengal := GameState.get_character(&"bengal_lt")
	bengal.ambition = 0.6
	bengal.grievance = 0.95
	bengal.rival_leverage = 0.5
	bengal.public_trust = 0.1
	_open_opportunity()
	_pump(10)
	_check(_rs.reassure(bengal), "reveal before saving")
	_check(SaveService.save_game("p10b_test"), "save mid-window")
	bengal.betrayal_ticks_until_land = -1
	bengal.betrayal_driving_motive = &""
	bengal.motive_revealed = false
	_check(SaveService.load_game("p10b_test"), "load")
	var restored := GameState.get_character(&"bengal_lt")
	_check(restored.betrayal_ticks_until_land == LoyaltyScoring.TELEGRAPH_LEAD_RIVAL_TICKS,
		"the open intent round-trips")
	_check(restored.betrayal_driving_motive == &"grievance", "the driving motive round-trips")
	_check(restored.motive_revealed, "the revealed flag round-trips")
	# Additivity: a P10-era character dict (no P10b keys) decodes to the class defaults.
	var legacy := SaveCodec.encode_character(restored)
	legacy.erase("betrayal_driving_motive")
	legacy.erase("motive_revealed")
	var old := SaveCodec.decode_character(legacy)
	_check(old.betrayal_driving_motive == &"" and old.motive_revealed == false,
		"pre-P10b saves load with hidden defaults (additive)")

func _test_determinism_multi() -> void:
	var runs := []
	for r in 2:
		_fresh_world()
		var bengal := GameState.get_character(&"bengal_lt")
		var regent := GameState.get_character(&"regent")
		_arm_strong(bengal)
		_arm_mild(regent)
		_open_opportunity()
		_pump(40)
		runs.append([_telegraphs, _defused, _committed, _telegraphed_ids.duplicate(),
			bengal.betrayal_ticks_until_land, regent.betrayal_ticks_until_land,
			bengal.betrayal_driving_motive, regent.betrayal_driving_motive])
	_check(runs[0] == runs[1],
		"same state + same ticks -> same decisions (%s vs %s)" % [runs[0], runs[1]])
