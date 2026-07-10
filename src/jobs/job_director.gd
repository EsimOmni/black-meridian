extends Node
## JobDirector (autoload) — holds active fixer jobs and wires the pure JobLifecycle
## stage machine to GameState/TimeService (brief §7.5). Since P08 it also OWNS systemic
## generation: sim triggers map to jobs through the pure JobGenerator, gated by a
## cadence cap so problems arrive as beats, never as a flood (brief §5.2).

signal job_offered(job: JobData)
signal job_stage_changed(job: JobData)
signal job_resolved(job: JobData)

## Cadence gate (brief §5.2: "run four to six" across a phase, not all at once): at most
## this many UNRESOLVED jobs at a time. A trigger firing at the cap is dropped with a
## log — the simpler deterministic choice over queueing (P08 decision).
const MAX_CONCURRENT_JOBS := 3

var active_jobs: Array[JobData] = []
## Scheduled delayed-consequence follow-ups: {"ticks_left": int, "venue_id": StringName}.
## Persisted through SaveService meta so a quicksave inside the window doesn't lose the problem.
var pending_followups: Array[Dictionary] = []

func _ready() -> void:
	TimeService.strategic_tick.connect(_on_strategic_tick)
	# RivalDirector is registered AFTER JobDirector in the autoload order, so its
	# singleton doesn't exist yet during this _ready — wire on the next idle frame.
	_connect_triggers.call_deferred()

func _connect_triggers() -> void:
	RivalDirector.rival_action_landed.connect(_on_rival_action_landed)
	EconomyService.inspection_started.connect(_on_inspection_started)
	# RelationshipService is bootstrap-wired, NOT an autoload (the P09 lesson), so resolve
	# the live node from the tree — bootstrap's _ready has already added it by the time
	# this deferred call runs. Absent under unit-test scenes; the betrayal arm stays dark.
	var relationships := get_tree().root.find_child("RelationshipService", true, false) as RelationshipService
	if relationships:
		relationships.betrayal_committed.connect(_on_betrayal_committed)

func _on_rival_action_landed(rival: FactionData, venue: VenueData, action: int) -> void:
	# SABOTAGE on a player venue → retaliation (P08). A PROBE is pressure, not a provocation.
	if action == BM.RivalAction.SABOTAGE:
		if venue == null or venue.owner_faction != GameState.player_faction_id:
			return
		_try_offer(JobGenerator.retaliation_job(venue, rival, TimeService.tick_index))
	# EXPAND onto neutral ground (venue is now the rival's) → Contested Ground (P08b territory).
	elif action == BM.RivalAction.EXPAND:
		if venue == null:
			return
		_try_offer(JobGenerator.contested_ground_job(venue, rival, TimeService.tick_index))

## P06b trigger: a sweep landing while evidence cases pin the district offers the aimed
## strike — a "Bury the Case" job against the STRONGEST case. No cases, no job (the
## sweep was pure heat; pausing rackets already answers that one).
func _on_inspection_started(district: DistrictData) -> void:
	var strongest := EvidenceMath.strongest_case(district)
	if strongest == null:
		return
	_try_offer(JobGenerator.bury_case_job(strongest, district, TimeService.tick_index))

## P08b territory arm: a betrayal handed a venue to the rival (RelationshipService._land set
## owner + INFLUENCED). Same job as an EXPAND loss — reclaim it. venue/rival may be null if the
## betrayal found no target; guard both.
func _on_betrayal_committed(_character: CharacterData, venue: VenueData, rival: FactionData) -> void:
	if venue == null or rival == null:
		return
	_try_offer(JobGenerator.contested_ground_job(venue, rival, TimeService.tick_index))

## The cadence gate: dedupe by id, then cap concurrent unresolved jobs.
func _try_offer(job: JobData) -> void:
	if job == null:
		return
	if get_job(job.id) != null:
		print("JobDirector: duplicate job '%s' dropped" % job.id)
		return
	if unresolved_count() >= MAX_CONCURRENT_JOBS:
		print("JobDirector: at capacity (%d unresolved) — '%s' dropped" % [MAX_CONCURRENT_JOBS, job.id])
		return
	offer(job)

func unresolved_count() -> int:
	var n := 0
	for j in active_jobs:
		if j.stage != BM.JobStage.RESOLVED:
			n += 1
	return n

func offer(job: JobData) -> void:
	job.stage = BM.JobStage.INTAKE
	job.ticks_remaining = job.deadline_ticks
	active_jobs.append(job)
	job_offered.emit(job)

## Replace active jobs + pending follow-ups from a loaded save (SaveService). Does NOT
## reset stage/deadline — the save's runtime state is already applied. Re-announces
## unresolved jobs so UI re-binds.
func restore_jobs(jobs: Array[JobData], pending: Array[Dictionary] = []) -> void:
	active_jobs = jobs
	pending_followups = pending
	for job in active_jobs:
		if job.stage != BM.JobStage.RESOLVED:
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

