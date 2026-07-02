extends CanvasLayer
## Minimal management HUD for the Month-1 greybox loop. Shows the player faction's
## dirty/clean cash, district heat, speed, and the selected venue. Built entirely in
## code so the slice runs without hand-authored UI scenes (real UI theme comes in Month 5).

var _dirty_label: Label
var _clean_label: Label
var _heat_label: Label
var _speed_label: Label
var _cycle_label: Label
var _income_label: Label
var _launder_label: Label
var _overflow_label: Label
var _venue_stats: RichTextLabel
var _venue_actions: VBoxContainer
var _hint_label: Label

var _selected: VenueData
var _pause_btn: Button
var _pressure_btn: Button

func _ready() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.offset_left = 16
	panel.offset_top = 16
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(320, 0)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "OMNI: BLACK MERIDIAN — Glass Wharf"
	title.add_theme_font_size_override("font_size", 16)
	vb.add_child(title)

	_cycle_label = _row(vb)
	_dirty_label = _row(vb)
	_clean_label = _row(vb)
	_heat_label = _row(vb)
	_speed_label = _row(vb)

	# The squeeze (brief §7.2): dirty income vs laundering capacity, read from the
	# EconomyService settle cache — the HUD never recomputes the economy.
	vb.add_child(HSeparator.new())
	_income_label = _row(vb)
	_launder_label = _row(vb)
	_overflow_label = _row(vb)
	_overflow_label.modulate = Color(0.95, 0.45, 0.35)  # overflow reads as danger

	vb.add_child(HSeparator.new())

	_venue_stats = RichTextLabel.new()
	_venue_stats.bbcode_enabled = true
	_venue_stats.fit_content = true
	_venue_stats.custom_minimum_size = Vector2(300, 80)
	_venue_stats.text = "[i]Select a venue.[/i]"
	vb.add_child(_venue_stats)

	_venue_actions = VBoxContainer.new()
	vb.add_child(_venue_actions)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.modulate = Color(0.7, 0.74, 0.8)
	_hint_label.text = "SPACE pause/resume   X cycle speed   WASD pan   wheel zoom   click venue   F9 save   L load"
	vb.add_child(_hint_label)

	# Live updates.
	TimeService.speed_changed.connect(func(_s): _refresh())
	TimeService.strategic_tick.connect(func(_t): _refresh())
	EconomyService.economy_settled.connect(func(_f, _d, _c, _e): _refresh())
	JobDirector.job_resolved.connect(func(_j): _refresh())  # outcome shows even while paused
	GameState.districts_changed.connect(_refresh)  # save/load rebuilds state while paused
	GameState.factions_changed.connect(_refresh)
	_refresh()

func _row(parent: Node) -> Label:
	var l := Label.new()
	parent.add_child(l)
	return l

func show_selection(venue: VenueData) -> void:
	_selected = venue
	_rebuild_venue_actions()
	_refresh()

## Actions are rebuilt only on selection change; _refresh() just updates their state.
func _rebuild_venue_actions() -> void:
	for c in _venue_actions.get_children():
		c.queue_free()
	_pause_btn = null
	_pressure_btn = null
	if _selected == null or _selected.owner_faction != GameState.player_faction_id:
		return
	if _selected.type == BM.VenueType.RACKET:
		_pause_btn = Button.new()
		_pause_btn.pressed.connect(func():
			EconomyService.set_racket_paused(_selected, not _selected.paused)
			_refresh())
		_venue_actions.add_child(_pause_btn)
	elif _selected.type == BM.VenueType.FRONT:
		_pressure_btn = Button.new()
		_pressure_btn.pressed.connect(func():
			EconomyService.pressure_front(_selected, GameState.player_faction())
			_refresh())
		_venue_actions.add_child(_pressure_btn)

