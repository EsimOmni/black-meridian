extends Node
class_name AudioCues
## P20 — the minimal sound layer: a rain-ambience loop, a global UI click, and three
## stingers on the sim's dramatic beats. Presentation only — listens to existing
## signals, never mutates state. All WAVs are generated in-house (assets/audio/,
## zero licensing surface — see assets/ATTRIBUTIONS.md).

const RAIN := "res://assets/audio/rain_loop.wav"
const CLICK := "res://assets/audio/ui_click.wav"
const STINGERS := {
	&"danger": "res://assets/audio/stinger_danger.wav",
	&"betrayal": "res://assets/audio/stinger_betrayal.wav",
	&"ending": "res://assets/audio/stinger_ending.wav",
}

var _rain: AudioStreamPlayer
var _click: AudioStreamPlayer
var _stinger: AudioStreamPlayer

func _ready() -> void:
	_rain = AudioStreamPlayer.new()
	var rain_stream: AudioStreamWAV = load(RAIN)
	if rain_stream != null:
		rain_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		rain_stream.loop_end = rain_stream.data.size() / 2  # 16-bit mono: bytes -> frames
		_rain.stream = rain_stream
	_rain.bus = &"Ambience"
	_rain.volume_db = -6.0
	add_child(_rain)
	_rain.play()

	_click = AudioStreamPlayer.new()
	_click.stream = load(CLICK)
	_click.bus = &"SFX"
	_click.volume_db = -8.0
	add_child(_click)

	_stinger = AudioStreamPlayer.new()
	_stinger.bus = &"SFX"
	add_child(_stinger)

	# Dramatic beats — the same signals the HUD reads.
	EconomyService.inspection_started.connect(func(_d): _play_stinger(&"danger"))
	_connect_scene_nodes.call_deferred()

	# Every button in the tree (now and later) clicks — a global hook, no per-panel wiring.
	get_tree().node_added.connect(_on_node_added)
	_hook_existing(get_tree().root)

func _connect_scene_nodes() -> void:
	var rs := get_tree().root.find_child("RelationshipService", true, false)
	if rs:
		rs.betrayal_telegraphed.connect(func(_c): _play_stinger(&"betrayal"))
	var nd := get_tree().root.find_child("NarrativeDirector", true, false)
	if nd:
		nd.ending_reached.connect(func(_e): _play_stinger(&"ending"))

func _play_stinger(kind: StringName) -> void:
	_stinger.stream = load(STINGERS[kind])
	_stinger.play()

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(_click.play)

func _hook_existing(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(_click.play)
	for child in node.get_children():
		_hook_existing(child)
