extends Node
## Full-cycle auto-play HEALTH probe (throwaway) — drives ONE complete 30-min Night
## Cycle (1800 strategic ticks) through the REAL settle + job-resolution paths, playing
## a simple DETERMINISTIC policy (zero RNG — cadence by tick counters / modulo only), and
## prints a phase-by-phase timeline of system health plus a dead-stretch summary.
##
## NOT a feel test. It reports only numbers: money curve, heat/evidence/grudge/central
## movement, jobs offered/resolved, inspections fired, phase transitions, and the longest
## run of coarse samples where nothing material changed.
##
## Discipline (feud/evidence/central probe): READS state, calls only existing public
## methods + the same resolution path the shipped code uses. Touches no game source.
## The phase machine (NightCycle) is NOT an autoload, so we instantiate it here exactly
## like bootstrap.gd does — otherwise phases never advance.
## Run: Godot --headless --path . res://tools/validation/full_cycle_probe.tscn

const TOTAL_TICKS := 1800          # 240 + 1080 + 360 + 120 = one full cycle
const SAMPLE_EVERY := 120          # coarse timeline cadence within a phase
const RESOLVE_DELAY_TICKS := 4     # a player "thinks" a few ticks before resolving a job

# Two policies, selected by the scene's node name ("FullCycleProbeAggressive" flips it).
# CLEAN  (default): pick the approach + cover-up that MINIMIZE net evidence_generated —
#   the safe fixer keeping trace down. Heat lever pauses early (0.60).
# AGGRESSIVE:        pick the approach + cover-up that MAXIMIZE net evidence_generated —
#   loud/forceful, cases accrue. Heat lever is lazy (0.80) so heat is allowed to
#   compound toward the inspection + central bars before the player backs off.
#   P06d cooling reflex: while a district sits in the pause band (crossed
#   HEAT_PAUSE_MARK, not yet cooled below HEAT_UNPAUSE_MARK) its jobs are answered
#   QUIET (argMIN) — the loud fixer backs off while the city pushes, then goes loud
#   again. Without this the inspection latch can never re-arm, so a static-loud run
#   is physically unable to show the case-driven RECURRENCE the P06d gate demands.
# Both are deterministic and zero-RNG. Choices are picked by SUMMING the real effect
# dicts from job_templates.gd — never by guessing which id is "loud".
var _aggressive := false
var HEAT_PAUSE_MARK := 0.60        # (set in _ready from policy) pause rackets above this combined
## Unpause only once the district cools BELOW the inspection re-arm bar (set in _ready
## from the real EconomyService constant, with margin). Resuming the heat flow any
## earlier keeps combined pinned above REARM forever, so the latch could never fire a
## second excursion — the P06d recurrence would be unreachable by instrument error.
var HEAT_UNPAUSE_MARK := 0.25

# --- event counters (from real signals) --------------------------------------
var _jobs_offered := 0
var _jobs_resolved := 0
var _inspections := 0
var _case_driven_inspections := 0   # raw heat under the bar at fire time (P06d recurrence)
var _phase_transitions := 0
var _origin_offered: Dictionary = {}     # BM.JobOrigin -> count offered
var _net_evidence_sum := 0.0             # sum of resolved jobs' net evidence_generated
var _peak_cases := 0                     # max evidence cases on glass wharf at any sample

# --- pending-resolution schedule: job_id -> tick_to_resolve -------------------
var _resolve_at: Dictionary = {}

# --- per-district racket pause bookkeeping (which we paused, so we only touch ours) ---
var _paused_rackets: Dictionary = {}   # district_id -> Array[VenueData] we paused

# --- dead-stretch detector state ----------------------------------------------
# Two detectors, on purpose. FULL: cash + jobs + heat + central all still (the strict
# "nothing at all happened" run). PRESSURE: the sim's PRESSURE systems (heat, central,
# grudge, jobs) still — this one IGNORES cash, because in this build cash runs away
# monotonically and would mask a frozen pressure map (the exact failure this probe hunts).
var _last_dirty := 0
var _last_offered := 0
var _last_resolved := 0
var _last_combined := 0.0
var _last_central := 0.0
var _last_grudge := 0.0
var _current_dead_run := 0
var _longest_dead_run := 0
var _current_plateau_run := 0
var _longest_plateau_run := 0

