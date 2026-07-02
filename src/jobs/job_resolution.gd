class_name JobResolution
extends RefCounted
## Pure resolution math for fixer jobs (brief §7.5). Resolution is multi-dimensional,
## never binary, and fully deterministic (pillar: telegraphed, no hidden rolls).
## Kept out of the JobDirector autoload so it unit-tests headless (see tasks/lessons.md).

## The nine resolution dimensions (brief §7.5). All accumulate from chosen options.
const DIMENSIONS: Array[StringName] = [
	&"objective_achieved",   ## 0..1 — did the apparent problem get solved
	&"evidence_generated",   ## -1..1 — net trace; negative = suppressed (cover-ups drive it down; P06 consumes)
	&"collateral_damage",    ## 0..1 — bystander/asset harm
	&"operative_injury",     ## -1..1 — net harm to your people; negative = protected/mitigated
	&"rival_suspicion",      ## 0..1 — rival attention drawn (P07 consumes)
	&"public_fear",          ## 0..1 — district fear shift
	&"relationship_change",  ## -1..1 — net shift on involved characters
	&"new_leverage",         ## 0..1 — leverage gained (P10 consumes)
	&"delayed_consequence",  ## 0..1 — deferred fallout weight (P08 consumes)
]

## Net axes (production − suppression): authored data feeds these negative on purpose
## ("I left no trace", "I protected my people") — they clamp -1..1, the rest 0..1.
## P06 decision: the net axis IS the model (no split) — heat responds to net trace,
## grievance to net harm. See job_lifecycle.gd apply_outcome for the wiring rationale.
const SIGNED_DIMENSIONS: Array[StringName] = [
	&"evidence_generated",
	&"operative_injury",
	&"relationship_change",
]

## Sum every chosen option's effect contributions into a full dimension dictionary.
static func resolve(job: JobData) -> Dictionary:
	var out := blank()
	for prep_id in job.chosen_prep:
		_accumulate(out, job.find_choice(job.prep_actions, prep_id))
	_accumulate(out, job.find_choice(job.approaches, job.chosen_approach))
	_accumulate(out, job.find_choice(job.coverups, job.chosen_coverup))
	_clamp(out)
	return out

## Outcome when the deadline expires before the player resolves the job:
## the problem festers — nothing achieved, evidence piles up, fallout deferred.
static func expired() -> Dictionary:
	var out := blank()
	out[&"evidence_generated"] = 0.3
	out[&"public_fear"] = 0.1
	out[&"delayed_consequence"] = 0.5
	return out

static func blank() -> Dictionary:
	var out := {}
	for d in DIMENSIONS:
		out[d] = 0.0
	return out

static func _accumulate(out: Dictionary, choice: JobChoiceData) -> void:
	if choice == null:
		return
	for key in choice.effects:
		assert(out.has(key), "Unknown resolution dimension: %s" % key)
		out[key] += float(choice.effects[key])

static func _clamp(out: Dictionary) -> void:
	for d in DIMENSIONS:
		if d in SIGNED_DIMENSIONS:
			out[d] = clampf(out[d], -1.0, 1.0)
		else:
			out[d] = clampf(out[d], 0.0, 1.0)
