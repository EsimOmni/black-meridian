class_name NarrativeBeats
extends RefCounted
## P16 pure narrative-beat logic (brief §13.2): which authored beat is ready, what a
## beat writes when it fires, what a resolved narrative job writes back. Kept out of the
## NarrativeDirector node so it unit-tests headless (tasks/lessons.md). Everything here
## is deterministic — conditions read the flags dictionary, writes are fixed values,
## no RNG anywhere. Beat progress lives in GameState.narrative_flags (save-additive):
##   &"fired@<beat>"    -> true       once the beat's job has been offered
##   &"resolved@<job>"  -> tick int   when a tracked job resolved (the chain's clock)
##   &"ledger_secured"  -> bool       beat 1's material outcome
##   &"accord_stance"   -> StringName beat 3's stance (&"truce"/&"leverage"/&"war")

## Breathing room between a chain job resolving and the next beat surfacing (strategic
## ticks — 30s at NORMAL speed). Short on purpose: ship-first pacing.
const LEAD_TICKS := 30

## The ordered beat chain. Each beat: its gate is the PREVIOUS job's resolution flag
## (+ lead), so the arc advances only through play — never on a wall clock.
const BEATS: Array[StringName] = [&"beat_ledger", &"beat_debt", &"beat_accord"]

## Beat -> the job it offers. The seed job (P03's cold open) is the chain's root.
const BEAT_JOBS := {
	&"beat_ledger": &"job_inspectors_ledger",
	&"beat_debt": &"job_lieutenants_debt",
	&"beat_accord": &"job_meridian_accord",
}
const BEAT_GATES := {
	&"beat_ledger": &"job_intercepted_shipment",
	&"beat_debt": &"job_inspectors_ledger",
	&"beat_accord": &"job_lieutenants_debt",
}

## Every job whose resolution tick the director must record (the chain's clock).
const TRACKED_JOB_IDS: Array[StringName] = [&"job_intercepted_shipment",
	&"job_inspectors_ledger", &"job_lieutenants_debt", &"job_meridian_accord"]

## The first beat whose gate holds at this tick, or &"" if none. One beat per call —
## beats surface as beats, never as a flood (the JobDirector cadence spirit).
static func ready_beat(flags: Dictionary, tick: int) -> StringName:
	for beat in BEATS:
		if flags.get(StringName("fired@" + String(beat)), false):
			continue
		var gate: StringName = BEAT_GATES[beat]
		var resolved_key := StringName("resolved@" + String(gate))
		if not flags.has(resolved_key):
			return &""  # the chain is strictly ordered — nothing later can be ready
		if tick >= int(flags[resolved_key]) + LEAD_TICKS:
			return beat
		return &""
	return &""

static func job_for_beat(beat: StringName) -> JobData:
	return NarrativeJobs.by_id(BEAT_JOBS.get(beat, &""))

## At-fire writes. beat_debt IS the loyalty-crisis cause (brief §7.6, causally
## understandable): the ledger revealed the Corvine bought the lieutenant's marker —
## the leverage exists from the moment the player learns of it. Telegraphed by the
## job text; preventable by the job's approaches (apply_resolution below).
static func apply_fire(beat: StringName, characters: Array[CharacterData]) -> void:
	if beat != &"beat_debt":
		return
	var lt := _find(characters, &"bengal_lt")
	if lt == null:
		return
	# Calibrated against the real gate (pressure >= betrayal_threshold*2 = 1.4 for the
	# seeded lieutenant, with >=0.05 float margin — tasks/lessons.md): these alone do NOT
	# open the crisis; the player's approach below decides whether it becomes reachable.
	lt.rival_leverage = maxf(lt.rival_leverage, 0.6)
	lt.survival_pressure = maxf(lt.survival_pressure, 0.4)

## Post-resolution narrative consequences, keyed by the job and the approach the player
## committed to. All fixed-value writes on top of the generic apply_outcome axes.
## An expired job (chosen_approach == &"") takes the worst branch — ignoring a named
## crisis is a choice too.
static func apply_resolution(job: JobData, characters: Array[CharacterData],
		flags: Dictionary) -> void:
	match job.id:
		&"job_inspectors_ledger":
			flags[&"ledger_secured"] = job.outcome.get(&"objective_achieved", 0.0) >= 0.5
		&"job_lieutenants_debt":
			var lt := _find(characters, &"bengal_lt")
			if lt == null:
				return
			# The preventability contract: pay_it / buy_marker keep the lieutenant's
			# pressure safely under the betrayal bar; bait / letting it expire push it
			# safely OVER (the two-gate P10 machine still needs an opportunity — the
			# crisis telegraphs when the sim supplies one, never as a surprise roll).
			match job.chosen_approach:
				&"appr_pay_it":       # the marker burns — the crisis dies at the root
					lt.rival_leverage = 0.0
					lt.survival_pressure = maxf(lt.survival_pressure - 0.4, 0.0)
				&"appr_buy_marker":   # the Corvine knife is gone; yours sits in a drawer he knows about
					lt.rival_leverage = 0.0
					lt.survival_pressure = maxf(lt.survival_pressure - 0.25, 0.0)
					lt.grievance = clampf(lt.grievance + 0.15, 0.0, 1.0)
				&"appr_bait":         # the debt stays theirs; he twists on it — and he can smell it
					lt.grievance = clampf(lt.grievance + 0.4, 0.0, 1.0)
					lt.public_trust = clampf(lt.public_trust - 0.15, 0.0, 1.0)
				_:                    # expired — the ignored crisis festers the same way
					lt.grievance = clampf(lt.grievance + 0.35, 0.0, 1.0)
					lt.public_trust = clampf(lt.public_trust - 0.15, 0.0, 1.0)
		&"job_meridian_accord":
			match job.chosen_approach:
				&"appr_good_faith":
					flags[&"accord_stance"] = &"truce"
				&"appr_from_strength":
					flags[&"accord_stance"] = &"leverage"
				_:                    # walked out, or stood her up (expired)
					flags[&"accord_stance"] = &"war"

## --- P19: the ending decision --------------------------------------------------
## The accord IS the slice's significant ending decision (brief §12.1); the epilogue
## surfaces a settle-window after it resolves. Three reachable endings, one per stance —
## a pure function of the flags, deterministic and save-safe like everything else here.

const ENDING_LEAD_TICKS := 120  ## ~2 min at NORMAL — the city settles before the verdict

const STANCE_ENDINGS := {
	&"truce": &"ending_accord",
	&"leverage": &"ending_armed_peace",
	&"war": &"ending_war",
}

## The ending due at this tick, or &"" (not yet / already reached).
static func ready_ending(flags: Dictionary, tick: int) -> StringName:
	if flags.has(&"ending"):
		return &""
	var stance: StringName = flags.get(&"accord_stance", &"")
	if stance == &"" or not flags.has(&"resolved@job_meridian_accord"):
		return &""
	if tick < int(flags[&"resolved@job_meridian_accord"]) + ENDING_LEAD_TICKS:
		return &""
	return STANCE_ENDINGS.get(stance, &"ending_war")

static func _find(characters: Array[CharacterData], id: StringName) -> CharacterData:
	for c in characters:
		if c.id == id:
			return c
	return null
