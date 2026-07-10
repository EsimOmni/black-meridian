extends GPUParticles3D
class_name RainCurtain
## P13b — static diagonal rain curtain over the city view (brief §9.1 rain-lacquered noir, §15 perf).
## Presentation-only: holds no authoritative state, connects no signals, never rebuilt on sim change.
## A single GPU particle system emitting thin streak quads through a fixed box that covers the whole
## clamped camera-pan area (management_camera pans x,z ∈ [-100,100]); brief §15 "fixed camera bands".

## Volume: emitter sits high above the ~31 m assembled buildings + zoom headroom, drops fall through
## the full band. Extents cover ±100 pan + margin.
const EMITTER_Y := 55.0
const BOX_EXTENTS := Vector3(110.0, 1.0, 110.0)

const DROP_COUNT := 5000
const DROP_LIFETIME := 2.2      ## long enough to cross the volume top-to-bottom
const FALL_SPEED := 55.0        ## −y gravity; drops accelerate, no damping
const DIAGONAL_X := -14.0       ## small −x so the curtain leans ~15° top-left → bottom-right (master)

## Streak geometry: a thin tall quad reads as a line, not a dot.
const DROP_SIZE := Vector2(0.02, 0.6)
const DROP_COLOR := Color(0.62, 0.70, 0.82, 0.45)  ## cool grey-blue, low alpha veil

func _ready() -> void:
	position = Vector3(0.0, EMITTER_Y, 0.0)
	amount = DROP_COUNT
	lifetime = DROP_LIFETIME
	preprocess = DROP_LIFETIME   ## start mid-storm, no ramp-in on scene load
	visibility_aabb = AABB(Vector3(-BOX_EXTENTS.x, -EMITTER_Y, -BOX_EXTENTS.z),
		Vector3(BOX_EXTENTS.x * 2.0, EMITTER_Y + 5.0, BOX_EXTENTS.z * 2.0))

	process_material = _make_process_material()
	draw_pass_1 = _make_drop_mesh()

func _make_process_material() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = BOX_EXTENTS
	# Diagonal fall: strong −y, small −x. gravity is a directional accel; no initial spread needed.
	pm.gravity = Vector3(DIAGONAL_X, -FALL_SPEED, 0.0)
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 0.0
	pm.damping_min = 0.0
	pm.damping_max = 0.0
	return pm

func _make_drop_mesh() -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = DROP_SIZE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y   ## stays near-vertical, doesn't flatten to camera
	mat.billboard_keep_scale = true
	mat.albedo_color = DROP_COLOR
	mat.emission_enabled = true
	mat.emission = Color(0.62, 0.70, 0.82)
	mat.emission_energy_multiplier = 0.4                    ## faint — streaks catch neon, don't glow
	mat.no_depth_test = false
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED  ## veil over scene, doesn't drown reflections
	mesh.material = mat
	return mesh
