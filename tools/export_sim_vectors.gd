extends SceneTree
## Simulation golden-vector extractor — the Unreal port's behavioral oracle (reboot S2).
##
## READ-ONLY. It builds throwaway DistrictData/VenueData/FactionData in memory, drives the
## four pure-math classes S2 ports, and writes one JSON document. It mutates no shipped
## resource, touches no autoload and must never be given a reason to.
##
## Companion to export_golden_vectors.gd (S1, the hash layers). Kept separate because the
## fixtures are consumed by different tests and the hash corpus is already 634 KB; a single
## file would make a heat mismatch hard to find inside a hash document.
##
## Run:
##   D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . \
##       -s tools/export_sim_vectors.gd -- --out=<abs path>.json
##
## Like S1's extractor it writes the file itself rather than printing to stdout: the
## godot_ai game_helper autoload emits a banner after the script finishes and that trailing
## text corrupts a redirected document.
##
## Autoloads do not exist in a `-s` SceneTree script, so nothing here may touch GameState.
## Every class driven below (EconomyMath, EvidenceMath, PressureMath, OperativeMath) is an
## autoload-free `class_name ... extends RefCounted` with static methods — that is exactly
## why S2's math is extractable this way and the service layer is not.
##
## `[V]` Covers GV-ECON-01..05, GV-HEAT-01..02, GV-EVID-01..03, GV-PRESS-01
## (07_IMPLEMENTATION_ROADMAP.md → S2; tolerances in 08_TEST_STRATEGY.md §5.1).

const SCHEMA := 1
const DEFAULT_OUT := "D:/black-meridian-ue/Tests/Golden/sim_vectors.json"
const ECONOMY_SERVICE_PATH := "res://src/simulation/economy_service.gd"
const WORLD_SEED_PATH := "res://src/core/world_seed.gd"

## Heat constants live on the EconomyService AUTOLOAD, and autoloads do not exist under
## `-s` — naming `EconomyService` at all drags that script into compilation, where it fails
## on its own `TimeService` reference. `WorldSeed` fails the same way via `GameState`.
## So those constants are PARSED OUT OF THE SOURCE, never transcribed: a transcribed
## constant is exactly the silently-wrong-but-deterministic failure S1 hit.
var _const: Dictionary = {}

func _parse_const(path: String, names: Array[String]) -> Dictionary:
	var src := FileAccess.get_file_as_string(path)
	assert(not src.is_empty(), "cannot read %s" % path)
	var out: Dictionary = {}
	for name in names:
		var re := RegEx.create_from_string(
			"const\\s+%s\\s*:=\\s*(-?[0-9]*\\.?[0-9]+)" % name)
		var m := re.search(src)
		assert(m != null, "cannot parse const %s from %s" % [name, path])
		out[name] = float(m.get_string(1))
	return out

func _init() -> void:
	_const = _parse_const(ECONOMY_SERVICE_PATH, [
		"HEAT_RISE_SCALE", "EXPOSURE_HEAT_FLOOR", "HEAT_DECAY_PER_TICK",
		"HEAT_INSPECTION_THRESHOLD", "HEAT_INSPECTION_WARN", "HEAT_INSPECTION_REARM",
		"INSPECTION_DURATION_TICKS", "INSPECTION_DISRUPTION",
		"FRONT_PRESSURE_STEP", "FRONT_PRESSURE_COST", "FRONT_CAPACITY_MAX",
	] as Array[String])
	_const.merge(_parse_const(WORLD_SEED_PATH, ["FREE_RESERVE"] as Array[String]))

	var out := {
		"schema": SCHEMA,
		"source": "godot-final",
		"godot_version": Engine.get_version_info().string,
		"note": "Simulation vectors for reboot S2 (economy, heat, evidence, pressure, operatives). Floats are JSON numbers: these are state values compared at 1e-5 per 08 §5.1, not 64-bit integers, so the double round-trip is lossless at this precision. Discrete fields (kind, id, index, counts, booleans) are compared EXACTLY.",
		"econ": _econ_vectors(),
		"heat": _heat_vectors(),
		"evidence": _evidence_vectors(),
		"pressure": _pressure_vectors(),
		"operatives": _operative_vectors(),
	}

	var path := _out_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		quit(1)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()

	print("wrote %s — %d econ, %d heat, %d evidence, %d pressure, %d operatives rows" % [
		path,
		out["econ"]["rows"].size(), out["heat"]["rows"].size(),
		out["evidence"]["rows"].size(), out["pressure"]["rows"].size(),
		out["operatives"]["rows"].size()])
	quit(0)

