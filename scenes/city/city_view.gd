extends Node3D
## Greybox city view (brief §1, §9): the city is a VISUAL PROXY of the strategic sim.
## In Month 1 this spawns simple boxes per venue from GameState data. Clicking a venue
## marker selects it. The authoritative state lives in GameState, never in these nodes.

signal venue_clicked(venue: VenueData)

const VENUE_HEIGHT := 2.0
const FRONT_COLOR := Color(0.30, 0.55, 0.75)   # fronts read cool/legitimate
const RACKET_COLOR := Color(0.80, 0.35, 0.30)  # rackets read warm/illicit

@onready var _markers := Node3D.new()

func _ready() -> void:
	add_child(_markers)
	_build_ground()
	rebuild()
	GameState.districts_changed.connect(rebuild)

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.09, 0.11)  # wet charcoal asphalt (brief §9.1 palette)
	mat.roughness = 0.5
	ground.material_override = mat
	ground.name = "Ground"
	add_child(ground)

func rebuild() -> void:
	for c in _markers.get_children():
		c.queue_free()
	for district in GameState.districts:
		for venue in district.venues:
			_markers.add_child(_make_marker(venue))

func _make_marker(venue: VenueData) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = String(venue.id)
	body.position = Vector3(venue.map_position.x, VENUE_HEIGHT * 0.5, venue.map_position.y)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.2, VENUE_HEIGHT, 2.2)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	var base := RACKET_COLOR if venue.type == BM.VenueType.RACKET else FRONT_COLOR
	# Tint by owner faction accent so player vs rival reads at a glance (brief §9.1).
	var faction := GameState.get_faction(venue.owner_faction)
	if faction:
		base = base.lerp(faction.accent_color, 0.45)
	mat.albedo_color = base
	mesh.material_override = mat
	body.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	body.add_child(col)

	body.input_ray_pickable = true
	body.input_event.connect(_on_marker_input.bind(venue))
	return body

func _on_marker_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3,
		_idx: int, venue: VenueData) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		venue_clicked.emit(venue)
