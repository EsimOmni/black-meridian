extends Node3D
## P17b — the betrayal confrontation: a constrained first-person splat scene
## (brief §6 pillar 4: walk through the consequence). Presentation ONLY — this scene
## owns no simulation state (brief §13.2). It re-fetches the confronted character via
## GameState.get_character and routes its single verb through the transition helper,
## which delegates to the EXISTING RelationshipService.reassure(). Walking away calls
## nothing. Zero RNG anywhere (enforced by the P17b gate's source scan).
##
## Controls: WASD walk (clamped to a hard AABB, no jump), mouse look,
## E inspect the tell, R reassure, Q walk away / leave.

signal reveal_resolved(character_id: StringName, reassured: bool)

const WALK_SPEED := 2.0
const MOUSE_SENS := 0.003
const EYE_HEIGHT := 1.6
const INSPECT_RANGE := 1.8

## The hard walk clamp around the world's center — supplied by the world provider
## (P17-lite: the world technique is a seam, not this scene's business).
var _bounds_half := 2.0

var transition  # CinematicTransition — set by the round-trip helper before setup()

var _character_id: StringName = &""
var _cam: Camera3D
var _tell: MeshInstance3D
var _center := Vector3.ZERO
var _floor_y := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _inspected := false
var _reassured := false
var _headline: Label
var _prompt: Label

func setup(character_id: StringName) -> void:
	_character_id = character_id
	_build_world()
	_build_proxies()
	_build_camera()
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## The cinematic world comes from the provider seam (P17-lite): mesh interior by
## default, the proven GDGS splat route behind the same contract for a later swap.
func _build_world() -> void:
	var world := CinematicWorldProvider.build(self)
	_center = world["center"]
	_floor_y = world["floor_y"]
	_bounds_half = world["bounds_half"]

## Conventional-3D greybox actors: the lieutenant (capsule) and the tell (box).
## Lighting belongs to the world provider (an interior lamp, not a sun).
func _build_proxies() -> void:
	var lieutenant := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28  # human-width silhouette — the default 0.5 reads as a tank indoors
	capsule.height = 1.8
	lieutenant.mesh = capsule
	lieutenant.position = _center + Vector3(0.0, 0.0, -1.4)
	lieutenant.position.y = _floor_y + 0.9
	add_child(lieutenant)

	_tell = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.4, 0.4)
	_tell.mesh = box
	_tell.position = _center + Vector3(0.7, 0.0, -1.1)
	_tell.position.y = _floor_y + 0.2
	add_child(_tell)

func _build_camera() -> void:
	_cam = Camera3D.new()
	_cam.position = Vector3(_center.x, _floor_y + EYE_HEIGHT, _center.z + 1.8)
	add_child(_cam)
	_cam.current = true

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	_headline = Label.new()
	_headline.position = Vector2(16, 16)
	ui.add_child(_headline)
	_prompt = Label.new()
	_prompt.position = Vector2(16, 64)
	ui.add_child(_prompt)
	var c := GameState.get_character(_character_id)
	if c != null:
		_headline.text = "%s — the room reads wrong.  Ticks to betrayal: %d" % [
			c.display_name, c.betrayal_ticks_until_land]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.2, 1.2)
		if _cam:
			_cam.rotation = Vector3(_pitch, _yaw, 0.0)
		return
	# ESC releases the cursor (so you can leave the window); click recaptures it for
	# mouse-look. Standard FPS toggle — nothing here mutates sim state.
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_E:
				if not _inspected and _near_tell():
					_inspected = true
					_show_tell()
			KEY_R:
				if _inspected and not _reassured:
					_attempt_reassure()
			KEY_Q:
				_finish()

func _process(delta: float) -> void:
	if _cam == null:
		return
	# Walk-only movement: yaw-relative WASD on a fixed-height plane, hard-clamped to
	# the validated volume. No jump, no fall-through, no combat.
	var input := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input.x += 1.0
	if input != Vector3.ZERO:
		var dir := Basis(Vector3.UP, _yaw) * input.normalized()
		var pos := _cam.position + dir * WALK_SPEED * delta
		pos.x = clampf(pos.x, _center.x - _bounds_half, _center.x + _bounds_half)
		pos.z = clampf(pos.z, _center.z - _bounds_half, _center.z + _bounds_half)
		pos.y = _floor_y + EYE_HEIGHT
		_cam.position = pos
	_update_prompt()

func _near_tell() -> bool:
	return _tell != null and _cam != null \
		and _cam.position.distance_to(_tell.position) <= INSPECT_RANGE

func _update_prompt() -> void:
	if _reassured:
		_prompt.text = "[Q] Leave"
	elif _inspected:
		_prompt.text = "[R] Reassure — the sit-down (-%d clean)    [Q] Walk away" \
			% LoyaltyScoring.REASSURE_COST_CLEAN
	elif _near_tell():
		_prompt.text = "[E] Inspect"
	else:
		_prompt.text = "Walk to the crate.    [Q] Walk away"

## Surfacing the tell: presentation of already-authoritative state, nothing more.
func _show_tell() -> void:
	var c := GameState.get_character(_character_id)
	if c == null:
		return
	if c.motive_revealed and c.betrayal_driving_motive != &"":
		_headline.text = "%s — driven by: %s.  Ticks to betrayal: %d" % [
			c.display_name, String(c.betrayal_driving_motive).capitalize(),
			c.betrayal_ticks_until_land]
	else:
		_headline.text = "%s — something is off. Sit down with them.  Ticks to betrayal: %d" % [
			c.display_name, c.betrayal_ticks_until_land]

func _attempt_reassure() -> void:
	if transition == null:
		return
	if transition.try_reassure(_character_id):
		_reassured = true
		_show_tell()  # motive_revealed just flipped — show the now-revealed motive
	else:
		_headline.text = "Can't afford the sit-down (need %d clean). Walk away, or don't." \
			% LoyaltyScoring.REASSURE_COST_CLEAN

func _finish() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	reveal_resolved.emit(_character_id, _reassured)