func _out_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			return arg.trim_prefix("--out=")
	return DEFAULT_OUT

# --- Fixtures -----------------------------------------------------------------
## Built by hand rather than from WorldSeed: WorldSeed.build() writes into the GameState
## autoload, which does not exist under `-s`. Hand-built data also lets the sweeps below
## cross thresholds the shipped seed never reaches.

func _racket(id: String, base_yield: int, staff: int, control: int,
		risk: float = 0.3) -> VenueData:
	var v := VenueData.new()
	v.id = StringName(id)
	v.type = BM.VenueType.RACKET
	v.owner_faction = &"compact"
	v.control_state = control
	v.base_yield = base_yield
	v.operational_staff = staff
	v.racket_risk = risk
	return v

func _front(id: String, capacity: int, efficiency: float,
		operating_cost: float) -> VenueData:
	var v := VenueData.new()
	v.id = StringName(id)
	v.type = BM.VenueType.FRONT
	v.owner_faction = &"compact"
	v.control_state = BM.ControlState.CONTROLLED
	v.laundering_capacity = capacity
	v.front_efficiency = efficiency
	v.operating_cost = operating_cost
	return v

func _district(id: String, prosperity: float, visibility: float) -> DistrictData:
	var d := DistrictData.new()
	d.id = StringName(id)
	d.prosperity = prosperity
	d.visibility = visibility
	return d

func _case(id: String, kind: int, weight: float) -> EvidenceCaseData:
	var c := EvidenceCaseData.new()
	c.id = StringName(id)
	c.kind = kind
	c.weight = weight
	c.label = EvidenceMath.KIND_LABELS[kind]
	return c

# --- GV-ECON-01..05 -----------------------------------------------------------

