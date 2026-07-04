extends Node
## P06b unit test — evidence chains: heat gets roots the player can attack (brief §7.3,
## §7.6). Cases accrue from the signed evidence axis, pin the inspection latch, erode
## under cover-ups, burn under the aimed "Bury the Case" job, and survive save/load.
## Run as a scene, NOT via -s (-s skips autoloads):
##   Godot --headless --path . res://tests/unit/test_evidence.tscn

var _failures := 0
var _inspection_fires := 0

func _ready() -> void:
	EconomyService.inspection_started.connect(func(_d): _inspection_fires += 1)
	await get_tree().process_frame  # JobDirector wires its triggers deferred
	_test_no_rng_in_evidence_files()
	_test_positive_evidence_spawns_then_grows_oldest()
	_test_case_pressure_is_clamped_and_deterministic()
	_test_cases_pin_the_inspection()
	_test_passive_erosion_hits_strongest()
	_test_burn_removes_targeted_case()
	_test_retaliation_evidence_invariants()
	_test_loud_retaliation_bootstraps_a_case()
	_test_quiet_retaliation_stays_clean()
	_test_cases_survive_save_load()
	if _failures == 0:
		print("[PASS] all evidence chain tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d evidence chain assertion(s) failed" % _failures)
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
	JobDirector.pending_followups = []
	_inspection_fires = 0
	return GameState.get_district(&"glass_wharf")

func _pump(n: int) -> void:
	for i in n:
		TimeService._do_tick()

func _pause_player_rackets(paused: bool) -> void:
	for v in GameState.get_district(&"glass_wharf").venues:
		if v.type == BM.VenueType.RACKET and v.owner_faction == GameState.player_faction_id:
			EconomyService.set_racket_paused(v, paused)

## Hand-plant a case (setup shortcut — accrual itself is under test elsewhere).
func _case(d: DistrictData, id: StringName, weight: float,
		kind: int = BM.EvidenceKind.MANIFEST) -> EvidenceCaseData:
	var c := EvidenceCaseData.new()
	c.id = id
	c.kind = kind
	c.weight = weight
	c.label = EvidenceMath.KIND_LABELS[kind]
	d.evidence_cases.append(c)
	return c

## A resolved job carrying only a signed evidence outcome, applied through the real
## writer (JobLifecycle.apply_outcome) with hand-built data — no autoload state touched.
func _apply_evidence(d: DistrictData, evidence: float, tick: int = 0) -> void:
	var job := JobTemplates.intercepted_shipment()
	job.outcome = JobResolution.blank()
	job.outcome[&"evidence_generated"] = evidence
	var involved: Array[CharacterData] = []
	JobLifecycle.apply_outcome(job, FactionData.new(), d, involved, tick)

## The house rule at the source level: zero RNG in the new evidence files.
func _test_no_rng_in_evidence_files() -> void:
	for path in ["res://src/simulation/evidence_math.gd", "res://src/core/evidence_case_data.gd"]:
		var text := FileAccess.get_file_as_string(path)
		_check(text != "", "%s readable" % path)
		_check(not ("randf" in text) and not ("randi" in text) and not ("randomize" in text),
			"%s contains no RNG calls" % path)

## Accrual: positive evidence spawns a case; at the cap, new trace grows the OLDEST.
func _test_positive_evidence_spawns_then_grows_oldest() -> void:
	var d := DistrictData.new()
	d.id = &"testd"
	_apply_evidence(d, 0.3, 1)
	_check(d.evidence_cases.size() == 1,
		"positive evidence spawns a case (got %d)" % d.evidence_cases.size())
	if d.evidence_cases.is_empty():
		return
	_check(absf(d.evidence_cases[0].weight - 0.3) < 0.0001, "case weight = deposited evidence")
	_check(String(d.evidence_cases[0].id).begins_with("case@testd@"), "case id is parseable")
	_check(d.evidence_cases[0].label != "", "case carries a human label")
	for t in range(2, 1 + EvidenceMath.MAX_CASES):  # distinct ticks -> distinct case ids
		_apply_evidence(d, 0.3, t)
	_check(d.evidence_cases.size() == EvidenceMath.MAX_CASES, "list fills to the cap")
	var oldest: EvidenceCaseData = d.evidence_cases[0]
	var before := oldest.weight
	_apply_evidence(d, 0.3, 99)
	_check(d.evidence_cases.size() == EvidenceMath.MAX_CASES,
		"case count stays bounded at %d" % EvidenceMath.MAX_CASES)
	_check(oldest.weight > before, "at the cap, new trace grows the OLDEST case")

