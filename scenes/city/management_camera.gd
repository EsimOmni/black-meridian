extends Camera3D
## Management camera (brief §9.2): near-orthographic top-down read, 35-45° downward,
## limited zoom bands, NO free rotation in the vertical slice. Pan with WASD / arrows / MMB drag.

@export var pan_speed: float = 18.0
@export var edge_pan_margin: float = 24.0
@export var edge_pan_enabled: bool = false  ## off by default; WASD is the primary control

## Zoom is height above the ground plane, clamped to discrete-ish bands (brief §9.2 limited zoom).
## Bands raised for P14: assembled buildings reach ~31 m (6 floors), so the top-down read must
## clear them — the old 10–34 range was sized for the 2 m greybox boxes.
@export var zoom_min: float = 18.0
@export var zoom_max: float = 120.0
@export var zoom_step: float = 8.0

var _target_height: float
var _pan_origin := Vector3.ZERO
var _dragging := false

func _ready() -> void:
	# 40° downward, looking toward -Z+down. Fixed pitch (no rotation in the slice).
	rotation_degrees = Vector3(-50.0, 0.0, 0.0)  # -50 pitch => ~40° down from horizontal read
	position.y = clampf(position.y if position.y > 0.0 else 75.0, zoom_min, zoom_max)
	_target_height = position.y
	_pan_origin = Vector3(position.x, 0.0, position.z)

func _process(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		move.z -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		move.z += 1.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		move.x += 1.0

	if move != Vector3.ZERO:
		move = move.normalized() * pan_speed * delta
		_pan_origin += move
		_pan_origin.x = clampf(_pan_origin.x, -100.0, 100.0)
		_pan_origin.z = clampf(_pan_origin.z, -100.0, 100.0)

	# Smooth zoom toward the target band.
	position.y = lerpf(position.y, _target_height, 8.0 * delta)
	# Keep the camera anchored over the pan origin at the current height + fixed back-offset.
	var back_offset := position.y * 0.7  # because of the downward pitch, pull back along +Z
	position.x = _pan_origin.x
	position.z = _pan_origin.z + back_offset

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_target_height = clampf(_target_height - zoom_step, zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_target_height = clampf(_target_height + zoom_step, zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_pan_origin.x = clampf(_pan_origin.x - event.relative.x * 0.04, -100.0, 100.0)
		_pan_origin.z = clampf(_pan_origin.z - event.relative.y * 0.04, -100.0, 100.0)