## Every control state x staff x disruption x pause, plus the demand and front/exposure
## formulas. Sweeps cross each branch of compute_dirty_income rather than sampling one
## happy path: wrong venue type, paused, zero staff, and the roundf boundary.
func _econ_vectors() -> Dictionary:
	var rows: Array = []

	# GV-ECON-02 — the control modifier table, every enum value including UNKNOWN.
	var modifiers: Array = []
	for state in BM.ControlState.values():
		modifiers.append({
			"control_state": state,
			"modifier": EconomyMath.control_modifier(state),
		})

	# GV-ECON-03 — DistrictDemand = 0.5 + prosperity, across the full 0..1 range.
	var demand: Array = []
	for prosperity in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]:
		demand.append({
			"prosperity": prosperity,
			"demand": _district("d", prosperity, 0.5).district_demand(),
		})

	# GV-ECON-01 — DirtyIncome. base_yield x demand x staff x control x (1-disruption),
	# rounded once at the end.
	for base_yield in [0, 1, 40, 120, 333]:
		for staff in [0, 1, 3, 7]:
			for state in BM.ControlState.values():
				for disruption in [0.0, 0.25, 0.5, 0.8, 1.0]:
					for prosperity in [0.0, 0.5, 1.0]:
						var v := _racket("r", base_yield, staff, state)
						v.disruption = disruption
						var d := _district("d", prosperity, 0.5)
						rows.append({
							"kind": "dirty_income",
							"base_yield": base_yield,
							"staff": staff,
							"control_state": state,
							"disruption": disruption,
							"prosperity": prosperity,
							"demand": d.district_demand(),
							"paused": false,
							"income": EconomyMath.compute_dirty_income(v, d.district_demand()),
						})

	# The two early-return branches: a paused racket and a non-racket venue both yield 0
	# even with otherwise-productive numbers.
	var paused := _racket("r", 120, 3, BM.ControlState.CONTROLLED)
	paused.paused = true
	rows.append({
		"kind": "dirty_income",
		"base_yield": 120, "staff": 3,
		"control_state": BM.ControlState.CONTROLLED,
		"disruption": 0.0, "prosperity": 0.5, "demand": 1.0,
		"paused": true,
		"income": EconomyMath.compute_dirty_income(paused, 1.0),
	})
	rows.append({
		"kind": "dirty_income_non_racket",
		"venue_type": BM.VenueType.FRONT,
		"income": EconomyMath.compute_dirty_income(
			_front("f", 500, 0.7, 0.15), 1.0),
	})

	# GV-ECON-04 — CleanCapital = capacity x efficiency x (1 - operating_cost).
	for capacity in [0, 100, 500, 1500]:
		for efficiency in [0.0, 0.5, 0.7, 1.0]:
			for operating_cost in [0.0, 0.15, 0.5, 1.0]:
				rows.append({
					"kind": "front_clean",
					"laundering_capacity": capacity,
					"front_efficiency": efficiency,
					"operating_cost": operating_cost,
					"clean": EconomyMath.compute_front_clean(
						_front("f", capacity, efficiency, operating_cost)),
				})
	rows.append({
		"kind": "front_clean_non_front",
		"venue_type": BM.VenueType.RACKET,
		"clean": EconomyMath.compute_front_clean(
			_racket("r", 120, 3, BM.ControlState.CONTROLLED)),
	})

	# GV-ECON-05 — ExposureGain, including the 1e-4 scalar. Overflow spans the range a
	# real settle produces; risk and visibility span their declared 0..1.
	for overflow in [0, 1, 250, 1000, 12500]:
		for risk in [0.0, 0.2, 0.3, 0.6, 1.0]:
			for visibility in [0.0, 0.25, 0.5, 0.9, 1.0]:
				rows.append({
					"kind": "exposure",
					"overflow": overflow,
					"racket_risk": risk,
					"visibility": visibility,
					"exposure": EconomyMath.compute_exposure(
						_racket("r", 120, 3, BM.ControlState.CONTROLLED, risk),
						_district("d", 0.5, visibility), overflow),
				})
	rows.append({
		"kind": "exposure_non_racket",
		"venue_type": BM.VenueType.FRONT,
		"exposure": EconomyMath.compute_exposure(
			_front("f", 500, 0.7, 0.15), _district("d", 0.5, 0.5), 1000),
	})

	return {
		"control_modifier": modifiers,
		"district_demand": demand,
		"exposure_scalar": 0.0001,
		"rows": rows,
	}

# --- GV-HEAT-01..02 -----------------------------------------------------------

