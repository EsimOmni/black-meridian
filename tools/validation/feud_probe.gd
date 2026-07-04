extends Node
## P07c acceptance probe — drives the feud loop end to end and prints it closing:
## rival sabotages a player venue -> player resolves the provoked retaliation -> that rival's
## grudge rises -> next choose_move bites harder -> grudge decays when left alone.
## Run as a scene (autoloads needed): Godot --headless --path . res://tools/validation/feud_probe.gd
## ... via a .tscn wrapper. Throwaway probe, like kit_gate.gd.

func _ready() -> void:
	WorldSeed.build()
	TimeService.set_speed(BM.Speed.PAUSED)
	var corvine := GameState.get_faction(&"corvine")
	var player_id := GameState.player_faction_id
	var district := GameState.get_district(&"glass_wharf")
	var target := district.venues[0]  # a player-owned venue

	print("--- P07c feud loop ---")
	print("corvine grudge at start: %.3f" % corvine.grudge)

	# Baseline: score the softest player target with no grudge.
	var weakness := RivalScoring.target_weakness(target, district)
	var cold := RivalScoring.score_action(BM.RivalAction.SABOTAGE, weakness, corvine, district)
	print("SABOTAGE score, grudge 0.00: %.3f" % cold)

	# The player answers a provocation: simulate resolving a RIVAL_PROVOCATION job that drew
	# rival_suspicion. This is exactly what JobDirector._apply_and_emit consumes.
	var job := JobGenerator.retaliation_job(target, corvine, 0)
	job.outcome = {&"rival_suspicion": 0.40, &"objective_achieved": 1.0, &"evidence_generated": 0.0,
		&"public_fear": 0.0, &"relationship_change": 0.0, &"collateral_damage": 0.0,
		&"operative_injury": 0.0, &"delayed_consequence": 0.0}
	job.stage = BM.JobStage.RESOLVED
	# Feed it through the real settle path so we test the actual writer, not a shortcut.
	JobDirector.active_jobs.append(job)
	JobDirector._apply_and_emit(job)
	print("corvine grudge after player answers (suspicion 0.40): %.3f" % corvine.grudge)

	# Memory shows up: the same target now scores higher.
	var hot := RivalScoring.score_action(BM.RivalAction.SABOTAGE, weakness, corvine, district)
	print("SABOTAGE score, grudge %.2f: %.3f  (delta +%.3f)" % [corvine.grudge, hot, hot - cold])
	var verdict_bites := hot > cold

	# In a calm world the grudge can push a rival to act where it otherwise would not.
	var pick := RivalScoring.choose_move(GameState.districts, player_id, corvine)
	print("choose_move in a calm world WITH grudge: %s" % ("acts" if not pick.is_empty() else "waits"))

	# Decay: leave the rival alone, grudge cools each rival tick (~10 strategic ticks).
	var before_decay := corvine.grudge
	for i in 30:
		TimeService._do_tick()
	print("corvine grudge after ~3 rival ticks alone: %.3f  (cooled from %.3f)" % [corvine.grudge, before_decay])
	var verdict_decays := corvine.grudge < before_decay

	print("--- verdict: %s ---" % ("FEUD CLOSES (rises->bites->decays)" if (verdict_bites and verdict_decays) else "BROKEN"))
	get_tree().quit(0 if (verdict_bites and verdict_decays) else 1)