# --- summary accumulators -----------------------------------------------------
var _min_dirty := 1 << 60
var _max_dirty := -(1 << 60)
var _peak_central := 0.0
var _central_alert_fired := false
var _phases_with_activity: Dictionary = {}   # phase_name -> bool (a job resolved or inspection fired in it)

var _night_cycle: NightCycle


func _ready() -> void:
	# Policy selected by scene node name — keeps a single script, two thin .tscn wrappers.
	_aggressive = String(name).to_lower().contains("aggressive")
	HEAT_PAUSE_MARK = 0.80 if _aggressive else 0.60
	HEAT_UNPAUSE_MARK = EconomyService.HEAT_INSPECTION_REARM - 0.05

	WorldSeed.build()
	TimeService.set_speed(BM.Speed.PAUSED)

	# Wire the phase machine exactly like bootstrap (NOT an autoload).
	_night_cycle = NightCycle.new()
	_night_cycle.name = "NightCycle"
	add_child(_night_cycle)

	# Count events off the real signals.
	JobDirector.job_offered.connect(_on_job_offered)
	JobDirector.job_resolved.connect(_on_job_resolved)
	EconomyService.inspection_started.connect(_on_inspection_started)
	EconomyService.central_alert_started.connect(func(_p): _central_alert_fired = true)
	GameState.night_cycle_advanced.connect(_on_phase_advanced)

	await get_tree().process_frame  # JobDirector wires its triggers deferred

	# The authored seed job that bootstrap offers — so the pipeline starts primed.
	JobDirector.offer(JobTemplates.intercepted_shipment())

	var player := GameState.player_faction()
	print("--- FULL-CYCLE AUTO-PLAY PROBE (1800 ticks, deterministic) — POLICY: %s ---" %
		("AGGRESSIVE (max trace, lazy heat lever @%.2f)" % HEAT_PAUSE_MARK if _aggressive
		else "CLEAN (min trace, heat lever @%.2f)" % HEAT_PAUSE_MARK))
	print("start: dirty $%d clean $%d | phase %s" %
		[player.dirty_cash, player.clean_capital, NightCycle.phase_name(GameState.phase)])
	_seed_baseline()
	_sample("start")

	# --- the main loop: 1800 real ticks through the real settle path ----------
	for t in range(1, TOTAL_TICKS + 1):
		TimeService._do_tick()          # THE real settle: economy -> heat -> central -> rival -> jobs
		_play_policy(t)                 # resolve due jobs, work the heat lever
		if t % SAMPLE_EVERY == 0:
			_sample("tick %d" % t)

	_print_summary()
	# Health probe: a clean completed run is exit 0. The VERDICT line carries the judgement.
	get_tree().quit(0)


# --- the deterministic player policy -----------------------------------------

## Called every tick after settle. Schedules newly-offered jobs for resolution a fixed
## delay later, resolves any that come due through the REAL lifecycle, and works the
## heat lever (pause rackets when a district runs hot, unpause when it cools).
func _play_policy(tick: int) -> void:
	# 1) schedule any newly-offered, not-yet-scheduled, unresolved job.
	for j in JobDirector.active_jobs:
		if j.stage != BM.JobStage.RESOLVED and not _resolve_at.has(j.id):
			_resolve_at[j.id] = tick + RESOLVE_DELAY_TICKS

	# 2) resolve everything due.
	for job_id in _resolve_at.keys():
		if _resolve_at[job_id] <= tick:
			var job := JobDirector.get_job(job_id)
			if job != null and job.stage != BM.JobStage.RESOLVED:
				_resolve_job(job)
			_resolve_at.erase(job_id)

	# 3) heat lever: pause/unpause player rackets per district on combined pressure.
	for d in GameState.districts:
		var combined := EvidenceMath.combined_pressure(d.local_heat, d.evidence_cases)
		if combined > HEAT_PAUSE_MARK and not _paused_rackets.has(d.id):
			var paused: Array = []
			for v in d.venues:
				if v.type == BM.VenueType.RACKET and v.owner_faction == GameState.player_faction_id \
						and not v.paused:
					EconomyService.set_racket_paused(v, true)
					paused.append(v)
			_paused_rackets[d.id] = paused
		elif combined < HEAT_UNPAUSE_MARK and _paused_rackets.has(d.id):
			for v in _paused_rackets[d.id]:
				EconomyService.set_racket_paused(v, false)
			_paused_rackets.erase(d.id)