## The disruption ramp and the rise/decay step. `[V]` The divisor is (1.0 - GRACE), not a
## literal 0.7 — see 03_BEHAVIORAL_PORT_MATRIX.md. The sweep steps ON the grace boundary
## deliberately (<= is a no-op there) and just past it.
func _heat_vectors() -> Dictionary:
	var rows: Array = []

	# GV-HEAT-02 — disruption_from_heat across the whole curve.
	for heat in [0.0, 0.1, 0.29, 0.3, 0.3001, 0.35, 0.5, 0.65, 0.9, 1.0]:
		rows.append({
			"kind": "disruption_from_heat",
			"local_heat": heat,
			"disruption": EconomyMath.disruption_from_heat(heat),
		})

	# GV-HEAT-01 — the rise/decay step, reproducing _update_district_heat's arithmetic.
	# Rise clamps [0,1]; decay uses maxf(0, ...) — the asymmetry is deliberate, and decay
	# is suppressed entirely while an inspection runs.
	for heat: float in [0.0, 0.0003, 0.2, 0.5, 0.97, 1.0]:
		for exposure: float in [0.0, 0.0079, 0.008, 0.02, 0.5, 2.0]:
			for inspection_ticks: int in [0, 1, 30]:
				var next := heat
				if exposure >= _const["EXPOSURE_HEAT_FLOOR"]:
					next = clampf(heat + exposure * _const["HEAT_RISE_SCALE"], 0.0, 1.0)
				elif inspection_ticks == 0:
					next = maxf(0.0, heat - _const["HEAT_DECAY_PER_TICK"])
				rows.append({
					"kind": "heat_step",
					"local_heat": heat,
					"tick_exposure": exposure,
					"inspection_ticks": inspection_ticks,
					"next_heat": next,
					"rose": exposure >= _const["EXPOSURE_HEAT_FLOOR"],
					"decayed": exposure < _const["EXPOSURE_HEAT_FLOOR"] \
						and inspection_ticks == 0,
				})

	return {
		"exposure_heat_floor": _const["EXPOSURE_HEAT_FLOOR"],
		"heat_rise_scale": _const["HEAT_RISE_SCALE"],
		"heat_decay_per_tick": _const["HEAT_DECAY_PER_TICK"],
		"heat_disruption_grace": EconomyMath.HEAT_DISRUPTION_GRACE,
		"heat_disruption_max": EconomyMath.HEAT_DISRUPTION_MAX,
		# The inspection latch's own constants. Emitted so the C++ tests can assert against
		# the fixture instead of re-typing literals — S2 forbids deriving thresholds from
		# literals in tests (`[V]` the P06d instrument-error lesson).
		"heat_inspection_threshold": _const["HEAT_INSPECTION_THRESHOLD"],
		"heat_inspection_warn": _const["HEAT_INSPECTION_WARN"],
		"heat_inspection_rearm": _const["HEAT_INSPECTION_REARM"],
		"inspection_duration_ticks": int(_const["INSPECTION_DURATION_TICKS"]),
		"inspection_disruption": _const["INSPECTION_DISRUPTION"],
		"front_pressure_step": int(_const["FRONT_PRESSURE_STEP"]),
		"front_pressure_cost": int(_const["FRONT_PRESSURE_COST"]),
		"front_capacity_max": int(_const["FRONT_CAPACITY_MAX"]),
		"rows": rows,
	}

# --- GV-EVID-01..03 -----------------------------------------------------------

## Case pressure, combined pressure, the hash-selected kind, the id format, and the
## cap-overflow rule. `[V]` combined_pressure is UNCLAMPED and can exceed 1.0.
func _evidence_vectors() -> Dictionary:
	var rows: Array = []

	# GV-EVID-01 — case_pressure (summed, clamped 0..1) and combined_pressure (unclamped).
	var weight_sets: Array = [
		[],
		[0.0],
		[0.25],
		[0.5, 0.5],
		[0.3, 0.3, 0.3],
		[0.4, 0.4, 0.4, 0.4],      # sums past 1.0 — case_pressure clamps, combined does not
		[1.0, 1.0, 1.0, 1.0],
	]
	for weights in weight_sets:
		var cases: Array[EvidenceCaseData] = []
		var i := 0
		for w in weights:
			cases.append(_case("case@gw@%d@0" % i, i % BM.EvidenceKind.size(), w))
			i += 1
		for heat in [0.0, 0.3, 0.5, 1.0]:
			rows.append({
				"kind": "pressure",
				"weights": weights,
				"local_heat": heat,
				"case_pressure": EvidenceMath.case_pressure(cases),
				"combined_pressure": EvidenceMath.combined_pressure(heat, cases),
			})

	# GV-EVID-02 — kind_for is posmod(hash(source_id), 4): a deterministic hash, never a
	# roll. NOTE this is Godot's built-in String.hash() (DJB2), NOT the _avalanche mix the
	# S1 fixture covers — a C++ port must route it through BMHash::StringHash.
	for source in _kind_sources():
		rows.append({
			"kind": "kind_for",
			"source_id": source,
			"string_hash": source.hash(),
			"evidence_kind": EvidenceMath.kind_for(StringName(source)),
		})

	# GV-EVID-03 — the case id format, which job ids parse. Load-bearing, not cosmetic.
	for district in ["gw", "glass_wharf", "d"]:
		for k in BM.EvidenceKind.values():
			for tick in [0, 1, 120, 1800, 65535]:
				rows.append({
					"kind": "case_id",
					"district": district,
					"evidence_kind": k,
					"tick": tick,
					"case_id": "case@%s@%d@%d" % [district, k, tick],
				})

	# GV-EVID-01 (cap) — at MAX_CASES the OLDEST (index 0) grows; no fifth case appears.
	# Also covers the same-id merge path and the deposit <= 0 no-op.
	rows.append_array(_deposit_rows())

	# erode_strongest: hits only the strongest, strict > so ties go to the earliest, and
	# a case at or below 0 is erased outright (no clamp before the check).
	rows.append_array(_erode_rows())

	return {
		"max_cases": EvidenceMath.MAX_CASES,
		"case_pressure_weight": EvidenceMath.CASE_PRESSURE_WEIGHT,
		"kind_count": BM.EvidenceKind.size(),
		"id_format": "case@%s@%d@%d",
		"rows": rows,
	}

