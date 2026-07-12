extends Node
## P16 full-chain integrity probe (throwaway, the P06d/P08b pattern) — drives the REAL
## tick/settle/resolution paths with a deterministic scripted policy and proves the
## authored narrative spine end to end:
##   cold open resolves -> beat_ledger fires (+lead) -> loud ledger plants a REAL
##   evidence case -> beat_debt fires (leverage armed) -> the bait approach pushes the
##   lieutenant over the betrayal bar -> with a real opportunity the P10 telegraph
##   OPENS -> reassure defuses it (preventability) -> beat_accord fires -> stance
##   recorded -> save/load mid-chain and at the end, flags survive byte-for-byte.
## Discipline: reads state, calls only existing public methods + the same resolution
## path the shipped code uses. Zero RNG — fixed script, fixed delays.
## Run: Godot --headless --path . res://tools/validation/narrative_probe.tscn

const RESOLVE_DELAY := 4
const SLOT := "narrative_probe_test"

var _relationships: RelationshipService
var _narrative: NarrativeDirector
var _resolve_at := {}         # job_id -> tick
var _beats_fired: Array[StringName] = []
var _telegraph_seen := false
var _defused_seen := false
var _failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: %s" % msg)
	else:
		_failures += 1
		printerr("  FAIL: %s" % msg)

