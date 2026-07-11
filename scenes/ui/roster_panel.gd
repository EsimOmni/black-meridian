extends CanvasLayer
class_name RosterPanel
## P14b-lite — the principals roster (brief §9.3, trimmed to 2D portraits by the ship-first
## decision 2026-07-12: no 3D models, no animation). Toggled with R. Read-only: portraits +
## the P10 motive network + relationship edges + the open betrayal tell, all read straight
## off GameState CharacterData. The panel decides nothing and owns no state (brief §13.2).

const UI_THEME := preload("res://assets/ui/theme.tres")
const PORTRAIT_DIR := "res://assets/characters/portraits/"
const PORTRAIT_SIZE := Vector2(170, 226)

var _root: PanelContainer
var _cards: HBoxContainer

func _ready() -> void:
	layer = 3  # above the HUD, below nothing that matters
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

	var vb := VBoxContainer.new()
	_root.add_child(vb)
	var title := Label.new()
	title.text = "ROSTER — Principals"
	title.theme_type_variation = &"TitleLabel"
	vb.add_child(title)
	var hint := Label.new()
	hint.theme_type_variation = &"HintLabel"
	hint.text = "R close · motives are what you can SEE — the hidden ones you infer, or force out in a sit-down"
	vb.add_child(hint)
	vb.add_child(HSeparator.new())
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 14)
	vb.add_child(_cards)

	# Live refresh only while open — the roster is a report, not a system.
	TimeService.strategic_tick.connect(func(_t): if _root.visible: _rebuild())
	GameState.factions_changed.connect(func(): if _root.visible: _rebuild())

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return  # the transition hides this layer during a reveal — R belongs to the cinematic there
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	_root.visible = not _root.visible
	if _root.visible:
		_rebuild()

func _rebuild() -> void:
	for c in _cards.get_children():
		c.queue_free()
	for character in GameState.characters:
		_cards.add_child(_make_card(character))

func _make_card(c: CharacterData) -> PanelContainer:
	var card := PanelContainer.new()
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(PORTRAIT_SIZE.x + 12, 0)
	card.add_child(vb)

	vb.add_child(_make_portrait(c))

	var name_l := Label.new()
	name_l.text = c.display_name + ("  (you)" if c.is_player else "")
	name_l.theme_type_variation = &"TitleLabel"
	vb.add_child(name_l)

	var role_l := Label.new()
	role_l.text = c.role
	role_l.theme_type_variation = &"HintLabel"
	role_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role_l.custom_minimum_size = Vector2(PORTRAIT_SIZE.x, 0)
	vb.add_child(role_l)

	var faction := GameState.get_faction(c.faction_id)
	var faction_l := Label.new()
	faction_l.text = faction.display_name if faction else "Unaligned"
	faction_l.theme_type_variation = &"HintLabel"
	if faction:
		faction_l.modulate = faction.accent_color
	vb.add_child(faction_l)

	vb.add_child(HSeparator.new())

	# The PUBLIC motive network (brief §7.6) — the player reads these; the hidden ones
	# (rival leverage, survival pressure) never render here. That asymmetry IS the design.
	if not c.is_player:
		_motive_row(vb, "Trust", c.public_trust, Palette.TEXT)
		_motive_row(vb, "Ambition", c.ambition, Palette.SODIUM_AMBER)
		_motive_row(vb, "Fear", c.fear, Palette.RIVAL_ACCENT)
		_motive_row(vb, "Grievance", c.grievance, Palette.DANGER)
		_motive_row(vb, "Shared success", c.shared_success, Palette.LEDGER_AMBER)
	else:
		var you := Label.new()
		you.text = "The Resolver decides which problem\nbecomes somebody else's war."
		you.theme_type_variation = &"HintLabel"
		vb.add_child(you)

	# Relationship edges (target id -> affinity −1..1), named against the live roster.
	if not c.relationships.is_empty():
		vb.add_child(HSeparator.new())
		for target_id in c.relationships:
			var other := GameState.get_character(target_id)
			var edge := Label.new()
			var aff: float = c.relationships[target_id]
			edge.text = "%s %s %+.1f" % ["◆" if aff >= 0.0 else "◇",
				other.display_name if other else String(target_id), aff]
			edge.theme_type_variation = &"HintLabel"
			edge.modulate = Palette.TEXT if aff >= 0.0 else Palette.BETRAYAL_CRIMSON
			vb.add_child(edge)

	# The open betrayal tell (P10) — same read the HUD shows, in roster context.
	if c.betrayal_ticks_until_land >= 0:
		var warn := Label.new()
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.custom_minimum_size = Vector2(PORTRAIT_SIZE.x, 0)
		warn.modulate = Palette.BETRAYAL_CRIMSON
		if c.motive_revealed and c.betrayal_driving_motive != &"":
			warn.text = "⚠ reads wrong — driven by %s" % String(c.betrayal_driving_motive).capitalize()
		else:
			warn.text = "⚠ reads wrong — motive unknown"
		vb.add_child(warn)

	return card

## Portrait if the asset exists, else a themed placeholder monogram — every portrait is a
## swappable placeholder in the ship-first push; the screen must not care which it gets.
func _make_portrait(c: CharacterData) -> Control:
	var path := PORTRAIT_DIR + String(c.id) + ".png"
	if ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.custom_minimum_size = PORTRAIT_SIZE
		return tr
	var ph := PanelContainer.new()
	ph.custom_minimum_size = PORTRAIT_SIZE
	var mono := Label.new()
	mono.text = _initials(c.display_name)
	mono.theme_type_variation = &"TitleLabel"
	mono.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mono.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ph.add_child(mono)
	return ph

func _motive_row(parent: Node, label: String, value: float, tint: Color) -> void:
	var l := Label.new()
	var filled := int(round(clampf(value, 0.0, 1.0) * 5.0))
	l.text = "%-14s %s%s" % [label, "▰".repeat(filled), "▱".repeat(5 - filled)]
	l.modulate = tint
	parent.add_child(l)

func _initials(name: String) -> String:
	var parts := name.split(" ", false)
	var s := ""
	for p in parts:
		s += p.substr(0, 1).to_upper()
	return s
