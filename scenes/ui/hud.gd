extends CanvasLayer
## Minimal management HUD for the Month-1 greybox loop. Shows the player faction's
## dirty/clean cash, district heat, speed, and the selected venue. Built entirely in
## code so the slice runs without hand-authored UI scenes. First-pass theme is Month 2
## (P11, assets/ui/theme.tres — generated from Palette); final UI polish is P19.

const UI_THEME := preload("res://assets/ui/theme.tres")

var _dirty_label: Label
var _clean_label: Label
var _heat_label: Label
var _speed_label: Label
var _cycle_label: Label
var _income_label: Label
var _launder_label: Label
var _overflow_label: Label
var _inspection_label: Label
var _rival_label: Label
var _reckoning_label: Label
var _venue_stats: RichTextLabel

## The bootstrap-wired phase machine (P09) — read for the phase clock + Reckoning summary.
var night_cycle_node: NightCycle
## The bootstrap-wired loyalty machine (P10) — the reassure verb routes through it.
var relationship_node: RelationshipService
## The bootstrap-wired reveal round-trip (P17b) — the Confront affordance routes through it.
var transition_node: CinematicTransition
var _betrayal_label: Label
var _reassure_btn: Button
var _confront_btn: Button
var _confront_target: StringName = &""
## P17c: the crime-scene affordance — armed by bootstrap when a rival sabotage/frame
## lands on player ground with an open case; shown while that district still has one.
var _walk_scene_btn: Button
var _walk_scene_district: StringName = &""
var _venue_actions: VBoxContainer
var _hint_label: Label

var _selected: VenueData
var _pause_btn: Button
var _pressure_btn: Button
var _assign_btn: Button
var _recall_btn: Button

func _ready() -> void:
	var panel := PanelContainer.new()
	panel.theme = UI_THEME  # theme inheritance: every child widget styles from here
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
	title.theme_type_variation = &"TitleLabel"
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
	_overflow_label.modulate = Palette.DANGER  # overflow reads as danger
	_inspection_label = _row(vb)
	_inspection_label.modulate = Palette.DANGER
	_inspection_label.visible = false
	_rival_label = _row(vb)
	_rival_label.modulate = Palette.RIVAL_ACCENT  # rival intent reads petrol (Corvine accent)
	_rival_label.visible = false
	# The Reckoning framing beat (P09): what this cycle settled — shown only in RECKONING.
	_reckoning_label = _row(vb)
	_reckoning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reckoning_label.custom_minimum_size = Vector2(300, 0)
	_reckoning_label.modulate = Palette.LEDGER_AMBER
	_reckoning_label.visible = false
	# The betrayal tells (P10, brief §7.6): visible only while an intent is open —
	# the window in which the crisis is still preventable.
	_betrayal_label = _row(vb)
	_betrayal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_betrayal_label.custom_minimum_size = Vector2(300, 0)
	_betrayal_label.modulate = Palette.BETRAYAL_CRIMSON
	_betrayal_label.visible = false
	_reassure_btn = Button.new()
	_reassure_btn.visible = false
	_reassure_btn.pressed.connect(_on_reassure_pressed)
	vb.add_child(_reassure_btn)
	# P17b: walk into the confrontation instead of resolving it from the ledger.
	_confront_btn = Button.new()
	_confront_btn.visible = false
	_confront_btn.pressed.connect(_on_confront_pressed)
	vb.add_child(_confront_btn)
	# P17c: walk into the crime-scene the rival left on your ground.
	_walk_scene_btn = Button.new()
	_walk_scene_btn.visible = false
	_walk_scene_btn.pressed.connect(_on_walk_scene_pressed)
	vb.add_child(_walk_scene_btn)

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
	_hint_label.theme_type_variation = &"HintLabel"
	_hint_label.text = "SPACE pause/resume   X cycle speed   WASD pan   wheel zoom   click venue   R roster   F9 save   L load"
	vb.add_child(_hint_label)

	# Live updates.
	TimeService.speed_changed.connect(func(_s): _refresh())
	TimeService.strategic_tick.connect(func(_t): _refresh())
	EconomyService.economy_settled.connect(func(_f, _d, _c, _e): _refresh())
	JobDirector.job_resolved.connect(func(_j): _refresh())  # outcome shows even while paused
	EconomyService.inspection_started.connect(func(_d): _refresh())
	EconomyService.inspection_ended.connect(func(_d): _refresh())
	RivalDirector.rival_intent_telegraphed.connect(func(_f, _v, _a): _refresh())
	RivalDirector.rival_action_landed.connect(func(_f, _v, _a): _refresh())
	GameState.districts_changed.connect(_refresh)  # save/load rebuilds state while paused
	GameState.factions_changed.connect(_refresh)
	GameState.night_cycle_advanced.connect(func(_c, _p): _refresh())
	if relationship_node:
		relationship_node.betrayal_telegraphed.connect(func(_c): _refresh())
		relationship_node.betrayal_defused.connect(func(_c): _refresh())
		relationship_node.betrayal_committed.connect(func(_c, _v, _r): _refresh())
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
	_assign_btn = null
	_recall_btn = null
	if _selected == null or _selected.owner_faction != GameState.player_faction_id:
		return
	if _selected.type == BM.VenueType.RACKET:
		_pause_btn = Button.new()
		_pause_btn.pressed.connect(func():
			EconomyService.set_racket_paused(_selected, not _selected.paused)
			_refresh())
		_venue_actions.add_child(_pause_btn)
		# P05b greybox staffing lever — routes through the service verb (clamped,
		# ownership-gated); the HUD never pokes operational_staff directly.
		_assign_btn = Button.new()
		_assign_btn.pressed.connect(func():
			EconomyService.assign_operatives(_selected, GameState.player_faction(), 1)
			_refresh())
		_venue_actions.add_child(_assign_btn)
		_recall_btn = Button.new()
		_recall_btn.pressed.connect(func():
			EconomyService.recall_operatives(_selected, GameState.player_faction(), 1)
			_refresh())
		_venue_actions.add_child(_recall_btn)
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
		_refresh_inspection(d)
	_cycle_label.text = "Night Cycle %d  ·  %s (%s / %s)" % [
		GameState.night_cycle, NightCycle.phase_name(GameState.phase),
		_mmss(GameState.phase_ticks), _mmss(NightCycle.phase_budget(GameState.phase))]
	_speed_label.text = "Speed:  %s" % _speed_name(TimeService.speed)
	_refresh_reckoning()
	_refresh_betrayal()
	_refresh_crime_scene()
	_refresh_rival_intent()
	_refresh_squeeze()
	_refresh_venue()

