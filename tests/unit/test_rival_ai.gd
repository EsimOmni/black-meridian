extends Node
## P07 unit test — deterministic rival utility AI (brief §7.4/§7.6).
## Run as a scene, NOT via -s (-s skips autoloads):
##   Godot --headless --path . res://tests/unit/test_rival_ai.tscn

var _failures := 0
var _telegraphs := 0
var _landings := 0
var _last_telegraph_target: StringName = &""

func _ready() -> void:
	RivalDirector.rival_intent_telegraphed.connect(func(_f, v, _a):
		_telegraphs += 1
		_last_telegraph_target = v.id)
	RivalDirector.rival_action_landed.connect(func(_f, _v, _a): _landings += 1)
	_test_no_rng_in_ai_files()
	_test_scoring_is_deterministic()
	_test_personality_skew()
	_test_calm_world_means_no_move()
	_test_telegraph_then_land_window()
	_test_intent_survives_save_load()
	_test_grudge_lifts_player_score()
	_test_grudge_crosses_commit_threshold()
	_test_grudge_decays_over_ticks()
	_test_grudge_survives_save_load()
	if _failures == 0:
		print("[PASS] all rival AI tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d rival AI assertion(s) failed" % _failures)
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
	_telegraphs = 0
	_landings = 0
	var d := GameState.get_district(&"glass_wharf")
	_drop_neutral_bait(d)  # these tests baseline a calm world with NO free neutral ground; drop the P08b EXPAND-bait lot
	return d

## The seed ships one neutral EXPAND-bait venue (gw_saltworks, P08b); the rival-AI tests baseline a
## calm world with no free ground (else the rival always EXPANDs it). Remove it so those assertions hold.
func _drop_neutral_bait(d: DistrictData) -> void:
	for i in range(d.venues.size() - 1, -1, -1):
		if d.venues[i].owner_faction == &"":
			d.venues.remove_at(i)

func _pump(n: int) -> void:
	for i in n:
		TimeService._do_tick()

func _corvine() -> FactionData:
	return GameState.get_faction(&"corvine")

## Brief §7.6: no randomness in rival decisions — enforce it at the source level.
func _test_no_rng_in_ai_files() -> void:
	for path in ["res://src/ai/rival_scoring.gd", "res://src/ai/rival_director.gd"]:
		var text := FileAccess.get_file_as_string(path)
		_check(text != "", "%s readable" % path)
		_check(not ("randf" in text) and not ("randi" in text) and not ("randomize" in text),
			"%s contains no RNG calls" % path)

func _test_scoring_is_deterministic() -> void:
	var d := _fresh_world()
	d.inspection_ticks = 100  # a pinned-down district: strong, stable weakness signal
	var first := RivalScoring.choose_move(GameState.districts, GameState.player_faction_id, _corvine())
	_check(not first.is_empty(), "weak state produces a move")
	for i in 50:
		var again := RivalScoring.choose_move(GameState.districts, GameState.player_faction_id, _corvine())
		if again["venue"] != first["venue"] or again["action"] != first["action"] \
				or again["score"] != first["score"]:
			_check(false, "choose_move diverged on call %d" % i)
			return
	_check(true, "")  # 50 identical argmax picks

func _test_personality_skew() -> void:
	var d := _fresh_world()
	# Aggressive + cunning (Corvine: aggr .7 / cun .8) on a weak target -> SABOTAGE over PROBE.
	var weakness := 0.8
	var sab := RivalScoring.score_action(BM.RivalAction.SABOTAGE, weakness, _corvine(), d)
	var probe := RivalScoring.score_action(BM.RivalAction.PROBE, weakness, _corvine(), d)
	_check(sab > probe, "aggressive/cunning leader skews SABOTAGE on a weak target (%f vs %f)" % [sab, probe])

	# A cautious leader de-scores acting in a hot district.
	var cautious := FactionData.new()
	cautious.aggression = 0.2
	cautious.caution = 0.9
	cautious.cunning = 0.4
	d.local_heat = 0.1
	var cool_score := RivalScoring.score_action(BM.RivalAction.SABOTAGE, weakness, cautious, d)
	d.local_heat = 0.9
	var hot_score := RivalScoring.score_action(BM.RivalAction.SABOTAGE, weakness, cautious, d)
	_check(hot_score < cool_score, "cautious leader de-scores a hot district (%f vs %f)" % [hot_score, cool_score])

func _test_calm_world_means_no_move() -> void:
	_fresh_world()  # heat 0.1, no disruption, no inspection
	var pick := RivalScoring.choose_move(GameState.districts, GameState.player_faction_id, _corvine())
	_check(pick.is_empty(), "calm world: nothing clears the commit threshold (rival waits)")

