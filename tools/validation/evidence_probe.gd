extends Node
## P06b acceptance probe — drives the evidence chain end to end through the REAL
## settle/resolve paths (the feud_probe discipline: test the actual writers, never a
## shortcut) and prints it closing: exposed jobs deposit trace -> cases accrue ->
## case pressure pins an inspection even as raw heat decays -> the sweep auto-offers
## "Bury the Case" -> a cover-up erodes the strongest case -> the played burn removes
## the targeted one -> pressure drops below the bar -> the sweep lifts and stays lifted.
## Run: Godot --headless --path . res://tools/validation/evidence_probe.tscn
## Throwaway probe, like feud_probe.

var _fires := 0

func _ready() -> void:
	WorldSeed.build()
	TimeService.set_speed(BM.Speed.PAUSED)
	EconomyService.inspection_started.connect(func(_d): _fires += 1)
	await get_tree().process_frame  # JobDirector wires its triggers deferred
	var district := GameState.get_district(&"glass_wharf")
	var venue := district.venues[0]
	print("--- P06b evidence chain ---")

	# Kill the heat flow: pause every player racket so ONLY the case layer can pin a sweep.
	for v in district.venues:
		if v.type == BM.VenueType.RACKET and v.owner_faction == GameState.player_faction_id:
			EconomyService.set_racket_paused(v, true)
	district.local_heat = 0.25  # well under the 0.45 threshold on its own

	# 1) Two exposed jobs resolve through the real path -> trace deposits into cases.
	_resolve_with_evidence(JobTemplates.intercepted_shipment(), 0.5)
	_resolve_with_evidence(JobGenerator.followup_job(venue, 1), 0.5)
	var pressure := EvidenceMath.case_pressure(district.evidence_cases)
	print("two exposed jobs (+0.5 each): %d case(s), case_pressure %.2f" %
		[district.evidence_cases.size(), pressure])
	for c in district.evidence_cases:
		print("  %s  weight %.2f  \"%s\"" % [c.id, c.weight, c.label])
	var verdict_accrues := pressure >= 0.9

	# 2) The roots pin the sweep even as the raw heat flow decays.
	var heat_before := district.local_heat
	TimeService._do_tick()
	print("tick: heat %.4f -> %.4f (decaying), combined %.2f -> inspection fires: %d" %
		[heat_before, district.local_heat,
		EvidenceMath.combined_pressure(district.local_heat, district.evidence_cases), _fires])
	var verdict_pins := _fires == 1 and district.local_heat <= heat_before \
		and district.local_heat < EconomyService.HEAT_INSPECTION_THRESHOLD

	# 3) The sweep auto-offered the aimed strike (JobDirector's inspection trigger).
	var burn: JobData = null
	for j in JobDirector.active_jobs:
		if j.origin == BM.JobOrigin.EVIDENCE_CHAIN and j.stage != BM.JobStage.RESOLVED:
			burn = j
	var verdict_offer := burn != null
	print("bury-the-case auto-offered: %s" %
		(String(burn.id) if burn != null else "NO"))

	# 4) Path A — a suppressive cover-up (-0.2) erodes the strongest case.
	var strongest := EvidenceMath.strongest_case(district)
	var weight_before := strongest.weight
	_resolve_with_evidence(JobGenerator.followup_job(venue, 2), -0.2)
	var after := EvidenceMath.case_pressure(district.evidence_cases)
	print("cover-up (-0.2): strongest %.2f -> %.2f, case_pressure %.2f -> %.2f" %
		[weight_before, EvidenceMath.strongest_case(district).weight, pressure, after])
	var verdict_erodes := after < pressure

	# 5) Path B — play the offered burn through the real lifecycle; the TARGETED case dies.
	var verdict_burn := false
	if burn != null:
		var target := JobDirector._burn_target_of(burn)
		JobDirector.begin(burn.id)
		JobDirector.choose_prep(burn.id, &"prep_case_room")     # evidence -0.1
		JobDirector.choose_approach(burn.id, &"appr_custodian") # evidence -0.4
		JobDirector.choose_coverup(burn.id, &"cover_never_was") # evidence -0.15 -> net -0.65
		verdict_burn = EvidenceMath.find_case(district, target) == null
		print("burn played (net -0.65): targeted %s -> %s" %
			[target, "REMOVED" if verdict_burn else "STILL STANDING"])

	# 6) The sweep runs out; combined pressure sits below the bar; no second fire.
	for i in EconomyService.INSPECTION_DURATION_TICKS + 5:
		TimeService._do_tick()
	var combined := EvidenceMath.combined_pressure(district.local_heat, district.evidence_cases)
	print("after the sweep runs out: combined %.3f (bar %.2f), inspection_ticks %d, total fires %d" %
		[combined, EconomyService.HEAT_INSPECTION_THRESHOLD, district.inspection_ticks, _fires])
	var verdict_lifts := district.inspection_ticks == 0 \
		and combined < EconomyService.HEAT_INSPECTION_THRESHOLD and _fires == 1

	var ok := verdict_accrues and verdict_pins and verdict_offer and verdict_erodes \
		and verdict_burn and verdict_lifts
	print("--- verdict: %s ---" %
		("EVIDENCE CHAIN CLOSES (accrues->pins->offers->erodes->burns->lifts)" if ok else "BROKEN"))
	get_tree().quit(0 if ok else 1)

## A resolved job carrying a signed evidence outcome, fed through the REAL consumer
## (JobDirector._apply_and_emit) — exactly what a played job hits at resolution.
func _resolve_with_evidence(job: JobData, evidence: float) -> void:
	job.outcome = JobResolution.blank()
	job.outcome[&"evidence_generated"] = evidence
	job.stage = BM.JobStage.RESOLVED
	JobDirector.active_jobs.append(job)
	JobDirector._apply_and_emit(job)
