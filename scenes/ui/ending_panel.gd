extends CanvasLayer
class_name EndingPanel
## P19 — the slice epilogue (brief §12.1: one significant ending decision). Shown once
## when the NarrativeDirector reaches an ending; the verdict text is authored per stance,
## the tally is read straight off GameState. Read-only presentation: the panel owns no
## state — the ending id and the "seen" latch live in GameState.narrative_flags, so a
## save made after the epilogue never replays it on load.

const UI_THEME := preload("res://assets/ui/theme.tres")

const EPILOGUES := {
	&"ending_accord": {
		"title": "THE WHARF ACCORD",
		"body": "The lines are drawn in ink instead of blood. The Corvine keep their side of the water; the Compact keeps the wharf — and everyone at the table pretends the peace was always the plan. The rain keeps falling. The ledgers keep filling. For one district, in one city, the night ends quiet.\n\nA quiet night is not a safe one. But it is yours.",
	},
	&"ending_armed_peace": {
		"title": "AN ARMED PEACE",
		"body": "She signed. Everyone at the table knew whose hand held the pen — the last page of a dead inspector's ledger, folded once, resting by your glass. The Corvine will honor the terms for exactly as long as the paper stays dangerous.\n\nPeace bought with leverage is rent, not property. The Resolver knows the difference — and collects either way.",
	},
	&"ending_war": {
		"title": "WAR FOR THE MERIDIAN",
		"body": "The card stayed on the table. By morning the collectors were back on the blocks, and by week's end the wharf had learned to read gunfire like weather. Some wars are cheaper than the peace — that was the wager.\n\nThe city will price it. It always does.",
	},
}

var _root: PanelContainer
var _narrative: NarrativeDirector

func _ready() -> void:
	layer = 4  # above the roster
	_root = PanelContainer.new()
	_root.theme = UI_THEME
	_root.anchors_preset = Control.PRESET_CENTER
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 0.5
	_root.anchor_bottom = 0.5
	_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.visible = false
	add_child(_root)
	# A load can restore a reached-but-unseen ending — surface it again.
	GameState.districts_changed.connect(_maybe_show_from_flags)

func bind(narrative: NarrativeDirector) -> void:
	_narrative = narrative
	_narrative.ending_reached.connect(show_ending)

func _maybe_show_from_flags() -> void:
	var ending: StringName = GameState.narrative_flags.get(&"ending", &"")
	if ending != &"" and not GameState.narrative_flags.get(&"ending_seen", false):
		show_ending(ending)

func show_ending(ending: StringName) -> void:
	var spec: Dictionary = EPILOGUES.get(ending, EPILOGUES[&"ending_war"])
	for c in _root.get_children():
		c.queue_free()
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(520, 0)
	_root.add_child(vb)

	var title := Label.new()
	title.text = spec["title"]
	title.theme_type_variation = &"TitleLabel"
	title.modulate = Palette.LEDGER_AMBER
	vb.add_child(title)
	var sub := Label.new()
	sub.text = "Night Cycle %d — the vertical slice concludes" % GameState.night_cycle
	sub.theme_type_variation = &"HintLabel"
	vb.add_child(sub)
	vb.add_child(HSeparator.new())

	var body := Label.new()
	body.text = spec["body"]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(520, 0)
	vb.add_child(body)
	vb.add_child(HSeparator.new())

	for line in _tally_lines():
		var l := Label.new()
		l.text = line
		l.theme_type_variation = &"HintLabel"
		vb.add_child(l)
	vb.add_child(HSeparator.new())

	var btn := Button.new()
	btn.text = "The city keeps breathing — continue"
	btn.pressed.connect(_dismiss)
	vb.add_child(btn)
	_root.visible = true
	TimeService.set_speed(BM.Speed.PAUSED)  # read the verdict on your own time (brief §5.1)

## The epilogue tally — a read of the world the player actually made.
func _tally_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	var pf := GameState.player_faction()
	var held := GameState.venues_owned_by(GameState.player_faction_id).size()
	var rival_held := 0
	var cases := 0
	for f in GameState.factions:
		if not f.is_player:
			rival_held += GameState.venues_owned_by(f.id).size()
	for d in GameState.districts:
		cases += d.evidence_cases.size()
	out.append("Ground held: %d venues   ·   Corvine hold: %d" % [held, rival_held])
	if pf:
		out.append("Clean capital: %d   ·   Dirty cash: %d" % [pf.clean_capital, pf.dirty_cash])
	out.append("Open evidence cases: %d" % cases)
	var lt := GameState.get_character(&"bengal_lt")
	if lt != null:
		if lt.faction_id != GameState.player_faction_id or lt.recruited_by_faction != &"":
			out.append("The Lieutenant: lost to the Corvine")
		elif lt.public_trust >= 0.6:
			out.append("The Lieutenant: stood by the Compact")
		else:
			out.append("The Lieutenant: stayed — for now")
	return out

func _dismiss() -> void:
	GameState.narrative_flags[&"ending_seen"] = true
	_root.visible = false
