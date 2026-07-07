class_name DistrictLandmarks
extends RefCounted
## Hero-landmark placement (P12b). District-level SCENERY, independent of the venue system:
## bespoke monolithic meshes that anchor the district skyline (brief §9.1, §1 — the city shows
## the state), placed at fixed positions echoing the LOCKED master keyframe. They are NOT venues,
## do NOT grow with influence, and carry no gameplay state — pure presentation. GameState stays
## authoritative; KitAssembler and the venue → building path are untouched (see the P12b
## architecture note's placement correction).

const LANDMARK_DIR := "res://assets/city/glasswharf_dock/"
const NOIR_DETAIL_SHADER := preload("res://src/presentation/landmark_noir_detail.gdshader")

## Fixed landmark placements for Glass Wharf, echoing glass_wharf_MASTER.jpg. The venue row runs
## x ∈ [-20, 20] at z ≈ ±1.5 (kit buildings, camera-facing); the water is behind (-z). The alien
## diplomatic tower stands OUT on the water on the right flank — arka plan, suya doğru — the frame's
## focal landmark, not on a gameplay lot. Position/rotation are the human 10% (composition taste).
const PLACEMENTS := [
	{
		"glb": LANDMARK_DIR + "warehouse_hero.glb",
		"name": "WarehouseHero",
		"position": Vector3(-14.0, 0.0, 9.0),   # front-left of the venue row, camera-facing — the master's near freight depot on the wharf edge
		"rotation_y": 1.4,                        # long axis roughly parallel to the water, gable end angled to the 3/4 camera
		"scale": 2.2,                             # a ~5 m depot reads too small beside the venue kit — bring it up to hero read
		"patina": 0.35,                           # damp wood/metal weathering, matches the master's wet freight facades
	},
	{
		"glb": LANDMARK_DIR + "alien_diplomatic_tower.glb",
		"name": "AlienDiplomaticTower",
		"position": Vector3(26.0, 0.0, -30.0),  # right flank, deep out on the water — a distant skyline landmark
		"rotation_y": -0.35,                     # quarter-turn so a facet faces the camera
		"patina": 0.55,                          # verdigris oxide bloom — the cold stain is invisible on this dark charcoal
	},
	{
		"glb": LANDMARK_DIR + "stone_institution.glb",
		"name": "StoneInstitution",
		"position": Vector3(-30.0, 0.0, -14.0),  # left flank, pushed back to sit level with the venue row (not looming in front)
		"rotation_y": 0.95,                       # +y portico front turned to face the 3/4 skyline eye
		"patina": 0.0,                            # stone: pure cold stain, no metal patina
	},
	{
		"glb": LANDMARK_DIR + "transit_spine.glb",
		"name": "TransitSpine",
		"position": Vector3(10.0, 0.0, -40.0),   # pushed deep onto the open water between the row and the right-rear tower (clear of the row)
		"rotation_y": -0.85,                      # steeper diagonal — the crossing runs toward the tower, not parallel to the row
		"patina": 0.0,                            # rusted steel: the cold stain reads on it directly, no metal patina
	},
]

## Spawn every landmark under `parent`. Called once at city build; landmarks are static skyline,
## so they are not rebuilt on districts_changed (they read district identity, not venue state).
static func spawn_all(parent: Node3D) -> void:
	for p in PLACEMENTS:
		var node := _load_landmark(p["glb"])
		if node == null:
			continue
		node.name = p["name"]
		node.position = p["position"]
		node.rotation.y = p["rotation_y"]
		var s: float = p.get("scale", 1.0)  # some heroes (warehouse) read too small at native size
		if s != 1.0:
			node.scale = Vector3(s, s, s)
		_apply_noir_detail(node, p.get("patina", 0.0))  # P12b trim lap: weather stone/metal, glow clean
		parent.add_child(node)

## Replace every non-emissive surface material with the triplanar noir weathering shader,
## feeding it the GLB material's base color/roughness/metallic so the tone is preserved and
## only weathered (venue-tint pattern: presentation-only override, the GLB itself is untouched,
## distinct-baked-material budget unchanged). Emissive slots (cyan seam / window glow) keep
## their own baked material so they bloom clean.
static func _apply_noir_detail(node: Node, patina: float) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh != null:
			for s in mesh.get_surface_count():
				var mat := mi.get_active_material(s)
				if mat is StandardMaterial3D and (mat as StandardMaterial3D).emission_enabled:
					continue  # the glow stays clean
				var detail := ShaderMaterial.new()
				detail.shader = NOIR_DETAIL_SHADER
				if mat is StandardMaterial3D:
					var sm := mat as StandardMaterial3D
					detail.set_shader_parameter("base_color", sm.albedo_color)
					detail.set_shader_parameter("base_roughness", sm.roughness)
					detail.set_shader_parameter("base_metallic", sm.metallic)
				detail.set_shader_parameter("patina_amount", patina)
				mi.set_surface_override_material(s, detail)
	for child in node.get_children():
		_apply_noir_detail(child, patina)

## Load a landmark GLB into a fresh Node3D (base-center pivot, y=0 = ground — validated by
## GLBValidator 'building' spec). One-shot, no cache: a landmark is placed once.
static func _load_landmark(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		push_error("DistrictLandmarks: failed to load %s (err %d)" % [path, err])
		return null
	return doc.generate_scene(state) as Node3D