## Drive one offered job to RESOLVED through the REAL lifecycle (begin -> approach ->
## coverup), the same call sequence the shipped JobDirector/JobLifecycle exposes to the
## player. Choices are DATA-DRIVEN off each option's real evidence_generated effect:
## CLEAN policy picks the argMIN (most trace suppressed), AGGRESSIVE the argMAX (most
## trace left). No hardcoded "which id is loud" — the effect dicts decide. No RNG.
func _resolve_job(job: JobData) -> void:
	var jid := job.id
	JobDirector.begin(jid)
	# begin() only advances INTAKE->PREPARATION; if the job wasn't INTAKE (defensive), bail.
	if JobDirector.get_job(jid).stage != BM.JobStage.PREPARATION:
		return
	var quiet_override := _aggressive and _job_cooling(job)
	var approach := _pick_by_evidence(job.approaches, quiet_override)
	var coverup := _pick_by_evidence(job.coverups, quiet_override)
	if approach == &"" or coverup == &"":
		return
	JobDirector.choose_approach(jid, approach)   # PREPARATION -> INTERVENTION
	JobDirector.choose_coverup(jid, coverup)     # INTERVENTION -> COVER_UP -> RESOLVED (+apply_and_emit)


## Pick the choice whose evidence_generated effect is extremal for the active policy:
## AGGRESSIVE -> max (leave the most trace, so cases accrue); CLEAN -> min (suppress).
## quiet_override flips an aggressive pick to argMIN — the P06d cooling reflex.
## Ties break to the first authored option (deterministic). Reads the REAL effects dict.
func _pick_by_evidence(choices: Array, quiet_override := false) -> StringName:
	if choices.is_empty():
		return &""
	var loud := _aggressive and not quiet_override
	var best: JobChoiceData = null
	var best_ev := 0.0
	for c in choices:
		var ev: float = float(c.effects.get(&"evidence_generated", 0.0))
		if best == null \
				or (loud and ev > best_ev) \
				or (not loud and ev < best_ev):
			best = c
			best_ev = ev
	return best.id if best != null else &""


## The cooling band: this job's district currently has its rackets paused by the policy
## (combined crossed HEAT_PAUSE_MARK, hasn't cooled below HEAT_UNPAUSE_MARK yet).
## Resolves the district by venue (retaliation/followup) or burycase id (the same
## parse JobDirector._district_of uses).
func _job_cooling(job: JobData) -> bool:
	for d in GameState.districts:
		if not _paused_rackets.has(d.id):
			continue
		for v in d.venues:
			if v.id == job.venue_id:
				return true
		var parts := String(job.id).split("@")
		if parts.size() == 8 and parts[1] == "burycase" and StringName(parts[2]) == d.id:
			return true
	return false


# --- signal handlers ----------------------------------------------------------

func _on_job_offered(job: JobData) -> void:
	_jobs_offered += 1
	_origin_offered[job.origin] = int(_origin_offered.get(job.origin, 0)) + 1

## An inspection is CASE-DRIVEN when raw heat alone sat under the effective bar at fire
## time — the standing cases supplied the decisive pressure (P06d's recurrence proof).
func _on_inspection_started(d: DistrictData) -> void:
	_inspections += 1
	var thr := EconomyService.HEAT_INSPECTION_THRESHOLD
	if GameState.central_alert_ticks > 0:
		thr -= PressureMath.CENTRAL_ALERT_INSPECTION_RELIEF
	if d.local_heat < thr and not d.evidence_cases.is_empty():
		_case_driven_inspections += 1

func _on_job_resolved(job: JobData) -> void:
	_jobs_resolved += 1
	_net_evidence_sum += float(job.outcome.get(&"evidence_generated", 0.0))
	_phases_with_activity[NightCycle.phase_name(GameState.phase)] = true

func _on_phase_advanced(cycle: int, phase: int) -> void:
	_phase_transitions += 1
	_sample("PHASE -> %s" % NightCycle.phase_name(phase))


# --- baseline / sampling ------------------------------------------------------

