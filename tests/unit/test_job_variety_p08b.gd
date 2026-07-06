extends Node
## P08b unit test — deterministic template variety within a job origin (brief §7.5).
## Two origins (retaliation, bury_case) carry two authored variants each, picked by a
## splitmix64-avalanche hash of the id string — zero RNG, byte-identical on rebuild.
## Run as a scene, NOT via -s (-s skips autoloads):
##   Godot --headless --path . res://tests/unit/test_job_variety_p08b.tscn

const SPREAD := 32  # tick spread for reachability / rebuild scans

var _failures := 0

func _ready() -> void:
	_test_variant_is_deterministic()
	_test_rebuild_matches_generate()
	_test_both_variants_reachable()
	_test_variety_balance_invariant()
	_test_no_rng_in_job_sources()
	if _failures == 0:
		print("[PASS] all P08b job variety tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d P08b job variety assertion(s) failed" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("  assertion failed: ", msg)

func _fresh_world() -> void:
	WorldSeed.build()
	TimeService.set_speed(BM.Speed.PAUSED)
	TimeService.tick_index = 0

func _venue(venue_id: StringName) -> VenueData:
	for d in GameState.districts:
		for v in d.venues:
			if v.id == venue_id:
				return v
	return null

## Hand-plant a case IN the district so JobGenerator.rebuild's find_case resolves it.
func _planted_case(d: DistrictData, tick: int) -> EvidenceCaseData:
	var c := EvidenceCaseData.new()
	c.id = StringName("case@%s@%d@%d" % [d.id, BM.EvidenceKind.MANIFEST, tick])
	c.kind = BM.EvidenceKind.MANIFEST
	c.weight = 0.3
	c.label = EvidenceMath.KIND_LABELS[BM.EvidenceKind.MANIFEST]
	d.evidence_cases.append(c)
	return c

## Byte-identical authored content: every field a template authors, per choice list —
## ids alone can't distinguish variants (they share the id set), so labels/descriptions
## and effects are compared too.
func _same_authored(a: JobData, b: JobData, ctx: String) -> void:
	_check(a.title == b.title, "%s: title matches (%s vs %s)" % [ctx, a.title, b.title])
	_check(a.apparent_problem == b.apparent_problem, "%s: apparent_problem matches" % ctx)
	_check(a.visible_stakes == b.visible_stakes and a.hidden_stakes == b.hidden_stakes,
		"%s: stakes match" % ctx)
	_check(a.known_evidence == b.known_evidence, "%s: known_evidence matches" % ctx)
	_check(a.deadline_ticks == b.deadline_ticks and a.reward_dirty == b.reward_dirty,
		"%s: deadline + reward match" % ctx)
	for pair in [[a.prep_actions, b.prep_actions, "prep"], [a.approaches, b.approaches, "appr"],
			[a.coverups, b.coverups, "cover"]]:
		var la: Array = pair[0]
		var lb: Array = pair[1]
		_check(la.size() == lb.size(), "%s: %s list size matches" % [ctx, pair[2]])
		if la.size() != lb.size():
			continue
		for i in la.size():
			_check(la[i].id == lb[i].id and la[i].label == lb[i].label
				and la[i].description == lb[i].description and la[i].effects == lb[i].effects,
				"%s: %s[%d] choice is byte-identical" % [ctx, pair[2], i])

## Variant index by observable content (titles are authored distinct per variant).
func _retaliation_variant_of(job: JobData) -> int:
	return 0 if job.title == "Answer in Kind" else 1

func _bury_variant_of(job: JobData) -> int:
	return 0 if job.title == "Bury the Case" else 1

## 1 — same (venue, rival, tick) always lands the same variant. No drift across calls.
func _test_variant_is_deterministic() -> void:
	_fresh_world()
	var venue := _venue(&"gw_contraband")
	var rival := GameState.get_faction(&"corvine")
	var first := JobGenerator.retaliation_job(venue, rival, 42)
	for i in 10:
		var again := JobGenerator.retaliation_job(venue, rival, 42)
		if again.title != first.title or again.apparent_problem != first.apparent_problem:
			_check(false, "retaliation variant drifted on repeat call %d" % i)
			return
	_check(true, "")

## 2 — the P02 contract: rebuild(id) reproduces the byte-identical authored content,
## proven for a job that lands on variant 0 AND one that lands on variant 1, for BOTH
## origins. If the tick scan can't find both variants, the hash isn't spreading — that
## is a FAILURE (the pre-fix P07b frozen-jitter bug), not something to fudge around.
func _test_rebuild_matches_generate() -> void:
	_fresh_world()
	var venue := _venue(&"gw_contraband")
	var rival := GameState.get_faction(&"corvine")
	var by_variant: Array[JobData] = [null, null]
	for t in SPREAD:
		var job := JobGenerator.retaliation_job(venue, rival, t)
		if by_variant[_retaliation_variant_of(job)] == null:
			by_variant[_retaliation_variant_of(job)] = job
	for v in 2:
		_check(by_variant[v] != null,
			"retaliation tick scan found a variant-%d job (hash must spread)" % v)
		if by_variant[v] == null:
			continue
		var rebuilt := JobGenerator.rebuild(by_variant[v].id, GameState.districts,
			GameState.factions)
		_check(rebuilt != null, "retaliation variant %d rebuilds from its id" % v)
		if rebuilt != null:
			_same_authored(by_variant[v], rebuilt, "retaliation v%d rebuild" % v)
	# Same proof for the second origin.
	var district := GameState.get_district(&"glass_wharf")
	var bury_by_variant: Array[JobData] = [null, null]
	for t in SPREAD:
		var job := JobGenerator.bury_case_job(_planted_case(district, t), district, t)
		if bury_by_variant[_bury_variant_of(job)] == null:
			bury_by_variant[_bury_variant_of(job)] = job
	for v in 2:
		_check(bury_by_variant[v] != null,
			"bury_case tick scan found a variant-%d job (hash must spread)" % v)
		if bury_by_variant[v] == null:
			continue
		var rebuilt := JobGenerator.rebuild(bury_by_variant[v].id, GameState.districts,
			GameState.factions)
		_check(rebuilt != null, "bury_case variant %d rebuilds from its id" % v)
		if rebuilt != null:
			_same_authored(bury_by_variant[v], rebuilt, "bury_case v%d rebuild" % v)

## 3 — the hash actually splits: across a spread of ticks BOTH variants occur for both
## origins (not frozen to one side like the pre-fix P07b jitter).
func _test_both_variants_reachable() -> void:
	_fresh_world()
	var venue := _venue(&"gw_contraband")
	var rival := GameState.get_faction(&"corvine")
	var counts := [0, 0]
	for t in SPREAD:
		counts[_retaliation_variant_of(JobGenerator.retaliation_job(venue, rival, t))] += 1
	_check(counts[0] > 0 and counts[1] > 0,
		"retaliation hits both variants over %d ticks (v0=%d v1=%d)" % [SPREAD, counts[0], counts[1]])
	var district := GameState.get_district(&"glass_wharf")
	var bury_counts := [0, 0]
	for t in SPREAD:
		bury_counts[_bury_variant_of(
			JobGenerator.bury_case_job(_planted_case(district, 100 + t), district, t))] += 1
	_check(bury_counts[0] > 0 and bury_counts[1] > 0,
		"bury_case hits both variants over %d ticks (v0=%d v1=%d)" % [SPREAD, bury_counts[0], bury_counts[1]])

## Pick the choice whose evidence_generated effect is extremal — read off the REAL
## effects dicts (same discipline as test_evidence), never a hardcoded "which id is loud".
func _extremal_by_evidence(choices: Array, want_max: bool) -> JobChoiceData:
	var best: JobChoiceData = null
	var best_ev := 0.0
	for c in choices:
		var ev: float = float(c.effects.get(&"evidence_generated", 0.0))
		if best == null or (want_max and ev > best_ev) or (not want_max and ev < best_ev):
			best = c
			best_ev = ev
	return best

## 4 — the P06d balance envelope holds for EVERY retaliation variant: loudest lifecycle
## nets >= +0.25 evidence, quietest <= -0.3. The new variant is authored to the same
## contract test_evidence guards for variant 0.
func _test_variety_balance_invariant() -> void:
	for v in JobTemplates.RETALIATION_VARIANTS:
		var t := JobTemplates.retaliation("Venue", "Rival", v)
		var loud_net := float(_extremal_by_evidence(t.approaches, true).effects.get(&"evidence_generated", 0.0)) \
			+ float(_extremal_by_evidence(t.coverups, true).effects.get(&"evidence_generated", 0.0))
		var quiet_net := float(_extremal_by_evidence(t.approaches, false).effects.get(&"evidence_generated", 0.0)) \
			+ float(_extremal_by_evidence(t.coverups, false).effects.get(&"evidence_generated", 0.0))
		_check(loud_net >= 0.25 - 0.0001,
			"variant %d loudest retaliation lifecycle nets >= +0.25 (got %f)" % [v, loud_net])
		_check(quiet_net <= -0.3 + 0.0001,
			"variant %d quietest retaliation lifecycle nets <= -0.3 (got %f)" % [v, quiet_net])
	# The variants are genuinely distinct reads, not one template twice.
	var v0 := JobTemplates.retaliation("Venue", "Rival", 0)
	var v1 := JobTemplates.retaliation("Venue", "Rival", 1)
	_check(v0.title != v1.title and v0.apparent_problem != v1.apparent_problem,
		"retaliation variants are distinct reading experiences")
	var b0 := JobTemplates.bury_case("Case", "District", 0)
	var b1 := JobTemplates.bury_case("Case", "District", 1)
	_check(b0.title != b1.title and b0.apparent_problem != b1.apparent_problem,
		"bury_case variants are distinct reading experiences")

## 5 — the house rule at the source level: zero RNG in the job source files.
func _test_no_rng_in_job_sources() -> void:
	for path in ["res://src/jobs/job_generator.gd", "res://src/jobs/job_templates.gd"]:
		var text := FileAccess.get_file_as_string(path)
		_check(text != "", "%s readable" % path)
		_check(not ("randf" in text) and not ("randi" in text) and not ("randomize" in text)
			and not ("RandomNumberGenerator" in text), "%s contains no RNG calls" % path)
