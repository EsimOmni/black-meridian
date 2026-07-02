extends Node
## P05 unit test — the brief §7.2 economy verbs + the surfaced squeeze.
## Run as a scene, NOT via -s (-s skips autoloads — GameState/EconomyService false-fail):
##   Godot --headless --path . res://tests/unit/test_economy_verbs.tscn

var _failures := 0

func _ready() -> void:
	_test_paused_racket_earns_nothing()
	_test_pressure_front_spends_clean()
	_test_pressure_front_insufficient_is_noop()
	_test_pressure_front_respects_max()
	_test_overflow_surfaced_for_hud()
	await _test_venue_panel_wiring()
	if _failures == 0:
		print("[PASS] all economy verb tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d economy verb assertion(s) failed" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("  assertion failed: ", msg)

func _racket() -> VenueData:
	var v := VenueData.new()
	v.id = &"t_racket"
	v.type = BM.VenueType.RACKET
	v.base_yield = 200
	v.operational_staff = 2
	v.control_state = BM.ControlState.CONTROLLED
	return v

func _front(owner: StringName) -> VenueData:
	var v := VenueData.new()
	v.id = &"t_front"
	v.type = BM.VenueType.FRONT
	v.owner_faction = owner
	v.laundering_capacity = 600
	v.front_efficiency = 0.75
	v.operating_cost = 0.18
	return v

func _test_paused_racket_earns_nothing() -> void:
	var v := _racket()
	var before := EconomyMath.compute_dirty_income(v, 1.0)
	_check(before > 0, "running racket earns (%d)" % before)
	v.paused = true
	_check(EconomyMath.compute_dirty_income(v, 1.0) == 0, "paused racket earns 0")
	v.paused = false
	_check(EconomyMath.compute_dirty_income(v, 1.0) == before, "resumed racket earns pre-pause value")

func _test_pressure_front_spends_clean() -> void:
	var f := FactionData.new()
	f.id = &"t_faction"
	f.clean_capital = 1000
	var v := _front(f.id)
	_check(EconomyService.pressure_front(v, f), "pressure succeeds with enough clean")
	_check(v.laundering_capacity == 600 + EconomyService.FRONT_PRESSURE_STEP,
		"capacity rose by the step (got %d)" % v.laundering_capacity)
	_check(f.clean_capital == 1000 - EconomyService.FRONT_PRESSURE_COST,
		"clean_capital paid the cost (got %d)" % f.clean_capital)

func _test_pressure_front_insufficient_is_noop() -> void:
	var f := FactionData.new()
	f.id = &"t_faction"
	f.clean_capital = EconomyService.FRONT_PRESSURE_COST - 1
	var v := _front(f.id)
	_check(not EconomyService.pressure_front(v, f), "insufficient clean is refused")
	_check(v.laundering_capacity == 600 and f.clean_capital == EconomyService.FRONT_PRESSURE_COST - 1,
		"no-op: capacity and pool untouched, never negative")

func _test_pressure_front_respects_max() -> void:
	var f := FactionData.new()
	f.id = &"t_faction"
	f.clean_capital = 100000
	var v := _front(f.id)
	v.laundering_capacity = EconomyService.FRONT_CAPACITY_MAX
	_check(not EconomyService.pressure_front(v, f), "at-max front is refused")
	_check(f.clean_capital == 100000, "refused pressure spends nothing")

## Regression guard on the value the HUD indicator reads: with the seeded world's
## dirty_income > laundering_capacity, settle_info must expose a positive overflow.
func _test_overflow_surfaced_for_hud() -> void:
	WorldSeed.build()
	TimeService.set_speed(BM.Speed.PAUSED)
	TimeService._do_tick()
	var info: Dictionary = EconomyService.settle_info(GameState.player_faction_id)
	_check(not info.is_empty(), "settle_info populated after a tick")
	_check(info["dirty_income"] > info["laundering_capacity"],
		"seeded world is squeezed (income %d > capacity %d)" % [info["dirty_income"], info["laundering_capacity"]])
	_check(info["overflow"] == info["dirty_income"] - info["laundering_capacity"] and info["overflow"] > 0,
		"overflow == income - capacity and positive (got %d)" % info["overflow"])

	# Pausing the biggest racket must shrink the overflow the HUD shows.
	var contraband: VenueData = null
	for v in GameState.districts[0].venues:
		if v.id == &"gw_contraband":
			contraband = v
	EconomyService.set_racket_paused(contraband, true)
	TimeService._do_tick()
	var after: Dictionary = EconomyService.settle_info(GameState.player_faction_id)
	_check(after["overflow"] < info["overflow"], "pausing a racket shrinks the overflow (%d -> %d)"
		% [info["overflow"], after["overflow"]])
	EconomyService.set_racket_paused(contraband, false)

## The panel actually drives the verbs: boot the real bootstrap scene, select venues,
## press the real buttons, assert authoritative state moved (state lives in VenueData/
## FactionData — the panel only calls verbs).
func _test_venue_panel_wiring() -> void:
	var bootstrap: Node = load("res://scenes/bootstrap/bootstrap.tscn").instantiate()
	add_child(bootstrap)
	await get_tree().process_frame
	var hud = bootstrap.get("_hud")
	_check(hud != null, "bootstrap exposes the HUD")

	var racket: VenueData = GameState.districts[0].venues[0]  # gw_contraband, player-owned
	hud.show_selection(racket)
	var pause_btn := _find_button_with_prefix(hud, "Pause racket")
	_check(pause_btn != null, "racket selection shows a Pause button")
	pause_btn.pressed.emit()
	_check(racket.paused, "Pause button pauses the racket (authoritative state)")
	var resume_btn := _find_button_with_prefix(hud, "Resume racket")
	_check(resume_btn != null, "button relabels to Resume")
	resume_btn.pressed.emit()
	_check(not racket.paused, "Resume button unpauses")

	var front: VenueData = null
	for v in GameState.districts[0].venues:
		if v.id == &"gw_nightclub":
			front = v
	hud.show_selection(front)
	var cap_before := front.laundering_capacity
	var clean_before: int = GameState.player_faction().clean_capital
	var pressure_btn := _find_button_with_prefix(hud, "Pressure front (+")
	_check(pressure_btn != null, "front selection shows an enabled Pressure button")
	pressure_btn.pressed.emit()
	_check(front.laundering_capacity == cap_before + EconomyService.FRONT_PRESSURE_STEP,
		"Pressure button raised capacity")
	_check(GameState.player_faction().clean_capital == clean_before - EconomyService.FRONT_PRESSURE_COST,
		"Pressure button spent clean_capital")

	bootstrap.queue_free()

func _find_button_with_prefix(root: Node, prefix: String) -> Button:
	for child in root.get_children():
		if child is Button and child.text.begins_with(prefix) and not child.disabled:
			return child
		var found := _find_button_with_prefix(child, prefix)
		if found:
			return found
	return null
