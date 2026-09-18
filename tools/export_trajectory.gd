extends Node
## Trajectory golden-vector extractor — the Unreal port's behavioral oracle (reboot S2).
##
## READ-ONLY. It seeds the shipped world, drives 1800 strategic ticks through the REAL
## settle path, samples the state every 120 ticks and writes one JSON document. It mutates
## no shipped source, authors no new game state and must never be given a reason to.
##
## Companion to export_golden_vectors.gd (S1 hash layers) and export_sim_vectors.gd (S2
## pure-math layers). Those two answer "is one formula right?"; this one answers "does the
## whole machine, composed and run for a full Night Cycle, land on the same numbers?" —
## the integration check neither unit fixture can make.
##
## Run:
##   D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . \
##       tools/export_trajectory.tscn -- --out=<abs path>.json
##
## Like both sibling extractors it writes the file itself rather than printing to stdout:
## the godot_ai game_helper autoload emits a banner after the run and that trailing text
## corrupts a redirected document.
##
## WHY A .tscn AND NOT `-s` (the load-bearing difference from its two siblings)
## ---------------------------------------------------------------------------
## A trajectory is not math, it is the SERVICE layer composed over time. The single writer
## of local_heat, central_pressure and the inspection latch is EconomyService._on_strategic_tick,
## and it reads and writes the GameState autoload throughout. TimeService owns the tick
## counter and the rival-tick cadence; RivalDirector rides on it. None of that exists under
## `godot --headless -s`, where the main loop that instantiates autoloads never runs — and
## merely NAMING `EconomyService` in a `-s` script drags it into compilation, where it dies
## on its own `TimeService` reference. The siblings dodge this by parsing constants out of
## the source and driving autoload-free static math; that dodge is unavailable here, because
## the thing being measured IS the autoload composition. So this runs as a scene, the repo
## convention for autoload-dependent tools (tools/validation/*.tscn), exactly as
## full_cycle_probe.gd does.
##
## Consequence: no constant is transcribed OR parsed here — every threshold in the header
## block is read live off the real autoload/class that owns it, which is strictly stronger
## than the regex parse the `-s` siblings are forced into.
##
## THE POLICY (what the Unreal side must reproduce)
## ------------------------------------------------
## PASSIVE — the player does nothing at all for 1800 ticks. No job is offered, begun or
## resolved; no racket is paused; no front is pressured; no operative moves; no evidence is
## deposited by hand. The world is seeded by WorldSeed.build() and then only TIME is applied.
##
## This is deliberate, and it is the opposite of full_cycle_probe.gd's choice. That probe is
## a HEALTH instrument and needs a player to prove the loop is alive, so it resolves jobs by
## an argmin/argmax over authored effect dicts. That makes its trajectory a function of the
## narrative CONTENT — change one number in job_templates.gd and the curve moves, with no
## port bug anywhere. A golden vector must fail only when the SIMULATION diverges, so the
## player input here is the empty set: the trajectory is a pure function of the seed plus
## the settle/heat/pressure/rival machinery. Everything it records is still exercised —
## income, laundering overflow, exposure, the heat ramp, disruption feedback, the inspection
## latch, central pressure, and the rival's deterministic telegraph/land cycle (which runs
## the S1 tie_jitter hash for real).
##
## ZERO RNG. Nothing in the driven path rolls: the economy is arithmetic, the two latches
## are thresholds, and RivalScoring is an argmax whose ties break on a String.hash()
## derivative. That is the property this file exists to pin, and re-running must be
## byte-identical.

const SCHEMA := 1
const DEFAULT_OUT := "D:/black-meridian-ue/Tests/Golden/trajectory.json"
const TOTAL_TICKS := 1800     ## one full Night Cycle: 240 + 1080 + 360 + 120
const SAMPLE_EVERY := 120     ## 15 samples plus the tick-0 baseline

## Inspections observed so far, off the real signal — the count is cumulative per sample.
var _inspections := 0
var _night_cycle: NightCycle


func _ready() -> void:
	WorldSeed.build()
	TimeService.set_speed(BM.Speed.PAUSED)   ## _process must never tick; the loop below owns time

	# The phase machine is NOT an autoload — bootstrap.gd instantiates it, so we do too.
	# Without it GameState.phase never advances and every sample would read COUNCIL.
	_night_cycle = NightCycle.new()
	_night_cycle.name = "NightCycle"
	add_child(_night_cycle)

	EconomyService.inspection_started.connect(func(_d: DistrictData) -> void: _inspections += 1)

	var samples: Array = [_sample()]
	for t in range(1, TOTAL_TICKS + 1):
		TimeService._do_tick()   ## the real settle: economy -> heat -> central -> rival
		if t % SAMPLE_EVERY == 0:
			samples.append(_sample())

	var out := {
		"schema": SCHEMA,
		"source": "godot-final",
		"godot_version": Engine.get_version_info().string,
		"note": _note(),
		"policy": _policy(),
		"constants": _constants(),
		"samples": samples,
	}

	var path := _out_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		get_tree().quit(1)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()

	print("wrote %s — %d samples over %d ticks, %d inspections" %
		[path, samples.size(), TOTAL_TICKS, _inspections])
	get_tree().quit(0)


