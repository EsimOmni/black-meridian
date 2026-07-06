extends Node
## P17b GATE test — the reveal scene's choice writes persistent strategic state and
## survives save/load before AND after the scene (brief §19: visually attractive but
## non-persistent = FAIL). Drives the SIM-EFFECT path (CinematicTransition.try_reassure
## + save/load) — never the 3D node swap (city_root stays null → clean headless no-op).
## Run as a scene, NOT via -s (-s skips autoloads):
##   Godot --headless --path . res://tests/unit/test_reveal_persistence_p17b.tscn

var _failures := 0
var _rs: RelationshipService
var _ct: CinematicTransition

func _ready() -> void:
	_rs = RelationshipService.new()
	add_child(_rs)
	_ct = CinematicTransition.new()
	_ct.relationship_node = _rs
	add_child(_ct)  # city_root stays null — headless: enter/resolve only pause the sim
	_test_reveal_writes_persistent_state()
	_test_persist_survives_save_load_AFTER()
	_test_persist_survives_save_load_BEFORE()
	_test_walk_away_leaves_intent_open()
	_test_reassure_cost_gate_respected()
	_test_no_rng_in_scene_sources()
	if _failures == 0:
		print("[PASS] all P17b reveal persistence tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d P17b assertion(s) failed" % _failures)
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
	# Neutralize the rival deterministically (same as test_loyalty_p10b) — no rival
	# intents or sabotage feed opportunity into these controlled scenarios.
	var corvine := GameState.get_faction(&"corvine")
	corvine.aggression = 0.0
	corvine.cunning = 0.0

## Seed an OPEN telegraphed intent exactly as RelationshipService opens one (P10b):
## motive fields armed, window set, driving motive captured, starting hidden.
## pressure = 0.9 + 0.95 + 0.5 - 0.1 - 0.2 = 2.05 → argmax = grievance.
func _seed_telegraph(c: CharacterData) -> void:
	c.ambition = 0.9
	c.grievance = 0.95
	c.rival_leverage = 0.5
	c.public_trust = 0.1
	c.shared_success = 0.0
	c.fear = 0.2
	c.betrayal_ticks_until_land = LoyaltyScoring.TELEGRAPH_LEAD_RIVAL_TICKS
	c.betrayal_driving_motive = LoyaltyScoring.driving_motive(c)
	c.motive_revealed = false

## 1. The in-scene choice changes persistent strategic state (brief §19).
func _test_reveal_writes_persistent_state() -> void:
	_fresh_world()
	var c := GameState.get_character(&"bengal_lt")
	_seed_telegraph(c)
	var pf := GameState.player_faction()
	pf.clean_capital = 1000
	var trust0 := c.public_trust
	var shared0 := c.shared_success
	var cap0 := pf.clean_capital
	_check(not c.motive_revealed, "setup: motive starts hidden")
	_ct.enter(&"bengal_lt")
	var ok := _ct.try_reassure(&"bengal_lt")
	_ct.resolve(&"bengal_lt", ok)
	_check(ok, "reassure succeeds with enough clean capital")
	_check(is_equal_approx(c.public_trust,
		clampf(trust0 + LoyaltyScoring.REASSURE_TRUST_GAIN, 0.0, 1.0)),
		"trust rises by the reassure gain")
	_check(is_equal_approx(c.shared_success,
		clampf(shared0 + LoyaltyScoring.REASSURE_SHARED_GAIN, 0.0, 1.0)),
		"shared success rises by the reassure gain")
	_check(pf.clean_capital == cap0 - LoyaltyScoring.REASSURE_COST_CLEAN,
		"clean capital pays the sit-down cost")
	_check(c.motive_revealed, "the sit-down reveals the driving motive")
	_check(TimeService.speed == BM.Speed.PAUSED,
		"the sim is restored to PAUSED — the player resumes deliberately")

## 2. The core P18 assertion: the reveal's consequence survives save→load.
func _test_persist_survives_save_load_AFTER() -> void:
	_fresh_world()
	var c := GameState.get_character(&"bengal_lt")
	_seed_telegraph(c)
	GameState.player_faction().clean_capital = 1000
	_ct.enter(&"bengal_lt")
	_check(_ct.try_reassure(&"bengal_lt"), "reassure before saving")
	_ct.resolve(&"bengal_lt", true)
	var trust := c.public_trust
	var shared := c.shared_success
	var cap: int = GameState.player_faction().clean_capital
	_check(SaveService.save_game("p17b_after"), "save AFTER the reveal")
	# Scramble live state so the load has to do the actual work (no tautology).
	c.public_trust = 0.0
	c.shared_success = 0.0
	c.motive_revealed = false
	c.betrayal_driving_motive = &""
	GameState.player_faction().clean_capital = 0
	_check(SaveService.load_game("p17b_after"), "load")
	var r := GameState.get_character(&"bengal_lt")
	_check(r.motive_revealed, "the revealed motive survives save/load")
	_check(r.betrayal_driving_motive == &"grievance", "the driving motive survives save/load")
	_check(is_equal_approx(r.public_trust, trust), "raised trust survives save/load")
	_check(is_equal_approx(r.shared_success, shared), "raised shared success survives save/load")
	_check(GameState.player_faction().clean_capital == cap, "spent capital survives save/load")
	_check(r.betrayal_ticks_until_land == LoyaltyScoring.TELEGRAPH_LEAD_RIVAL_TICKS,
		"the still-open window survives — defusal is the next gate re-check, not the reassure")