func _kind_sources() -> Array[String]:
	var sources: Array[String] = [
		"gw_contraband", "gw_clinic", "gw_saltworks",
		"job@bury@0", "gen@retaliation@gw_contraband@corvine@120",
		"", " ", "@", "0",
		"ışık_çürüyen", "黑子午线", "😀",
	]
	return sources

## deposit() mutates the district in place, so each row gets a fresh one.
func _deposit_rows() -> Array:
	var rows: Array = []

	# Fill to the cap one deposit at a time, then one past it.
	var d := _district("gw", 0.5, 0.5)
	for i in 6:
		var source := "src_%d" % i
		var before := d.evidence_cases.size()
		var c := EvidenceMath.deposit(d, 0.2, StringName(source), i)
		rows.append({
			"kind": "deposit",
			"sequence": i,
			"source_id": source,
			"amount": 0.2,
			"tick": i,
			"cases_before": before,
			"cases_after": d.evidence_cases.size(),
			"returned_id": String(c.id) if c != null else "",
			"returned_weight": c.weight if c != null else 0.0,
			"grew_oldest": before >= EvidenceMath.MAX_CASES,
			"weights_after": _weights_of(d),
		})

	# Same source + same tick = same id -> merges into the existing case, clamped at 1.0.
	var merge := _district("gw", 0.5, 0.5)
	EvidenceMath.deposit(merge, 0.6, &"same", 7)
	var merged := EvidenceMath.deposit(merge, 0.9, &"same", 7)
	rows.append({
		"kind": "deposit_merge",
		"amounts": [0.6, 0.9],
		"cases_after": merge.evidence_cases.size(),
		"returned_weight": merged.weight,
		"weights_after": _weights_of(merge),
	})

	# amount <= 0 is a no-op returning null.
	var noop := _district("gw", 0.5, 0.5)
	for amount in [0.0, -0.5]:
		var r := EvidenceMath.deposit(noop, amount, &"src", 0)
		rows.append({
			"kind": "deposit_noop",
			"amount": amount,
			"returned_null": r == null,
			"cases_after": noop.evidence_cases.size(),
		})

	return rows

func _erode_rows() -> Array:
	var rows: Array = []

	for amount in [0.0, 0.1, 0.35, 0.5, 2.0]:
		var d := _district("gw", 0.5, 0.5)
		# Deliberate tie on 0.5 between index 0 and 2: strict > means the EARLIEST wins.
		d.evidence_cases = [
			_case("case@gw@0@0", 0, 0.5),
			_case("case@gw@1@1", 1, 0.2),
			_case("case@gw@2@2", 2, 0.5),
		] as Array[EvidenceCaseData]
		var strongest := EvidenceMath.strongest_case(d)
		var strongest_id := String(strongest.id) if strongest != null else ""
		EvidenceMath.erode_strongest(d, amount)
		rows.append({
			"kind": "erode_strongest",
			"amount": amount,
			"strongest_id": strongest_id,
			"cases_after": d.evidence_cases.size(),
			"ids_after": _ids_of(d),
			"weights_after": _weights_of(d),
		})

	# remove_case is the aimed mechanism — distinct from passive erosion.
	for target in ["case@gw@1@1", "case@gw@missing@0"]:
		var d := _district("gw", 0.5, 0.5)
		d.evidence_cases = [
			_case("case@gw@0@0", 0, 0.5),
			_case("case@gw@1@1", 1, 0.2),
		] as Array[EvidenceCaseData]
		rows.append({
			"kind": "remove_case",
			"target_id": target,
			"removed": EvidenceMath.remove_case(d, StringName(target)),
			"cases_after": d.evidence_cases.size(),
			"ids_after": _ids_of(d),
		})

	return rows

