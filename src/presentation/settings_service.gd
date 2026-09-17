extends Node
## SettingsService (autoload, P20) — player-facing configuration: rebindable core verbs,
## text size, performance tier, audio mix. PRESENTATION/CONFIG ONLY — nothing here is
## simulation state; it persists to user://settings.cfg, never into saves. Input actions
## are registered at RUNTIME (InputMap.add_action) so project.godot is never touched —
## an open editor clobbers external project.godot edits (tasks/lessons.md).

const CONFIG_PATH := "user://settings.cfg"
## var, not const: the 4.7 parser rejects property writes through a const reference,
## and text scaling mutates this shared theme instance at runtime.
var _theme: Theme = preload("res://assets/ui/theme.tres")

## The rebindable management verbs and their defaults. Cinematic-scene keys (E/R/Q)
## stay fixed — they are scene-local prompts, not campaign verbs (ship-first trim).
const ACTIONS := {
	&"bm_pause": KEY_SPACE,
	&"bm_speed": KEY_X,
	&"bm_camera": KEY_C,
	&"bm_roster": KEY_R,
	&"bm_save": KEY_F9,
	&"bm_load": KEY_L,
	&"bm_settings": KEY_ESCAPE,
}
const ACTION_LABELS := {
	&"bm_pause": "Pause / resume", &"bm_speed": "Cycle speed", &"bm_camera": "Skyline camera",
	&"bm_roster": "Roster", &"bm_save": "Quick-save", &"bm_load": "Quick-load",
	&"bm_settings": "Settings",
}

## Theme font sizes at scale 1.0 — from tools/build_theme.gd (the theme generator).
const BASE_FONT_SIZES := {
	"default": 13, "TitleLabel": 16, "BodyLabel": 12, "HintLabel": 11, "TooltipLabel": 12}
const TEXT_SCALES := {&"small": 0.85, &"normal": 1.0, &"large": 1.25}

var text_scale: StringName = &"normal"
var perf_tier: StringName = &"full"      ## &"full" | &"lite"
var volumes := {&"Master": 1.0, &"Ambience": 0.8, &"SFX": 0.8}  ## linear 0..1

func _ready() -> void:
	_register_actions()
	_ensure_audio_buses()
	load_settings()
	apply_all()

# --- Input ---------------------------------------------------------------------

func _register_actions() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		_bind_key(action, ACTIONS[action])

func _bind_key(action: StringName, keycode: Key) -> void:
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action, ev)

func bound_key(action: StringName) -> Key:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return (ev as InputEventKey).keycode
	return KEY_NONE

## Rebind a verb. Refuses keys already bound to another verb (silent conflicts are
## worse than a refused click). Returns false on conflict.
func rebind(action: StringName, keycode: Key) -> bool:
	for other in ACTIONS:
		if other != action and bound_key(other) == keycode:
			return false
	_bind_key(action, keycode)
	save_settings()
	return true

# --- Text size -------------------------------------------------------------------

func set_text_scale(scale: StringName) -> void:
	if not TEXT_SCALES.has(scale):
		return
	text_scale = scale
	_apply_text_scale()
	save_settings()

func _apply_text_scale() -> void:
	var f: float = TEXT_SCALES[text_scale]
	_theme.default_font_size = int(round(BASE_FONT_SIZES["default"] * f))
	for variation in ["TitleLabel", "BodyLabel", "HintLabel", "TooltipLabel"]:
		_theme.set_font_size("font_size", variation, int(round(BASE_FONT_SIZES[variation] * f)))
	_theme.set_font_size("normal_font_size", "RichTextLabel", int(round(13 * f)))

# --- Performance tier -------------------------------------------------------------

## full = everything on. lite = the costly presentation extras off: SSR, key-light
## shadows, and the P13 VFX layers (nodes self-register into the groups below).
func set_perf_tier(tier: StringName) -> void:
	if tier != &"full" and tier != &"lite":
		return
	perf_tier = tier
	apply_perf()
	save_settings()

func apply_perf() -> void:
	var lite := perf_tier == &"lite"
	for node in get_tree().get_nodes_in_group(&"bm_vfx"):
		if node is Node3D:
			(node as Node3D).visible = not lite
	for node in get_tree().get_nodes_in_group(&"bm_env"):
		if node is WorldEnvironment and (node as WorldEnvironment).environment != null:
			(node as WorldEnvironment).environment.ssr_enabled = not lite
	for node in get_tree().get_nodes_in_group(&"bm_key_light"):
		if node is DirectionalLight3D:
			(node as DirectionalLight3D).shadow_enabled = not lite

# --- Audio -------------------------------------------------------------------------

func _ensure_audio_buses() -> void:
	for bus_name in [&"Ambience", &"SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")

func set_volume(bus: StringName, linear: float) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	_apply_volume(bus)
	save_settings()

func _apply_volume(bus: StringName) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	var v: float = volumes[bus]
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(idx, v <= 0.001)

# --- Persistence ---------------------------------------------------------------------

func apply_all() -> void:
	_apply_text_scale()
	apply_perf()
	for bus in volumes:
		_apply_volume(bus)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for action in ACTIONS:
		cfg.set_value("keys", String(action), bound_key(action))
	cfg.set_value("ui", "text_scale", String(text_scale))
	cfg.set_value("video", "perf_tier", String(perf_tier))
	for bus in volumes:
		cfg.set_value("audio", String(bus), volumes[bus])
	cfg.save(CONFIG_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return  # first run — defaults stand
	for action in ACTIONS:
		var key: int = cfg.get_value("keys", String(action), ACTIONS[action])
		_bind_key(action, key as Key)
	text_scale = StringName(cfg.get_value("ui", "text_scale", "normal"))
	perf_tier = StringName(cfg.get_value("video", "perf_tier", "full"))
	for bus in volumes.keys():
		volumes[bus] = cfg.get_value("audio", String(bus), volumes[bus])