## The Reckoning summary (P09): frames what the per-tick systems already settled this
## cycle — no new math, the HUD only reads the phase machine's tally (brief §5.2).
func _refresh_reckoning() -> void:
	if GameState.phase != BM.Phase.RECKONING or night_cycle_node == null:
		_reckoning_label.visible = false
		return
	var s: Dictionary = night_cycle_node.summary()
	_reckoning_label.visible = true
	_reckoning_label.text = "RECKONING — the cycle settles: %+d dirty · %+d clean · heat %+d%%. Council convenes next." % [
		s["dirty_earned"], s["clean_earned"], int(round(s["heat_delta"] * 100.0))]

## A phase clock readout: 1 strategic tick = 1s at NORMAL speed.
func _mmss(ticks: int) -> String:
	return "%d:%02d" % [int(ticks / 60.0), ticks % 60]

## The betrayal tells (P10, brief §7.6): while an intent is open the lieutenant reads
## wrong — and the player has one concrete lever to pull. The HUD only reads the
## intent state off CharacterData; the defusal decision stays in RelationshipService.
func _refresh_betrayal() -> void:
	# P10b: multiple intents can be open at once — one tell line per lieutenant. While
	# the driving motive is hidden the player knows SOMETHING is wrong, not why; the
	# reassure sit-down reveals it. The button targets the first open intent (greybox).
	var lines: PackedStringArray = []
	for c in GameState.characters:
		if c.betrayal_ticks_until_land < 0:
			continue
		var line := "⚠ %s: delayed responses · a missed check-in · a private meeting off the books" % c.display_name
		if c.motive_revealed and c.betrayal_driving_motive != &"":
			line += "\n   driven by: %s" % String(c.betrayal_driving_motive).capitalize()
		else:
			line += "\n   motive unknown — sit down with them to learn why"
		lines.append(line)
	if lines.is_empty():
		_betrayal_label.visible = false
		_reassure_btn.visible = false
		_confront_btn.visible = false
		_confront_target = &""
		return
	_betrayal_label.visible = true
	_betrayal_label.text = "\n".join(lines)
	var pf := GameState.player_faction()
	_reassure_btn.visible = true
	_reassure_btn.disabled = pf == null or pf.clean_capital < LoyaltyScoring.REASSURE_COST_CLEAN
	_reassure_btn.text = "Address the grievance (+trust, -%d clean)" % LoyaltyScoring.REASSURE_COST_CLEAN
	# P17b: confront the first open intent in person (greybox — same targeting rule
	# as the reassure button). The HUD only names the character; the round-trip and
	# every consequence live in CinematicTransition/RelationshipService.
	for c in GameState.characters:
		if c.betrayal_ticks_until_land >= 0:
			_confront_target = c.id
			_confront_btn.visible = transition_node != null
			_confront_btn.text = "Confront %s (walk the floor)" % c.display_name
			break

