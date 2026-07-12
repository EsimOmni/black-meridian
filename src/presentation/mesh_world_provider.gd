class_name MeshWorldProvider
extends RefCounted
## The $0 mesh interior behind the CinematicWorldProvider contract (ship-first decision
## 2026-07-12: mesh interior, no Marble, no splat spend). A small enclosed wharf
## back-room — the kind of space the Resolver's confrontations happen in: dark concrete,
## stacked freight, one hanging sodium lamp. Built in code from primitives + the
## existing CC-BY dock props (already attribution-logged), so it ships with zero new
## asset cost and stays a swappable placeholder like everything else in this push.
##
## Room: 8 x 6 m, 3.2 m ceiling, centered on origin. The player walk-clamp
## (bounds_half 2.4) keeps the camera inside the furniture line, so no colliders
## are needed — same discipline as the P17b spec's hardcoded AABB.

const ROOM_W := 8.0     # x extent
const ROOM_D := 6.0     # z extent
const ROOM_H := 3.2
const WALL_T := 0.2

const PROPS := [
	# Stacked freight along the back wall — the room reads as storage, not a void.
	{"path": "res://assets/city/glasswharf_dock/pallet_pack.glb",
		"pos": Vector3(-2.6, 0.0, -2.2), "rot_y": 0.3, "scale": 1.4},
	{"path": "res://assets/city/glasswharf_dock/pallet_pack.glb",
		"pos": Vector3(2.9, 0.0, -2.3), "rot_y": -1.2, "scale": 1.1},
	# Work clutter near the side wall — a shelf's worth of dockside oddments.
	{"path": "res://assets/city/glasswharf_dock/fishing_supplies.glb",
		"pos": Vector3(3.2, 0.0, 1.6), "rot_y": 2.4, "scale": 1.0},
]

static func build(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "MeshWorld"
	parent.add_child(root)
	_build_shell(root)
	_build_props(root)
	_build_lighting(root)
	return {"center": Vector3.ZERO, "floor_y": 0.0, "bounds_half": 2.4}

static func _build_shell(root: Node3D) -> void:
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.10, 0.11, 0.13)  # wet-charcoal concrete (brief §9.1)
	concrete.roughness = 0.85
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.13, 0.14, 0.17)  # cold plaster/corrugation
	wall_mat.roughness = 0.9

	_box(root, Vector3(ROOM_W, WALL_T, ROOM_D), Vector3(0, -WALL_T * 0.5, 0), concrete)  # floor
	_box(root, Vector3(ROOM_W, WALL_T, ROOM_D), Vector3(0, ROOM_H + WALL_T * 0.5, 0), wall_mat)  # ceiling
	_box(root, Vector3(ROOM_W, ROOM_H, WALL_T), Vector3(0, ROOM_H * 0.5, -ROOM_D * 0.5), wall_mat)  # back
	_box(root, Vector3(ROOM_W, ROOM_H, WALL_T), Vector3(0, ROOM_H * 0.5, ROOM_D * 0.5), wall_mat)   # front
	_box(root, Vector3(WALL_T, ROOM_H, ROOM_D), Vector3(-ROOM_W * 0.5, ROOM_H * 0.5, 0), wall_mat)  # left
	_box(root, Vector3(WALL_T, ROOM_H, ROOM_D), Vector3(ROOM_W * 0.5, ROOM_H * 0.5, 0), wall_mat)   # right

	# A thin sodium light-leak strip where the roller door meets the floor — the one
	# hint there is a wharf outside (emissive; the bootstrap glow blooms it gently).
	var leak_mat := StandardMaterial3D.new()
	leak_mat.emission_enabled = true
	leak_mat.emission = Color(0.9, 0.65, 0.3)
	leak_mat.emission_energy_multiplier = 2.2
	leak_mat.albedo_color = Color(0.2, 0.15, 0.08)
	_box(root, Vector3(2.6, 0.05, 0.05), Vector3(0.6, 0.03, ROOM_D * 0.5 - WALL_T), leak_mat)

static func _build_props(root: Node3D) -> void:
	for p in PROPS:
		var packed: PackedScene = load(p["path"])
		if packed == null:
			printerr("MeshWorldProvider: missing prop %s" % p["path"])
			continue
		var node := packed.instantiate() as Node3D
		node.position = p["pos"]
		node.rotation = Vector3(0.0, p["rot_y"], 0.0)
		var s: float = p["scale"]
		node.scale = Vector3(s, s, s)
		root.add_child(node)

static func _build_lighting(root: Node3D) -> void:
	# One hanging sodium work-lamp over the middle of the room — the confrontation
	# light. Shadows on so the freight stacks carve real darkness.
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, ROOM_H - 0.4, -0.4)
	lamp.light_color = Color(0.95, 0.78, 0.55)
	lamp.light_energy = 2.4
	lamp.omni_range = 7.0
	lamp.shadow_enabled = true
	root.add_child(lamp)
	# The lamp's visible fixture: a small emissive bulb so the source reads on camera.
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.85, 0.6)
	bulb_mat.emission_energy_multiplier = 3.0
	bulb_mat.albedo_color = Color(0.3, 0.25, 0.18)
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	bulb.mesh = sphere
	bulb.material_override = bulb_mat
	bulb.position = Vector3(0.0, ROOM_H - 0.4, -0.4)
	root.add_child(bulb)
	# A cold petrol fill from the light-leak side, very low — keeps the shadow side
	# from going to pure black without flattening the lamp's chiaroscuro.
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.6, 0.5, ROOM_D * 0.5 - 0.6)
	fill.light_color = Color(0.35, 0.5, 0.7)
	fill.light_energy = 0.5
	fill.omni_range = 5.0
	root.add_child(fill)

static func _box(root: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)
