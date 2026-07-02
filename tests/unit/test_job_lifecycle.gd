extends SceneTree
## Unit test for the fixer-job skeleton (P03, brief §7.5): a job advances through all
## four lifecycle stages and its resolution applies >=2 dimensions to strategic state.
## Drives the pure JobLifecycle/JobResolution helpers with hand-built data — no autoloads.
## Run headless:
##   Godot --headless --path . -s tests/unit/test_job_lifecycle.gd

var _failures: int = 0

func _init() -> void:
	_test_full_lifecycle_applies_dimensions()
	_test_prep_limit_and_toggle()
	_test_invalid_transitions()
	_test_deadline_expiry()
	if _failures == 0:
		print("[PASS] all job lifecycle tests passed")
		quit(0)
	else:
		printerr("[FAIL] %d job lifecycle assertion(s) failed" % _failures)
		quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("  assertion failed: ", msg)

func _make_world() -> Dictionary:
	var faction := FactionData.new()
	faction.id = &"compact"
	faction.dirty_cash = 1000

	var district := DistrictData.new()
	district.id = &"glass_wharf"
	district.local_heat = 0.1
	district.fear = 0.2

	var bengal := CharacterData.new()
	bengal.id = &"bengal_lt"
	bengal.public_trust = 0.6
	bengal.grievance = 0.3

	return {"faction": faction, "district": district, "bengal": bengal}

func _test_full_lifecycle_applies_dimensions() -> void:
	var w := _make_world()
	var job := PlaceholderJobs.intercepted_shipment()
	job.ticks_remaining = job.deadline_ticks

	_check(job.stage == BM.JobStage.INTAKE, "job starts at INTAKE")
	_check(JobLifecycle.begin(job), "begin() from INTAKE")
	_check(job.stage == BM.JobStage.PREPARATION, "stage is PREPARATION")
	_check(JobLifecycle.choose_prep(job, &"prep_lookouts"), "prep action accepted")
	_check(JobLifecycle.choose_approach(job, &"appr_deal"), "approach accepted")
	_check(job.stage == BM.JobStage.INTERVENTION, "stage is INTERVENTION")
	_check(JobLifecycle.choose_coverup(job, &"cover_scapegoat"), "coverup accepted")
	_check(job.stage == BM.JobStage.RESOLVED, "stage is RESOLVED")
	_check(not job.outcome.is_empty(), "outcome populated")

	# appr_deal objective 0.5 -> reward; deal +0.3 relationship, scapegoat -0.4 -> net -0.1.
	var cash_before: int = w.faction.dirty_cash
	var trust_before: float = w.bengal.public_trust
	var grievance_before: float = w.bengal.grievance
	var involved: Array[CharacterData] = [w.bengal]
	JobLifecycle.apply_outcome(job, w.faction, w.district, involved)

	_check(w.faction.dirty_cash == cash_before + job.reward_dirty,
		"dimension 1 (objective_achieved) paid reward_dirty (%d -> %d)" % [cash_before, w.faction.dirty_cash])
	_check(absf(w.bengal.public_trust - (trust_before + 0.15 * -0.1)) < 0.0001,
		"dimension 2 (relationship_change) shifted public_trust (got %f)" % w.bengal.public_trust)
	_check(w.bengal.grievance > grievance_before,
		"dimension 3 (collateral_damage) raised grievance")

func _test_prep_limit_and_toggle() -> void:
	var job := PlaceholderJobs.intercepted_shipment()
	JobLifecycle.begin(job)
	_check(JobLifecycle.choose_prep(job, &"prep_scout"), "prep 1")
	_check(JobLifecycle.choose_prep(job, &"prep_bribe_clerk"), "prep 2")
	_check(JobLifecycle.choose_prep(job, &"prep_lookouts"), "prep 3")
	_check(not JobLifecycle.choose_prep(job, &"prep_rush"), "prep 4 rejected (max %d)" % BM.JOB_MAX_PREP_ACTIONS)
	_check(JobLifecycle.choose_prep(job, &"prep_scout"), "re-pick toggles off")
	_check(job.chosen_prep.size() == 2, "toggle removed the action")
	_check(not JobLifecycle.choose_prep(job, &"appr_force"), "non-prep id rejected")

func _test_invalid_transitions() -> void:
	var job := PlaceholderJobs.intercepted_shipment()
	_check(not JobLifecycle.choose_approach(job, &"appr_quiet"), "no approach from INTAKE")
	_check(not JobLifecycle.choose_coverup(job, &"cover_paper"), "no coverup from INTAKE")
	JobLifecycle.begin(job)
	_check(not JobLifecycle.choose_coverup(job, &"cover_paper"), "no coverup from PREPARATION")
	_check(not JobLifecycle.begin(job), "begin() only from INTAKE")

func _test_deadline_expiry() -> void:
	var w := _make_world()
	var job := PlaceholderJobs.intercepted_shipment()
	job.ticks_remaining = 2
	JobLifecycle.begin(job)
	_check(not JobLifecycle.tick(job), "tick 1 does not expire")
	_check(JobLifecycle.tick(job), "tick 2 expires the job")
	_check(job.stage == BM.JobStage.RESOLVED, "expired job is RESOLVED")
	_check(job.outcome[&"evidence_generated"] == 0.3, "expiry generates evidence")

	var heat_before: float = w.district.local_heat
	var cash_before: int = w.faction.dirty_cash
	var involved: Array[CharacterData] = []
	JobLifecycle.apply_outcome(job, w.faction, w.district, involved)
	_check(w.faction.dirty_cash == cash_before, "expiry pays no reward")
	_check(w.district.local_heat > heat_before, "expiry raises district heat")