func _ready() -> void:
	print("--- P16 NARRATIVE CHAIN PROBE (deterministic, scripted) ---")
	WorldSeed.build()
	TimeService.set_speed(BM.Speed.PAUSED)
	TimeService.tick_index = 0
	# Bootstrap-wired services, instantiated exactly like bootstrap.gd does.
	_relationships = RelationshipService.new()
	add_child(_relationships)
	_narrative = NarrativeDirector.new()
	add_child(_narrative)
	_narrative.beat_fired.connect(func(beat, _job): _beats_fired.append(beat))
	_relationships.betrayal_telegraphed.connect(func(c):
		_telegraph_seen = true
		print("    [dbg] telegraph t=%d p=%.3f" % [TimeService.tick_index, c.betrayal_pressure()]))
	_relationships.betrayal_defused.connect(func(c):
		_defused_seen = true
		print("    [dbg] defused t=%d p=%.3f" % [TimeService.tick_index, c.betrayal_pressure()]))
	_relationships.betrayal_committed.connect(func(c, _v, _r):
		print("    [dbg] LANDED t=%d p=%.3f" % [TimeService.tick_index, c.betrayal_pressure()]))
	JobDirector.job_offered.connect(_on_offered)
	await get_tree().process_frame  # deferred trigger wiring (JobDirector -> services)

	# The cold open, exactly as bootstrap offers it.
	JobDirector.offer(JobTemplates.intercepted_shipment())

	# Phase 1 — play until the accord is fired and resolved (bounded loop).
	var saved_midchain := false
	for t in 1200:
		# Re-fetch through GameState EVERY iteration: the mid-chain load below replaces
		# the data objects, and a stale reference reads (and reassures) a dead world.
		var lt := GameState.get_character(&"bengal_lt")
		var district := GameState.get_district(&"glass_wharf")
		TimeService._do_tick()
		_resolve_due(TimeService.tick_index)
		# The moment the debt job resolves (bait path), hand the sim a real opportunity
		# (an active inspection) so the two-gate telegraph can open deterministically.
		if lt.pressure_exceeds_threshold() and district.inspection_ticks <= 0 \
				and not _telegraph_seen:
			district.inspection_ticks = 60
		# Preventability: the moment the telegraph opens, the player sits him down.
		if _telegraph_seen and lt.betrayal_ticks_until_land >= 0 and not _defused_seen:
			var ok := _relationships.reassure(lt)
			print("    [dbg] reassure t=%d ok=%s p=%.3f ticks=%d" % [TimeService.tick_index,
				ok, lt.betrayal_pressure(), lt.betrayal_ticks_until_land])
		# Mid-chain persistence: save once between beat_debt firing and the accord.
		if not saved_midchain and &"beat_debt" in _beats_fired:
			saved_midchain = true
			_check(SaveService.save_game(SLOT), "mid-chain save succeeds")
			var flags_before := var_to_str(GameState.narrative_flags)
			GameState.narrative_flags[&"tamper"] = true  # diverge, then prove restore
			_check(SaveService.load_game(SLOT), "mid-chain load succeeds")
			_check(var_to_str(GameState.narrative_flags) == flags_before,
				"narrative flags survive the mid-chain roundtrip byte-for-byte")
		if GameState.narrative_flags.get(&"accord_stance", &"") != &"":
			break

	# Phase 2 — assertions over the whole run (fresh lookups — same staleness rule).
	var district := GameState.get_district(&"glass_wharf")
	_check(&"beat_ledger" in _beats_fired, "beat_ledger fired after the cold open")
	_check(&"beat_debt" in _beats_fired, "beat_debt fired after the ledger")
	_check(&"beat_accord" in _beats_fired, "beat_accord fired after the debt")
	_check(_beats_fired == [&"beat_ledger", &"beat_debt", &"beat_accord"],
		"beats fired strictly in authored order")
	_check(district.evidence_cases.size() > 0 or district.local_heat > 0.1,
		"the loud ledger left real trace (case or heat)")
	_check(_telegraph_seen, "the loyalty crisis TELEGRAPHED (two gates held)")
	_check(_defused_seen, "the reassure sit-down DEFUSED it (preventable, §7.6)")
	_check(GameState.narrative_flags.get(&"accord_stance", &"") == &"leverage",
		"accord stance recorded from the chosen approach")
	_check(GameState.narrative_flags.get(&"ledger_secured", false) == true,
		"ledger_secured recorded from the ledger outcome")

	# Phase 3 — end-of-chain save/load: stance survives.
	_check(SaveService.save_game(SLOT), "final save succeeds")
	var stance_before: StringName = GameState.narrative_flags[&"accord_stance"]
	WorldSeed.build()  # hard reset — a genuinely different world
	_check(GameState.narrative_flags.is_empty(), "reset clears narrative flags")
	_check(SaveService.load_game(SLOT), "final load succeeds")
	_check(GameState.narrative_flags.get(&"accord_stance", &"") == stance_before,
		"accord stance survives a full save/load")

	if _failures == 0:
		print("[PASS] NARRATIVE CHAIN CLOSES — authored spine, crisis, persistence all hold")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d narrative probe assertion(s) failed" % _failures)
		get_tree().quit(1)

func _on_offered(job: JobData) -> void:
	_resolve_at[job.id] = TimeService.tick_index + RESOLVE_DELAY

## The fixed script: loud on the ledger (plant the case), bait on the debt (open the
## crisis), from-strength at the accord (stance=leverage). Everything else quiet-ish.
func _resolve_due(tick: int) -> void:
	for job_id in _resolve_at.keys():
		if _resolve_at[job_id] > tick:
			continue
		_resolve_at.erase(job_id)
		var job := JobDirector.get_job(job_id)
		if job == null or job.stage == BM.JobStage.RESOLVED:
			continue
		JobDirector.begin(job_id)
		var prep: JobChoiceData = job.prep_actions[0]
		JobDirector.choose_prep(job_id, prep.id)
		var approach := _scripted_approach(job)
		JobDirector.choose_approach(job_id, approach)
		JobDirector.choose_coverup(job_id, job.coverups[0].id)

func _scripted_approach(job: JobData) -> StringName:
	match job.id:
		&"job_inspectors_ledger":
			return &"appr_smash_grab"
		&"job_lieutenants_debt":
			return &"appr_bait"
		&"job_meridian_accord":
			return &"appr_from_strength"
		_:
			return job.approaches[0].id