## Give the loop something to bite from tick 1: the seeded world is deliberately squeezed,
## but with a hot-enough start the heat/central chain has signal to show. We nudge Glass
## Wharf's opening heat up a touch (still under the warn line) so the first samples aren't
## all zeros — a READ-adjacent seed tweak, same spirit as the central probe seeding hot
## districts. This is disclosed in the report as a policy shortcut.
func _seed_baseline() -> void:
	var gw := GameState.get_district(&"glass_wharf")
	if gw:
		gw.local_heat = maxf(gw.local_heat, 0.20)


func _gw() -> DistrictData:
	return GameState.get_district(&"glass_wharf")

## One timeline line + dead-stretch bookkeeping.
func _sample(tag: String) -> void:
	var player := GameState.player_faction()
	var gw := _gw()
	var combined := EvidenceMath.combined_pressure(gw.local_heat, gw.evidence_cases) if gw else 0.0
	var corvine := GameState.get_faction(&"corvine")
	var grudge := corvine.grudge if corvine else 0.0
	var alert := 1 if GameState.central_alert else 0

	print("tick %5d | %-10s | dirty $%-6d clean $%-6d | gw_heat %.3f combined %.3f | central %.3f alert %d | grudge %.3f | jobs %d/%d | insp %d" %
		[TimeService.tick_index, NightCycle.phase_name(GameState.phase),
		player.dirty_cash, player.clean_capital,
		gw.local_heat if gw else 0.0, combined,
		GameState.central_pressure, alert, grudge,
		_jobs_offered, _jobs_resolved, _inspections])

	# summary accumulators
	_min_dirty = mini(_min_dirty, player.dirty_cash)
	_max_dirty = maxi(_max_dirty, player.dirty_cash)
	_peak_central = maxf(_peak_central, GameState.central_pressure)
	if gw:
		_peak_cases = maxi(_peak_cases, gw.evidence_cases.size())

	# dead-stretch bookkeeping. Only count coarse cadence samples (tag begins "tick") —
	# phase-transition and start rows are structural, not timeline steps.
	if tag.begins_with("tick"):
		var cash_still: bool = absi(player.dirty_cash - _last_dirty) < 5
		var offered_still: bool = _jobs_offered == _last_offered
		var resolved_still: bool = _jobs_resolved == _last_resolved
		var heat_still: bool = absf(combined - _last_combined) < 0.005
		var central_still: bool = absf(GameState.central_pressure - _last_central) < 0.005
		var grudge_still: bool = absf(grudge - _last_grudge) < 0.005

		# FULL dead: strictly nothing moved, cash included.
		if cash_still and offered_still and heat_still and central_still:
			_current_dead_run += 1
			_longest_dead_run = maxi(_longest_dead_run, _current_dead_run)
		else:
			_current_dead_run = 0

		# PRESSURE plateau: the continuous pressure STATE (heat / central / grudge) is
		# frozen, regardless of cash or the job metronome. This is the real "the mid-game
		# went flat" signal in a build where cash never stops and jobs tick like a clock —
		# it isolates whether the state that's supposed to threaten the player is moving.
		if heat_still and central_still and grudge_still:
			_current_plateau_run += 1
			_longest_plateau_run = maxi(_longest_plateau_run, _current_plateau_run)
		else:
			_current_plateau_run = 0
		# (offered_still / resolved_still kept for the FULL-dead check above.)

		_last_dirty = player.dirty_cash
		_last_offered = _jobs_offered
		_last_resolved = _jobs_resolved
		_last_combined = combined
		_last_central = GameState.central_pressure
		_last_grudge = grudge


