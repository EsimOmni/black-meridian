extends GPUParticles3D
class_name SteamVents
## P13c — sparse ground steam over the wharf (brief §9.1 atmosphere). Presentation-only, sibling of
## the venue markers under city_view: no authoritative state, no signals, never rebuilt on sim change.
## Soft slow-rising puffs, an accent (not a curtain) — the master's damp wharf breathing.

const EMITTER_Y := 1.0
const BOX_EXTENTS := Vector3(90.0, 0.5, 90.0)  ## spread across the wharf, low over the ground

const PUFF_COUNT := 90
const PUFF_LIFETIME := 4.2      ## long, drifting
const RISE_SPEED := 2.4         ## slow +y, no gravity
const PUFF_SIZE := Vector2(7.0, 7.0)                ## a cloud, not a droplet
const PUFF_COLOR := Color(0.55, 0.60, 0.66, 0.06)   ## cool neutral grey, whisper-low alpha

func _ready() -> void:
	position = Vector3(0.0, EMITTER_Y, 0.0)
	amount = PUFF_COUNT
	lifetime = PUFF_LIFETIME
	preprocess = PUFF_LIFETIME   ## start mid-drift, no ramp-in
	visibility_aabb = AABB(Vector3(-BOX_EXTENTS.x, -1.0, -BOX_EXTENTS.z),
		Vector3(BOX_EXTENTS.x * 2.0, EMITTER_Y + RISE_SPEED * PUFF_LIFETIME + 8.0, BOX_EXTENTS.z * 2.0))

	process_material = _make_process_material()
	draw_pass_1 = _make_puff_mesh()

func _make_process_material() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = BOX_EXTENTS
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 20.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = RISE_SPEED * 0.7
	pm.initial_velocity_max = RISE_SPEED
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 1.2
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	return pm

func _make_puff_mesh() -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = PUFF_SIZE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES   ## face camera, soft puff
	mat.billboard_keep_scale = true
	mat.albedo_color = PUFF_COLOR
	mat.albedo_texture = _soft_disc()   ## radial falloff → soft puff, not a hard square
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED  ## veil, doesn't occlude
	mesh.material = mat
	return mesh

## A white disc that fades to transparent at the edge — turns the flat quad into a soft round puff.
static func _soft_disc() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
