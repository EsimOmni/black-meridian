extends SceneTree
## Regenerates the shared first-pass UI theme (assets/ui/theme.tres) from Palette —
## the palette module is the single source of truth; never hand-edit the .tres.
## Run headless:  Godot --headless --path . -s tools/build_theme.gd

const OUT := "res://assets/ui/theme.tres"

func _init() -> void:
	var theme := Theme.new()
	theme.default_font_size = 13

	# Panels: charcoal fill, subtle petrol border.
	theme.set_stylebox("panel", "PanelContainer", _panel_box())

	# Labels — named sizes as theme type variations (replaces per-widget overrides).
	theme.set_color("font_color", "Label", Palette.TEXT)
	theme.set_type_variation(&"TitleLabel", &"Label")
	theme.set_font_size("font_size", &"TitleLabel", 16)
	theme.set_color("font_color", &"TitleLabel", Palette.TEXT_BRIGHT)
	theme.set_type_variation(&"BodyLabel", &"Label")
	theme.set_font_size("font_size", &"BodyLabel", 12)
	theme.set_type_variation(&"HintLabel", &"Label")
	theme.set_font_size("font_size", &"HintLabel", 11)
	theme.set_color("font_color", &"HintLabel", Palette.TEXT_MUTED)

	theme.set_color("default_color", "RichTextLabel", Palette.TEXT)
	theme.set_font_size("normal_font_size", "RichTextLabel", 13)

	# Buttons: raised charcoal, petrol on hover, sodium amber when pressed.
	theme.set_stylebox("normal", "Button", _button_box(Palette.CHARCOAL_RAISED, Palette.OXIDIZED, 0.5))
	theme.set_stylebox("hover", "Button", _button_box(Palette.CHARCOAL_RAISED.lightened(0.06), Palette.PETROL, 1.0))
	theme.set_stylebox("pressed", "Button", _button_box(Palette.CHARCOAL, Palette.SODIUM_AMBER, 0.9))
	theme.set_stylebox("disabled", "Button", _button_box(Palette.CHARCOAL, Palette.OXIDIZED, 0.25))
	var focus := _button_box(Color.TRANSPARENT, Palette.SODIUM_AMBER, 0.6)
	focus.draw_center = false
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", Palette.TEXT)
	theme.set_color("font_hover_color", "Button", Palette.TEXT_BRIGHT)
	theme.set_color("font_pressed_color", "Button", Palette.SODIUM_AMBER)
	theme.set_color("font_disabled_color", "Button", Palette.TEXT_MUTED)

	# Separators + tooltips stay in the same family.
	var sep := StyleBoxLine.new()
	sep.color = Color(Palette.OXIDIZED, 0.55)
	theme.set_stylebox("separator", "HSeparator", sep)
	theme.set_stylebox("panel", "TooltipPanel", _panel_box())
	theme.set_color("font_color", "TooltipLabel", Palette.TEXT)
	theme.set_font_size("font_size", "TooltipLabel", 12)

	var err := ResourceSaver.save(theme, OUT)
	if err != OK:
		printerr("theme save failed: error %d" % err)
		quit(1)
		return
	print("theme written: ", OUT)
	quit(0)

func _panel_box() -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(Palette.CHARCOAL, 0.94)
	b.set_border_width_all(1)
	b.border_color = Color(Palette.PETROL, 0.8)
	b.set_corner_radius_all(3)
	b.content_margin_left = 12
	b.content_margin_right = 12
	b.content_margin_top = 10
	b.content_margin_bottom = 10
	return b

func _button_box(bg: Color, border: Color, border_alpha: float) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.set_border_width_all(1)
	b.border_color = Color(border, border_alpha)
	b.set_corner_radius_all(2)
	b.content_margin_left = 8
	b.content_margin_right = 8
	b.content_margin_top = 4
	b.content_margin_bottom = 4
	return b
