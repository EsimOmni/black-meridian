extends Node
## P04b unit test — suppression dimensions must survive the clamp (the gate regression:
## _clamp() floored evidence_generated / operative_injury to 0 while the authored data
## feeds them negative on purpose). Run as a scene, NOT via -s (-s skips autoloads):
##   Godot --headless --path . res://tests/unit/test_job_resolution.tscn

var _failures := 0

func _ready() -> void:
	_test_clean_job_reads_net_negative_evidence()
	_test_lookouts_protects_operatives()
	_test_relationship_change_still_clamped()
	_test_no_dimension_exceeds_unit_range()
	if _failures == 0:
		print("[PASS] all job resolution clamp tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d job resolution assertion(s) failed" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("  assertion failed: ", msg)

## Drive a fresh placeholder job through the lifecycle with the given choices and resolve.
func _resolve(preps: Array[StringName], approach: StringName, coverup: StringName) -> Dictionary:
	var job := PlaceholderJobs.intercepted_shipment()
	JobLifecycle.begin(job)
	for p in preps:
		JobLifecycle.choose_prep(job, p)
	JobLifecycle.choose_approach(job, approach)
	JobLifecycle.choose_coverup(job, coverup)
	return job.outcome

## The exact regression from the gate probe: Scout(-0.1) + Quiet(+0.1) + Paper(-0.3) = -0.30,
## which the old clamp erased to 0.0 ("I left no trace" was invisible).
func _test_clean_job_reads_net_negative_evidence() -> void:
	var out := _resolve([&"prep_scout"], &"appr_quiet", &"cover_paper")
	_check(out[&"evidence_generated"] < 0.0, "clean job evidence is net-negative, not clamped to 0")
	_check(absf(out[&"evidence_generated"] - (-0.30)) < 0.0001,
		"evidence == -0.30 (got %f)" % out[&"evidence_generated"])

func _test_lookouts_protects_operatives() -> void:
	var out := _resolve([&"prep_lookouts"], &"appr_quiet", &"cover_paper")
	_check(out[&"operative_injury"] < 0.0, "Post lookouts drives operative_injury negative")
	_check(absf(out[&"operative_injury"] - (-0.20)) < 0.0001,
		"operative_injury == -0.20 (got %f)" % out[&"operative_injury"])

func _test_relationship_change_still_clamped() -> void:
	var out := _resolve([], &"appr_deal", &"cover_scapegoat")  # Blame-a-dockhand path
	_check(out[&"relationship_change"] >= -1.0 and out[&"relationship_change"] <= 1.0,
		"relationship_change within [-1, 1]")
	_check(absf(out[&"relationship_change"] - (-0.10)) < 0.0001,
		"deal(+0.3) + scapegoat(-0.4) == -0.10 (got %f)" % out[&"relationship_change"])

## Sweep every prep subset (<=3 of 4) x approach x cover-up: no dimension may leave [-1, 1].
func _test_no_dimension_exceeds_unit_range() -> void:
	var template := PlaceholderJobs.intercepted_shipment()
	var prep_ids: Array[StringName] = []
	for c in template.prep_actions:
		prep_ids.append(c.id)
	for mask in range(1 << prep_ids.size()):
		var subset: Array[StringName] = []
		for i in prep_ids.size():
			if mask & (1 << i):
				subset.append(prep_ids[i])
		if subset.size() > BM.JOB_MAX_PREP_ACTIONS:
			continue
		for appr in template.approaches:
			for cover in template.coverups:
				var out := _resolve(subset, appr.id, cover.id)
				for dim in JobResolution.DIMENSIONS:
					if out[dim] < -1.0 or out[dim] > 1.0:
						_check(false, "%s out of [-1,1] (%f) via %s + %s + %s"
							% [dim, out[dim], str(subset), appr.id, cover.id])