## 3. Brief §19: survive save/load BEFORE the scene too — save mid-telegraph, load,
## confront on the LOADED state, save again, load again; consistent throughout.
func _test_persist_survives_save_load_BEFORE() -> void:
	_fresh_world()
	var c := GameState.get_character(&"bengal_lt")
	_seed_telegraph(c)
	GameState.player_faction().clean_capital = 1000
	_check(SaveService.save_game("p17b_before"), "save BEFORE any confront")
	c.betrayal_ticks_until_land = -1
	c.betrayal_driving_motive = &""
	_check(SaveService.load_game("p17b_before"), "load the pre-confront save")
	var r := GameState.get_character(&"bengal_lt")
	_check(r.betrayal_ticks_until_land == LoyaltyScoring.TELEGRAPH_LEAD_RIVAL_TICKS,
		"the telegraphed intent survives the before-save")
	_check(r.betrayal_driving_motive == &"grievance" and not r.motive_revealed,
		"the hidden motive survives the before-save")
	_ct.enter(&"bengal_lt")
	_check(_ct.try_reassure(&"bengal_lt"), "reassure on the LOADED state")
	_ct.resolve(&"bengal_lt", true)
	_check(SaveService.save_game("p17b_before2"), "save AFTER the reveal on loaded state")
	r.motive_revealed = false
	r.public_trust = 0.0
	_check(SaveService.load_game("p17b_before2"), "load again")
	var r2 := GameState.get_character(&"bengal_lt")
	_check(r2.motive_revealed, "the reveal survives the after-save")
	_check(r2.betrayal_driving_motive == &"grievance", "the motive stays consistent throughout")
	_check(is_equal_approx(r2.public_trust,
		clampf(0.1 + LoyaltyScoring.REASSURE_TRUST_GAIN, 0.0, 1.0)),
		"the raised trust stays consistent throughout")

## 4. Walk away is a real non-choice: nothing is called, the intent stays open.
func _test_walk_away_leaves_intent_open() -> void:
	_fresh_world()
	var c := GameState.get_character(&"bengal_lt")
	_seed_telegraph(c)
	var pf := GameState.player_faction()
	pf.clean_capital = 1000
	var trust0 := c.public_trust
	var cap0 := pf.clean_capital
	_ct.enter(&"bengal_lt")
	_ct.resolve(&"bengal_lt", false)  # walk away: NO verb call
	_check(c.betrayal_ticks_until_land == LoyaltyScoring.TELEGRAPH_LEAD_RIVAL_TICKS,
		"the intent stays open after walking away")
	_check(not c.motive_revealed, "the motive stays hidden after walking away")
	_check(is_equal_approx(c.public_trust, trust0) and pf.clean_capital == cap0,
		"walking away spends and gains nothing")

## 5. The scene cannot dodge the sim's cost rule: reassure refuses below the cost.
func _test_reassure_cost_gate_respected() -> void:
	_fresh_world()
	var c := GameState.get_character(&"bengal_lt")
	_seed_telegraph(c)
	var pf := GameState.player_faction()
	pf.clean_capital = LoyaltyScoring.REASSURE_COST_CLEAN - 1
	var trust0 := c.public_trust
	var shared0 := c.shared_success
	_ct.enter(&"bengal_lt")
	var ok := _ct.try_reassure(&"bengal_lt")
	_check(not ok, "reassure returns false below the clean-capital cost")
	_check(pf.clean_capital == LoyaltyScoring.REASSURE_COST_CLEAN - 1, "no capital moved")
	_check(is_equal_approx(c.public_trust, trust0)
		and is_equal_approx(c.shared_success, shared0), "no motive state mutated")
	_check(not c.motive_revealed, "the motive stays hidden")
	_check(c.betrayal_ticks_until_land == LoyaltyScoring.TELEGRAPH_LEAD_RIVAL_TICKS,
		"the intent stays open")
	_ct.resolve(&"bengal_lt", false)

## 6. House style (§7.6): no RNG anywhere in the new scene sources.
func _test_no_rng_in_scene_sources() -> void:
	for path in ["res://scenes/cinematic/reveal_scene.gd",
			"res://src/presentation/cinematic_transition.gd"]:
		var text := FileAccess.get_file_as_string(path)
		_check(text != "", "%s readable" % path)
		_check(not ("randf" in text) and not ("randi" in text)
			and not ("randomize" in text) and not ("RandomNumberGenerator" in text),
			"%s contains no RNG calls" % path)
