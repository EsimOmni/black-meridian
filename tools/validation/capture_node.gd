extends Node
## P14 capture node — lives inside a scene run normally (autoloads active, unlike -s mode).
## Waits for the city to assemble, saves a management-camera PNG, quits. Throwaway probe.

@export var out_path: String = "user://city_capture.png"
var _frames := 0

func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 30:
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_path)
	print("[capture] wrote ", out_path, " (", img.get_width(), "x", img.get_height(), ")")
	get_tree().quit(0)