func _out_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			return arg.trim_prefix("--out=")
	return DEFAULT_OUT


func _note() -> String:
	return ("Reference economic trajectory for reboot S2: the shipped WorldSeed world driven " +
		"%d strategic ticks through the REAL autoload settle path (EconomyService -> heat -> " +
		"central pressure -> RivalDirector) and sampled every %d ticks. POLICY: PASSIVE — the " +
		"player takes no action for the whole cycle (no job resolved, no racket paused, no " +
		"front pressured, no operative moved), so the curve is a pure function of the seed plus " +
		"time and cannot drift when authored job content changes. Zero RNG: the economy is " +
		"arithmetic, both latches are thresholds, and the rival is an argmax whose ties break " +
		"on String.hash(). Re-running MUST be byte-identical. Floats are JSON numbers, compared " +
		"at 1e-5 per 08 §5.1; discrete fields (tick, cash, counts, booleans, phase) compare " +
		"EXACTLY. Runs as a .tscn, not `-s`: this measures the autoload composition itself, " +
		"which does not exist in a -s SceneTree script.") % [TOTAL_TICKS, SAMPLE_EVERY]


func _policy() -> Dictionary:
	return {
		"name": "passive",
		"player_actions": [],
		"rng": "none",
		"total_ticks": TOTAL_TICKS,
		"sample_every": SAMPLE_EVERY,
		"seed": "WorldSeed.build()",
		"night_cycle_machine": "instantiated as in bootstrap.gd (NightCycle is not an autoload)",
		"rival_tick_interval": BM.RIVAL_TICK_INTERVAL,
	}


## Every threshold the trajectory's shape depends on, read LIVE off the class that owns it
## (no transcription, no regex parse — the scene has the real autoloads). Emitted so the
## C++ tests can assert against the fixture instead of re-typing literals.
func _constants() -> Dictionary:
	return {
		"heat_rise_scale": EconomyService.HEAT_RISE_SCALE,
		"exposure_heat_floor": EconomyService.EXPOSURE_HEAT_FLOOR,
		"heat_decay_per_tick": EconomyService.HEAT_DECAY_PER_TICK,
		"heat_inspection_threshold": EconomyService.HEAT_INSPECTION_THRESHOLD,
		"heat_inspection_warn": EconomyService.HEAT_INSPECTION_WARN,
		"heat_inspection_rearm": EconomyService.HEAT_INSPECTION_REARM,
		"inspection_duration_ticks": EconomyService.INSPECTION_DURATION_TICKS,
		"inspection_disruption": EconomyService.INSPECTION_DISRUPTION,
		"central_rise_floor": PressureMath.CENTRAL_RISE_FLOOR,
		"central_rise_scale": PressureMath.CENTRAL_RISE_SCALE,
		"central_decay_per_tick": PressureMath.CENTRAL_DECAY_PER_TICK,
		"central_alert_threshold": PressureMath.CENTRAL_ALERT_THRESHOLD,
		"central_alert_rearm": PressureMath.CENTRAL_ALERT_REARM,
		"central_alert_duration_ticks": PressureMath.CENTRAL_ALERT_DURATION_TICKS,
		"central_alert_inspection_relief": PressureMath.CENTRAL_ALERT_INSPECTION_RELIEF,
		"phase_budget_ticks": NightCycle.PHASE_BUDGET_TICKS,
	}


## One sample of the whole authoritative state. Ordered containers only — factions and
## districts are emitted as arrays in GameState order, and every id is carried alongside
## its values so a port cannot pass by accident of ordering.
func _sample() -> Dictionary:
	var factions: Array = []
	for f in GameState.factions:
		factions.append({
			"id": String(f.id),
			"dirty_cash": f.dirty_cash,
			"clean_capital": f.clean_capital,
		})

	var districts: Array = []
	for d in GameState.districts:
		districts.append({
			"id": String(d.id),
			"local_heat": d.local_heat,
			# The latch's own state travels with the heat it is latched on — a port can
			# reproduce local_heat exactly and still have the excursion out of phase.
			"evidence_case_count": d.evidence_cases.size(),
			"case_pressure": EvidenceMath.case_pressure(d.evidence_cases),
			"combined_pressure": EvidenceMath.combined_pressure(d.local_heat, d.evidence_cases),
			"inspection_ticks": d.inspection_ticks,
			"inspection_armed": d.inspection_armed,
		})

	return {
		"tick": TimeService.tick_index,
		"night_cycle": GameState.night_cycle,
		"phase": GameState.phase,
		"phase_name": NightCycle.phase_name(GameState.phase),
		"factions": factions,
		"districts": districts,
		"central_pressure": GameState.central_pressure,
		"central_alert": GameState.central_alert,
		"central_alert_ticks": GameState.central_alert_ticks,
		"inspections_so_far": _inspections,
	}
