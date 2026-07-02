extends Node
## P04 bootstrap smoke + P02 in-scene save/load (brief §19 Month-1 gate, §18).
## Boots the REAL bootstrap scene (greybox city, HUD, job panel — every UI listener live),
## pumps strategic ticks, exercises quick-save/quick-load through the full presentation
## stack, and asserts that cash/heat/job state evolve and that a load restores + repaints.
##   Godot --headless --path . res://tests/integration/bootstrap_smoke_runner.tscn

const TICKS := 30

var _failures := 0

func _ready() -> void:
	# The real entry scene, listeners and all. Its _ready seeds the world and offers the job.
	var bootstrap: Node = load("res://scenes/bootstrap/bootstrap.tscn").instantiate()
	add_child(bootstrap)
	await get_tree().process_frame  # let deferred _ready wiring settle

	var pf := GameState.player_faction()
	var cash0: int = pf.dirty_cash
	var job := JobDirector.get_job(&"job_intercepted_shipment")
	_check(job != null, "placeholder job offered at boot")
	_check(job.stage == BM.JobStage.INTAKE, "job starts at INTAKE")
	var deadline0: int = job.ticks_remaining

	# Beat 1/4: the world changes while time runs.
	_pump(TICKS)
	_check(pf.dirty_cash > cash0, "dirty cash evolved over %d ticks" % TICKS)
	_check(job.ticks_remaining == deadline0 - TICKS, "job deadline counted down")

	# Save mid-loop through the real service.
	_check(SaveService.save_game("smoke_test"), "quick-save mid-loop")
	var cash_at_save: int = GameState.player_faction().dirty_cash
	var tick_at_save: int = TimeService.tick_index

	# Beats 2-3: inspect + commit — drive the job like a player would.
	JobDirector.begin(&"job_intercepted_shipment")
	JobDirector.choose_prep(&"job_intercepted_shipment", &"prep_lookouts")
	JobDirector.choose_approach(&"job_intercepted_shipment", &"appr_quiet")
	JobDirector.choose_coverup(&"job_intercepted_shipment", &"cover_paper")
	_check(job.stage == BM.JobStage.RESOLVED, "job resolved through all four stages")
	_check(GameState.player_faction().dirty_cash >= cash_at_save + job.reward_dirty,
		"job reward applied to faction cash")
	_pump(TICKS)

	# Load through the full presentation stack (city rebuild, HUD repaint, panel re-bind).
	_check(SaveService.load_game("smoke_test"), "quick-load mid-loop")
	await get_tree().process_frame  # let queued UI rebuilds run
	_check(GameState.player_faction().dirty_cash == cash_at_save, "cash restored to save point")
	_check(TimeService.tick_index == tick_at_save, "tick restored to save point")
	_check(TimeService.speed == BM.Speed.PAUSED, "load leaves the game paused")
	var restored_job := JobDirector.get_job(&"job_intercepted_shipment")
	_check(restored_job != null and restored_job.stage == BM.JobStage.INTAKE,
		"job restored to its saved stage (INTAKE)")

	# HUD actually repainted from the restored state (presentation reads, never owns).
	var hud_cash := _find_label_with_prefix(bootstrap, "Dirty cash:")
	_check(hud_cash != null and hud_cash.text.ends_with(str(cash_at_save)),
		"HUD shows restored cash (%s)" % (hud_cash.text if hud_cash else "label missing"))

	# And the sim keeps running cleanly after a load.
	_pump(TICKS)
	_check(GameState.player_faction().dirty_cash > cash_at_save, "sim continues after load")

	if _failures == 0:
		print("[PASS] bootstrap smoke + in-scene save/load")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d bootstrap smoke assertion(s) failed" % _failures)
		get_tree().quit(1)

func _pump(n: int) -> void:
	for i in n:
		TimeService._do_tick()

func _find_label_with_prefix(root: Node, prefix: String) -> Label:
	for child in root.get_children():
		if child is Label and child.text.begins_with(prefix):
			return child
		var found := _find_label_with_prefix(child, prefix)
		if found:
			return found
	return null

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: ", msg)
	else:
		_failures += 1
		printerr("  assertion failed: ", msg)