func _on_strategic_tick(tick: int) -> void:
	for job in active_jobs:
		if JobLifecycle.tick(job):
			_apply_and_emit(job)
	_tick_followups(tick)

## P08 trigger 2 (fire side): the scheduled follow-up surfaces after its lead window.
func _tick_followups(tick: int) -> void:
	var still: Array[Dictionary] = []
	var due: Array[StringName] = []
	for entry in pending_followups:
		entry["ticks_left"] -= 1
		if entry["ticks_left"] <= 0:
			due.append(entry["venue_id"])
		else:
			still.append(entry)
	pending_followups = still
	for venue_id in due:
		var venue := _find_venue(venue_id)
		if venue:
			_try_offer(JobGenerator.followup_job(venue, tick))

func _apply_and_emit(job: JobData) -> void:
	var involved: Array[CharacterData] = []
	for cid in job.involved_character_ids:
		var c := GameState.get_character(cid)
		if c:
			involved.append(c)
	var district := _district_of(job)
	JobLifecycle.apply_outcome(job, GameState.player_faction(), district, involved,
		TimeService.tick_index)
	# P06b path B: a burn that actually suppressed trace (net negative evidence) removes
	# its TARGETED case — the aimed strike, distinct from apply_outcome's passive
	# strongest-first erosion. A botched burn (net positive) leaves the case standing
	# and has already deposited fresh trace above.
	if job.origin == BM.JobOrigin.EVIDENCE_CHAIN and district != null \
			and job.outcome.get(&"evidence_generated", 0.0) < 0.0:
		var target := _burn_target_of(job)
		if target != &"":
			EvidenceMath.remove_case(district, target)
	# P07c: the feud closes. When the player resolves the retaliation a rival provoked, that
	# rival remembers — its grudge rises by the job's rival_suspicion (the previously-orphaned
	# outcome axis). Single writer of grudge upward; RivalDirector decays it. The provocateur is
	# encoded in the generated id (gen@retaliation@<venue>@<rival>@<tick>).
	if job.origin == BM.JobOrigin.RIVAL_PROVOCATION:
		var suspicion: float = job.outcome.get(&"rival_suspicion", 0.0)
		if suspicion > 0.0:
			var rival := _provocateur_of(job)
			if rival:
				rival.grudge = clampf(rival.grudge + suspicion, 0.0, 1.0)
	# P08b: a resolved Contested Ground job with a real objective reclaims the venue — back to the
	# player, but CONTESTED (disputed, not fully controlled), so the loop stays alive. Origin-gated
	# single write, mirroring the EVIDENCE_CHAIN/RIVAL_PROVOCATION post-outcome branches.
	if job.origin == BM.JobOrigin.TERRITORY_LOSS \
			and job.outcome.get(&"objective_achieved", 0.0) >= 0.5:
		var venue := _find_venue(job.venue_id)
		if venue != null:
			venue.owner_faction = GameState.player_faction_id
			venue.control_state = BM.ControlState.CONTESTED
	# P08 trigger 2 (schedule side): a heavy delayed_consequence finally spawns the
	# follow-up problem apply_outcome had been holding — the loop never simply empties
	# (brief §5.1: "a new problem is created rather than every problem disappearing").
	if job.outcome.get(&"delayed_consequence", 0.0) >= JobGenerator.FOLLOWUP_THRESHOLD:
		pending_followups.append({
			"ticks_left": JobGenerator.FOLLOWUP_LEAD_TICKS, "venue_id": job.venue_id})
	job_resolved.emit(job)

func _find_venue(venue_id: StringName) -> VenueData:
	for d in GameState.districts:
		for v in d.venues:
			if v.id == venue_id:
				return v
	return null

## The district a job's consequences land in: by its venue for venue-bound jobs, or
## parsed from the generated id for case-bound burycase jobs (which have no venue).
func _district_of(job: JobData) -> DistrictData:
	for d in GameState.districts:
		for v in d.venues:
			if v.id == job.venue_id:
				return d
	var parts := String(job.id).split("@")
	if parts.size() == 8 and parts[1] == "burycase":
		return GameState.get_district(StringName(parts[2]))
	return null

## P06b: the case a burycase job targets, from its generated id
## (gen@burycase@<district>@<case id: 4 segments>@<tick>). Empty for other ids.
func _burn_target_of(job: JobData) -> StringName:
	var parts := String(job.id).split("@")
	if parts.size() != 8 or parts[1] != "burycase":
		return &""
	return StringName("@".join(parts.slice(3, 7)))

## P07c: the rival that provoked a RIVAL_PROVOCATION job, from its generated id
## (gen@retaliation@<venue>@<rival>@<tick>). Returns null for authored/unparseable ids.
func _provocateur_of(job: JobData) -> FactionData:
	var parts := String(job.id).split("@")
	if parts.size() != 5 or parts[1] != "retaliation":
		return null
	return GameState.get_faction(StringName(parts[3]))
