extends Node
## P06c acceptance probe — drives central pressure end to end through the REAL settle
## path (TimeService._do_tick -> EconomyService._on_strategic_tick; the feud/evidence
## probe discipline: the actual writers, never a shortcut) and prints it closing:
## several districts run hot -> city_pressure climbs -> central_pressure rises toward it
## and crosses the bar -> central_alert_started fires -> while the alert is up, a COOLER
## district crosses its eased inspection threshold it would NOT have crossed unaided ->
## the whole city cools -> central_pressure decays below re-arm -> the alert lifts and
## re-arms, exactly once.
## Run: Godot --headless --path . res://tools/validation/central_pressure_probe.tscn
## Throwaway probe, like feud_probe / evidence_probe.

var _alert_starts := 0
var _alert_ends := 0
var _cool_fire_tick := -1  # tick_index when the cooler district's sweep landed

func _ready() -> void:
	WorldSeed.build()
	TimeService.set_speed(BM.Speed.PAUSED)
	EconomyService.central_alert_started.connect(func(_p): _alert_starts += 1)
	EconomyService.central_alert_ended.connect(func(_p): _alert_ends += 1)
	EconomyService.inspection_started.connect(func(d):
		if d.id == &"glass_wharf" and _cool_fire_tick < 0:
			_cool_fire_tick = TimeService.tick_index)
	await get_tree().process_frame  # JobDirector wires its triggers deferred
	print("--- P06c central pressure ---")

	# Glass Wharf is the COOLER district: rackets paused, combined parked between the
	# eased (0.30) and normal (0.45) inspection thresholds — unaided it never sweeps.
	var cool := GameState.get_district(&"glass_wharf")
	for v in cool.venues:
		if v.type == BM.VenueType.RACKET and v.owner_faction == GameState.player_faction_id:
			EconomyService.set_racket_paused(v, true)
	cool.local_heat = 0.38

	# Three more districts run HOT — the "several districts at once" the Compact answers.
	for i in 3:
		var d := DistrictData.new()
		d.id = StringName("central_probe_%d" % i)
		d.display_name = "Probe District %d" % i
		d.local_heat = 0.85
		GameState.districts.append(d)
	var city := PressureMath.city_pressure(GameState.districts)
	print("city runs hot: %d districts, city_pressure %.3f (floor %.2f)" %
		[GameState.districts.size(), city, PressureMath.CENTRAL_RISE_FLOOR])

	# 1) central_pressure rises toward the city signal and crosses the bar.
	var ticks_to_alert := 0
	while _alert_starts == 0 and ticks_to_alert < 40:
		TimeService._do_tick()
		ticks_to_alert += 1
	print("central climbs: %.3f after %d tick(s) -> alert fired: %d (bar %.2f)" %
		[GameState.central_pressure, ticks_to_alert, _alert_starts,
		PressureMath.CENTRAL_ALERT_THRESHOLD])
	var verdict_climbs := _alert_starts == 1 \
		and GameState.central_pressure >= PressureMath.CENTRAL_ALERT_THRESHOLD
	var verdict_telegraph := _cool_fire_tick < 0  # the cool district NEVER swept pre-alert

	# 2) The bite: under the alert, the cooler district crosses the EASED threshold —
	# a sweep it would not have faced unaided (combined < the normal threshold).
	var combined := EvidenceMath.combined_pressure(cool.local_heat, cool.evidence_cases)
	var unaided_immune := combined < EconomyService.HEAT_INSPECTION_THRESHOLD
	for i in 3:
		TimeService._do_tick()
	var verdict_bite := _cool_fire_tick >= 0 and unaided_immune \
		and combined >= EconomyService.HEAT_INSPECTION_THRESHOLD \
			- PressureMath.CENTRAL_ALERT_INSPECTION_RELIEF
	print("the bite: cooler district combined %.3f (< %.2f unaided bar) swept under the alert: %s" %
		[combined, EconomyService.HEAT_INSPECTION_THRESHOLD,
		"YES" if _cool_fire_tick >= 0 else "NO"])

	# 3) The whole city cools -> central decays below re-arm -> the alert lifts, re-arms.
	for d in GameState.districts:
		d.local_heat = 0.0
	for i in 80:
		TimeService._do_tick()
	print("city cooled: central %.3f (re-arm %.2f), alert ended: %d, re-armed: %s, total fires: %d" %
		[GameState.central_pressure, PressureMath.CENTRAL_ALERT_REARM, _alert_ends,
		"YES" if not GameState.central_alert else "NO", _alert_starts])
	var verdict_lifts := _alert_ends == 1 and not GameState.central_alert \
		and GameState.central_pressure < PressureMath.CENTRAL_ALERT_REARM \
		and _alert_starts == 1

	var ok := verdict_climbs and verdict_telegraph and verdict_bite and verdict_lifts
	print("--- verdict: %s ---" %
		("CENTRAL PRESSURE CLOSES (climbs->alerts->tightens the map->decays->re-arms)" if ok else "BROKEN"))
	get_tree().quit(0 if ok else 1)
