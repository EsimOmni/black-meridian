extends CanvasLayer
class_name SettingsPanel
## P20 — the settings screen (ESC): rebinding, text size, performance tier, audio mix.
## Pure presentation over SettingsService; owns no state and never touches the sim.

const UI_THEME := preload("res://assets/ui/theme.tres")

var _root: PanelContainer
var _capturing: StringName = &""   ## the action awaiting a key press, or &""
var _key_buttons := {}             ## action -> Button
var _hint: Label

func _ready() -> void:
	layer = 5  # topmost management panel
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
	_build()

func _build() -> void:
	for c in _root.get_children():
		c.queue_free()
	_key_buttons.clear()
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(380, 0)
	_root.add_child(vb)

	var title := Label.new()
	title.text = "SETTINGS"
	title.theme_type_variation = &"TitleLabel"
	vb.add_child(title)
	_hint = Label.new()
	_hint.theme_type_variation = &"HintLabel"
	_hint.text = "ESC close"
	vb.add_child(_hint)
	vb.add_child(HSeparator.new())

	_section(vb, "Keybinds")
	for action in SettingsService.ACTIONS:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = SettingsService.ACTION_LABELS[action]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 0)
		b.text = OS.get_keycode_string(SettingsService.bound_key(action))
		b.pressed.connect(_begin_capture.bind(action))
		_key_buttons[action] = b
		row.add_child(b)
		vb.add_child(row)
	vb.add_child(HSeparator.new())

	_section(vb, "Text size")
	var sizes := HBoxContainer.new()
	for scale in SettingsService.TEXT_SCALES:
		var sb := Button.new()
		sb.text = String(scale).capitalize()
		sb.pressed.connect(func(): SettingsService.set_text_scale(scale))
		sizes.add_child(sb)
	vb.add_child(sizes)
	vb.add_child(HSeparator.new())

	_section(vb, "Performance")
	var tiers := HBoxContainer.new()
	for tier in [&"full", &"lite"]:
		var tb := Button.new()
		tb.text = "Full (SSR + shadows + VFX)" if tier == &"full" else "Lite"
		tb.pressed.connect(func(): SettingsService.set_perf_tier(tier))
		tiers.add_child(tb)
	vb.add_child(tiers)
	vb.add_child(HSeparator.new())

	_section(vb, "Audio")
	for bus in SettingsService.volumes:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = String(bus)
		l.custom_minimum_size = Vector2(90, 0)
		row.add_child(l)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = SettingsService.volumes[bus]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(v): SettingsService.set_volume(bus, v))
		row.add_child(slider)
		vb.add_child(row)

func _section(parent: Node, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"TitleLabel"
	parent.add_child(l)

func _begin_capture(action: StringName) -> void:
	_capturing = action
	_key_buttons[action].text = "press a key…"
	_hint.text = "Press the new key for '%s' (ESC cancels)" % SettingsService.ACTION_LABELS[action]

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return  # hidden during cinematics — their keys are their own
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode
	# Capture mode swallows the next key press as the new binding.
	if _capturing != &"":
		if key != KEY_ESCAPE:
			if not SettingsService.rebind(_capturing, key):
				_hint.text = "'%s' is already bound — pick another key" % OS.get_keycode_string(key)
				_key_buttons[_capturing].text = OS.get_keycode_string(SettingsService.bound_key(_capturing))
				_capturing = &""
				get_viewport().set_input_as_handled()
				return
		_key_buttons[_capturing].text = OS.get_keycode_string(SettingsService.bound_key(_capturing))
		_hint.text = "ESC close"
		_capturing = &""
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"bm_settings"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	_root.visible = not _root.visible
	if _root.visible:
		_build()  # re-read current bindings/volumes