## case_pressure: clamped sum of weights, pure and deterministic.
func _test_case_pressure_is_clamped_and_deterministic() -> void:
	var cases: Array[EvidenceCaseData] = []
	_check(EvidenceMath.case_pressure(cases) == 0.0, "empty list = zero pressure")
	for w in [0.2, 0.3]:
		var c := EvidenceCaseData.new()
		c.weight = w
		cases.append(c)
	_check(absf(EvidenceMath.case_pressure(cases) - 0.5) < 0.0001, "pressure = sum of weights")
	var big := EvidenceCaseData.new()
	big.weight = 0.9
	cases.append(big)
	_check(EvidenceMath.case_pressure(cases) == 1.0, "pressure clamps at 1")
	var first := EvidenceMath.case_pressure(cases)
	for i in 50:
		if EvidenceMath.case_pressure(cases) != first:
			_check(false, "case_pressure diverged on call %d" % i)
			return
	_check(true, "")  # 50 identical evaluations

## The roots pin the sweep: with raw heat well BELOW the old threshold, standing cases
## fire the inspection — and combined pressure below the bar does not.
func _test_cases_pin_the_inspection() -> void:
	var d := _fresh_world()
	_pause_player_rackets(true)  # kill the flow; only the case layer can pin from here
	d.local_heat = 0.2  # -0.25 under the 0.45 threshold on its own
	_case(d, &"case@glass_wharf@0@900", 0.2)  # combined 0.2 + 0.5*0.2 = 0.30 < 0.45
	_pump(1)
	_check(_inspection_fires == 0,
		"combined pressure below the bar does not fire (got %d)" % _inspection_fires)
	_case(d, &"case@glass_wharf@1@901", 0.5)
	_case(d, &"case@glass_wharf@2@902", 0.5)  # pressure clamps 1.0 -> combined 0.70
	var heat_before: float = d.local_heat
	_pump(1)
	_check(d.local_heat <= heat_before, "raw heat was decaying, not rising")
	_check(_inspection_fires == 1,
		"case pressure alone pins the inspection (got %d)" % _inspection_fires)
	_check(d.inspection_ticks == EconomyService.INSPECTION_DURATION_TICKS, "sweep armed")
	var burn: JobData = null
	for j in JobDirector.active_jobs:
		if j.origin == BM.JobOrigin.EVIDENCE_CHAIN:
			burn = j
	_check(burn != null, "the sweep auto-offers a Bury the Case job")
	_pause_player_rackets(false)

## Path A: negative evidence erodes the STRONGEST case; a case ground to zero is removed.
func _test_passive_erosion_hits_strongest() -> void:
	var d := DistrictData.new()
	d.id = &"testd"
	var weak := _case(d, &"case@testd@0@1", 0.2)
	var strong := _case(d, &"case@testd@1@2", 0.5)
	_apply_evidence(d, -0.3)
	_check(absf(strong.weight - 0.2) < 0.0001,
		"erosion hits the strongest case (got %f)" % strong.weight)
	_check(absf(weak.weight - 0.2) < 0.0001, "the weaker case is untouched")
	_apply_evidence(d, -0.3)  # tie at 0.2/0.2 breaks to the earliest -> weak grinds to zero
	_check(d.evidence_cases.size() == 1,
		"a case ground to zero is removed (got %d)" % d.evidence_cases.size())
	_check(EvidenceMath.find_case(d, strong.id) != null, "the other case still stands")

