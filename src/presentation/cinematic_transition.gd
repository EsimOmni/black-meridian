class_name CinematicTransition
extends Node
## P17b/P18 — the enter/resolve round-trip between the management city and the
## first-person reveal scene (brief §14.2). Bootstrap-wired like RelationshipService.
##
## Two separable paths (the gate test drives the first WITHOUT the second):
## 1. SIM EFFECT — try_reassure(): pure delegation to the EXISTING verb
##    RelationshipService.reassure(). No new simulation logic lives here or in the
##    scene; walking away calls nothing.
## 2. NODE SWAP — hide (never free) the city, instance the reveal scene, restore on
##    resolve. When city_root is null (headless test — no window, no city scene) the
##    swap no-ops cleanly and enter/resolve only pause the sim.

signal reveal_resolved(character_id: StringName, reassured: bool)

const RevealScene := preload("res://scenes/cinematic/reveal_scene.tscn")

## The city presentation root to hide while the reveal is up. Null = headless.
var city_root: Node3D
## The bootstrap-wired loyalty machine (P10) — the reassure verb routes through it.
var relationship_node: RelationshipService

var _reveal  # live reveal scene instance (untyped: scene script has no class_name)
var _prev_camera: Camera3D

func enter(character_id: StringName) -> void:
	# Pause the strategic sim for the duration of the confrontation (brief §14.2).
	TimeService.set_speed(BM.Speed.PAUSED)
	if city_root == null or _reveal != null:
		return  # nothing to swap (headless) or already inside the scene
	_prev_camera = get_viewport().get_camera_3d()
	city_root.visible = false
	_reveal = RevealScene.instantiate()
	_reveal.transition = self
	add_child(_reveal)
	_reveal.setup(character_id)
	_reveal.reveal_resolved.connect(resolve)

## The sim-effect of the scene's ONE decision — the existing deterministic verb,
## nothing else. Returns false when the cost gate refuses (not enough clean capital).
func try_reassure(character_id: StringName) -> bool:
	if relationship_node == null:
		return false
	var c := GameState.get_character(character_id)
	if c == null:
		return false
	return relationship_node.reassure(c)

func resolve(character_id: StringName, reassured: bool) -> void:
	# The consequence is already written (reassure ran in-scene, or nothing did).
	if _reveal != null:
		_reveal.queue_free()
		_reveal = null
	if city_root != null:
		city_root.visible = true
	if is_instance_valid(_prev_camera):
		_prev_camera.current = true
	_prev_camera = null
	# Restore to PAUSED — the player resumes deliberately (brief §5.1).
	TimeService.set_speed(BM.Speed.PAUSED)
	reveal_resolved.emit(character_id, reassured)
