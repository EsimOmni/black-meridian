extends MultiMeshInstance3D
class_name CrowdProxy
## P13d — pedestrian crowd illusion (brief §15: illusion, not simulation). Presentation-only, sibling of
## the venue markers under city_view: no authoritative state, no signals, never rebuilt on sim change.
## A single MultiMesh of low-poly figures scattered deterministically along the wharf; a vertex shader
## gives each a faint idle sway (no CPU cost, no _process). Static bodies, top-down dark silhouettes —
## the master's crowded pier read. No walking (→ P13e), no faction tint / state-reactive density (→ P13e+).

## Anchor points — the open pier IN FRONT OF the venue line, not the venues themselves. The venue
## x-coords come from WorldSeed map_positions, but z is pushed out to +Z (the open dockside the camera
## faces) so the crowd fills the pier apron the master shows — never buried inside the buildings that
## KitAssembler raises at the venue centres. Hard-coded → deterministic, independent of sim load order.
const PIER_Z := 22.0            ## the open dock apron in front of the venue row (venues sit at z≈±4)
const ANCHOR_X := [-50.0, -30.0, -10.0, 10.0, 30.0, 50.0, 20.0]
const PER_ANCHOR := 12          ## ~84 figures total — the "20-40 near" end, MultiMesh carries it free
const SCATTER_RADIUS := 8.0     ## how far a cluster spreads along the apron
const FIGURE_HEIGHT := 1.7

func _ready() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true    ## carries a per-instance sway phase in .x
	mm.mesh = _make_figure_mesh()
	mm.instance_count = ANCHOR_X.size() * PER_ANCHOR
	_place(mm)
	multimesh = mm
	material_override = _make_sway_material()
	# Top-down diorama never casts crowd shadows; keep the render cheap and the silhouettes clean.
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Deterministic scatter — a hash of the instance index drives offset/rotation/scale, so two boots
## produce byte-identical placement (no RNG, save-safe).
func _place(mm: MultiMesh) -> void:
	var i := 0
	for a in ANCHOR_X.size():
		var ax: float = ANCHOR_X[a]
		for k in PER_ANCHOR:
			var h1 := _hash01(i * 2 + 1)
			var h2 := _hash01(i * 2 + 7)
			var h3 := _hash01(i * 3 + 13)
			# spread within the cluster (disc-ish), figures thin out toward the edge
			var ang := h1 * TAU
			var rad := sqrt(h2) * SCATTER_RADIUS
			var pos := Vector3(ax + cos(ang) * rad, 0.0, PIER_Z + sin(ang) * rad)
			var basis := Basis(Vector3.UP, h3 * TAU)          # deterministic facing variety
			var s := 0.9 + _hash01(i + 101) * 0.25            # slight height variation
			basis = basis.scaled(Vector3(1.0, s, 1.0))
			mm.set_instance_transform(i, Transform3D(basis, pos))
			mm.set_instance_custom_data(i, Color(_hash01(i * 5 + 3), 0.0, 0.0, 0.0))  # sway phase
			i += 1

## A tiny low-poly figure: a capsule body with a small sphere head, merged into one ArrayMesh.
func _make_figure_mesh() -> ArrayMesh:
	var body := CapsuleMesh.new()
	body.radius = 0.22
	body.height = FIGURE_HEIGHT
	body.radial_segments = 6
	body.rings = 3
	var head := SphereMesh.new()
	head.radius = 0.16
	head.radial_segments = 6
	head.rings = 4

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# body centered so its base sits at y=0
	_append_mesh(st, body, Vector3(0.0, FIGURE_HEIGHT * 0.5, 0.0))
	_append_mesh(st, head, Vector3(0.0, FIGURE_HEIGHT + 0.02, 0.0))
	st.generate_normals()
	return st.commit()

func _append_mesh(st: SurfaceTool, prim: PrimitiveMesh, offset: Vector3) -> void:
	var arr := prim.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for t in idx.size():
		st.add_vertex(verts[idx[t]] + offset)

func _make_sway_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert;
uniform vec3 crowd_color : source_color = vec3(0.14, 0.15, 0.18);
uniform float sway_speed = 1.4;
uniform float sway_amp = 0.04;   // metres of top sway
void vertex() {
	// height weight: feet planted (0), head sways most (1)
	float w = clamp(VERTEX.y / 1.9, 0.0, 1.0);
	float phase = INSTANCE_CUSTOM.x * 6.2831853;
	VERTEX.x += sin(TIME * sway_speed + phase) * sway_amp * w;
	VERTEX.z += cos(TIME * sway_speed * 0.8 + phase) * sway_amp * 0.5 * w;
}
void fragment() {
	ALBEDO = crowd_color;   // anonymous dark silhouette (no faction tint this slice)
	ROUGHNESS = 0.9;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

## Deterministic pseudo-random in [0,1) from an int — a hash, not RNG (byte-identical across boots).
func _hash01(n: int) -> float:
	var x := (n * 374761393 + 668265263) & 0x7fffffff
	x = (x ^ (x >> 13)) * 1274126177 & 0x7fffffff
	return float(x % 100000) / 100000.0
