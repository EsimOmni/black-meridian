extends GPUParticles3D
class_name RainSplashes
## P13c — rain-on-ground ripple accents (brief §9.1 rain-lacquered). Presentation-only, sibling of the
## venue markers under city_view: no authoritative state, no signals, never rebuilt on sim change.
## Flat expanding rings on the ground plane where drops land — an accent, not every drop; pairs with
## the RainCurtain (P13b) to sell that the rain is actually hitting the wharf.

const EMITTER_Y := 0.3
const BOX_EXTENTS := Vector3(110.0, 0.1, 110.0)  ## flat plane over the whole camera-pan area

const SPLASH_COUNT := 500
const SPLASH_LIFETIME := 0.7    ## short — a ring that blooms and fades
const RING_SIZE := Vector2(1.4, 1.4)
const RING_COLOR := Color(0.60, 0.68, 0.80, 0.32)  ## cool light, low alpha

func _ready() -> void:
	position = Vector3(0.0, EMITTER_Y, 0.0)
	amount = SPLASH_COUNT
	lifetime = SPLASH_LIFETIME
	preprocess = SPLASH_LIFETIME
	visibility_aabb = AABB(Vector3(-BOX_EXTENTS.x, -1.0, -BOX_EXTENTS.z),
		Vector3(BOX_EXTENTS.x * 2.0, 3.0, BOX_EXTENTS.z * 2.0))

	process_material = _make_process_material()
	draw_pass_1 = _make_ring_mesh()

func _make_process_material() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = BOX_EXTENTS
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.0   ## the ring is born in place and doesn't move
	pm.spread = 0.0
	# The ring blooms outward over its life: grow scale 0 → full via a curve.
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.1))
	curve.add_point(Vector2(1.0, 1.0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = curve
	pm.scale_curve = scale_tex
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	return pm

func _make_ring_mesh() -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = RING_SIZE
	mesh.orientation = PlaneMesh.FACE_Y   ## lay the quad flat on the XZ ground plane (not upright)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED   ## keep it flat on the ground, no camera-facing
	mat.albedo_color = RING_COLOR
	mat.albedo_texture = _soft_ring()   ## radial falloff → a soft splash blot, not a hard square
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mesh.material = mat
	return mesh

## A soft white blot that fades to transparent at the edge — the ground splash mark.
static func _soft_ring() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
