extends SceneTree
## Standalone unit test for KitAssembler pure planning (P14). Building form is a pure function
## of VenueData + DistrictData — this asserts that mapping without a scene tree.
## Run headless:
##   Godot --headless --path . -s tests/unit/test_kit_assembler.gd
## Exits 0 on pass, 1 on failure. KitAssembler is a class_name, no autoload needed.

var _failures: int = 0

func _init() -> void:
	_test_family_selection()
	_test_floors_from_influence()
	_test_ground_module_per_type()
	_test_variation_deterministic()
	_test_transit_shape()
	if _failures == 0:
		print("[PASS] all kit assembler plan tests passed")
		quit(0)
	else:
		printerr("[FAIL] %d kit assembler assertion(s) failed" % _failures)
		quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("  assertion failed: ", msg)

func _venue(id: StringName, type: BM.VenueType) -> VenueData:
	var v := VenueData.new()
	v.id = id
	v.type = type
	return v

func _district(influence: float) -> DistrictData:
	var d := DistrictData.new()
	d.influence = influence
	return d

func _test_family_selection() -> void:
	_check(KitAssembler.family_for(_venue(&"a", BM.VenueType.TRANSIT_NODE)) == KitAssembler.Family.TRANSIT,
		"transit node -> TRANSIT")
	_check(KitAssembler.family_for(_venue(&"a", BM.VenueType.POLITICAL_OFFICE)) == KitAssembler.Family.TOWER,
		"political office -> TOWER")
	_check(KitAssembler.family_for(_venue(&"a", BM.VenueType.INTELLIGENCE_NODE)) == KitAssembler.Family.TOWER,
		"intelligence node -> TOWER")
	_check(KitAssembler.family_for(_venue(&"a", BM.VenueType.RACKET)) == KitAssembler.Family.WAREHOUSE,
		"racket -> WAREHOUSE")
	_check(KitAssembler.family_for(_venue(&"a", BM.VenueType.FRONT)) == KitAssembler.Family.WAREHOUSE,
		"front -> WAREHOUSE")

func _test_floors_from_influence() -> void:
	_check(KitAssembler.floors_for(_district(0.0)) == 2, "influence 0.0 -> 2 floors")
	_check(KitAssembler.floors_for(_district(1.0)) == 6, "influence 1.0 -> 6 floors")
	# Monotonic: more influence never yields fewer floors.
	_check(KitAssembler.floors_for(_district(0.75)) >= KitAssembler.floors_for(_district(0.25)),
		"floors monotonic in influence")
	_check(KitAssembler.floors_for(null) == 2, "null district -> floor of range (2)")

func _test_ground_module_per_type() -> void:
	var front := KitAssembler.plan_building(_venue(&"f", BM.VenueType.FRONT), _district(0.5))
	_check(front.ground == &"ground_frontage_b", "FRONT -> shutter ground (_b)")
	var racket := KitAssembler.plan_building(_venue(&"r", BM.VenueType.RACKET), _district(0.5))
	_check(racket.ground == &"ground_frontage", "RACKET -> loading-door ground")

func _test_variation_deterministic() -> void:
	var v := _venue(&"stable_id", BM.VenueType.RACKET)
	var d := _district(0.5)
	var p1 := KitAssembler.plan_building(v, d)
	var p2 := KitAssembler.plan_building(v, d)
	_check(p1.cap == p2.cap and p1.mids == p2.mids, "same id -> identical plan (deterministic)")
	# The two known ids exercise both variation branches so neither is dead.
	var a := KitAssembler.plan_building(_venue(&"gw_dock_01", BM.VenueType.RACKET), d)
	var b := KitAssembler.plan_building(_venue(&"gw_dock_02", BM.VenueType.RACKET), d)
	_check(a.cap in [&"roof_cap", &"roof_cap_b"], "warehouse cap is a roof_cap variant")
	_check(b.cap in [&"roof_cap", &"roof_cap_b"], "warehouse cap is a roof_cap variant")

func _test_transit_shape() -> void:
	var p := KitAssembler.plan_building(_venue(&"t", BM.VenueType.TRANSIT_NODE), _district(0.9))
	_check(p.ground == &"transit_pier", "transit ground = pier")
	_check(p.cap == &"transit_deck", "transit cap = deck")
	_check(p.mids.is_empty(), "transit has no mid stack")