## Path B: resolving a bury_case job removes the TARGETED case (by id) — proven against
## a STRONGER bystander case that must survive the aimed strike.
func _test_burn_removes_targeted_case() -> void:
	var d := _fresh_world()
	var target := _case(d, &"case@glass_wharf@0@10", 0.3)
	var bystander := _case(d, &"case@glass_wharf@1@11", 0.8)
	var job := JobGenerator.bury_case_job(target, d, 20)
	_check(job.origin == BM.JobOrigin.EVIDENCE_CHAIN, "bury job carries the new origin")
	JobDirector.offer(job)
	JobDirector.begin(job.id)
	JobDirector.choose_approach(job.id, &"appr_custodian")  # evidence -0.4
	JobDirector.choose_coverup(job.id, &"cover_never_was")  # evidence -0.15 -> net -0.55
	_check(job.stage == BM.JobStage.RESOLVED, "burn resolved")
	_check(EvidenceMath.find_case(d, target.id) == null, "the TARGETED case is removed")
	_check(EvidenceMath.find_case(d, bystander.id) != null,
		"the stronger bystander still stands — the burn is aimed, not strongest-first")
	# The clumsy route: net POSITIVE evidence leaves the targeted case standing.
	var target2 := _case(d, &"case@glass_wharf@2@12", 0.3)
	var botch := JobGenerator.bury_case_job(target2, d, 30)
	JobDirector.offer(botch)
	JobDirector.begin(botch.id)
	JobDirector.choose_approach(botch.id, &"appr_snatch")  # evidence +0.2
	JobDirector.choose_coverup(botch.id, &"cover_walk")    # nothing suppressed -> net +0.2
	_check(EvidenceMath.find_case(d, target2.id) != null,
		"a botched burn leaves the targeted case standing")

## Pick the choice whose evidence_generated effect is extremal — read off the REAL
## effects dicts (the full-cycle-probe discipline), never a hardcoded "which id is loud".
## Ties break to the first authored option (deterministic).
func _extremal_by_evidence(choices: Array, want_max: bool) -> JobChoiceData:
	var best: JobChoiceData = null
	var best_ev := 0.0
	for c in choices:
		var ev: float = float(c.effects.get(&"evidence_generated", 0.0))
		if best == null or (want_max and ev > best_ev) or (not want_max and ev < best_ev):
			best = c
			best_ev = ev
	return best

## Drive a REAL generated retaliation job (JobGenerator targeting, real venue, real
## rival) to RESOLVED through the shipped JobDirector path — begin -> approach ->
## coverup -> apply_outcome. No hand-built outcome dict anywhere (P06d: hand-injected
## outcomes are exactly what masked the bootstrap gap).
func _run_retaliation(d: DistrictData, loud: bool, tick: int) -> JobData:
	var venue: VenueData = null
	for v in d.venues:
		if v.owner_faction == GameState.player_faction_id:
			venue = v
			break
	var job := JobGenerator.retaliation_job(venue, GameState.get_faction(&"corvine"), tick)
	JobDirector.offer(job)
	JobDirector.begin(job.id)
	JobDirector.choose_approach(job.id, _extremal_by_evidence(job.approaches, loud).id)
	JobDirector.choose_coverup(job.id, _extremal_by_evidence(job.coverups, loud).id)
	return job

## P06d invariants, asserted directly off the template so a future edit that re-breaks
## the bootstrap fails here: the loudest lifecycle nets >= +0.25, the quietest <= -0.3.
func _test_retaliation_evidence_invariants() -> void:
	var t := JobTemplates.retaliation("Venue", "Rival")
	var loud_net := float(_extremal_by_evidence(t.approaches, true).effects.get(&"evidence_generated", 0.0)) \
		+ float(_extremal_by_evidence(t.coverups, true).effects.get(&"evidence_generated", 0.0))
	var quiet_net := float(_extremal_by_evidence(t.approaches, false).effects.get(&"evidence_generated", 0.0)) \
		+ float(_extremal_by_evidence(t.coverups, false).effects.get(&"evidence_generated", 0.0))
	_check(loud_net >= 0.25 - 0.0001,
		"loudest retaliation lifecycle nets >= +0.25 evidence (got %f)" % loud_net)
	_check(quiet_net <= -0.3 + 0.0001,
		"quietest retaliation lifecycle nets <= -0.3 evidence (got %f)" % quiet_net)