func _refresh() -> void:
	var pf := GameState.player_faction()
	if pf:
		_dirty_label.text = "Dirty cash:  %d" % pf.dirty_cash
		_clean_label.text = "Clean capital:  %d" % pf.clean_capital
	var d := GameState.get_district(&"glass_wharf")
	if d:
		_heat_label.text = "Local heat:  %d%%" % int(d.local_heat * 100.0)
	_cycle_label.text = "Night Cycle %d  ·  Tick %d" % [GameState.night_cycle, TimeService.tick_index]
	_speed_label.text = "Speed:  %s" % _speed_name(TimeService.speed)
	_refresh_squeeze()
	_refresh_venue()

func _refresh_squeeze() -> void:
	var info: Dictionary = EconomyService.settle_info(GameState.player_faction_id)
	if info.is_empty():  # no settle yet (game starts paused)
		_income_label.text = "Dirty income:  —"
		_launder_label.text = "Laundering cap:  —"
		_overflow_label.visible = false
		return
	_income_label.text = "Dirty income:  %d/tick" % info["dirty_income"]
	_launder_label.text = "Laundering cap:  %d/tick" % info["laundering_capacity"]
	var overflow: int = info["overflow"]
	_overflow_label.visible = overflow > 0
	if overflow > 0:
		_overflow_label.text = "UNLAUNDERED OVERFLOW: +%d/tick → heat rising" % overflow

func _refresh_venue() -> void:
	if _selected == null:
		return
	var faction := GameState.get_faction(_selected.owner_faction)
	var owner_name := faction.display_name if faction else "Unclaimed"
	var type_name := "Racket" if _selected.type == BM.VenueType.RACKET else "Front"
	var lines := "[b]%s[/b]\n%s · %s\nControl: %s" % [
		_selected.display_name, type_name, owner_name, _control_name(_selected.control_state)]
	if _selected.type == BM.VenueType.RACKET:
		lines += "\nBase yield: %d · Staff: %d" % [_selected.base_yield, _selected.operational_staff]
		if _selected.paused:
			lines += "\n[color=#f2b06a]PAUSED — earning nothing, creating no exposure[/color]"
	elif _selected.type == BM.VenueType.FRONT:
		lines += "\nLaundering cap: %d/%d · Efficiency: %d%% · Op cost: %d%%\nClean output: %d/tick" % [
			_selected.laundering_capacity, EconomyService.FRONT_CAPACITY_MAX,
			int(_selected.front_efficiency * 100.0), int(_selected.operating_cost * 100.0),
			EconomyMath.compute_front_clean(_selected)]
	_venue_stats.text = lines

	if _pause_btn:
		_pause_btn.text = "Resume racket" if _selected.paused else "Pause racket (stop income + exposure)"
	if _pressure_btn:
		var pf := GameState.player_faction()
		if _selected.laundering_capacity >= EconomyService.FRONT_CAPACITY_MAX:
			_pressure_btn.disabled = true
			_pressure_btn.text = "Pressure front — at max capacity"
		elif pf and pf.clean_capital < EconomyService.FRONT_PRESSURE_COST:
			_pressure_btn.disabled = true
			_pressure_btn.text = "Pressure front — need %d clean" % EconomyService.FRONT_PRESSURE_COST
		else:
			_pressure_btn.disabled = false
			_pressure_btn.text = "Pressure front (+%d cap, -%d clean)" % [
				EconomyService.FRONT_PRESSURE_STEP, EconomyService.FRONT_PRESSURE_COST]

func _speed_name(s: int) -> String:
	match s:
		BM.Speed.PAUSED: return "PAUSED"
		BM.Speed.NORMAL: return "▶ 1x"
		BM.Speed.FAST: return "▶▶ 2x"
		BM.Speed.FASTER: return "▶▶▶ 4x"
		_: return "?"

func _control_name(c: int) -> String:
	match c:
		BM.ControlState.UNKNOWN: return "Unknown"
		BM.ControlState.CONTESTED: return "Contested"
		BM.ControlState.INFLUENCED: return "Influenced"
		BM.ControlState.CONTROLLED: return "Controlled"
		BM.ControlState.FORTIFIED: return "Fortified"
		BM.ControlState.COMPROMISED: return "Compromised"
		_: return "?"
