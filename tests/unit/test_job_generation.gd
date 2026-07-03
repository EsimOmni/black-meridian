extends Node
## P08 unit test — deterministic systemic job generation (brief §7.5/§7.6).
## Run as a scene, NOT via -s (-s skips autoloads):
##   Godot --headless --path . res://tests/unit/test_job_generation.tscn

var _failures := 0
var _offered: Array[JobData] = []

func _ready() -> void:
	JobDirector.job_offered.connect(func(j): _offered.append(j))
	await get_tree().process_frame  # JobDirector wires its rival trigger deferred
	_test_no_rng_in_generation_files()
	_test_generation_is_deterministic()
	_test_rival_sabotage_spawns_retaliation()
	_test_heavy_consequence_spawns_followup()
	_test_light_consequence_spawns_nothing()
	_test_cadence_gate_holds_the_cap()
	_test_generated_job_save_load()
	_test_pending_followup_survives_save_load()
	if _failures == 0:
		print("[PASS] all job generation tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d job generation assertion(s) failed" % _failures)
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
	_offered.clear()

func _pump(n: int) -> void:
	for i in n:
		TimeService._do_tick()

func _venue(venue_id: StringName) -> VenueData:
	for d in GameState.districts:
		for v in d.venues:
			if v.id == venue_id:
				return v
	return null

func _corvine() -> FactionData:
	return GameState.get_faction(&"corvine")

## P08 house rule: no randomness anywhere in generation — enforce at the source level.
func _test_no_rng_in_generation_files() -> void:
	for path in ["res://src/jobs/job_generator.gd", "res://src/jobs/job_templates.gd"]:
		var text := FileAccess.get_file_as_string(path)
		_check(text != "", "%s readable" % path)
		_check(not ("randf" in text) and not ("randi" in text) and not ("randomize" in text),
			"%s contains no RNG calls" % path)

func _test_generation_is_deterministic() -> void:
	_fresh_world()
	var venue := _venue(&"gw_contraband")
	var a := JobGenerator.retaliation_job(venue, _corvine(), 42)
	var b := JobGenerator.retaliation_job(venue, _corvine(), 42)
	_check(a.id == b.id and a.title == b.title and a.venue_id == b.venue_id
		and a.deadline_ticks == b.deadline_ticks, "same trigger + state -> identical job")
	_check(a.origin == BM.JobOrigin.RIVAL_PROVOCATION, "retaliation origin is RIVAL_PROVOCATION")
	_check(a.prep_actions.size() > 0 and a.approaches.size() > 0 and a.coverups.size() > 0
		and a.deadline_ticks > 0, "generated job is playable (choices + deadline)")
	for i in a.prep_actions.size():
		if a.prep_actions[i].id != b.prep_actions[i].id:
			_check(false, "prep choice ids diverged at %d" % i)
	# The rebuild path (save/load) re-runs the same builder from the parsed id.
	var r := JobGenerator.rebuild(a.id, GameState.districts, GameState.factions)
	_check(r != null and r.id == a.id and r.title == a.title and r.venue_id == a.venue_id
		and r.approaches.size() == a.approaches.size(), "rebuild(id) reproduces the job")
	_check(JobGenerator.rebuild(&"job_intercepted_shipment", GameState.districts,
		GameState.factions) == null, "rebuild ignores authored ids")

func _test_rival_sabotage_spawns_retaliation() -> void:
	_fresh_world()
	var venue := _venue(&"gw_contraband")
	RivalDirector.rival_action_landed.emit(_corvine(), venue, BM.RivalAction.SABOTAGE)
	_check(_offered.size() == 1, "SABOTAGE on a player venue offers a job (got %d)" % _offered.size())
	if _offered.size() == 1:
		var job := _offered[0]
		_check(job.origin == BM.JobOrigin.RIVAL_PROVOCATION, "job reads as rival provocation")
		_check(job.venue_id == venue.id, "job targets the sabotaged venue")
		_check(job.stage == BM.JobStage.INTAKE and job.ticks_remaining == job.deadline_ticks,
			"offered job starts at intake with a live deadline")
	RivalDirector.rival_action_landed.emit(_corvine(), venue, BM.RivalAction.PROBE)
	_check(_offered.size() == 1, "a PROBE is pressure, not a provocation — no job")
	TimeService.tick_index = 5  # distinct id — isolate the ownership check from dedupe
	var old_owner := venue.owner_faction
	venue.owner_faction = &"corvine"
	RivalDirector.rival_action_landed.emit(_corvine(), venue, BM.RivalAction.SABOTAGE)
	_check(_offered.size() == 1, "sabotage on a non-player venue spawns nothing")
	venue.owner_faction = old_owner

