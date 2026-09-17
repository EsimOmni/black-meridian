extends CanvasLayer
class_name OnboardingNudges
## P20 — the onboarding nudge chain, on top of the P04 first-decision pause. One-line
## contextual toasts the FIRST time each core pressure system bites, so a new player
## learns the loop from the game, not a manual. Presentation only; per-session latches
## (a returning player has a settings file and a save — the toasts stay quiet value).

const UI_THEME := preload("res://assets/ui/theme.tres")
const SHOW_SECONDS := 9.0

const NUDGES := {
	&"overflow": "UNLAUNDERED OVERFLOW — dirty income above your laundering cap heats the district. Select a front and Pressure it, or Pause a racket.",
	&"inspection": "INSPECTION — the district's heat drew the inspectors; racket yields are disrupted until it cools. Quiet answers and paused rackets cool it.",
	&"rival": "THE CORVINE ARE MOVING — a rival intent is telegraphed before it lands. The warning window is your time to prepare or absorb.",
	&"betrayal": "SOMEONE READS WRONG — a lieutenant is telegraphing betrayal. Address the grievance (Reassure), or walk the floor and confront them.",
	&"ending_hint": "THE TABLE IS SET — how you handle the Corvine sit-down decides how this night ends.",
}

var _label: Label
var _timer: Timer
var _shown := {}

func _ready() -> void:
	layer = 2
	var panel := PanelContainer.new()
	panel.theme = UI_THEME
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -320
	panel.offset_right = 320
	panel.offset_top = -84
	panel.offset_bottom = -24
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.modulate = Palette.LEDGER_AMBER
	panel.add_child(_label)
	panel.visible = false
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(func(): panel.visible = false)
	add_child(_timer)
	_panel = panel

	EconomyService.economy_settled.connect(_on_settled)
	EconomyService.inspection_started.connect(func(_d): _show(&"inspection"))
	RivalDirector.rival_intent_telegraphed.connect(func(_f, _v, _a): _show(&"rival"))
	_connect_scene_nodes.call_deferred()

var _panel: PanelContainer

func _connect_scene_nodes() -> void:
	var rs := get_tree().root.find_child("RelationshipService", true, false)
	if rs:
		rs.betrayal_telegraphed.connect(func(_c): _show(&"betrayal"))
	var nd := get_tree().root.find_child("NarrativeDirector", true, false)
	if nd:
		nd.beat_fired.connect(func(beat, _job):
			if beat == &"beat_accord": _show(&"ending_hint"))

func _on_settled(faction_id: StringName, _dirty: int, _clean: int, _exposure: float) -> void:
	if faction_id != GameState.player_faction_id:
		return
	var info: Dictionary = EconomyService.settle_info(faction_id)
	if int(info.get("overflow", 0)) > 0:
		_show(&"overflow")

func _show(kind: StringName) -> void:
	if _shown.has(kind):
		return
	_shown[kind] = true
	_label.text = NUDGES[kind]
	_panel.visible = true
	_timer.start(SHOW_SECONDS)