func _on_confront_pressed() -> void:
	if transition_node != null and _confront_target != &"":
		transition_node.enter(_confront_target)

## P17c: bootstrap arms the affordance when the trigger lands (sabotage/frame on a
## player-owned venue with an open case). The HUD only holds the district ID.
func offer_crime_scene(district_id: StringName) -> void:
	_walk_scene_district = district_id
	_refresh_crime_scene()

## Shown while the armed district still has an open case — labelled with its STRONGEST
## case (the one the scene is built around). The HUD reads state; it decides nothing.
func _refresh_crime_scene() -> void:
	if _walk_scene_btn == null:
		return
	if _walk_scene_district == &"":
		_walk_scene_btn.visible = false
		return
	var d := GameState.get_district(_walk_scene_district)
	var strongest := EvidenceMath.strongest_case(d) if d != null else null
	if strongest == null:
		_walk_scene_btn.visible = false
		_walk_scene_district = &""  # case burned or removed — the offer lapses
		return
	_walk_scene_btn.visible = transition_node != null
	_walk_scene_btn.text = "Walk the scene — %s" % strongest.label

func _on_walk_scene_pressed() -> void:
	if transition_node != null and _walk_scene_district != &"":
		transition_node.enter_crime_scene(_walk_scene_district)

func _on_reassure_pressed() -> void:
	for c in GameState.characters:
		if c.betrayal_ticks_until_land >= 0:
			if relationship_node:
				relationship_node.reassure(c)
			_refresh()
			return

## The rival telegraph (brief §7.6): a committed move is visible before it lands.
func _refresh_rival_intent() -> void:
	for faction in GameState.factions:
		if faction.is_player or faction.intent_action < 0:
			continue
		var target := "?"
		for district in GameState.districts:
			for venue in district.venues:
				if venue.id == faction.intent_venue_id:
					target = venue.display_name
		if target == "?":  # P07b RECRUIT: the intent target is a character, not a venue
			var character := GameState.get_character(faction.intent_venue_id)
			if character != null:
				target = character.display_name
		_rival_label.visible = true
		_rival_label.text = "⚠ %s is moving on %s" % [faction.display_name, target]
		return
	_rival_label.visible = false

## The inspection beat is telegraphed before it fires (brief §7.6 — never a surprise).
func _refresh_inspection(d: DistrictData) -> void:
	if d.inspection_ticks > 0:
		_inspection_label.visible = true
		_inspection_label.text = "%s: INSPECTION — yields disrupted (%d ticks)" % [
			d.display_name.to_upper(), d.inspection_ticks]
	elif d.local_heat >= EconomyService.HEAT_INSPECTION_WARN and d.inspection_armed:
		_inspection_label.visible = true
		_inspection_label.text = "⚠ %s: inspection imminent — reduce heat" % d.display_name
	else:
		_inspection_label.visible = false

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
		if _selected.owner_faction == GameState.player_faction_id:
			lines += "  (free pool: %d)" % EconomyService.free_operatives(GameState.player_faction())
		if _selected.disruption > 0.0:
			lines += "\n[color=#%s]Disrupted: -%d%% income (heat)[/color]" % [
				Palette.SODIUM_AMBER.to_html(false), int(_selected.disruption * 100.0)]
		if _selected.paused:
			lines += "\n[color=#%s]PAUSED — earning nothing, creating no exposure[/color]" % \
				Palette.SODIUM_AMBER.to_html(false)
	elif _selected.type == BM.VenueType.FRONT:
		lines += "\nLaundering cap: %d/%d · Efficiency: %d%% · Op cost: %d%%\nClean output: %d/tick" % [
			_selected.laundering_capacity, EconomyService.FRONT_CAPACITY_MAX,
			int(_selected.front_efficiency * 100.0), int(_selected.operating_cost * 100.0),
			EconomyMath.compute_front_clean(_selected)]
	_venue_stats.text = lines

	if _pause_btn:
		_pause_btn.text = "Resume racket" if _selected.paused else "Pause racket (stop income + exposure)"
	if _assign_btn:
		var free := EconomyService.free_operatives(GameState.player_faction())
		_assign_btn.disabled = free <= 0
		_assign_btn.text = "Assign operative (+1 staff · %d free)" % free
	if _recall_btn:
		_recall_btn.disabled = _selected.operational_staff <= 0
		_recall_btn.text = "Recall operative (-1 staff)"
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