func _test_heavy_consequence_spawns_followup() -> void:
	_fresh_world()
	var job := JobTemplates.intercepted_shipment()
	JobDirector.offer(job)
	JobDirector.begin(job.id)
	JobDirector.choose_prep(job.id, &"prep_rush")          # delayed_consequence +0.2
	JobDirector.choose_approach(job.id, &"appr_quiet")
	JobDirector.choose_coverup(job.id, &"cover_silence")   # delayed_consequence +0.3
	_check(job.stage == BM.JobStage.RESOLVED, "job resolved")
	_check(JobDirector.pending_followups.size() == 1, "heavy consequence schedules a follow-up")
	_offered.clear()
	_pump(JobGenerator.FOLLOWUP_LEAD_TICKS - 1)
	_check(_offered.is_empty(), "follow-up stays inside its %d-tick lead" % JobGenerator.FOLLOWUP_LEAD_TICKS)
	_pump(1)
	_check(_offered.size() == 1, "follow-up surfaces after the lead (got %d)" % _offered.size())
	if _offered.size() == 1:
		_check(_offered[0].origin == BM.JobOrigin.FAILED_RACKET
			and _offered[0].venue_id == &"gw_contraband",
			"follow-up is the FAILED_RACKET debris of the source venue")
	_check(JobDirector.pending_followups.is_empty(), "fired follow-up leaves the queue")

func _test_light_consequence_spawns_nothing() -> void:
	_fresh_world()
	var job := JobTemplates.intercepted_shipment()
	JobDirector.offer(job)
	JobDirector.begin(job.id)
	JobDirector.choose_approach(job.id, &"appr_quiet")     # no delayed_consequence anywhere
	JobDirector.choose_coverup(job.id, &"cover_paper")
	_check(JobDirector.pending_followups.is_empty(), "clean resolution schedules nothing")
	_offered.clear()
	_pump(JobGenerator.FOLLOWUP_LEAD_TICKS + 5)
	_check(_offered.is_empty(), "no follow-up ever surfaces from a clean job")

func _test_cadence_gate_holds_the_cap() -> void:
	_fresh_world()
	JobDirector.offer(JobTemplates.intercepted_shipment())
	TimeService.tick_index = 1
	RivalDirector.rival_action_landed.emit(_corvine(), _venue(&"gw_contraband"), BM.RivalAction.SABOTAGE)
	TimeService.tick_index = 2
	RivalDirector.rival_action_landed.emit(_corvine(), _venue(&"gw_protection"), BM.RivalAction.SABOTAGE)
	_check(JobDirector.unresolved_count() == JobDirector.MAX_CONCURRENT_JOBS,
		"world fills to the cap (%d)" % JobDirector.MAX_CONCURRENT_JOBS)
	TimeService.tick_index = 3
	RivalDirector.rival_action_landed.emit(_corvine(), _venue(&"gw_contraband"), BM.RivalAction.SABOTAGE)
	_check(JobDirector.unresolved_count() == JobDirector.MAX_CONCURRENT_JOBS,
		"a trigger at the cap is dropped, never exceeds it")
	_check(_offered.size() == JobDirector.MAX_CONCURRENT_JOBS, "no fourth offer was emitted")

func _test_generated_job_save_load() -> void:
	_fresh_world()
	TimeService.tick_index = 7
	RivalDirector.rival_action_landed.emit(_corvine(), _venue(&"gw_contraband"), BM.RivalAction.SABOTAGE)
	var job := _offered[0]
	JobDirector.begin(job.id)
	JobDirector.choose_prep(job.id, &"prep_trace_crew")
	var saved_id := job.id
	var saved_title := job.title
	_check(SaveService.save_game("p08_test"), "save with a generated job in flight")
	JobDirector.active_jobs = []
	_check(SaveService.load_game("p08_test"), "load")
	var restored := JobDirector.get_job(saved_id)
	_check(restored != null, "generated job round-trips by id")
	if restored:
		var expected_prep: Array[StringName] = [&"prep_trace_crew"]
		_check(restored.stage == BM.JobStage.PREPARATION and restored.chosen_prep == expected_prep,
			"runtime state (stage, chosen prep) restored")
		_check(restored.title == saved_title and restored.approaches.size() == 3,
			"authored content rebuilt from the template id")

func _test_pending_followup_survives_save_load() -> void:
	_fresh_world()
	var job := JobTemplates.intercepted_shipment()
	JobDirector.offer(job)
	JobDirector.begin(job.id)
	JobDirector.choose_approach(job.id, &"appr_quiet")
	JobDirector.choose_coverup(job.id, &"cover_silence")   # +0.3 -> scheduled
	_check(JobDirector.pending_followups.size() == 1, "follow-up pending before save")
	_check(SaveService.save_game("p08_pending"), "save inside the follow-up window")
	JobDirector.pending_followups = []
	_check(SaveService.load_game("p08_pending"), "load")
	_check(JobDirector.pending_followups.size() == 1, "pending follow-up survives save/load")
	_offered.clear()
	_pump(JobGenerator.FOLLOWUP_LEAD_TICKS)
	_check(_offered.size() == 1, "restored follow-up still fires (got %d)" % _offered.size())
