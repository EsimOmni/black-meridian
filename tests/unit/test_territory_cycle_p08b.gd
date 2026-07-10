extends Node
## P08b full-cycle probe (run via .tscn — needs autoloads). Proves the territory-loss loop CLOSES
## end to end against the real seed: rival EXPANDs the seeded neutral venue → JobDirector offers a
## TERRITORY_LOSS "Contested Ground" job → resolving it with a real objective reclaims the venue to
## the player as CONTESTED. Ticks the real TimeService/RivalDirector/JobDirector — no hand-mocking.

var _failures := 0
var _offered_territory := false

func _ready() -> void:
	# JobDirector wires its sim triggers via call_deferred from _ready — wait a frame so the
	# rival_action_landed / betrayal arms are connected before we start pumping ticks.
	await get_tree().process_frame
	await get_tree().process_frame

	JobDirector.job_offered.connect(func(j):
		if j.origin == BM.JobOrigin.TERRITORY_LOSS:
			_offered_territory = true)

	WorldSeed.build()
	TimeService.set_speed(BM.Speed.PAUSED)
	TimeService.tick_index = 0
	var d := GameState.get_district(&"glass_wharf")
	var sw := _venue(d, &"gw_saltworks")
	_check(sw != null and sw.owner_faction == &"", "seed ships gw_saltworks neutral (owner empty)")

	# Pump enough rival ticks to telegraph + land an EXPAND on the neutral lot. Rival tick fires
	# every ~10 strategic ticks; telegraph lead is a few rival ticks — 60 strategic ticks is ample.
	for i in 60:
		TimeService._do_tick()

	_check(sw.owner_faction == &"corvine", "rival EXPANDed the neutral lot (owner → corvine, got %s)" % sw.owner_faction)
	_check(_offered_territory, "a TERRITORY_LOSS job was offered when the rival took ground")

	# Find the offered contested job and resolve it with a real objective (>= 0.5 reclaims).
	var job: JobData = null
	for j in JobDirector.active_jobs:
		if j.origin == BM.JobOrigin.TERRITORY_LOSS:
			job = j
			break
	_check(job != null, "the contested-ground job is in active_jobs")
	if job != null:
		job.outcome = {&"objective_achieved": 0.75}
		JobDirector._apply_and_emit(job)
		_check(sw.owner_faction == GameState.player_faction_id, "resolved loud → venue reclaimed to player (got %s)" % sw.owner_faction)
		_check(sw.control_state == BM.ControlState.CONTESTED, "reclaimed venue is CONTESTED (disputed, loop stays alive)")

	if _failures == 0:
		print("[PASS] P08b territory-loss full cycle closes: EXPAND → job → reclaim")
	else:
		print("[FAIL] P08b territory cycle: %d assertion(s) failed" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)

func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		print("  assertion failed: %s" % label)

func _venue(d: DistrictData, id: StringName) -> VenueData:
	for v in d.venues:
		if v.id == id:
			return v
	return null
