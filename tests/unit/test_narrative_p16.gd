extends Node
## P16 unit test — the authored narrative chain (brief §13.2, §7.6). Guards: the job
## registry resolves the three authored ids (save rebuild contract), the beat chain
## gates strictly in order with the lead window, the evidence envelope on the ledger
## job, and the loyalty-crisis preventability contract (pay_it stays under the betrayal
## bar, bait/expiry go safely over — margins per tasks/lessons.md, never ON the bar).
## Run as a scene, NOT via -s (-s skips autoloads):
##   Godot --headless --path . res://tests/unit/test_narrative_p16.tscn

var _failures := 0

func _ready() -> void:
	_test_registry_and_shape()
	_test_origins_never_hit_gated_branches()
	_test_ledger_evidence_envelope()
	_test_beat_chain_gating()
	_test_fire_writes_and_preventability()
	_test_accord_stance()
	if _failures == 0:
		print("[PASS] all P16 narrative tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d P16 narrative assertion(s) failed" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("  assertion failed: ", msg)

func _fresh_world() -> void:
	WorldSeed.build()
	TimeService.set_speed(BM.Speed.PAUSED)
	TimeService.tick_index = 0

const NARRATIVE_IDS: Array[StringName] = [&"job_inspectors_ledger",
	&"job_lieutenants_debt", &"job_meridian_accord"]

func _test_registry_and_shape() -> void:
	for id in NARRATIVE_IDS:
		var job := JobTemplates.by_id(id)  # the save-rebuild route, not NarrativeJobs directly
		_check(job != null, "%s resolves through JobTemplates.by_id" % id)
		if job == null:
			continue
		_check(job.id == id, "%s: id round-trips" % id)
		_check(job.prep_actions.size() >= 3, "%s: >=3 preps" % id)
		_check(job.approaches.size() == 3, "%s: 3 approaches" % id)
		_check(job.coverups.size() == 3, "%s: 3 coverups" % id)
		var seen := {}
		for list: Array in [job.prep_actions, job.approaches, job.coverups]:
			for c in list:
				_check(not seen.has(c.id), "%s: choice id %s unique" % [id, c.id])
				seen[c.id] = true
	_check(JobTemplates.by_id(&"job_nonexistent") == null, "unknown id still null")

## The JobDirector post-outcome branches are origin-gated; narrative jobs must never
## take the TERRITORY_LOSS (venue reassignment) or EVIDENCE_CHAIN (case burn) branch.
func _test_origins_never_hit_gated_branches() -> void:
	for id in NARRATIVE_IDS:
		var job := JobTemplates.by_id(id)
		_check(job.origin != BM.JobOrigin.TERRITORY_LOSS and \
			job.origin != BM.JobOrigin.EVIDENCE_CHAIN,
			"%s: origin avoids gated post-outcome branches" % id)

## P06d-style envelope on the authored evidence beat: the loudest full lifecycle nets
## >= +0.25 evidence (the incident feeds a real case), the quietest <= -0.3.
func _test_ledger_evidence_envelope() -> void:
	var job := NarrativeJobs.inspectors_ledger()
	var loud := _extreme_evidence(job, true)
	var quiet := _extreme_evidence(job, false)
	_check(loud >= 0.25, "ledger loudest lifecycle nets >= +0.25 (got %.2f)" % loud)
	_check(quiet <= -0.3, "ledger quietest lifecycle nets <= -0.3 (got %.2f)" % quiet)

func _extreme_evidence(job: JobData, loudest: bool) -> float:
	var total := 0.0
	for p in job.prep_actions:
		var e: float = p.effects.get(&"evidence_generated", 0.0)
		if (loudest and e > 0.0) or (not loudest and e < 0.0):
			total += e
	total += _extreme_of(job.approaches, loudest)
	total += _extreme_of(job.coverups, loudest)
	return clampf(total, -1.0, 1.0)

func _extreme_of(choices: Array[JobChoiceData], loudest: bool) -> float:
	var best := -INF if loudest else INF
	for c in choices:
		var e: float = c.effects.get(&"evidence_generated", 0.0)
		best = maxf(best, e) if loudest else minf(best, e)
	return best

func _test_beat_chain_gating() -> void:
	var flags := {}
	_check(NarrativeBeats.ready_beat(flags, 10_000) == &"", "no beat before the cold open resolves")
	flags[&"resolved@job_intercepted_shipment"] = 100
	_check(NarrativeBeats.ready_beat(flags, 100 + NarrativeBeats.LEAD_TICKS - 1) == &"",
		"lead window holds the beat")
	_check(NarrativeBeats.ready_beat(flags, 100 + NarrativeBeats.LEAD_TICKS) == &"beat_ledger",
		"beat_ledger ready after the lead")
	flags[&"fired@beat_ledger"] = true
	_check(NarrativeBeats.ready_beat(flags, 10_000) == &"", "fired beat never re-fires; chain waits")
	flags[&"resolved@job_inspectors_ledger"] = 500
	_check(NarrativeBeats.ready_beat(flags, 530) == &"beat_debt", "beat_debt chains off the ledger")
	flags[&"fired@beat_debt"] = true
	flags[&"resolved@job_lieutenants_debt"] = 900
	_check(NarrativeBeats.ready_beat(flags, 930) == &"beat_accord", "beat_accord chains off the debt")
	flags[&"fired@beat_accord"] = true
	_check(NarrativeBeats.ready_beat(flags, 100_000) == &"", "chain complete — nothing after the accord")

## The loyalty-crisis contract (§7.6): after the beat fires, the SUPPORTIVE approach
## keeps the lieutenant under the betrayal bar with margin; bait and expiry push him
## over with margin. Runs the REAL pipeline: apply_outcome + apply_resolution.
func _test_fire_writes_and_preventability() -> void:
	for approach in [&"appr_pay_it", &"appr_buy_marker", &"appr_bait", &""]:
		_fresh_world()
		var lt := GameState.get_character(&"bengal_lt")
		NarrativeBeats.apply_fire(&"beat_debt", GameState.characters)
		_check(lt.rival_leverage >= 0.6 and lt.survival_pressure >= 0.4,
			"beat_debt fire arms leverage + survival pressure")
		_check(not lt.pressure_exceeds_threshold(),
			"the fire alone does not open the crisis (approach decides)")
		var job := NarrativeJobs.lieutenants_debt()
		job.chosen_approach = approach
		job.outcome = JobResolution.blank()
		if approach != &"":
			var choice := job.find_choice(job.approaches, approach)
			job.outcome[&"relationship_change"] = choice.effects.get(&"relationship_change", 0.0)
		JobLifecycle.apply_outcome(job, GameState.player_faction(),
			GameState.get_district(&"glass_wharf"), [lt], 0)
		NarrativeBeats.apply_resolution(job, GameState.characters, GameState.narrative_flags)
		var over := lt.pressure_exceeds_threshold()
		var bar := lt.betrayal_threshold * 2.0
		var margin := absf(lt.betrayal_pressure() - bar)
		match approach:
			&"appr_pay_it", &"appr_buy_marker":
				_check(not over, "%s keeps the lieutenant under the bar (p=%.2f)"
					% [approach, lt.betrayal_pressure()])
			_:
				_check(over, "%s pushes the lieutenant over the bar (p=%.2f)"
					% [approach if approach != &"" else &"expired", lt.betrayal_pressure()])
		_check(margin >= 0.05, "%s: >=0.05 margin off the bar (%.3f)" % [approach, margin])

func _test_accord_stance() -> void:
	var cases := {&"appr_good_faith": &"truce", &"appr_from_strength": &"leverage",
		&"appr_walk_out": &"war", &"": &"war"}
	for approach in cases:
		var flags := {}
		var job := NarrativeJobs.meridian_accord()
		job.chosen_approach = approach
		job.outcome = JobResolution.blank()
		NarrativeBeats.apply_resolution(job, [], flags)
		_check(flags.get(&"accord_stance", &"") == cases[approach],
			"accord %s -> %s" % [approach, cases[approach]])
	# The ledger's material flag both ways.
	for objective in [0.8, 0.2]:
		var flags := {}
		var job := NarrativeJobs.inspectors_ledger()
		job.outcome = JobResolution.blank()
		job.outcome[&"objective_achieved"] = objective
		NarrativeBeats.apply_resolution(job, [], flags)
		_check(flags.get(&"ledger_secured", null) == (objective >= 0.5),
			"ledger_secured tracks objective %.1f" % objective)
