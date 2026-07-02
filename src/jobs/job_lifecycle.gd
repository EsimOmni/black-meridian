class_name JobLifecycle
extends RefCounted
## Pure stage machine + outcome application for fixer jobs (brief §7.5).
## Intake → Preparation (≤3 actions) → Intervention (one approach) → Cover-up (one story).
## No autoload references — JobDirector wires this to GameState/TimeService; unit tests
## drive it with hand-built data (see tasks/lessons.md: testable logic never in autoloads).

## INTAKE → PREPARATION. The player has reviewed the situation and taken the job.
static func begin(job: JobData) -> bool:
	if job.stage != BM.JobStage.INTAKE:
		return false
	job.stage = BM.JobStage.PREPARATION
	return true

## Toggle-select a preparation action while in PREPARATION (max BM.JOB_MAX_PREP_ACTIONS).
static func choose_prep(job: JobData, choice_id: StringName) -> bool:
	if job.stage != BM.JobStage.PREPARATION:
		return false
	if job.find_choice(job.prep_actions, choice_id) == null:
		return false
	if job.chosen_prep.has(choice_id):
		job.chosen_prep.erase(choice_id)
		return true
	if job.chosen_prep.size() >= BM.JOB_MAX_PREP_ACTIONS:
		return false
	job.chosen_prep.append(choice_id)
	return true

## PREPARATION → INTERVENTION. Locks one approach; the intervention is now underway.
static func choose_approach(job: JobData, choice_id: StringName) -> bool:
	if job.stage != BM.JobStage.PREPARATION:
		return false
	if job.find_choice(job.approaches, choice_id) == null:
		return false
	job.chosen_approach = choice_id
	job.stage = BM.JobStage.INTERVENTION
	return true

## INTERVENTION → COVER_UP → RESOLVED. Picks the story told afterwards and resolves the
## job into its multi-dimensional outcome. Effects are applied by the caller (JobDirector)
## so this stays autoload-free.
static func choose_coverup(job: JobData, choice_id: StringName) -> bool:
	if job.stage != BM.JobStage.INTERVENTION:
		return false
	if job.find_choice(job.coverups, choice_id) == null:
		return false
	job.chosen_coverup = choice_id
	job.stage = BM.JobStage.COVER_UP
	job.outcome = JobResolution.resolve(job)
	job.stage = BM.JobStage.RESOLVED
	return true

## Deadline tick. Returns true when the job just expired (caller applies the expired outcome).
static func tick(job: JobData) -> bool:
	if job.stage == BM.JobStage.RESOLVED:
		return false
	job.ticks_remaining -= 1
	if job.ticks_remaining > 0:
		return false
	job.outcome = JobResolution.expired()
	job.stage = BM.JobStage.RESOLVED
	return true

## Apply a resolved job's outcome to the strategic state (brief §7.5: consequences flow
## back into cash, heat, fear, relationships). rival_suspicion / new_leverage /
## delayed_consequence stay recorded in job.outcome for the P07/P08/P10 systems.
static func apply_outcome(job: JobData, faction: FactionData, district: DistrictData,
		involved: Array[CharacterData]) -> void:
	var out := job.outcome
	if out.is_empty():
		return
	if out[&"objective_achieved"] >= 0.5:
		faction.dirty_cash += job.reward_dirty
	if district != null:
		# P06 decision (closes the P04b deferral): evidence_generated stays a single SIGNED
		# net axis — net trace left is exactly what police attention responds to, so a
		# suppressed job (negative) legitimately LOWERS heat and an exposed one raises it.
		# No production-vs-suppression split; if a future system needs the two sides
		# separately, revisit then — don't silently split.
		district.local_heat = clampf(
			district.local_heat + 0.08 * out[&"evidence_generated"] + 0.04 * out[&"public_fear"], 0.0, 1.0)
		district.fear = clampf(district.fear + 0.1 * out[&"public_fear"], 0.0, 1.0)
	for c in involved:
		c.public_trust = clampf(c.public_trust + 0.15 * out[&"relationship_change"], 0.0, 1.0)
		c.grievance = clampf(
			c.grievance + 0.1 * out[&"collateral_damage"] + 0.15 * out[&"operative_injury"], 0.0, 1.0)
