extends Node
## P06c unit test — central pressure: the one scale above the districts (brief §7.3)
## + the telegraphed city-wide alert latch + the eased-inspection bite (brief §7.6).
## Run as a scene, NOT via -s (-s skips autoloads):
##   Godot --headless --path . res://tests/unit/test_central_pressure.tscn

var _failures := 0
var _alert_starts := 0
var _alert_ends := 0
var _gw_inspection_fires := 0

func _ready() -> void:
	EconomyService.central_alert_started.connect(func(_p): _alert_starts += 1)
	EconomyService.central_alert_ended.connect(func(_p): _alert_ends += 1)
	EconomyService.inspection_started.connect(func(d):
		if d.id == &"glass_wharf":
			_gw_inspection_fires += 1)
	await get_tree().process_frame  # JobDirector wires its triggers deferred
	_test_no_rng_in_pressure_files()
	_test_city_pressure_is_a_mean_and_deterministic()
	_test_step_central_rises_decays_clamps()
	_test_alert_latches_once_at_threshold()
	_test_alert_eases_the_district_inspection()
	_test_decay_and_rearm_only_below_the_bar()
	_test_central_state_survives_save_load()
	if _failures == 0:
		print("[PASS] all central pressure tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d central pressure assertion(s) failed" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("  assertion failed: ", msg)

func _fresh_world() -> DistrictData:
	WorldSeed.build()
	TimeService.set_speed(BM.Speed.PAUSED)
	JobDirector.active_jobs = []
	return GameState.get_district(&"glass_wharf")

func _pump(n: int) -> void:
	for i in n:
		TimeService._do_tick()

func _pause_player_rackets() -> void:
	for v in GameState.get_district(&"glass_wharf").venues:
		if v.type == BM.VenueType.RACKET and v.owner_faction == GameState.player_faction_id:
			EconomyService.set_racket_paused(v, true)

func _district_with_heat(heat: float) -> DistrictData:
	var d := DistrictData.new()
	d.local_heat = heat
	return d

## 7) The one rule: zero RNG in the new code.
func _test_no_rng_in_pressure_files() -> void:
	var src := FileAccess.get_file_as_string("res://src/simulation/pressure_math.gd")
	_check(src.length() > 0, "pressure_math.gd readable")
	for token in ["randf", "randi", "randomize"]:
		_check(not token in src, "no %s in pressure_math.gd" % token)

## 1) city_pressure = mean of per-district combined pressure; pure and deterministic;
## one hot district scores LOWER than the whole city warm (the mean shape).
func _test_city_pressure_is_a_mean_and_deterministic() -> void:
	var empty: Array[DistrictData] = []
	_check(PressureMath.city_pressure(empty) == 0.0, "empty city has zero pressure")

	var one_hot: Array[DistrictData] = [
		_district_with_heat(1.0), _district_with_heat(0.0),
		_district_with_heat(0.0), _district_with_heat(0.0),
	]
	var all_warm: Array[DistrictData] = [
		_district_with_heat(0.5), _district_with_heat(0.5),
		_district_with_heat(0.5), _district_with_heat(0.5),
	]
	var hot_score := PressureMath.city_pressure(one_hot)
	var warm_score := PressureMath.city_pressure(all_warm)
	_check(absf(hot_score - 0.25) < 0.0001, "one hot of four means 0.25 (got %f)" % hot_score)
	_check(absf(warm_score - 0.5) < 0.0001, "all warm means 0.5 (got %f)" % warm_score)
	_check(warm_score > hot_score,
		"the whole city warm outranks one district on fire (%f vs %f)" % [warm_score, hot_score])

	# The mean IS the mean of combined pressure — cases count, not just heat.
	var cased := _district_with_heat(0.2)
	EvidenceMath.deposit(cased, 0.6, &"test_src", 1)
	var mixed: Array[DistrictData] = [cased, _district_with_heat(0.0)]
	var expected := (EvidenceMath.combined_pressure(cased.local_heat, cased.evidence_cases) + 0.0) / 2.0
	_check(absf(PressureMath.city_pressure(mixed) - expected) < 0.0001,
		"city pressure averages COMBINED pressure (cases included)")

	var first := PressureMath.city_pressure(one_hot)
	for i in 50:
		_check(PressureMath.city_pressure(one_hot) == first, "call %d identical (pure)" % i)

## 2) step_central: rises toward the city signal above the floor, decays below it,
## clamps 0..1, monotonic in the expected direction.
func _test_step_central_rises_decays_clamps() -> void:
	var risen := PressureMath.step_central(0.2, 0.8)
	_check(absf(risen - 0.29) < 0.0001, "rises by RISE_SCALE of the gap (got %f)" % risen)
	_check(PressureMath.step_central(0.9, 0.5) < 0.9,
		"tracks DOWN toward a cooler map too (bounded, never a ratchet)")
	var decayed := PressureMath.step_central(0.5, 0.1)
	_check(absf(decayed - 0.49) < 0.0001, "decays by DECAY_PER_TICK below the floor (got %f)" % decayed)
	_check(PressureMath.step_central(0.0, 0.0) == 0.0, "clamped at 0")
	_check(PressureMath.step_central(0.99, 1.5) == 1.0, "clamped at 1 even against a >1 city signal")

	var p := 0.0
	for i in 30:
		var next := PressureMath.step_central(p, 0.8)
		_check(next > p, "monotonically rising toward the city signal (tick %d)" % i)
		_check(next < 0.8, "never overshoots the signal it tracks (tick %d)" % i)
		p = next

## 3) The alert latches ONCE when central_pressure crosses the threshold (armed->fires
## exactly once, not every tick), and does NOT fire below the bar.
func _test_alert_latches_once_at_threshold() -> void:
	var d := _fresh_world()
	_alert_starts = 0
	d.local_heat = 1.0  # city signal 1.0 -> pressure climbs 0 -> past 0.6 within 10 ticks
	_pump(10)
	_check(GameState.central_pressure >= PressureMath.CENTRAL_ALERT_THRESHOLD,
		"pressure crossed the bar (got %f)" % GameState.central_pressure)
	_check(_alert_starts == 1, "crossing fires the alert exactly once (got %d)" % _alert_starts)
	_check(GameState.central_alert, "alert latched")
	_check(GameState.central_alert_ticks > 0, "city-wide consequence countdown armed")
	_pump(5)
	_check(_alert_starts == 1, "staying above the bar does NOT re-fire (got %d)" % _alert_starts)

	# Below the bar: a city that plateaus under the threshold never alerts.
	d = _fresh_world()
	_alert_starts = 0
	_pause_player_rackets()
	d.local_heat = 0.5  # asymptote 0.5 < 0.6 threshold, margin 0.1
	_pump(30)
	_check(_alert_starts == 0,
		"a warm-but-under-bar city never alerts (pressure %f)" % GameState.central_pressure)

## 4) The bite: same district state, combined BETWEEN the eased and normal thresholds —
## no sweep with the alert off, sweep with the alert on.
func _test_alert_eases_the_district_inspection() -> void:
	# Alert OFF: combined ~0.38 sits under the 0.45 threshold -> no sweep.
	var d := _fresh_world()
	_gw_inspection_fires = 0
	_pause_player_rackets()
	d.local_heat = 0.38  # in (0.30, 0.45) with >=0.05 margin on both sides
	_pump(1)
	_check(_gw_inspection_fires == 0, "alert off: no sweep at combined 0.38 (got %d)" % _gw_inspection_fires)
	_check(d.inspection_ticks == 0, "alert off: no inspection countdown")

	# Alert ON, identical district state -> the eased threshold (0.30) catches it.
	d = _fresh_world()
	_gw_inspection_fires = 0
	_pause_player_rackets()
	d.local_heat = 0.38
	GameState.central_alert = true
	GameState.central_alert_ticks = 5
	_pump(1)
	_check(_gw_inspection_fires == 1, "alert on: the SAME state arms a sweep (got %d)" % _gw_inspection_fires)
	_check(d.inspection_ticks == EconomyService.INSPECTION_DURATION_TICKS,
		"alert on: inspection countdown armed")

## 5) Decay + re-arm: a cool city drops the pressure; the alert re-arms only once it
## falls below CENTRAL_ALERT_REARM, not before.
func _test_decay_and_rearm_only_below_the_bar() -> void:
	var d := _fresh_world()
	_pause_player_rackets()
	d.local_heat = 0.0  # city signal 0 -> pure decay
	GameState.central_pressure = 0.5
	GameState.central_alert = true   # a past alert, consequence already over
	GameState.central_alert_ticks = 0
	_pump(5)  # 0.5 -> 0.45, still above the 0.4 re-arm bar
	_check(GameState.central_alert, "above the re-arm bar the latch stays down (pressure %f)"
		% GameState.central_pressure)
	_pump(10)  # -> 0.35, below the bar with margin
	_check(GameState.central_pressure < PressureMath.CENTRAL_ALERT_REARM,
		"cool city decays the pressure (got %f)" % GameState.central_pressure)
	_check(not GameState.central_alert, "below the re-arm bar the alert re-arms")

## 6) Save/load: the three campaign scalars survive a roundtrip mid-alert.
func _test_central_state_survives_save_load() -> void:
	_fresh_world()
	GameState.central_pressure = 0.72
	GameState.central_alert = true
	GameState.central_alert_ticks = 7
	_check(SaveService.save_game("p06c_test"), "mid-alert save written")

	WorldSeed.build()  # wipes the campaign — reset() clears the central axis
	_check(GameState.central_pressure == 0.0 and not GameState.central_alert
		and GameState.central_alert_ticks == 0, "rebuild cleared the central axis")

	_check(SaveService.load_game("p06c_test"), "mid-alert save loaded")
	_check(GameState.central_pressure == 0.72,
		"central_pressure restored exactly (got %f)" % GameState.central_pressure)
	_check(GameState.central_alert, "central_alert restored")
	_check(GameState.central_alert_ticks == 7,
		"central_alert_ticks restored (got %d)" % GameState.central_alert_ticks)
