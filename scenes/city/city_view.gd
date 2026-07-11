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
	DistrictLandmarks.spawn_all(self)  # P12b hero landmarks: static district skyline, not venues
	DockProps.spawn_all(self)  # scatter dressing: containers, crane, market, pallets, bollards — static, no venue state
	add_child(RainCurtain.new())  # P13b static rain curtain: atmosphere, presentation-only, no venue state
	add_child(SteamVents.new())   # P13c sparse ground steam: atmosphere, presentation-only
	add_child(RainSplashes.new()) # P13c rain-on-ground ripple accents: atmosphere, presentation-only
	add_child(CrowdProxy.new())   # P13d pedestrian crowd illusion: MultiMesh, presentation-only
	add_child(TrafficProxy.new()) # P13e traffic illusion: MultiMesh flow on the service road, presentation-only
	GameState.districts_changed.connect(rebuild)

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.06, 0.08)  # wet charcoal asphalt (brief §9.1 palette)
	mat.roughness = 0.08                          # rain-lacquered: near-mirror so the night HDRI reflects sharply
	mat.metallic = 0.45                           # higher metallic -> the sky-reflection reads as wet sheen, not matte
	mat.metallic_specular = 0.85
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
	# P14: the venue's strategic state assembles a kit building (brief §1 — the city shows the
	# state). Form is a pure function of district + venue; GameState stays authoritative.
	var body := StaticBody3D.new()
	body.name = String(venue.id)
	var district := GameState.get_district_of_venue(venue)
	var plan := KitAssembler.plan_building(venue, district)
	var height := KitAssembler.building_height(plan)
	body.position = Vector3(venue.map_position.x, 0.0, venue.map_position.y)

	var building := KitAssembler.assemble(plan)
	# Tint the whole building by owner faction accent so player vs rival reads at a glance
	# (brief §9.1) — applied as a per-instance override on every mesh in the stack.
	var base := RACKET_COLOR if venue.type == BM.VenueType.RACKET else FRONT_COLOR
	var faction := GameState.get_faction(venue.owner_faction)
	if faction:
		base = base.lerp(faction.accent_color, 0.45)
	_tint_building(building, base)
	body.add_child(building)

	var shape := BoxShape3D.new()
	shape.size = Vector3(KitAssembler.CELL, height, KitAssembler.CELL)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, height * 0.5, 0.0)
	body.add_child(col)

	body.input_ray_pickable = true
	body.input_event.connect(_on_marker_input.bind(venue))
	return body

## Warm sodium-neon shopfront glow — the master's signature: lit ground-floor windows spilling into
## the wet street. Blended from the faction accent so the racket/front read survives, pushed warm.
const SHOPFRONT_GLOW := Color(1.0, 0.72, 0.38)

## Tint an assembled building. The building root's DIRECT children are the kit bands (ground/mids/cap),
## each placed by KitAssembler.assemble at position.y = 0 / CELL / CELL*2… — that offset carries the
## band identity. The ground band (y < CELL) becomes an emissive shopfront so the env glow blooms it
## into lit frontage (brief §9.1 wet-neon); upper bands stay matte tint so the tower doesn't glow as a
## solid block. We branch here, at the band level, then tint each band's inner meshes accordingly —
## the inner GLB meshes sit at local y≈0, so the band identity must be read from the band node, not
## the leaf mesh (which is why an earlier leaf-level y check lit the whole stack).
func _tint_building(building: Node3D, color: Color) -> void:
	for band in building.get_children():
		var lit := band is Node3D and (band as Node3D).position.y < KitAssembler.CELL
		_tint_meshes(band, color, lit)

## Apply the per-instance material to every MeshInstance3D under a band. `lit` = ground frontage.
func _tint_meshes(node: Node, color: Color, lit: bool) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.6
		if lit:
			mat.emission_enabled = true
			mat.emission = color.lerp(SHOPFRONT_GLOW, 0.6)  # warm the accent toward sodium neon
			mat.emission_energy_multiplier = 0.9            # low — the env glow does the bloom, not raw brightness
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_tint_meshes(child, color, lit)

func _on_marker_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3,
		_idx: int, venue: VenueData) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		venue_clicked.emit(venue)
