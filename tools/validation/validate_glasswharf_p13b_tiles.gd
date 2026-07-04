extends SceneTree

const GLBValidator := preload("res://tools/validation/glb_validator.gd")

const FILES := [
	"res://assets/city/glasswharf_dock/ground_frontage_b.glb",
	"res://assets/city/glasswharf_dock/mid_floor_b.glb",
	"res://assets/city/glasswharf_dock/roof_cap_b.glb",
	"res://assets/city/glasswharf_dock/tower_mid.glb",
	"res://assets/city/glasswharf_dock/tower_cap.glb",
	"res://assets/city/glasswharf_dock/transit_pier.glb",
	"res://assets/city/glasswharf_dock/transit_deck.glb",
]

func _init() -> void:
	var spec := GLBValidator.spec_for(&"kit_tile")
	var failed := false
	var lines: Array[String] = []
	for path in FILES:
		var report := GLBValidator.validate_file(path, spec)
		lines.append("%s pass=%s" % [path, report["pass"]])
		for check in report["checks"]:
			lines.append("  %s %s %s" % [check["name"], check["level"], check["detail"]])
		if not report["pass"]:
			failed = true
	var f := FileAccess.open("res://tools/validation/validate_glasswharf_p13b_tiles.report.txt", FileAccess.WRITE)
	for line in lines:
		print(line)
		f.store_line(line)
	f.close()
	quit(1 if failed else 0)