func _print_summary() -> void:
	var player := GameState.player_faction()
	var gw := _gw()
	print("--- SUMMARY ---")
	print("jobs: offered %d / resolved %d  (still unresolved at end: %d)" %
		[_jobs_offered, _jobs_resolved, JobDirector.unresolved_count()])
	print("inspections fired: %d (case-driven: %d — raw heat under the bar at fire time)" %
		[_inspections, _case_driven_inspections])
	print("phase transitions: %d (expect 4: COUNCIL->OPERATIONS->CRISIS->RECKONING->[cycle 2 COUNCIL])" % _phase_transitions)
	print("cycle reached: %d, phase at end: %s" % [GameState.night_cycle, NightCycle.phase_name(GameState.phase)])
	print("dirty cash: min $%d  max $%d  end $%d" % [_min_dirty, _max_dirty, player.dirty_cash])
	print("clean capital at end: $%d" % player.clean_capital)
	print("central pressure: peak %.3f (bar %.2f)  central_alert ever fired: %s" %
		[_peak_central, PressureMath.CENTRAL_ALERT_THRESHOLD,
		"YES" if _central_alert_fired else "NO"])
	print("glass wharf end: heat %.3f  cases %d (peak %d)  combined %.3f  inspection_ticks %d" %
		[gw.local_heat if gw else 0.0, gw.evidence_cases.size() if gw else 0, _peak_cases,
		EvidenceMath.combined_pressure(gw.local_heat, gw.evidence_cases) if gw else 0.0,
		gw.inspection_ticks if gw else 0])
	print("resolved-job net evidence (sum of evidence_generated): %.3f  (>0 => cases should accrue)" %
		_net_evidence_sum)
	var origins := PackedStringArray()
	for o in _origin_offered:
		origins.append("%s=%d" % [_origin_name(o), _origin_offered[o]])
	print("jobs offered by origin: %s" % ", ".join(origins))
	var samples := int(TOTAL_TICKS / SAMPLE_EVERY)
	print("DEAD STRETCH (full, all-still incl. cash): %d / %d samples (a sample spans %d ticks)" %
		[_longest_dead_run, samples, SAMPLE_EVERY])
	print("PRESSURE PLATEAU (heat+central+grudge frozen, ignoring cash): %d / %d samples" %
		[_longest_plateau_run, samples])

	# --- verdict ---------------------------------------------------------------
	# LOOP ALIVE requires: jobs kept flowing (resolved several), pressures moved (heat or
	# central climbed off the floor at some point), the cycle ran all 4 phases, no full
	# dead stretch, AND the pressure map didn't freeze for most of the run. The plateau
	# gate is the strict one — it's what a runaway-cash build hides.
	var reasons: Array[String] = []
	if _jobs_resolved < 3:
		reasons.append("job pipeline stalled (only %d resolved)" % _jobs_resolved)
	if _peak_central < 0.05 and _max_dirty - _min_dirty < 50 and _inspections == 0:
		reasons.append("no pressure ever moved (central flat, cash flat, no inspections)")
	if _phase_transitions < 4:
		reasons.append("cycle did not complete all phases (%d transitions)" % _phase_transitions)
	if _longest_dead_run > samples / 2:
		reasons.append("full dead stretch (%d/%d consecutive all-still samples)" % [_longest_dead_run, samples])
	if _longest_plateau_run > samples / 2:
		reasons.append("pressure map froze (%d/%d consecutive samples with heat+central+grudge flat — jobs/cash kept moving but nothing THREATENED the player)" % [_longest_plateau_run, samples])

	if reasons.is_empty():
		print("VERDICT: LOOP ALIVE")
	else:
		print("VERDICT: LOOP FLAT: %s" % "; ".join(reasons))

	# P06d acceptance read (aggressive runs only): the evidence chain must BOOTSTRAP from
	# the feud in real play — cases accrue from retaliation resolutions (no manual
	# injection anywhere in this probe), at least one sweep recurs on CASE pressure, and
	# central climbs past the old ~0.45 ceiling.
	if _aggressive:
		var bootstrap_ok: bool = _peak_cases >= 1 and _case_driven_inspections >= 1 \
			and _peak_central > 0.45
		print("P06D VERDICT: %s" % ("EVIDENCE BOOTSTRAPS FROM THE FEUD" if bootstrap_ok
			else "STILL STERILE (peak cases %d, case-driven insp %d, central peak %.3f)"
			% [_peak_cases, _case_driven_inspections, _peak_central]))


func _origin_name(origin: int) -> String:
	match origin:
		BM.JobOrigin.FAILED_RACKET: return "FAILED_RACKET"
		BM.JobOrigin.WITNESS: return "WITNESS"
		BM.JobOrigin.RIVAL_PROVOCATION: return "RIVAL_PROVOCATION"
		BM.JobOrigin.INTERNAL_DISPUTE: return "INTERNAL_DISPUTE"
		BM.JobOrigin.INSTITUTIONAL_PRESSURE: return "INSTITUTIONAL_PRESSURE"
		BM.JobOrigin.EVIDENCE_CHAIN: return "EVIDENCE_CHAIN"
		_: return "?%d" % origin
