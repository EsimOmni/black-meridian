extends Node
## JobDirector (autoload) — holds active fixer jobs and wires the pure JobLifecycle
## stage machine to GameState/TimeService (brief §7.5). Month-1 skeleton: jobs are
## offered by hand (bootstrap); systemic generation from sim state is P08.

signal job_offered(job: JobData)
signal job_stage_changed(job: JobData)
signal job_resolved(job: JobData)

var active_jobs: Array[JobData] = []

func _ready() -> void:
	TimeService.strategic_tick.connect(_on_strategic_tick)

func offer(job: JobData) -> void:
	job.stage = BM.JobStage.INTAKE
	job.ticks_remaining = job.deadline_ticks
	active_jobs.append(job)
	job_offered.emit(job)

func get_job(job_id: StringName) -> JobData:
	for j in active_jobs:
		if j.id == job_id:
			return j
	return null

func begin(job_id: StringName) -> void:
	var job := get_job(job_id)
	if job and JobLifecycle.begin(job):
		job_stage_changed.emit(job)

func choose_prep(job_id: StringName, choice_id: StringName) -> void:
	var job := get_job(job_id)
	if job and JobLifecycle.choose_prep(job, choice_id):
		job_stage_changed.emit(job)

func choose_approach(job_id: StringName, choice_id: StringName) -> void:
	var job := get_job(job_id)
	if job and JobLifecycle.choose_approach(job, choice_id):
		job_stage_changed.emit(job)

func choose_coverup(job_id: StringName, choice_id: StringName) -> void:
	var job := get_job(job_id)
	if job and JobLifecycle.choose_coverup(job, choice_id):
		_apply_and_emit(job)

func _on_strategic_tick(_tick: int) -> void:
	for job in active_jobs:
		if JobLifecycle.tick(job):
			_apply_and_emit(job)

func _apply_and_emit(job: JobData) -> void:
	var involved: Array[CharacterData] = []
	for cid in job.involved_character_ids:
		var c := GameState.get_character(cid)
		if c:
			involved.append(c)
	var district: DistrictData = null
	for d in GameState.districts:
		for v in d.venues:
			if v.id == job.venue_id:
				district = d
				break
	JobLifecycle.apply_outcome(job, GameState.player_faction(), district, involved)
	job_resolved.emit(job)
