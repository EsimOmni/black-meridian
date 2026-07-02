extends Node3D
## P01 splat benchmark: loads the 542k-splat PLY through GDGS, orbits a camera,
## measures frame times at 1080p with vsync off, prints BENCH_RESULT and quits.
## Run: Godot_console.exe --path . res://scenes/cinematic/splat_bench.tscn

const SPLAT_PATH := "res://assets/splat/bench_542k.ply"
const WARMUP_S := 3.0
const MEASURE_S := 12.0

var _cam: Camera3D
var _label: Label
var _center := Vector3.ZERO
var _radius := 4.0
var _elapsed := 0.0
var _measuring := false
var _shot_taken := false
var _frame_times: Array[float] = []

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	var res: Resource = load(SPLAT_PATH)
	if res == null:
		printerr("BENCH_FAIL: could not load %s (import missing?)" % SPLAT_PATH)
		get_tree().quit(1)
		return
	print("BENCH_INFO point_count=%d aabb=%s" % [res.point_count, res.aabb])

	var splat := GaussianSplatNode.new()
	splat.gaussian = res
	add_child(splat)

	var effect_script := load("res://addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd")
	var compositor := Compositor.new()
	compositor.compositor_effects = [effect_script.new()]
	var env := WorldEnvironment.new()
	env.compositor = compositor
	add_child(env)

	var aabb: AABB = res.aabb
	_center = aabb.get_center()
	_radius = maxf(aabb.size.length() * 0.45, 1.0)

	_cam = Camera3D.new()
	add_child(_cam)
	_update_cam(0.0)
	_cam.current = true

	_label = Label.new()
	_label.position = Vector2(16, 16)
	var ui := CanvasLayer.new()
	ui.add_child(_label)
	add_child(ui)

func _update_cam(t: float) -> void:
	var ang := t * 0.5
	var pos := _center + Vector3(cos(ang) * _radius, _radius * 0.25, sin(ang) * _radius)
	_cam.look_at_from_position(pos, _center, Vector3.UP)

func _process(delta: float) -> void:
	_elapsed += delta
	_update_cam(_elapsed)
	_label.text = "FPS %d  splats 542246  %s" % [
		Engine.get_frames_per_second(),
		"MEASURING" if _measuring else "warmup"]

	if _elapsed < WARMUP_S:
		return
	if not _measuring:
		_measuring = true
		_frame_times.clear()
		return
	_frame_times.append(delta)
	if not _shot_taken and _elapsed >= WARMUP_S + MEASURE_S * 0.5:
		_shot_taken = true
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://docs/prompts/notes/P01-bench-frame.png")
	if _elapsed >= WARMUP_S + MEASURE_S:
		_finish()

func _finish() -> void:
	set_process(false)
	var n := _frame_times.size()
	var total := 0.0
	for ft in _frame_times:
		total += ft
	var avg_fps := n / total
	var sorted: Array[float] = _frame_times.duplicate()
	sorted.sort()
	var p99: float = sorted[int(n * 0.99)]  # 99th percentile frame time = 1% low
	var low1_fps: float = 1.0 / p99
	var vp: Vector2i = get_window().size
	print("BENCH_RESULT frames=%d avg_fps=%.1f low1_fps=%.1f res=%dx%d gpu=%s" % [
		n, avg_fps, low1_fps, vp.x, vp.y,
		RenderingServer.get_video_adapter_name()])
	get_tree().quit(0)
