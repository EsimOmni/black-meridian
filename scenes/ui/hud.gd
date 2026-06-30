extends CanvasLayer
## Minimal management HUD for the Month-1 greybox loop. Shows the player faction's
## dirty/clean cash, district heat, speed, and the selected venue. Built entirely in
## code so the slice runs without hand-authored UI scenes (real UI theme comes in Month 5).

var _dirty_label: Label
var _clean_label: Label
var _heat_label: Label
var _speed_label: Label
var _cycle_label: Label
var _selection_label: RichTextLabel
var _hint_label: Label

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

	var sep := HSeparator.new()
	vb.add_child(sep)

	_selection_label = RichTextLabel.new()
	_selection_label.bbcode_enabled = true
	_selection_label.fit_content = true
	_selection_label.custom_minimum_size = Vector2(300, 80)
	_selection_label.text = "[i]Select a venue.[/i]"
	vb.add_child(_selection_label)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.modulate = Color(0.7, 0.74, 0.8)
	_hint_label.text = "SPACE pause/resume   X cycle speed   WASD pan   wheel zoom   click venue"
	vb.add_child(_hint_label)

	# Live updates.
	TimeService.speed_changed.connect(func(_s): _refresh())
	TimeService.strategic_tick.connect(func(_t): _refresh())
	EconomyService.economy_settled.connect(func(_f, _d, _c, _e): _refresh())
	_refresh()

func _row(parent: Node) -> Label:
	var l := Label.new()
	parent.add_child(l)
	return l

func show_selection(venue: VenueData) -> void:
	var faction := GameState.get_faction(venue.owner_faction)
	var owner_name := faction.display_name if faction else "Unclaimed"
	var type_name := "Racket" if venue.type == BM.VenueType.RACKET else "Front"
	var lines := "[b]%s[/b]\n%s · %s\nControl: %s" % [
		venue.display_name, type_name, owner_name, _control_name(venue.control_state)]
	if venue.type == BM.VenueType.RACKET:
		lines += "\nBase yield: %d · Staff: %d" % [venue.base_yield, venue.operational_staff]
	else:
		lines += "\nLaundering cap: %d" % venue.laundering_capacity
	_selection_label.text = lines

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
