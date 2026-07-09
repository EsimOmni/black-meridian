class_name DockProps
extends RefCounted
## Prop scatter-dressing for Glass Wharf. District-level SCENERY like DistrictLandmarks, but for
## small, repeatable set-dressing (containers, crane, boat, lamps, pallets) rather than one-of-a-kind
## hero structures. Same discipline: pure presentation, GameState stays authoritative, no state in
## scene nodes, NO RNG — placements are a fixed authored array (brief: zero RNG in src; this is
## presentation but we still author positions rather than scatter randomly, so the scene is
## deterministic and save-independent).
##
## Difference from DistrictLandmarks: props keep their OWN baked Sketchfab material (no noir-detail
## weathering shader — they already read as aged geometry, and the shader washes texture-mapped GLBs
## flat grey, same reason the landmark `textured` flag exists). Placement supports rotation on all
## axes + a y_offset so a prop whose GLB pivot sits off-ground can be seated without re-exporting.

const PROP_DIR := "res://assets/city/glasswharf_dock/"

## Fixed prop placements echoing the master keyframe's crowded wet pier. Positions are the human 10%
## (composition taste). Only the Faz-1 batch is placed here — dock_crane, bollard_rope,
## fishing_supplies, market_stall, pallet_pack — all with a clean base-center pivot AND a
## license-verified CC-BY source (attribution logged). The earlier-batch props (containers, dumpster,
## boat, the two lamps) are held back: some export with a tilted/floating pivot, and their download
## UID/license was never recorded — they stay out until re-exported clean and license-verified.
## Props are read at management-camera scale (near-ortho diorama), where a native 2 m container reads
## as a toy beside the 18–36 m kit buildings (CELL 4.5 × floors+2). We bump props to a mid scale so
## they anchor as dock furniture, and SPREAD them along the front pier band (z ≈ +6..+15, camera-near,
## in front of the venue row at z ≈ ±1.5) instead of piling at centre — echoing the master's wide,
## crowded-but-ordered wharf rather than a heap. Not 1:1 with the cinematic master (different camera
## language); the goal is a legible dressed pier, not a photo match.
const PLACEMENTS := [
	{
		"glb": PROP_DIR + "dock_crane.glb",
		"name": "DockCrane",
		"position": Vector3(65.0, 0.0, -35.0),   # right flank on the water — the master's harbor crane silhouette (2.5× spread)
		"rotation_y": -0.6,
		"scale": 2.5,                             # a 3.4 m crane vanishes beside 30 m towers — bring it to skyline read
	},
	{
		"glb": PROP_DIR + "market_stall.glb",
		"name": "MarketStallA",
		"position": Vector3(-32.5, 0.0, 32.5),   # left of the near pier — the master's lit market strip (2.5× spread)
		"rotation_y": 0.5,
		"scale": 2.2,
	},
	{
		"glb": PROP_DIR + "market_stall.glb",
		"name": "MarketStallB",
		"position": Vector3(-17.5, 0.0, 35.0),    # second stall beside the first — a small row reads as a market (2.5× spread)
		"rotation_y": 0.35,
		"scale": 2.2,
	},
	{
		"glb": PROP_DIR + "pallet_pack.glb",
		"name": "PalletPackA",
		"position": Vector3(-47.5, 0.0, 30.0),   # cargo clutter at the warehouse mouth, far-left pier (2.5× spread)
		"rotation_y": 0.9,
		"scale": 2.4,
	},
	{
		"glb": PROP_DIR + "pallet_pack.glb",
		"name": "PalletPackB",
		"position": Vector3(-43.75, 0.0, 25.0),  # (2.5× spread)
		"rotation_y": 0.2,
		"scale": 2.4,
	},
	{
		"glb": PROP_DIR + "fishing_supplies.glb",
		"name": "FishingSupplies",
		"position": Vector3(15.0, 0.0, 37.5),     # pier-edge clutter, camera-near centre (2.5× spread)
		"rotation_y": -0.4,
		"scale": 2.0,
	},
	{
		"glb": PROP_DIR + "bollard_rope.glb",
		"name": "BollardA",
		"position": Vector3(30.0, 0.0, 37.5),    # wharf-edge mooring line, front-right (2.5× spread)
		"rotation_y": 0.0,
		"scale": 2.5,
	},
	{
		"glb": PROP_DIR + "bollard_rope.glb",
		"name": "BollardB",
		"position": Vector3(0.0, 0.0, 40.0),     # mooring at the near-pier centre (2.5× spread)
		"rotation_y": 0.0,
		"scale": 2.5,
	},
	{
		"glb": PROP_DIR + "corner.glb",          # kit corner block, repurposed as a low dockside container/plinth on the pier
		"name": "DockCornerBlock",
		"position": Vector3(45.0, 0.0, 27.5),    # right-front pier, beside the mooring line — a squat cargo block anchoring the corner (2.5× spread)
		"rotation_y": 0.4,
		"scale": 0.9,                             # 4.5 m native reads as a shipping container at this scale, not a building
	},
	{
		"glb": PROP_DIR + "roof_prop.glb",       # small roof-vent/AC prop, set on the near pier as ground clutter
		"name": "PierRoofProp",
		"position": Vector3(-7.5, 0.0, 33.75),    # near-centre pier clutter, between the market strip and the fishing supplies (2.5× spread)
		"rotation_y": -0.7,
		"scale": 1.8,
	},
]

## Spawn every prop under `parent`. Called once at city build; props are static dressing, not rebuilt
## on districts_changed (they carry no venue state).
static func spawn_all(parent: Node3D) -> void:
	for p in PLACEMENTS:
		var node := _load_prop(p["glb"])
		if node == null:
			continue
		node.name = p["name"]
		var y_off: float = p.get("y_offset", 0.0)
		node.position = p["position"] + Vector3(0.0, y_off, 0.0)
		node.rotation = Vector3(p.get("rotation_x", 0.0), p.get("rotation_y", 0.0), p.get("rotation_z", 0.0))
		var s: float = p.get("scale", 1.0)
		if s != 1.0:
			node.scale = Vector3(s, s, s)
		# Props keep their own baked Sketchfab material — no noir-detail shader (see class doc).
		parent.add_child(node)

## Load a prop GLB into a fresh Node3D. One-shot, no cache: each placement is authored once, and a
## few props reuse the same GLB (market_stall/pallet/container) — a shared cached node can't be
## parented twice, so we load per placement (prop meshes are small, this is cheap at city build).
static func _load_prop(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		push_error("DockProps: failed to load %s (err %d)" % [path, err])
		return null
	return doc.generate_scene(state) as Node3D
