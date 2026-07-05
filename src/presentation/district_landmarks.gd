class_name DistrictLandmarks
extends RefCounted
## Hero-landmark placement (P12b). District-level SCENERY, independent of the venue system:
## bespoke monolithic meshes that anchor the district skyline (brief §9.1, §1 — the city shows
## the state), placed at fixed positions echoing the LOCKED master keyframe. They are NOT venues,
## do NOT grow with influence, and carry no gameplay state — pure presentation. GameState stays
## authoritative; KitAssembler and the venue → building path are untouched (see the P12b
## architecture note's placement correction).

const LANDMARK_DIR := "res://assets/city/glasswharf_dock/"

## Fixed landmark placements for Glass Wharf, echoing glass_wharf_MASTER.jpg. The venue row runs
## x ∈ [-20, 20] at z ≈ ±1.5 (kit buildings, camera-facing); the water is behind (-z). The alien
## diplomatic tower stands OUT on the water on the right flank — arka plan, suya doğru — the frame's
## focal landmark, not on a gameplay lot. Position/rotation are the human 10% (composition taste).
const PLACEMENTS := [
	{
		"glb": LANDMARK_DIR + "alien_diplomatic_tower.glb",
		"name": "AlienDiplomaticTower",
		"position": Vector3(26.0, 0.0, -30.0),  # right flank, deep out on the water — a distant skyline landmark
		"rotation_y": -0.35,                     # quarter-turn so a facet faces the camera
	},
	{
		"glb": LANDMARK_DIR + "stone_institution.glb",
		"name": "StoneInstitution",
		"position": Vector3(-30.0, 0.0, -14.0),  # left flank, pushed back to sit level with the venue row (not looming in front)
		"rotation_y": 0.95,                       # +y portico front turned to face the 3/4 skyline eye
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
		parent.add_child(node)

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
