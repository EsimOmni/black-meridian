extends Node3D
## Bootstrap — the Month-1 entry scene. Seeds the world, builds the greybox city + camera
## + lighting + HUD in code, and wires input (pause/speed/selection) for the 15-minute
## greybox loop (brief §19, Month 1 gate). Real scene composition replaces this later.

const CityViewScript := preload("res://scenes/city/city_view.gd")
const CameraScript := preload("res://scenes/city/management_camera.gd")
const HudScript := preload("res://scenes/ui/hud.gd")
const JobPanelScript := preload("res://scenes/ui/job_panel.gd")

var _hud
var _night_cycle: NightCycle

func _ready() -> void:
	WorldSeed.build()
	_build_lighting()
	_build_city()
	_build_camera()
	_build_night_cycle()
	_build_hud()
	_build_jobs()
	# Start paused so the player makes the first decision (brief §5.1).
	TimeService.set_speed(BM.Speed.PAUSED)

func _build_lighting() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.04, 0.05, 0.07)  # rain-lacquered noir (brief §9.1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.18, 0.20, 0.26)
	e.ambient_light_energy = 0.6
	e.fog_enabled = true
	e.fog_density = 0.01
	e.fog_light_color = Color(0.10, 0.13, 0.18)
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 40, 0)
	sun.light_color = Color(0.85, 0.80, 0.70)  # sodium amber key
	sun.light_energy = 0.9
	add_child(sun)

func _build_city() -> void:
	var city := Node3D.new()
	city.name = "CityView"
	city.set_script(CityViewScript)
	add_child(city)
	city.venue_clicked.connect(_on_venue_clicked)

func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "ManagementCamera"
	cam.set_script(CameraScript)
	cam.position = Vector3(0, 22, 14)
	cam.current = true
	add_child(cam)

## The phase machine is a bootstrap-wired node, NOT an autoload — unit-test scenes of
## other systems must never have phases advancing underneath them (P09).
func _build_night_cycle() -> void:
	_night_cycle = NightCycle.new()
	_night_cycle.name = "NightCycle"
	add_child(_night_cycle)

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.set_script(HudScript)
	_hud.night_cycle_node = _night_cycle
	add_child(_hud)

func _build_jobs() -> void:
	var panel := CanvasLayer.new()
	panel.set_script(JobPanelScript)
	add_child(panel)
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
			KEY_F9:
				SaveService.save_game("quick")
				print("Quick-saved.")
			KEY_L:
				# NOT F8/F10: editor-launched games receive the editor's debug shortcuts —
				# F8 stops the game process outright, F10 is swallowed by the debugger.
				# Deferred so the world rebuild happens outside the input flush.
				_quick_load.call_deferred()
