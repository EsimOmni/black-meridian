extends Node
## P17-lite VISUAL probe (throwaway dev tool, not a test): boots a seeded world and
## drops straight into the reveal scene so the mesh interior can be eyeballed /
## screenshotted without driving a live betrayal telegraph first.
## Run windowed: Godot --path . res://tools/validation/cinematic_view_probe.tscn

func _ready() -> void:
	WorldSeed.build()
	TimeService.set_speed(BM.Speed.PAUSED)
	_build_bootstrap_lighting_copy()
	var reveal := preload("res://scenes/cinematic/reveal_scene.tscn").instantiate()
	add_child(reveal)
	reveal.setup(&"bengal_lt")

## The REAL flow enters the cinematic with bootstrap's env + lights still live (the
## transition only hides city_root) — reproduce that here so the eyeball test sees the
## true lighting, not an isolated default env. Copied from bootstrap._build_lighting.
func _build_bootstrap_lighting_copy() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.07, 0.10)
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.05
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_strength = 1.0
	e.glow_bloom = 0.15
	e.glow_hdr_threshold = 1.5
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	e.fog_enabled = true
	e.fog_density = 0.012
	e.fog_light_color = Color(0.12, 0.16, 0.22)
	e.fog_sky_affect = 0.0
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_color = Color(0.95, 0.82, 0.62)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_color = Color(0.45, 0.60, 0.85)
	fill.light_energy = 0.6
	fill.shadow_enabled = false
	add_child(fill)
