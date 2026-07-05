extends SceneTree
## Throwaway gate — validate the alien diplomatic tower hero against the 'building' spec.

const GLBValidator := preload("res://tools/validation/glb_validator.gd")

func _init() -> void:
	var spec := GLBValidator.spec_for(&"building")
	var report := GLBValidator.validate_file("res://assets/city/glasswharf_dock/alien_diplomatic_tower.glb", spec)
	print("=== alien_diplomatic_tower vs 'building' spec ===")
	print("PASS: ", report["pass"])
	for check in report["checks"]:
		print("  %-12s %-5s %s" % [check["name"], check["level"], check["detail"]])
	quit(0 if report["pass"] else 1)
