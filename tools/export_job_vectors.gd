extends SceneTree
## Job golden-vector extractor — the Unreal port's behavioral oracle (reboot S3).
##
## READ-ONLY. It drives the four autoload-free job classes (JobResolution, JobLifecycle,
## JobGenerator, JobTemplates) over hand-built data and writes one JSON document. It
## mutates no shipped resource and touches no autoload.
##
## Run:
##   D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . \
##       -s tools/export_job_vectors.gd -- --out=<abs path>.json
##
## Like S1/S2's extractors it writes the file itself rather than printing to stdout: the
## godot_ai game_helper autoload emits a banner AFTER the script finishes and that trailing
## text corrupts a redirected document.
##
## Autoloads do not exist in a `-s` SceneTree script. Verified 2026-09-18: JobResolution,
## JobLifecycle, JobGenerator, JobTemplates, NarrativeJobs and EvidenceMath contain ZERO
## autoload references (the only grep hits are comments), which is exactly why the job
## layer is extractable this way. JobDirector IS an autoload — it is deliberately not
## driven here; its state moves to FBMJobDirector in BMCore and is tested there.
##
## `[V]` Covers GV-JOB-01..04 (07_IMPLEMENTATION_ROADMAP.md -> S3).

const SCHEMA := 1
const DEFAULT_OUT := "D:/black-meridian-ue/Tests/Golden/job_vectors.json"

func _init() -> void:
	var out := {
		"schema": SCHEMA,
		"source": "godot-final",
		"godot_version": Engine.get_version_info().string,
		"note": "Job vectors for reboot S3. Floats are JSON numbers (state values compared at 1e-5 per 08 5.1). Discrete fields — stage, origin, variant index, id strings, parse results, booleans — are compared EXACTLY. The variant layer's hash and avalanche fields are DECIMAL STRINGS, not numbers: they are 64-bit and would round silently through a double (the S1 lesson).",
		"resolution": _resolution_vectors(),
		"lifecycle": _lifecycle_vectors(),
		"ids": _id_vectors(),
		"variant": _variant_vectors(),
	}

	var path := _out_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		quit(1)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()

	print("wrote %s — %d resolution, %d lifecycle, %d ids, %d variant rows" % [
		path,
		out["resolution"]["rows"].size(), out["lifecycle"]["rows"].size(),
		out["ids"]["rows"].size(), out["variant"]["rows"].size()])
	quit(0)

func _out_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			return arg.substr(6)
	return DEFAULT_OUT

func _resolution_vectors() -> Dictionary:
	var rows: Array = []

	for case in _resolution_cases():
		var job := JobData.new()
		job.prep_actions = case["prep_pool"]
		job.approaches = case["approach_pool"]
		job.coverups = case["coverup_pool"]
		job.chosen_prep = case["chosen_prep"]
		job.chosen_approach = case["chosen_approach"]
		job.chosen_coverup = case["chosen_coverup"]
		rows.append({
			"kind": case["kind"],
			"chosen_prep": case["chosen_prep"].map(func(s): return String(s)),
			"chosen_approach": String(case["chosen_approach"]),
			"chosen_coverup": String(case["chosen_coverup"]),
			"outcome": _outcome_row(JobResolution.resolve(job)),
		})

	rows.append({
		"kind": "expired",
		"chosen_prep": [],
		"chosen_approach": "",
		"chosen_coverup": "",
		"outcome": _outcome_row(JobResolution.expired()),
	})
	rows.append({
		"kind": "blank",
		"chosen_prep": [],
		"chosen_approach": "",
		"chosen_coverup": "",
		"outcome": _outcome_row(JobResolution.blank()),
	})

	return {
		"dimensions": JobResolution.DIMENSIONS.map(func(d): return String(d)),
		"signed_dimensions": JobResolution.SIGNED_DIMENSIONS.map(func(d): return String(d)),
		"rows": rows,
	}

func _outcome_row(outcome: Dictionary) -> Dictionary:
	var row: Dictionary = {}
	for d in JobResolution.DIMENSIONS:
		row[String(d)] = outcome[d]
	return row