func _weights_of(d: DistrictData) -> Array:
	var out: Array = []
	for c in d.evidence_cases:
		out.append(c.weight)
	return out

func _ids_of(d: DistrictData) -> Array:
	var out: Array = []
	for c in d.evidence_cases:
		out.append(String(c.id))
	return out

# --- GV-PRESS-01 --------------------------------------------------------------

## City pressure is the MEAN of district combined pressure, never a sum, and step_central
## is a tracker: above the floor it moves TOWARD the city signal (so it can fall), below
## the floor it decays at a fixed rate.
func _pressure_vectors() -> Dictionary:
	var rows: Array = []

	# city_pressure — the mean, including the empty-array guard.
	var district_sets: Array = [
		[],
		[0.0],
		[0.5],
		[0.25, 0.5],
		[0.0, 0.0, 0.9],
		[0.4, 0.4, 0.4],
		[1.0, 1.0, 1.0, 1.0],
	]
	for heats in district_sets:
		var districts: Array[DistrictData] = []
		var i := 0
		for h in heats:
			var d := _district("d%d" % i, 0.5, 0.5)
			d.local_heat = h
			districts.append(d)
			i += 1
		rows.append({
			"kind": "city_pressure_no_cases",
			"local_heats": heats,
			"city": PressureMath.city_pressure(districts),
		})

	# The same means, but with cases attached — proves the city signal reads combined
	# pressure (heat + 0.5 x weights), not raw heat.
	for heats in [[0.2], [0.2, 0.2], [0.0, 0.6]]:
		var districts: Array[DistrictData] = []
		var i := 0
		for h in heats:
			var d := _district("d%d" % i, 0.5, 0.5)
			d.local_heat = h
			d.evidence_cases = [_case("case@d%d@0@0" % i, 0, 0.4)] as Array[EvidenceCaseData]
			districts.append(d)
			i += 1
		rows.append({
			"kind": "city_pressure_with_cases",
			"local_heats": heats,
			"case_weight_each": 0.4,
			"city": PressureMath.city_pressure(districts),
		})

	# step_central — the rise/decay integrator, stepping across the floor in both
	# directions and at the clamps.
	for current in [0.0, 0.1, 0.35, 0.5, 0.75, 1.0]:
		for city in [0.0, 0.2, 0.3499, 0.35, 0.4, 0.6, 1.0, 1.5]:
			rows.append({
				"kind": "step_central",
				"current": current,
				"city": city,
				"next": PressureMath.step_central(current, city),
				"rising": city >= PressureMath.CENTRAL_RISE_FLOOR,
			})

	return {
		"central_rise_floor": PressureMath.CENTRAL_RISE_FLOOR,
		"central_rise_scale": PressureMath.CENTRAL_RISE_SCALE,
		"central_decay_per_tick": PressureMath.CENTRAL_DECAY_PER_TICK,
		"central_alert_threshold": PressureMath.CENTRAL_ALERT_THRESHOLD,
		"central_alert_rearm": PressureMath.CENTRAL_ALERT_REARM,
		"central_alert_duration_ticks": PressureMath.CENTRAL_ALERT_DURATION_TICKS,
		"central_alert_inspection_relief": PressureMath.CENTRAL_ALERT_INSPECTION_RELIEF,
		"rows": rows,
	}

# --- Operative conservation ---------------------------------------------------