## The bootstrap: a LOUD retaliation — the dominant job of real play — deposits the
## first case with no manual injection. This is the chain the long-session gate found
## dead: feud -> loud answer -> positive net evidence -> case -> combined pressure.
func _test_loud_retaliation_bootstraps_a_case() -> void:
	var d := _fresh_world()
	_check(d.evidence_cases.is_empty(), "fresh world starts caseless")
	var job := _run_retaliation(d, true, 60)
	_check(job.stage == BM.JobStage.RESOLVED, "loud retaliation resolved")
	_check(float(job.outcome.get(&"evidence_generated", 0.0)) > 0.0,
		"loud resolution nets positive evidence (got %f)" % float(job.outcome.get(&"evidence_generated", 0.0)))
	_check(d.evidence_cases.size() == 1,
		"the loud answer deposits a case, no hand injection (got %d)" % d.evidence_cases.size())
	if not d.evidence_cases.is_empty():
		_check(d.evidence_cases[0].weight > 0.0, "the deposited case carries weight")
		_check(String(d.evidence_cases[0].id).begins_with("case@glass_wharf@"),
			"retaliation-born case id is burn-path parseable (got %s)" % d.evidence_cases[0].id)

## The fork's other tine: a QUIET retaliation deposits nothing, and against a standing
## case it erodes — a careful answer still keeps you clean (net-negative preserved).
func _test_quiet_retaliation_stays_clean() -> void:
	var d := _fresh_world()
	var job := _run_retaliation(d, false, 70)
	_check(job.stage == BM.JobStage.RESOLVED, "quiet retaliation resolved")
	_check(float(job.outcome.get(&"evidence_generated", 0.0)) < 0.0,
		"quiet resolution nets negative evidence (got %f)" % float(job.outcome.get(&"evidence_generated", 0.0)))
	_check(d.evidence_cases.is_empty(),
		"the quiet answer deposits NO case (got %d)" % d.evidence_cases.size())
	var standing := _case(d, &"case@glass_wharf@0@71", 0.5)
	_run_retaliation(d, false, 72)
	_check(standing.weight < 0.5,
		"against a standing case, the quiet answer erodes it (got %f)" % standing.weight)

## Cases survive save/load exactly; an in-flight EVIDENCE_CHAIN job rehydrates by id.
func _test_cases_survive_save_load() -> void:
	var d := _fresh_world()
	_case(d, &"case@glass_wharf@0@40", 0.35)
	var target := _case(d, &"case@glass_wharf@3@41", 0.6, BM.EvidenceKind.PHYSICAL)
	var job := JobGenerator.bury_case_job(target, d, 50)
	JobDirector.offer(job)
	JobDirector.begin(job.id)
	_check(SaveService.save_game("p06b_test"), "save mid-case")
	WorldSeed.build()
	JobDirector.active_jobs = []
	_check(GameState.get_district(&"glass_wharf").evidence_cases.is_empty(),
		"fresh world starts with no cases")
	_check(SaveService.load_game("p06b_test"), "load")
	var rd := GameState.get_district(&"glass_wharf")
	_check(rd.evidence_cases.size() == 2,
		"cases survive save/load (got %d)" % rd.evidence_cases.size())
	var rc := EvidenceMath.find_case(rd, target.id)
	_check(rc != null and rc.weight == target.weight and rc.kind == target.kind
		and rc.label == target.label, "case fields round-trip exactly (full float precision)")
	var restored := JobDirector.get_job(job.id)
	_check(restored != null, "burycase job rehydrates by id")
	if restored:
		_check(restored.origin == BM.JobOrigin.EVIDENCE_CHAIN,
			"EVIDENCE_CHAIN origin survives the round-trip")
		_check(restored.stage == BM.JobStage.PREPARATION, "runtime stage restored")
		_check(restored.approaches.size() == 3, "authored content rebuilt from the id")
