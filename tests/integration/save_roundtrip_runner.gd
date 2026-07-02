extends Node
## P02 integration test — deterministic save/load round-trip (brief §13.2, §18).
## Runs with the full autoload stack (unlike -s unit tests):
##   Godot --headless --path . res://tests/integration/save_roundtrip_runner.tscn
## Proves: (1) load restores the exact saved snapshot, (2) identical inputs after a load
## reproduce the exact same state as the original timeline (save → load → same tick →
## same state), (3) a version-mismatched file is refused cleanly.

const SLOT := "roundtrip_test"
const TICKS_A := 25   ## ticks before the save
const TICKS_B := 25   ## ticks replayed after the save, twice

var _failures := 0

func _ready() -> void:
	# Deterministic setup: seeded world + the placeholder job mid-lifecycle.
	WorldSeed.build()
	TimeService.set_speed(BM.Speed.PAUSED)  # we pump ticks manually
	TimeService.tick_index = 0
	JobDirector.active_jobs = []
	JobDirector.offer(PlaceholderJobs.intercepted_shipment())
	JobDirector.begin(&"job_intercepted_shipment")
	JobDirector.choose_prep(&"job_intercepted_shipment", &"prep_lookouts")

	_pump(TICKS_A)
	var snap_a := _snapshot()
	_check(SaveService.save_game(SLOT), "save_game succeeds")

	# Timeline 1: play on from the save point.
	_play_phase_b()
	var snap_x := _snapshot()
	_check(snap_x != snap_a, "state actually diverged after the save")

	# Load → must restore the exact snapshot.
	_check(SaveService.load_game(SLOT), "load_game succeeds")
	_check(_snapshot() == snap_a, "loaded state equals the saved snapshot byte-for-byte")

	# Timeline 2: replay identical inputs → must reproduce timeline 1 exactly.
	_play_phase_b()
	_check(_snapshot() == snap_x, "replay after load reproduces the same state (determinism)")

	# Version refusal: corrupt the version field; load must fail cleanly and not touch state.
	var before := _snapshot()
	_write_bad_version()
	_check(not SaveService.load_game(SLOT), "version mismatch is refused")
	_check(_snapshot() == before, "refused load leaves state untouched")

	if _failures == 0:
		print("[PASS] save/load deterministic round-trip")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d save/load assertion(s) failed" % _failures)
		get_tree().quit(1)

## Identical "player input" applied in both timelines: N ticks, then the job is driven
## to resolution (approach + cover-up), then N more ticks.
func _play_phase_b() -> void:
	_pump(TICKS_B)
	JobDirector.choose_approach(&"job_intercepted_shipment", &"appr_deal")
	JobDirector.choose_coverup(&"job_intercepted_shipment", &"cover_scapegoat")
	_pump(TICKS_B)

func _pump(n: int) -> void:
	for i in n:
		TimeService._do_tick()

func _snapshot() -> String:
	var meta := {
		"player_faction_id": GameState.player_faction_id,
		"night_cycle": GameState.night_cycle,
		"phase": GameState.phase,
		"tick_index": TimeService.tick_index,
	}
	return var_to_str(SaveCodec.encode_state(
		GameState.districts, GameState.factions, GameState.characters,
		JobDirector.active_jobs, meta))

func _write_bad_version() -> void:
	var f := FileAccess.open(SaveService.save_path(SLOT), FileAccess.WRITE)
	f.store_string(var_to_str({"version": 999, "meta": {}}))
	f.close()

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: ", msg)
	else:
		_failures += 1
		printerr("  assertion failed: ", msg)