## free = pool - assigned, derived and never stored; assign/recall MOVE staff and never
## mint it. Both verbs are ownership-gated and return the count actually moved.
##
## `[V]` On `conserved` vs `over_assigned`: the real invariant is that `operative_pool` is
## NEVER written by OperativeMath (`pool_unchanged`). The stronger identity
## `assigned + free == pool` holds ONLY while `assigned <= pool`. When a fixture starts
## over-assigned (pool 0 with staff on a venue, pool 2 with staff 4 — reachable in the
## shipped game via an ownership flip, which moves `owner_faction` without touching
## `operational_staff`), `free_pool`'s `maxi(0, ...)` floors the negative remainder and the
## identity breaks by design. Those rows are flagged, not "wrong": a port that makes them
## balance has changed the behavior.
func _operative_vectors() -> Dictionary:
	var rows: Array = []

	for pool in [0, 2, 5, 9]:
		for staff in [0, 1, 4]:
			for n in [-1, 0, 1, 3, 99]:
				for owned in [true, false]:
					var ctx := _operative_ctx(pool, staff, owned)
					var faction: FactionData = ctx["faction"]
					var venue: VenueData = ctx["venue"]
					var districts: Array[DistrictData] = ctx["districts"]

					var free_before := OperativeMath.free_pool(faction, districts)
					var moved := OperativeMath.assign(faction, venue, n, districts)
					rows.append({
						"kind": "assign",
						"pool": pool, "staff_before": staff, "n": n, "owned": owned,
						"assigned_before": OperativeMath.assigned_sum(faction, districts) - moved,
						"free_before": free_before,
						"moved": moved,
						"staff_after": venue.operational_staff,
						"free_after": OperativeMath.free_pool(faction, districts),
						"pool_after": faction.operative_pool,
						"pool_unchanged": faction.operative_pool == pool,
						"over_assigned": OperativeMath.assigned_sum(faction, districts) > pool,
						"conserved": OperativeMath.assigned_sum(faction, districts) \
							+ OperativeMath.free_pool(faction, districts) == faction.operative_pool,
					})

					var ctx2 := _operative_ctx(pool, staff, owned)
					var faction2: FactionData = ctx2["faction"]
					var venue2: VenueData = ctx2["venue"]
					var districts2: Array[DistrictData] = ctx2["districts"]
					var recalled := OperativeMath.recall(faction2, venue2, n)
					rows.append({
						"kind": "recall",
						"pool": pool, "staff_before": staff, "n": n, "owned": owned,
						"moved": recalled,
						"staff_after": venue2.operational_staff,
						"free_after": OperativeMath.free_pool(faction2, districts2),
						"pool_after": faction2.operative_pool,
						"pool_unchanged": faction2.operative_pool == pool,
						"over_assigned": OperativeMath.assigned_sum(faction2, districts2) > pool,
						"conserved": OperativeMath.assigned_sum(faction2, districts2) \
							+ OperativeMath.free_pool(faction2, districts2) == faction2.operative_pool,
					})

	# `[V]` The known leak: an ownership flip moves owner_faction WITHOUT touching
	# operational_staff, so operatives transfer with the venue and free_pool's maxi(0, ...)
	# absorbs the mismatch. Recorded so the port reproduces it deliberately.
	var ctx3 := _operative_ctx(5, 4, true)
	var faction3: FactionData = ctx3["faction"]
	var venue3: VenueData = ctx3["venue"]
	var districts3: Array[DistrictData] = ctx3["districts"]
	var before_flip := OperativeMath.free_pool(faction3, districts3)
	venue3.owner_faction = &"corvine"
	rows.append({
		"kind": "ownership_flip_leak",
		"pool": 5,
		"staff_on_flipped_venue": venue3.operational_staff,
		"free_before_flip": before_flip,
		"free_after_flip": OperativeMath.free_pool(faction3, districts3),
		"assigned_after_flip": OperativeMath.assigned_sum(faction3, districts3),
	})

	return {
		"free_reserve": int(_const["FREE_RESERVE"]),
		"rows": rows,
	}

func _operative_ctx(pool: int, staff: int, owned: bool) -> Dictionary:
	var faction := FactionData.new()
	faction.id = &"compact"
	faction.operative_pool = pool

	var venue := _racket("r", 120, staff, BM.ControlState.CONTROLLED)
	if not owned:
		venue.owner_faction = &"corvine"

	var d := _district("gw", 0.5, 0.5)
	d.venues = [venue] as Array[VenueData]

	return {
		"faction": faction,
		"venue": venue,
		"districts": [d] as Array[DistrictData],
	}
