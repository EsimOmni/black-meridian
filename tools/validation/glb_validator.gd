class_name GLBValidator
extends RefCounted
## P15 — the GLB validation gate (brief §10.2–§10.4): every generated or purchased asset
## is graded by the same checks before entering the game; raw GLBs are never used directly.
## Pure static methods, no autoload, no scene dependencies (the EconomyMath discipline).
## The core input is an already-loaded scene root, so tests feed code-built fixtures with
## zero file I/O; validate_file() is the thin GLTFDocument wrapper around the pure core.
##
## LOD reality: a runtime GLTFDocument load produces NO importer LODs, so the LOD check is
## a convention — MeshInstance3D nodes named *_LOD0/_LOD1/... (case-insensitive), or manual
## visibility_range_begin/end. It never claims to read importer-generated LODs.
## Naming, layout and per-category budgets are documented in docs/asset-standard.md;
## SPECS below is the executable side of that document.

const ABSURD_MAX_M := 1000.0
const ABSURD_MIN_M := 0.01
const DEFAULT_PIVOT_EPS := 0.05

## Per-category budgets. Heights in meters; soft caps warn, *_hard caps fail.
const SPECS := {
	&"building": {
		"height_min_m": 3.0, "height_max_m": 120.0,
		"max_tris": 15000, "max_tris_hard": 30000,
		"max_surfaces": 4, "max_surfaces_hard": 8,
		"max_materials": 3, "max_materials_hard": 6,
		"require_lods": 2, "collision": "required",
	},
	&"prop": {
		"height_min_m": 0.05, "height_max_m": 8.0,
		"max_tris": 2000, "max_tris_hard": 6000,
		"max_surfaces": 2, "max_surfaces_hard": 4,
		"max_materials": 2, "max_materials_hard": 4,
		"require_lods": 1, "collision": "allowed",
	},
	&"vehicle": {
		"height_min_m": 0.8, "height_max_m": 5.0,
		"max_tris": 10000, "max_tris_hard": 20000,
		"max_surfaces": 3, "max_surfaces_hard": 6,
		"max_materials": 3, "max_materials_hard": 5,
		"require_lods": 2, "collision": "required",
	},
	&"character": {
		"height_min_m": 0.5, "height_max_m": 3.0,
		"max_tris": 20000, "max_tris_hard": 40000,
		"max_surfaces": 2, "max_surfaces_hard": 5,
		"max_materials": 2, "max_materials_hard": 4,
		"require_lods": 0, "collision": "forbidden",
	},
}

static func spec_for(category: StringName) -> Dictionary:
	assert(SPECS.has(category), "unknown asset category: %s" % category)
	return (SPECS[category] as Dictionary).duplicate(true)

## Thin wrapper: runtime GLB load (headless-safe, bypasses the editor .import pipeline),
## then delegates to the pure core.
static func validate_file(path: String, spec: Dictionary) -> Dictionary:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(path), state)
	if err != OK:
		return {"pass": false, "checks": [
			_c("load", "fail", "GLTFDocument.append_from_file error %d for %s" % [err, path])]}
	var root := doc.generate_scene(state) as Node3D
	if root == null:
		return {"pass": false, "checks": [
			_c("load", "fail", "generate_scene produced no Node3D for %s" % path)]}
	var report := validate_scene(root, spec)
	root.free()
	return report

