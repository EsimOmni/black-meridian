extends Node
## P18 unit test — entering EITHER cinematic sequence writes a "checkpoint" save of the
## pre-scene strategic state (brief §14.2 pause→checkpoint→enter): a crash inside the
## cinematic can never cost the player their campaign. Drives the sim-effect path only
## (city_root null — the node swap no-ops headless, the P17b test pattern).
## Run as a scene, NOT via -s (-s skips autoloads):
##   Godot --headless --path . res://tests/unit/test_cinematic_checkpoint_p18.tscn

var _failures := 0
var _ct: CinematicTransition

func _ready() -> void:
	var rs := RelationshipService.new()
	add_child(rs)
	_ct = CinematicTransition.new()
	_ct.relationship_node = rs
	add_child(_ct)
	_test_confront_writes_checkpoint()
	_test_crime_scene_writes_checkpoint()
	if _failures == 0:
		print("[PASS] all P18 cinematic checkpoint tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d P18 checkpoint assertion(s) failed" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("  assertion failed: ", msg)

func _fresh_world() -> void:
	WorldSeed.build()
	TimeService.set_speed(BM.Speed.PAUSED)
	TimeService.tick_index = 0

func _test_confront_writes_checkpoint() -> void:
	_fresh_world()
	# Distinctive pre-scene state the checkpoint must capture.
	GameState.player_faction().dirty_cash = 7777
	TimeService.tick_index = 321
	GameState.narrative_flags[&"fired@beat_ledger"] = true
	_ct.enter(&"bengal_lt")
	_check(FileAccess.file_exists(SaveService.save_path("checkpoint")),
		"entering the confrontation writes user://saves/checkpoint.bmsave")
	# Scramble live state so the restore has to do real work (no tautology).
	GameState.player_faction().dirty_cash = 1
	TimeService.tick_index = 9
	GameState.narrative_flags.clear()
	_check(SaveService.load_game("checkpoint"), "the checkpoint loads")
	_check(GameState.player_faction().dirty_cash == 7777,
		"the checkpoint restored the pre-scene cash")
	_check(TimeService.tick_index == 321, "the checkpoint restored the pre-scene tick")
	_check(GameState.narrative_flags.get(&"fired@beat_ledger", false) == true,
		"the checkpoint restored the narrative flags")

func _test_crime_scene_writes_checkpoint() -> void:
	_fresh_world()
	GameState.player_faction().dirty_cash = 4242
	_ct.enter_crime_scene(&"glass_wharf")
	GameState.player_faction().dirty_cash = 2
	_check(SaveService.load_game("checkpoint"), "the crime-scene checkpoint loads")
	_check(GameState.player_faction().dirty_cash == 4242,
		"the crime-scene checkpoint restored the pre-scene state")