func _test_telegraph_then_land_window() -> void:
	var d := _fresh_world()
	d.inspection_ticks = 200  # weakness window (also floors disruption at 0.8 next settle)
	d.inspection_armed = false

	_pump(10)  # rival tick #1: commit + telegraph
	_check(_telegraphs == 1, "commit telegraphs exactly once (got %d)" % _telegraphs)
	_check(_last_telegraph_target == &"gw_protection",
		"deterministic argmax picks the softest posture (INFLUENCED) under inspection (got %s)" % _last_telegraph_target)
	_check(_landings == 0, "never lands on the telegraph tick")

	_pump(20)  # rival ticks #2-#3: window still open
	_check(_telegraphs == 1, "no re-telegraph while the intent is pending (got %d)" % _telegraphs)
	_check(_landings == 0, "still within the player's response window")

	var target: VenueData = null
	for v in d.venues:
		if v.id == &"gw_protection":
			target = v
	var income_before := EconomyMath.compute_dirty_income(target, d.district_demand())

	_pump(10)  # rival tick #4: TELEGRAPH_LEAD_RIVAL_TICKS (3) elapsed -> lands
	_check(_landings == 1, "the move lands after the fixed %d-rival-tick lead (got %d)"
		% [RivalScoring.TELEGRAPH_LEAD_RIVAL_TICKS, _landings])
	_check(target.sabotage_ticks > 0, "sabotage component armed on the target")
	_check(_corvine().intent_action == -1, "intent cleared after landing")

	_pump(1)  # economy composes the hit into disruption
	var income_after := EconomyMath.compute_dirty_income(target, d.district_demand())
	_check(target.disruption > EconomyService.INSPECTION_DISRUPTION - 0.0001,
		"hit rides on top of the inspection disruption (got %f)" % target.disruption)
	_check(income_after < income_before, "the hit bites income (%d -> %d)" % [income_before, income_after])

func _test_intent_survives_save_load() -> void:
	var d := _fresh_world()
	d.inspection_ticks = 200
	d.inspection_armed = false
	_pump(10)  # telegraph
	_check(_corvine().intent_action >= 0, "intent active before save")
	var saved_action := _corvine().intent_action
	var saved_target := _corvine().intent_venue_id
	var saved_window := _corvine().intent_ticks_until_land
	_check(SaveService.save_game("rival_test"), "save mid-window")
	_check(SaveService.load_game("rival_test"), "load mid-window")
	var corvine := _corvine()  # decoded object replaced the old one
	_check(corvine.intent_action == saved_action and corvine.intent_venue_id == saved_target
		and corvine.intent_ticks_until_land == saved_window,
		"telegraph->land window survives save/load")

## P07c: a grudge-holding rival scores a player venue higher than the same rival with no grudge.
func _test_grudge_lifts_player_score() -> void:
	var d := _fresh_world()
	var target: VenueData = d.venues[0]  # a player-owned venue
	var weakness := RivalScoring.target_weakness(target, d)
	var rival := _corvine()
	rival.grudge = 0.0
	var cold := RivalScoring.score_action(BM.RivalAction.SABOTAGE, weakness, rival, d)
	rival.grudge = 1.0
	var hot := RivalScoring.score_action(BM.RivalAction.SABOTAGE, weakness, rival, d)
	_check(hot > cold, "grudge lifts the SABOTAGE score on a player target (%f > %f)" % [hot, cold])
	rival.grudge = 0.0  # leave the world clean for the next test

## P07c: grudge lifts a sub-threshold target over COMMIT_THRESHOLD — memory makes the rival act
## when a stateless rival would have waited (calm world = no move, proved above).
func _test_grudge_crosses_commit_threshold() -> void:
	_fresh_world()  # calm: choose_move returns {} at grudge 0 (see _test_calm_world_means_no_move)
	var rival := _corvine()
	rival.grudge = 0.0
	_check(RivalScoring.choose_move(GameState.districts, GameState.player_faction_id, rival).is_empty(),
		"grudge 0 in a calm world: rival waits")
	rival.grudge = 1.0
	var pick := RivalScoring.choose_move(GameState.districts, GameState.player_faction_id, rival)
	_check(not pick.is_empty(), "a full grudge makes the rival act in a world it would otherwise ignore")
	rival.grudge = 0.0

## P07c: grudge decays each rival tick toward 0 (a grudge cools if left alone).
func _test_grudge_decays_over_ticks() -> void:
	_fresh_world()
	var rival := _corvine()
	rival.grudge = 0.5
	_pump(10)  # one rival tick
	_check(rival.grudge < 0.5, "grudge decays after a rival tick (got %f)" % rival.grudge)
	var after_one := rival.grudge
	_pump(30)  # several more rival ticks
	_check(rival.grudge < after_one, "grudge keeps cooling over ticks (%f -> %f)" % [after_one, rival.grudge])
	_check(rival.grudge >= 0.0, "grudge never goes negative (got %f)" % rival.grudge)
	rival.grudge = 0.0

## P07c: a mid-feud grudge survives save/load (new save state).
func _test_grudge_survives_save_load() -> void:
	_fresh_world()
	_corvine().grudge = 0.42
	_check(SaveService.save_game("grudge_test"), "save mid-feud")
	_corvine().grudge = 0.0  # clobber to prove load restores it, not that it lingered
	_check(SaveService.load_game("grudge_test"), "load mid-feud")
	_check(absf(_corvine().grudge - 0.42) < 0.0001, "grudge survives save/load (got %f)" % _corvine().grudge)
	_corvine().grudge = 0.0
