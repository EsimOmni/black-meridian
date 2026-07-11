extends MultiMeshInstance3D
class_name TrafficProxy
## P13e — traffic illusion (brief §15: spline traffic, not vehicle physics). Presentation-only, sibling
## of the venue markers under city_view: no authoritative state, no signals, never rebuilt on sim change.
## A single MultiMesh of low-poly vehicles on the wharf service road between the venue row and the pier
## apron; a vertex shader drives the whole flow (TIME + per-instance hash phase), so there is no _process
## and no CPU cost. Two fixed lanes, opposite directions. No faction tint / state-reactive density (cut).

## The service road threads the clear corridor between the venue row (z≈±4, buildings end ~z 8.5) and
## the pier crowd (z≥14). Hard-coded → deterministic, independent of sim load order.
const LANE_Z := [10.5, 12.5]    ## eastbound / westbound lanes
const PER_LANE := 12            ## ~24 vehicles total — MultiMesh carries it free
const SPAN := 140.0             ## vehicles wrap across x ∈ [-70, 70]
const SPEED := 5.5              ## m/s — slow dockside traffic

func _ready() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true    ## .x = flow phase, .y = direction, .z = paint tone
	mm.mesh = _make_vehicle_mesh()
	mm.instance_count = LANE_Z.size() * PER_LANE
	_place(mm)
	multimesh = mm
	material_override = _make_flow_material()
	# The shader translates instances ±SPAN/2 in world x; the auto AABB only covers the parked
	# transforms, so without this the whole flow gets frustum-culled at the pan edges.
	custom_aabb = AABB(Vector3(-SPAN * 0.5 - 5.0, 0.0, LANE_Z[0] - 3.0), Vector3(SPAN + 10.0, 5.0, 8.0))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Deterministic placement — a hash of the instance index drives phase/jitter/scale, so two boots
## produce byte-identical flow (no RNG, save-safe). All instances park at lane-centre x=0; the
## shader's phase term spreads them along the span.
func _place(mm: MultiMesh) -> void:
	var i := 0
	for lane in LANE_Z.size():
		var dir := 1.0 if lane == 0 else -1.0
		for k in PER_LANE:
			# evenly spaced + small jitter: spacing stays ≥ ~5.8 m so vehicles never overlap
			var phase := (float(k) + 0.5) / PER_LANE + (_hash01(i * 7 + 5) - 0.5) * (0.5 / PER_LANE)
			var zj := (_hash01(i * 3 + 11) - 0.5) * 0.6
			var s := 0.85 + _hash01(i + 41) * 0.35           # van → small truck size variety
			var basis := Basis(Vector3.UP, 0.0 if dir > 0.0 else PI)  # face the travel direction
			basis = basis.scaled(Vector3(s, s, s))
			mm.set_instance_transform(i, Transform3D(basis, Vector3(0.0, 0.0, LANE_Z[lane] + zj)))
			mm.set_instance_custom_data(i, Color(phase, dir, _hash01(i * 5 + 17), 0.0))
			i += 1

## A tiny low-poly vehicle: a slab body with a cab block toward the front, merged into one ArrayMesh.
func _make_vehicle_mesh() -> ArrayMesh:
	var body := BoxMesh.new()
	body.size = Vector3(4.2, 1.3, 1.9)
	var cab := BoxMesh.new()
	cab.size = Vector3(1.6, 0.7, 1.7)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# body raised so its underside sits at wheel height, base at y=0
	_append_mesh(st, body, Vector3(0.0, 0.95, 0.0))
	_append_mesh(st, cab, Vector3(1.0, 1.95, 0.0))
	st.generate_normals()
	return st.commit()

func _append_mesh(st: SurfaceTool, prim: PrimitiveMesh, offset: Vector3) -> void:
	var arr := prim.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for t in idx.size():
		st.add_vertex(verts[idx[t]] + offset)

func _make_flow_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, world_vertex_coords;
uniform vec3 paint_a : source_color = vec3(0.16, 0.17, 0.20);
uniform vec3 paint_b : source_color = vec3(0.20, 0.18, 0.15);
uniform float span = 140.0;
uniform float flow_speed = 5.5;
varying float tone;
void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float dir = INSTANCE_CUSTOM.y;
	tone = INSTANCE_CUSTOM.z;
	// sawtooth travel along the lane: deterministic flow, wraps seamlessly at the span edges
	float travel = mod(phase * span + TIME * flow_speed, span);
	VERTEX.x += (travel - span * 0.5) * dir;
}
void fragment() {
	ALBEDO = mix(paint_a, paint_b, tone);   // anonymous dark paint tones (no faction tint this slice)
	ROUGHNESS = 0.55;                        // rain-wet sheet metal picks up the night HDRI
	METALLIC = 0.3;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("span", SPAN)
	mat.set_shader_parameter("flow_speed", SPEED)
	return mat

## Deterministic pseudo-random in [0,1) from an int — a hash, not RNG (byte-identical across boots).
func _hash01(n: int) -> float:
	var x := (n * 374761393 + 668265263) & 0x7fffffff
	x = (x ^ (x >> 13)) * 1274126177 & 0x7fffffff
	return float(x % 100000) / 100000.0
