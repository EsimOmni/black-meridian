extends Node
## P06 unit test — heat's consequence loop (brief §7.3) + the deterministic inspection
## beat (brief §7.6) + the P04b evidence-sign wiring into heat.
## Run as a scene, NOT via -s (-s skips autoloads):
##   Godot --headless --path . res://tests/unit/test_heat_consequence.tscn

var _failures := 0
var _inspection_fires := 0

func _ready() -> void:
	EconomyService.inspection_started.connect(func(_d): _inspection_fires += 1)
	_test_heat_disrupts_income()
	_test_heat_decays_slower_than_rise()
	_test_inspection_fires_once_and_rearms()
	_test_inspection_bites_income()
	_test_evidence_sign_drives_heat()
	if _failures == 0:
		print("[PASS] all heat consequence tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d heat consequence assertion(s) failed" % _failures)
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

func _pause_player_rackets(paused: bool) -> void:
	for v in GameState.get_district(&"glass_wharf").venues:
		if v.type == BM.VenueType.RACKET and v.owner_faction == GameState.player_faction_id:
			EconomyService.set_racket_paused(v, paused)

## The loop-closing regression: high heat -> disruption -> measurably lower dirty income.
func _test_heat_disrupts_income() -> void:
	_check(EconomyMath.disruption_from_heat(0.0) == 0.0, "no disruption at zero heat")
	_check(EconomyMath.disruption_from_heat(EconomyMath.HEAT_DISRUPTION_GRACE) == 0.0,
		"no disruption inside the grace band")
	_check(EconomyMath.disruption_from_heat(0.8) > EconomyMath.disruption_from_heat(0.5),
		"disruption grows with heat")
	_check(absf(EconomyMath.disruption_from_heat(1.0) - EconomyMath.HEAT_DISRUPTION_MAX) < 0.0001,
		"disruption caps at HEAT_DISRUPTION_MAX")

	var d := _fresh_world()
	var racket: VenueData = d.venues[0]  # gw_contraband
	var income_cold := EconomyMath.compute_dirty_income(racket, d.district_demand())
	d.local_heat = 0.9
	_pump(1)  # settle applies heat -> disruption to venues
	_check(racket.disruption > 0.0, "hot district disrupted the venue (got %f)" % racket.disruption)
	var income_hot := EconomyMath.compute_dirty_income(racket, d.district_demand())
	_check(income_hot < income_cold,
		"heat costs income (%d cold vs %d hot)" % [income_cold, income_hot])

## Backing off recovers heat, but slower than it climbed (causality stays legible).
func _test_heat_decays_slower_than_rise() -> void:
	var d := _fresh_world()
	d.local_heat = 0.4
	_pump(1)
	var rise_per_tick := d.local_heat - 0.4
	_check(rise_per_tick > 0.0, "squeezed world raises heat (+%f/tick)" % rise_per_tick)

	_pause_player_rackets(true)  # rival baseline stays below EXPOSURE_HEAT_FLOOR
	var heat_before := d.local_heat
	_pump(10)
	var decay_per_tick := (heat_before - d.local_heat) / 10.0
	_check(decay_per_tick > 0.0, "heat decays when the player backs off (-%f/tick)" % decay_per_tick)
	_check(decay_per_tick < rise_per_tick,
		"decay (%f) is slower than rise (%f)" % [decay_per_tick, rise_per_tick])
	_pause_player_rackets(false)

## The threshold beat: fires exactly once per excursion, deterministically, and re-arms
## only after heat falls below the re-arm level. No RNG anywhere in the path.
func _test_inspection_fires_once_and_rearms() -> void:
	var d := _fresh_world()
	_inspection_fires = 0
	# One squeezed tick rises ~0.00084 — start just under the threshold so tick 1 crosses.
	d.local_heat = EconomyService.HEAT_INSPECTION_THRESHOLD - 0.0005
	_pump(1)
	_check(_inspection_fires == 1, "crossing the threshold fires the inspection once (got %d)" % _inspection_fires)
	_check(d.inspection_ticks == EconomyService.INSPECTION_DURATION_TICKS, "inspection countdown armed")
	_pump(10)
	_check(_inspection_fires == 1, "staying above threshold does NOT re-fire (got %d)" % _inspection_fires)

	# Run the inspection out, drop below re-arm, and cross again -> a second fire.
	_pause_player_rackets(true)
	_pump(EconomyService.INSPECTION_DURATION_TICKS)
	_check(d.inspection_ticks == 0, "inspection ended")
	d.local_heat = EconomyService.HEAT_INSPECTION_REARM - 0.01
	_pump(1)  # re-arm pass
	_pause_player_rackets(false)
	d.local_heat = EconomyService.HEAT_INSPECTION_THRESHOLD - 0.0005
	_pump(1)
	_check(_inspection_fires == 2, "after re-arm, crossing fires again (got %d)" % _inspection_fires)

func _test_inspection_bites_income() -> void:
	var d := _fresh_world()
	var racket: VenueData = d.venues[0]
	var income_before := EconomyMath.compute_dirty_income(racket, d.district_demand())
	d.local_heat = EconomyService.HEAT_INSPECTION_THRESHOLD
	_pump(1)  # fires + applies the disruption floor
	_check(d.inspection_ticks > 0, "inspection active")
	_check(racket.disruption >= EconomyService.INSPECTION_DISRUPTION,
		"inspection floors disruption at %f (got %f)" % [EconomyService.INSPECTION_DISRUPTION, racket.disruption])
	var income_during := EconomyMath.compute_dirty_income(racket, d.district_demand())
	_check(income_during < income_before,
		"inspection bites income (%d -> %d)" % [income_before, income_during])

## P04b debt closed: the signed net evidence axis drives heat in both directions.
func _test_evidence_sign_drives_heat() -> void:
	var d := DistrictData.new()
	d.local_heat = 0.5
	var f := FactionData.new()
	var job := PlaceholderJobs.intercepted_shipment()
	var involved: Array[CharacterData] = []

	job.outcome = JobResolution.blank()
	job.outcome[&"evidence_generated"] = -0.3  # suppressed: police see less
	JobLifecycle.apply_outcome(job, f, d, involved)
	_check(d.local_heat < 0.5, "suppressed evidence LOWERS heat (got %f)" % d.local_heat)

	d.local_heat = 0.5
	job.outcome = JobResolution.blank()
	job.outcome[&"evidence_generated"] = 0.3   # exposed: police see more
	JobLifecycle.apply_outcome(job, f, d, involved)
	_check(d.local_heat > 0.5, "exposed evidence RAISES heat (got %f)" % d.local_heat)