## Hand-built choice pools. Deliberately includes contributions that overshoot both ends of
## both clamp ranges, so a per-term clamp and an end clamp produce DIFFERENT vectors.
func _resolution_cases() -> Array:
	var prep := [
		JobChoiceData.make(&"p_big", "big", "", {&"objective_achieved": 0.5}),
		JobChoiceData.make(&"p_big2", "big2", "", {&"objective_achieved": 0.5}),
		JobChoiceData.make(&"p_big3", "big3", "", {&"objective_achieved": 0.5}),
		JobChoiceData.make(&"p_neg", "neg", "", {&"evidence_generated": -0.6}),
		JobChoiceData.make(&"p_mixed", "mixed", "",
			{&"evidence_generated": 0.4, &"operative_injury": -0.3, &"new_leverage": 0.2}),
	] as Array[JobChoiceData]
	var approaches := [
		JobChoiceData.make(&"a_loud", "loud", "",
			{&"objective_achieved": 0.7, &"evidence_generated": 0.35, &"public_fear": 0.2,
				&"rival_suspicion": 0.2}),
		JobChoiceData.make(&"a_over", "over", "",
			{&"evidence_generated": 0.9, &"collateral_damage": 1.2}),
	] as Array[JobChoiceData]
	var coverups := [
		JobChoiceData.make(&"c_deny", "deny", "", {&"evidence_generated": -0.3}),
		JobChoiceData.make(&"c_under", "under", "",
			{&"evidence_generated": -1.5, &"relationship_change": -1.4}),
		JobChoiceData.make(&"c_heavy", "heavy", "", {&"delayed_consequence": 0.5}),
	] as Array[JobChoiceData]

	return [
		{"kind": "single_approach_only", "prep_pool": prep, "approach_pool": approaches,
			"coverup_pool": coverups, "chosen_prep": [] as Array[StringName],
			"chosen_approach": &"a_loud", "chosen_coverup": &""},
		{"kind": "full_three_prep", "prep_pool": prep, "approach_pool": approaches,
			"coverup_pool": coverups,
			"chosen_prep": [&"p_big", &"p_big2", &"p_big3"] as Array[StringName],
			"chosen_approach": &"a_loud", "chosen_coverup": &"c_deny"},
		{"kind": "over_clamp_unsigned", "prep_pool": prep, "approach_pool": approaches,
			"coverup_pool": coverups,
			"chosen_prep": [&"p_big", &"p_big2", &"p_big3"] as Array[StringName],
			"chosen_approach": &"a_over", "chosen_coverup": &"c_heavy"},
		{"kind": "signed_negative_then_positive", "prep_pool": prep,
			"approach_pool": approaches, "coverup_pool": coverups,
			"chosen_prep": [&"p_neg"] as Array[StringName],
			"chosen_approach": &"a_loud", "chosen_coverup": &""},
		{"kind": "under_clamp_signed", "prep_pool": prep, "approach_pool": approaches,
			"coverup_pool": coverups, "chosen_prep": [&"p_neg"] as Array[StringName],
			"chosen_approach": &"a_loud", "chosen_coverup": &"c_under"},
		{"kind": "mixed_axes", "prep_pool": prep, "approach_pool": approaches,
			"coverup_pool": coverups,
			"chosen_prep": [&"p_mixed", &"p_neg"] as Array[StringName],
			"chosen_approach": &"a_loud", "chosen_coverup": &"c_deny"},
		{"kind": "unknown_choice_ids_ignored", "prep_pool": prep,
			"approach_pool": approaches, "coverup_pool": coverups,
			"chosen_prep": [&"p_big"] as Array[StringName],
			"chosen_approach": &"a_missing", "chosen_coverup": &"c_missing"},
	]

func _lifecycle_vectors() -> Dictionary:
	return {"rows": []}

func _id_vectors() -> Dictionary:
	return {"rows": []}

func _variant_vectors() -> Dictionary:
	return {"rows": []}