## Pure core. Returns { "pass": bool, "checks": [ {name, level: "pass"|"warn"|"fail", detail} ] }.
## "pass" is true iff no check failed; warns never block.
@warning_ignore("integer_division")
static func validate_scene(root: Node3D, spec: Dictionary) -> Dictionary:
	var stats := {
		"meshes": [],          # [{mi: MeshInstance3D, xform: Transform3D}]
		"collision_nodes": 0,
		"lod_levels": {},      # int level -> true
		"lod_re": RegEx.create_from_string("(?i)_lod(\\d+)$"),
	}
	_collect(root, Transform3D.IDENTITY, stats)
	var checks: Array = []

	if (stats.meshes as Array).is_empty():
		checks.append(_c("meshes", "fail", "no MeshInstance3D with a mesh found"))
		return {"pass": false, "checks": checks}

	# Combined AABB in root space (node transforms applied).
	var aabb: AABB
	var first := true
	for entry in stats.meshes:
		var a: AABB = entry.xform * (entry.mi.mesh as Mesh).get_aabb()
		aabb = a if first else aabb.merge(a)
		first = false

	# scale — meters convention; absurd extents mean a unit-mismatch export (cm/inch).
	var max_dim := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var hmin: float = spec.get("height_min_m", 0.0)
	var hmax: float = spec.get("height_max_m", ABSURD_MAX_M)
	if max_dim > ABSURD_MAX_M or max_dim < ABSURD_MIN_M:
		checks.append(_c("scale", "fail",
			"absurd extent %.2f m — unit mismatch? (cm/inch export)" % max_dim))
	elif aabb.size.y < hmin or aabb.size.y > hmax:
		checks.append(_c("scale", "fail",
			"height %.2f m outside spec %.2f–%.2f m" % [aabb.size.y, hmin, hmax]))
	else:
		checks.append(_c("scale", "pass",
			"height %.2f m, footprint %.2f × %.2f m" % [aabb.size.y, aabb.size.x, aabb.size.z]))

	# pivot — base-center convention: origin at footprint center, y = 0 at the base.
	var eps: float = spec.get("pivot_eps", DEFAULT_PIVOT_EPS)
	var center := aabb.get_center()
	if absf(center.x) > eps or absf(center.z) > eps or absf(aabb.position.y) > eps:
		checks.append(_c("pivot", "fail",
			"origin not base-center: center (%.2f, %.2f), base y %.2f (eps %.2f)"
			% [center.x, center.z, aabb.position.y, eps]))
	else:
		checks.append(_c("pivot", "pass", "base-center within %.2f m" % eps))

	# Per-surface sweep: normals / UVs / tris / baked materials / draw calls.
	var missing_normals := PackedStringArray()
	var missing_uv := PackedStringArray()
	var missing_uv2 := PackedStringArray()
	var total_surfaces := 0
	var total_tris := 0
	var materials := {}
	var manual_lod_range := false
	for entry in stats.meshes:
		var mi: MeshInstance3D = entry.mi
		var mesh: Mesh = mi.mesh
		if mi.visibility_range_end > 0.0 or mi.visibility_range_begin > 0.0:
			manual_lod_range = true
		for s in mesh.get_surface_count():
			total_surfaces += 1
			var label := "%s[%d]" % [mi.name, s]
			var arrays := mesh.surface_get_arrays(s)
			if not _slot_present(arrays[Mesh.ARRAY_NORMAL]):
				missing_normals.append(label)
			if not _slot_present(arrays[Mesh.ARRAY_TEX_UV]):
				missing_uv.append(label)
			if not _slot_present(arrays[Mesh.ARRAY_TEX_UV2]):
				missing_uv2.append(label)
			var idx = arrays[Mesh.ARRAY_INDEX]
			if _slot_present(idx):
				total_tris += idx.size() / 3
			elif _slot_present(arrays[Mesh.ARRAY_VERTEX]):
				total_tris += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			var mat := mesh.surface_get_material(s)
			if mat != null:
				materials[mat] = true

	if missing_normals.is_empty():
		checks.append(_c("normals", "pass", "all %d surfaces carry normals" % total_surfaces))
	else:
		checks.append(_c("normals", "fail",
			"surfaces missing normals: %s" % ", ".join(missing_normals)))

	if not missing_uv.is_empty():
		checks.append(_c("uv", "fail", "surfaces missing UV: %s" % ", ".join(missing_uv)))
	elif not missing_uv2.is_empty():
		checks.append(_c("uv", "warn",
			"UV present; UV2 absent on: %s (needed only for lightmaps)" % ", ".join(missing_uv2)))
	else:
		checks.append(_c("uv", "pass", "UV + UV2 present on all %d surfaces" % total_surfaces))

	checks.append(_budget("materials", materials.size(),
		spec.get("max_materials", 1 << 30), spec.get("max_materials_hard", 1 << 30),
		"distinct baked materials"))
	checks.append(_budget("draw_calls", total_surfaces,
		spec.get("max_surfaces", 1 << 30), spec.get("max_surfaces_hard", 1 << 30),
		"surfaces (~ draw calls)"))
	checks.append(_budget("tris", total_tris,
		spec.get("max_tris", 1 << 30), spec.get("max_tris_hard", 1 << 30), "triangles"))

	# lod — naming convention *_LODn, or manual visibility-range as the alternative.
	var required: int = spec.get("require_lods", 0)
	var levels: int = (stats.lod_levels as Dictionary).size()
	if required <= 0:
		checks.append(_c("lod", "pass", "LODs not required for this category"))
	elif levels >= required:
		checks.append(_c("lod", "pass", "%d *_LODn levels found (required %d)" % [levels, required]))
	elif manual_lod_range:
		checks.append(_c("lod", "pass", "manual visibility-range LOD in use"))
	else:
		checks.append(_c("lod", "fail",
			"%d of %d required LOD levels — name meshes *_LOD0/_LOD1/… or set visibility ranges"
			% [levels, required]))

	# collision policy — advisory only (warn), colliders are often authored engine-side.
	var policy: String = spec.get("collision", "allowed")
	var col: int = stats.collision_nodes
	if policy == "forbidden" and col > 0:
		checks.append(_c("collision", "warn",
			"%d collision nodes present but policy forbids them (engine adds its own)" % col))
	elif policy == "required" and col == 0:
		checks.append(_c("collision", "warn", "no collision nodes; policy expects a collider"))
	else:
		checks.append(_c("collision", "pass", "%d collision nodes (policy: %s)" % [col, policy]))

	var ok := true
	for ch in checks:
		if ch["level"] == "fail":
			ok = false
	return {"pass": ok, "checks": checks}

static func _collect(node: Node, xform: Transform3D, stats: Dictionary) -> void:
	var local := xform
	if node is Node3D:
		local = xform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			(stats.meshes as Array).append({"mi": mi, "xform": local})
		var m: RegExMatch = stats.lod_re.search(String(node.name))
		if m != null:
			stats.lod_levels[m.get_string(1).to_int()] = true
	if node is CollisionObject3D or node is CollisionShape3D:
		stats.collision_nodes += 1
	for child in node.get_children():
		_collect(child, local, stats)

static func _slot_present(slot) -> bool:
	return slot != null and not slot.is_empty()

static func _budget(name: String, value: int, soft: int, hard: int, what: String) -> Dictionary:
	if value > hard:
		return _c(name, "fail", "%d %s exceeds hard cap %d" % [value, what, hard])
	if value > soft:
		return _c(name, "warn", "%d %s exceeds soft cap %d (hard cap %d)" % [value, what, soft, hard])
	return _c(name, "pass", "%d %s (caps %d soft / %d hard)" % [value, what, soft, hard])

static func _c(name: String, level: String, detail: String) -> Dictionary:
	return {"name": name, "level": level, "detail": detail}
