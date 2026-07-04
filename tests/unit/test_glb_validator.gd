extends Node
## P15 unit test — GLBValidator graded against deterministic, code-built fixtures (the repo
## holds zero GLBs; nothing here depends on the concept master or any downloaded asset).
## Run as a scene, NOT via -s (the established runner pattern):
##   Godot --headless --path . res://tests/unit/test_glb_validator.tscn

var _failures := 0

func _ready() -> void:
	_test_clean_building_passes()
	_test_broken_building_fails()
	_test_warns_never_block()
	_test_determinism()
	_test_validate_file_roundtrip()
	if _failures == 0:
		print("[PASS] all glb validator tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d glb validator assertion(s) failed" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("  assertion failed: ", msg)

func _level(report: Dictionary, name: String) -> String:
	for ch in report["checks"]:
		if ch["name"] == name:
			return ch["level"]
	return "missing"

# --- Tests ---------------------------------------------------------------------

func _test_clean_building_passes() -> void:
	var root := _make_clean_building()
	var report := GLBValidator.validate_scene(root, GLBValidator.spec_for(&"building"))
	_check(report["pass"] == true, "clean building must pass")
	for ch in report["checks"]:
		_check(ch["level"] == "pass",
			"clean building expected all-pass, got %s on %s — %s"
			% [ch["level"], ch["name"], ch["detail"]])
	root.free()

func _test_broken_building_fails() -> void:
	var root := _make_broken_building()
	var report := GLBValidator.validate_scene(root, GLBValidator.spec_for(&"building"))
	_check(report["pass"] == false, "broken building must fail")
	var fails: Array[String] = []
	for ch in report["checks"]:
		if ch["level"] == "fail":
			fails.append(ch["name"])
	_check(fails.size() >= 3, "expected >=3 fails, got %d (%s)" % [fails.size(), str(fails)])
	for expected in ["scale", "pivot", "normals", "lod"]:
		_check(expected in fails, "expected a fail on '%s'" % expected)
	root.free()

func _test_warns_never_block() -> void:
	var root := _make_clean_building()
	var spec := GLBValidator.spec_for(&"building")
	spec["max_surfaces"] = 1  # fixture has 2 surfaces -> soft cap exceeded, hard cap not
	spec["max_surfaces_hard"] = 99
	var report := GLBValidator.validate_scene(root, spec)
	_check(_level(report, "draw_calls") == "warn", "soft-cap breach must grade warn")
	_check(report["pass"] == true, "warns must never block the pass verdict")
	root.free()

func _test_determinism() -> void:
	var root := _make_clean_building()
	var spec := GLBValidator.spec_for(&"building")
	var a := JSON.stringify(GLBValidator.validate_scene(root, spec))
	var b := JSON.stringify(GLBValidator.validate_scene(root, spec))
	_check(a == b, "same scene + spec must produce a byte-identical report")
	root.free()

## Round-trip the clean fixture through a real .glb on disk to prove the validate_file
## wrapper (GLTFDocument load path). Export drops collision bodies and may drop UV2 —
## both degrade to warns at worst, so the overall verdict must still be pass.
func _test_validate_file_roundtrip() -> void:
	var root := _make_clean_building()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	_check(err == OK, "glTF export append_from_scene failed: error %d" % err)
	var abs_path := ProjectSettings.globalize_path("user://p15_roundtrip.glb")
	if err == OK:
		err = doc.write_to_filesystem(state, abs_path)
		_check(err == OK, "glTF write_to_filesystem failed: error %d" % err)
	root.free()
	if err != OK:
		return
	var report := GLBValidator.validate_file(abs_path, GLBValidator.spec_for(&"building"))
	_check(report["pass"] == true, "round-tripped clean building must pass validate_file")
	_check(_level(report, "normals") == "pass", "normals must survive the glb round-trip")
	_check(_level(report, "lod") == "pass", "*_LODn names must survive the glb round-trip")
	_check(_level(report, "pivot") == "pass", "base-center pivot must survive the glb round-trip")
	DirAccess.remove_absolute(abs_path)

# --- Fixtures (code-built ArrayMesh scenes, no external files) -------------------

func _make_clean_building() -> Node3D:
	var root := Node3D.new()
	root.name = "glasswharf_kit_tower_a"
	var mat := StandardMaterial3D.new()
	var lod0 := MeshInstance3D.new()
	lod0.name = "glasswharf_kit_tower_a_LOD0"
	lod0.mesh = _box_mesh(Vector3(8.0, 24.0, 8.0), true, true, mat)
	root.add_child(lod0)
	var lod1 := MeshInstance3D.new()
	lod1.name = "glasswharf_kit_tower_a_LOD1"
	lod1.mesh = _box_mesh(Vector3(8.0, 24.0, 8.0), true, true, mat)
	root.add_child(lod1)
	var body := StaticBody3D.new()
	body.name = "collider"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 24.0, 8.0)
	shape.shape = box
	shape.position = Vector3(0.0, 12.0, 0.0)
	body.add_child(shape)
	root.add_child(body)
	return root

## Deliberately wrong on four counts: 500x scale (a cm-export mistake), pivot at
## center-of-mass instead of base, one surface with normals stripped, no *_LODn names.
func _make_broken_building() -> Node3D:
	var root := Node3D.new()
	root.name = "tower_broken"
	var mi := MeshInstance3D.new()
	mi.name = "tower_broken_mesh"
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
		_box_arrays(Vector3(4000.0, 12000.0, 4000.0), false, true))
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
		_box_arrays(Vector3(4000.0, 12000.0, 4000.0), false, false))
	mi.mesh = mesh
	root.add_child(mi)
	return root

func _box_mesh(size: Vector3, base_centered: bool, with_normals: bool, mat: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
		_box_arrays(size, base_centered, with_normals))
	if mat != null:
		mesh.surface_set_material(0, mat)  # baked material — what the validator reads
	return mesh

## Raw surface arrays for a box, sourced from BoxMesh geometry then reshaped: optional
## base-center pivot (vertices lifted so y=0 is the base), UV2 mirrored from UV, and
## optional normal stripping (tangents must go with them or the surface is invalid).
func _box_arrays(size: Vector3, base_centered: bool, with_normals: bool) -> Array:
	var bm := BoxMesh.new()
	bm.size = size
	var arrays: Array = bm.surface_get_arrays(0)
	if base_centered:
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] = verts[i] + Vector3(0.0, size.y * 0.5, 0.0)
		arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV2] = arrays[Mesh.ARRAY_TEX_UV]
	if not with_normals:
		arrays[Mesh.ARRAY_NORMAL] = null
		arrays[Mesh.ARRAY_TANGENT] = null
	return arrays
