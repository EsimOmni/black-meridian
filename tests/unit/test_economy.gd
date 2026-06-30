extends SceneTree
## Standalone unit test for the EconomyService pure formulas (brief §7.2).
## Run headless:
##   Godot --headless --path . -s tests/unit/test_economy.gd
## Exits with code 0 on pass, 1 on failure. EconomyMath is a class_name, no autoload needed.

var _failures: int = 0

func _init() -> void:
	_test_control_modifier()
	_test_dirty_income()
	_test_front_clean()
	_test_disruption_reduces_income()
	if _failures == 0:
		print("[PASS] all economy formula tests passed")
		quit(0)
	else:
		printerr("[FAIL] %d economy assertion(s) failed" % _failures)
		quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("  assertion failed: ", msg)

func _test_control_modifier() -> void:
	_check(EconomyMath.control_modifier(BM.ControlState.CONTROLLED) == 1.0, "controlled = 1.0")
	_check(EconomyMath.control_modifier(BM.ControlState.FORTIFIED) > 1.0, "fortified > 1.0")
	_check(EconomyMath.control_modifier(BM.ControlState.UNKNOWN) == 0.0, "unknown = 0.0")
	_check(EconomyMath.control_modifier(BM.ControlState.INFLUENCED) < 1.0, "influenced < 1.0")

func _test_dirty_income() -> void:
	var v := VenueData.new()
	v.type = BM.VenueType.RACKET
	v.base_yield = 200
	v.operational_staff = 2
	v.control_state = BM.ControlState.CONTROLLED
	v.disruption = 0.0
	# demand 1.0, control 1.0, disruption 1.0 => 200 * 1.0 * 2 * 1.0 * 1.0 = 400
	var income := EconomyMath.compute_dirty_income(v, 1.0)
	_check(income == 400, "dirty income == 400 (got %d)" % income)

func _test_front_clean() -> void:
	var v := VenueData.new()
	v.type = BM.VenueType.FRONT
	v.laundering_capacity = 600
	v.front_efficiency = 0.75
	v.operating_cost = 0.18
	# 600 * 0.75 * (1 - 0.18) = 600 * 0.75 * 0.82 = 369
	var clean := EconomyMath.compute_front_clean(v)
	_check(clean == 369, "front clean == 369 (got %d)" % clean)

func _test_disruption_reduces_income() -> void:
	var v := VenueData.new()
	v.type = BM.VenueType.RACKET
	v.base_yield = 200
	v.operational_staff = 2
	v.control_state = BM.ControlState.CONTROLLED
	var full := EconomyMath.compute_dirty_income(v, 1.0)
	v.disruption = 0.5
	var halved := EconomyMath.compute_dirty_income(v, 1.0)
	_check(halved < full, "disruption reduces income (%d < %d)" % [halved, full])
	_check(halved == full / 2, "half disruption halves income (got %d, expected %d)" % [halved, full / 2])
