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
		"position": Vector3(-35.0, 0.0, 22.5),   # front-left of the venue row, camera-facing — the master's near freight depot on the wharf edge (2.5× spread)
		"rotation_y": 1.4,                        # long axis roughly parallel to the water, gable end angled to the 3/4 camera
		"scale": 2.2,                             # a ~5 m depot reads too small beside the venue kit — bring it up to hero read
		"textured": true,                         # Sketchfab GLB — keep its baked brick/metal texture, skip the flat-color noir shader
	},
	{
		"glb": LANDMARK_DIR + "industrial_block_a.glb",
		"name": "IndustrialBlockA",
		"position": Vector3(40.0, 0.0, -20.0),   # right-mid, set back behind the venue row — a taller brick freight block on the skyline (2.5× spread)
		"rotation_y": -1.1,                       # broad face angled toward the 3/4 camera
		"textured": true,
	},
	{
		"glb": LANDMARK_DIR + "dock_house_pier.glb",
		"name": "DockHousePier",
		"position": Vector3(5.0, 0.0, 30.0),    # front-center on the wharf edge, out over the water — the near stilt-house + jetty combo (2.5× spread)
		"rotation_y": 0.3,                        # jetty runs toward the water/camera-right
		"scale": 1.3,                             # bring the ~11 m combo up so the stilt house reads beside the warehouse
		"textured": true,
	},
	{
		"glb": LANDMARK_DIR + "alien_tower_hero.glb",  # Blender-optimized and base-centered GLB
		"name": "AlienDiplomaticTower",
		"position": Vector3(85.0, 0.0, -85.0),  # right flank, deep out on the water — pushed further right+back so it clears the venue row instead of centering behind it (2.5× spread)
		"rotation_y": -0.35,                     # quarter-turn so a facet faces the camera
		"scale": 10.0,                           # raw GLB is ~1.83 m native after base cut; ×10 ≈ 18 m focal spire
		"base_offset_y": 0.0,                    # mesh bottom is already at y=0 (base-centered in Blender)
		"textured": true,                        # keep the baked PBR (patina brutalist base → bioluminescent crown), skip the flat-color noir shader
		"matte": true,                           # Hunyuan's glTF ships metallicFactor=1.0 + an ORM map → Godot reads it metallic-mirror; kill metallic/roughness so it reads as painted stone. The crown carries its own baked Crown_Emissive (Codex Blender pass), which _kill_mirror_keep_emission preserves.
	},
	{
		"glb": LANDMARK_DIR + "stone_institution.glb",
		"name": "StoneInstitution",
		"position": Vector3(-75.0, 0.0, -35.0),  # left flank, pushed back to sit level with the venue row (not looming in front) (2.5× spread)
		"rotation_y": 0.95,                       # +y portico front turned to face the 3/4 skyline eye
		"patina": 0.0,                            # stone: pure cold stain, no metal patina
	},
	{
		"glb": LANDMARK_DIR + "transit_spine.glb",
		"name": "TransitSpine",
		"position": Vector3(25.0, 0.0, -100.0),   # pushed deep onto the open water between the row and the right-rear tower (clear of the row) (2.5× spread)
		"rotation_y": -0.85,                      # steeper diagonal — the crossing runs toward the tower, not parallel to the row
		"patina": 0.0,                            # rusted steel: the cold stain reads on it directly, no metal patina
	},
	{
		"glb": LANDMARK_DIR + "warehouse_a.glb",  # first P12b Codex-Blender asset (validator PASS, base-centered, LOD0/1); a 36 m stepped-parapet freight block
		"name": "WarehouseBlockA",
		"position": Vector3(-50.0, 0.0, -65.0),  # left-of-centre, deep behind the venue row — fills the mid-left skyline gap between the institution and the transit crossing (2.5× spread)
		"rotation_y": 0.55,                       # long face angled to the 3/4 skyline eye, stepped parapet catching the key light
		"patina": 0.35,                           # industrial freight: light metal patina on the stain, distinct from the pure-stone institution
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
		# Raw (non-Blender) GLBs aren't base-centered; lift by the mesh's below-y=0 dip × scale so the base sits on the ground.
		var off_y: float = p.get("base_offset_y", 0.0)
		if off_y != 0.0:
			node.position.y += off_y * s
		# The noir-detail shader replaces a flat baked slot with weathered stone/metal, driven by
		# the material's albedo_COLOR uniform. Texture-mapped GLBs (Sketchfab imports) carry their
		# tone in the albedo MAP with a white base color, so the shader would wash them flat grey —
		# they already read as aged brick/wood, so keep their own material and only weather the
		# flat-colored P12b landmarks (alien tower / stone institution).
		if not p.get("textured", false):
			_apply_noir_detail(node, p.get("patina", 0.0))  # P12b trim lap: weather stone/metal, glow clean
		elif p.get("matte", false):
			_kill_mirror_keep_emission(node)  # kill the Hunyuan glTF's metallic-mirror; keep the crown's baked bioluminescent emission
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

## Kill the metallic-mirror on every surface while PRESERVING each surface's own baked emission.
## Hunyuan3D's glTF export writes metallicFactor=1.0 plus an ORM map, so Godot builds a
## metallic-mirror material; under the scene's HDRI reflection + glow the tower blows to white.
## We drop metallic + the ORM channels (keeping the albedo MAP, so the baked patina/organic color
## stays) so it reads as painted stone, not chrome. The Codex Blender pass split the crown onto its
## own `Crown_Emissive` material with a baked cyan-green emission texture — we KEEP that emission
## (enabled/texture/color/energy) untouched so the crown self-lights; only the base's flat mirror is
## killed. This replaced the old approach of injecting a (near-black, useless) emissive PNG here.
static func _kill_mirror_keep_emission(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh != null:
			for s in mesh.get_surface_count():
				var mat := mesh.surface_get_material(s)
				if not (mat is StandardMaterial3D):
					mat = mi.get_active_material(s)  # some imports carry the material on the instance, not the mesh surface
				if mat is StandardMaterial3D:
					var m := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					m.metallic = 0.0
					m.metallic_texture = null           # drop the ORM metallic channel — Hunyuan ships metallicFactor=1
					m.roughness = 0.9
					m.roughness_texture = null           # drop the ORM roughness channel — uniform matte, can't specular-blow
					m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED  # no dielectric highlight for the HDRI to bloom
					# The crown's baked emission (Crown_Emissive) is left intact on the duplicate — we
					# only touched metallic/roughness/specular, so the self-lit bioluminescence survives.
					mi.set_surface_override_material(s, m)
	for child in node.get_children():
		_kill_mirror_keep_emission(child)

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
