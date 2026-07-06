extends Node3D
## Bootstrap — the Month-1 entry scene. Seeds the world, builds the greybox city + camera
## + lighting + HUD in code, and wires input (pause/speed/selection) for the 15-minute
## greybox loop (brief §19, Month 1 gate). Real scene composition replaces this later.

const CityViewScript := preload("res://scenes/city/city_view.gd")
const CameraScript := preload("res://scenes/city/management_camera.gd")
const SkylineCameraScript := preload("res://scenes/city/skyline_camera.gd")
const HudScript := preload("res://scenes/ui/hud.gd")
const JobPanelScript := preload("res://scenes/ui/job_panel.gd")

var _hud
var _night_cycle: NightCycle
var _relationships: RelationshipService
var _transition: CinematicTransition
var _city: Node3D
var _management_camera: Camera3D
var _skyline_camera: Camera3D

func _ready() -> void:
	WorldSeed.build()
	_build_lighting()
	_build_city()
	_build_camera()
	_build_night_cycle()
	_build_relationships()
	_build_transition()
	_build_hud()
	_build_jobs()
	# Start paused so the player makes the first decision (brief §5.1).
	TimeService.set_speed(BM.Speed.PAUSED)

func _build_lighting() -> void:
	# P12b noir atmosphere pass — lift the hero landmarks out of silhouette without
	# breaking the brief-§9.2 top-down management read. Both cameras share this rig, so
	# every change is chosen to help both: a stronger sodium key + a cold rim/fill breaks
	# the flat silhouette, ACES tonemap + glow lets the emissive seams/windows actually
	# glow, and a wet-ground spec reflection gives the master's rain-lacquered read.
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.07, 0.10)  # rain-lacquered petrol-blue noir (brief §9.1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.20, 0.24, 0.32)  # cool ambient, slightly lifted so faces read
	e.ambient_light_energy = 0.7
	# ACES tonemap so bright emissives roll off instead of clipping; a hint of exposure.
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.05
	e.tonemap_white = 6.0
	# Glow — the master's wet-neon read: emissive seams (cyan) + windows (sodium) bloom.
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_strength = 1.0
	e.glow_bloom = 0.15
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	# Volumetric-ish depth fog, tuned to the master's petrol haze (thin, distance falls off).
	e.fog_enabled = true
	e.fog_density = 0.012
	e.fog_light_color = Color(0.12, 0.16, 0.22)
	e.fog_sky_affect = 0.0
	env.environment = e
	add_child(env)

	# Key — sodium amber, high 3/4 to echo the master's raking light; shadows ON so the
	# portico columns and tower facets carve out (this is what breaks the silhouette).
	var sun := DirectionalLight3D.new()
	sun.name = "KeyLight"
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_color = Color(0.95, 0.82, 0.62)  # sodium amber key
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias = 0.04
	add_child(sun)

	# Cold rim/fill from the opposite-rear — separates the dark landmark masses from the
	# dark backdrop so they read as forms, not flat cut-outs. Low energy, no shadow.
	var fill := DirectionalLight3D.new()
	fill.name = "RimFill"
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_color = Color(0.45, 0.60, 0.85)  # cold petrol rim
	fill.light_energy = 0.6
	fill.shadow_enabled = false
	add_child(fill)

func _build_city() -> void:
	var city := Node3D.new()
	city.name = "CityView"
	city.set_script(CityViewScript)
	add_child(city)
	city.venue_clicked.connect(_on_venue_clicked)
	_city = city

func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "ManagementCamera"
	cam.set_script(CameraScript)
	cam.position = Vector3(0, 38, 26)  # P14: raised to clear ~31 m assembled buildings
	cam.current = true
	add_child(cam)
	_management_camera = cam

	# P12b: a second, non-gameplay skyline camera presents the hero landmarks at the master's
	# cinematic 3/4 angle. Off by default; toggled with C. The management view stays authoritative.
	var skyline := Camera3D.new()
	skyline.name = "SkylineCamera"
	skyline.set_script(SkylineCameraScript)
	add_child(skyline)
	_skyline_camera = skyline

## Swap between the top-down management read and the cinematic skyline establishing shot (C).
func _toggle_skyline_camera() -> void:
	if _skyline_camera == null or _management_camera == null:
		return
	if _skyline_camera.current:
		_management_camera.current = true
	else:
		_skyline_camera.current = true

## The phase machine is a bootstrap-wired node, NOT an autoload — unit-test scenes of
## other systems must never have phases advancing underneath them (P09).
func _build_night_cycle() -> void:
	_night_cycle = NightCycle.new()
	_night_cycle.name = "NightCycle"
	add_child(_night_cycle)

## Bootstrap-wired for the same reason as NightCycle (P09 lesson) — its clock must
## never advance loyalty state under other systems' test scenes.
func _build_relationships() -> void:
	_relationships = RelationshipService.new()
	_relationships.name = "RelationshipService"
	add_child(_relationships)

## P17b: the enter/resolve round-trip into the reveal scene. Bootstrap-wired like
## RelationshipService — the test drives its sim-effect path with city_root null.
func _build_transition() -> void:
	_transition = CinematicTransition.new()
	_transition.name = "CinematicTransition"
	_transition.city_root = _city
	_transition.relationship_node = _relationships
	add_child(_transition)

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.set_script(HudScript)
	_hud.night_cycle_node = _night_cycle
	_hud.relationship_node = _relationships
	_hud.transition_node = _transition
	add_child(_hud)
	_transition.hud_layers.append(_hud)  # hide the management panels during the reveal

func _build_jobs() -> void:
	var panel := CanvasLayer.new()
	panel.set_script(JobPanelScript)
	add_child(panel)
	_transition.hud_layers.append(panel)  # hide the job panel during the reveal too
	# The authored seed job; further problems emerge systemically (P08 JobGenerator).
	JobDirector.offer(JobTemplates.intercepted_shipment())

func _quick_load() -> void:
	if SaveService.load_game("quick"):
		print("Quick-loaded.")

func _on_venue_clicked(venue: VenueData) -> void:
	if _hud:
		_hud.show_selection(venue)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				TimeService.toggle_pause()
			KEY_X:
				TimeService.cycle_speed()
			KEY_C:
				_toggle_skyline_camera()
			KEY_F9:
				SaveService.save_game("quick")
				print("Quick-saved.")
			KEY_L:
				# NOT F8/F10: editor-launched games receive the editor's debug shortcuts —
				# F8 stops the game process outright, F10 is swallowed by the debugger.
				# Deferred so the world rebuild happens outside the input flush.
				_quick_load.call_deferred()
			KEY_B:
				# DEBUG: jump straight into the first-person reveal scene (P17b) without
				# waiting for a betrayal telegraph. Arms bengal_lt's intent, then enters.
				_debug_enter_reveal()

func _debug_enter_reveal() -> void:
	var c := GameState.get_character(&"bengal_lt")
	if c == null:
		return
	c.ambition = 0.9
	c.grievance = 0.95
	c.rival_leverage = 0.5
	c.public_trust = 0.1
	c.shared_success = 0.0
	c.betrayal_ticks_until_land = LoyaltyScoring.TELEGRAPH_LEAD_RIVAL_TICKS
	c.betrayal_driving_motive = LoyaltyScoring.driving_motive(c)
	c.motive_revealed = false
	_transition.enter(&"bengal_lt")
