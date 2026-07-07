extends Node3D
## P17c — the crime-scene reveal: a constrained first-person splat scene, the second
## cinematic sequence type on the P17b rails (brief §6 pillar 4, §7.7). Presentation
## ONLY — this scene owns no simulation state (brief §13.2). It holds two IDS (district
## + target case) and re-resolves them via GameState.get_district / EvidenceMath every
## read. Its single verb routes through the transition helper, which delegates to the
## EXISTING EvidenceMath.remove_case(); leaving calls nothing. Zero RNG anywhere
## (enforced by the P17c gate's source scan).
##
## Controls: WASD walk (clamped to a hard AABB, no jump), mouse look,
## E inspect the planted evidence, R remove it, Q leave.

signal crime_scene_resolved(district_id: StringName, case_id: StringName, removed: bool)

const SPLAT_PATH := "res://assets/splat/bench_542k.ply"
const WALK_SPEED := 2.0
const MOUSE_SENS := 0.003
const EYE_HEIGHT := 1.6
const INSPECT_RANGE := 1.8
const BOUNDS_HALF := 2.0  ## the ~4×4 walkable box around the splat center (P17b spec)

var transition  # CinematicTransition — set by the round-trip helper before setup()

var _district_id: StringName = &""
var _case_id: StringName = &""
var _cam: Camera3D
var _crate: MeshInstance3D
var _center := Vector3.ZERO
var _floor_y := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _inspected := false
var _removed := false
var _headline: Label
var _prompt: Label

func setup(district_id: StringName, case_id: StringName) -> void:
	_district_id = district_id
	_case_id = case_id
	_build_splat()
	_build_proxies()
	_build_camera()
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## The proxy splat world — same GDGS setup as reveal_scene.gd (proven P01 path).
func _build_splat() -> void:
	var res: Resource = load(SPLAT_PATH)
	if res == null:
		printerr("crime_scene: could not load %s — greybox only" % SPLAT_PATH)
		return
	var splat := GaussianSplatNode.new()
	splat.gaussian = res
	add_child(splat)
	var effect_script := load("res://addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd")
	var compositor := Compositor.new()
	compositor.compositor_effects = [effect_script.new()]
	var env := WorldEnvironment.new()
	env.compositor = compositor
	add_child(env)
	var aabb: AABB = res.aabb
	_center = aabb.get_center()
	_floor_y = _center.y - 0.8

## Conventional-3D greybox: the planted evidence (a crate) the player walks to.
func _build_proxies() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.light_color = Color(0.95, 0.82, 0.62)
	add_child(light)

	_crate = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	_crate.mesh = box
	_crate.position = _center + Vector3(0.7, 0.0, -1.1)
	_crate.position.y = _floor_y + 0.25
	add_child(_crate)

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
	var d := GameState.get_district(_district_id)
	var c := _open_case()
	if d != null and c != null:
		_headline.text = "%s — planted evidence on your ground.  %s" % [d.display_name, c.label]
	elif d != null:
		_headline.text = "%s — the scene is clean. Nothing here names the operation." % d.display_name

## Re-resolve the target case fresh each read — the scene never caches the object.
func _open_case() -> EvidenceCaseData:
	var d := GameState.get_district(_district_id)
	if d == null:
		return null
	return EvidenceMath.find_case(d, _case_id)

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
				if not _inspected and _near_crate() and _open_case() != null:
					_inspected = true
					_show_case()
			KEY_R:
				if _inspected and not _removed:
					_attempt_remove()
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
		pos.x = clampf(pos.x, _center.x - BOUNDS_HALF, _center.x + BOUNDS_HALF)
		pos.z = clampf(pos.z, _center.z - BOUNDS_HALF, _center.z + BOUNDS_HALF)
		pos.y = _floor_y + EYE_HEIGHT
		_cam.position = pos
	_update_prompt()

func _near_crate() -> bool:
	return _crate != null and _cam != null \
		and _cam.position.distance_to(_crate.position) <= INSPECT_RANGE

func _update_prompt() -> void:
	if _removed:
		_prompt.text = "[Q] Leave"
	elif _open_case() == null:
		_prompt.text = "Nothing to find.    [Q] Leave"
	elif _inspected:
		_prompt.text = "[R] Remove the evidence    [Q] Leave it — the sweep keeps coming"
	elif _near_crate():
		_prompt.text = "[E] Inspect"
	else:
		_prompt.text = "Walk to the crate.    [Q] Leave"

## Surfacing the case: presentation of already-authoritative state, nothing more.
func _show_case() -> void:
	var c := _open_case()
	if c == null:
		return
	var d := GameState.get_district(_district_id)
	_headline.text = "%s — %s.  It pins the district at %d%% case weight." % [
		d.display_name if d != null else String(_district_id),
		c.label, int(c.weight * 100.0)]

func _attempt_remove() -> void:
	if transition == null:
		return
	if transition.try_remove_evidence(_district_id, _case_id):
		_removed = true
		_headline.text = "The scene is clean. Nothing here names the operation."
	else:
		_headline.text = "The evidence is already gone — someone got here first."

func _finish() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	crime_scene_resolved.emit(_district_id, _case_id, _removed)
