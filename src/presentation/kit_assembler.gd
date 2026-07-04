class_name KitAssembler
extends RefCounted
## P14 — turns a venue's strategic state into an assembled kit building (brief §1: the city
## shows the state). PURE DERIVATION: building form is a function of DistrictData + VenueData
## read at rebuild time — no authoritative state, no RNG, no state in scene nodes. GameState
## stays authoritative; this is presentation. `plan_building` is a pure Dictionary (unit-tested
## with no scene tree); `assemble` builds the tile stack from a plan.

const CELL := 4.5   ## grid cell / floor band (P13 grid contract)
const KIT_DIR := "res://assets/city/glasswharf_dock/"

## Module GLB paths, keyed by module name. One load per key, duplicated per instance.
const MODULES := {
	&"ground_frontage": KIT_DIR + "ground_frontage.glb",
	&"ground_frontage_b": KIT_DIR + "ground_frontage_b.glb",
	&"mid_floor": KIT_DIR + "mid_floor.glb",
	&"mid_floor_b": KIT_DIR + "mid_floor_b.glb",
	&"roof_cap": KIT_DIR + "roof_cap.glb",
	&"roof_cap_b": KIT_DIR + "roof_cap_b.glb",
	&"tower_mid": KIT_DIR + "tower_mid.glb",
	&"tower_cap": KIT_DIR + "tower_cap.glb",
	&"transit_pier": KIT_DIR + "transit_pier.glb",
	&"transit_deck": KIT_DIR + "transit_deck.glb",
}

enum Family { WAREHOUSE, TOWER, TRANSIT }

## Per-module loaded-scene cache (module key -> PackedScene root), so 12 GLBs parse once even
## across ~40 venues. Static: shared for the process lifetime; cleared only if assets change.
static var _scene_cache: Dictionary = {}

## --- PURE PLANNING (no scene tree — unit-testable) -------------------------------------------

## Family from venue type (brief §7.1 typologies → §9.1 dialects).
static func family_for(venue: VenueData) -> Family:
	match venue.type:
		BM.VenueType.TRANSIT_NODE:
			return Family.TRANSIT
		BM.VenueType.POLITICAL_OFFICE, BM.VenueType.INTELLIGENCE_NODE:
			return Family.TOWER
		_:
			return Family.WAREHOUSE

## Mid-floor count from district influence: 2..6 (an influential plot reads taller — brief §1).
## A null district (unplaced venue) falls back to the floor of the range.
static func floors_for(district: DistrictData) -> int:
	var influence := district.influence if district else 0.0
	return 2 + int(clampf(influence, 0.0, 1.0) * 4.0)

## Deterministic variation bit from the venue id — same id always plans the same building
## (save-safe, no RNG), different ids break the copy-paste read (P13b variation).
static func _variant(venue: VenueData) -> int:
	return int(hash(venue.id)) & 1

## Pure building plan. Returns a Dictionary the assembler consumes; nothing here touches nodes.
## Shape: { family, floors, ground, mids: Array[StringName], cap }.
static func plan_building(venue: VenueData, district: DistrictData) -> Dictionary:
	var fam := family_for(venue)
	var floors := floors_for(district)
	var v := _variant(venue)

	if fam == Family.TRANSIT:
		# Transit is pier + deck, not a floor stack (see assemble()).
		return {"family": fam, "floors": 0, "ground": &"transit_pier",
			"mids": [] as Array, "cap": &"transit_deck"}

	if fam == Family.TOWER:
		var tower_mids: Array = []
		for i in floors:
			tower_mids.append(&"tower_mid")
		return {"family": fam, "floors": floors, "ground": &"tower_mid",
			"mids": tower_mids, "cap": &"tower_cap"}

	# Warehouse: ground reads the venue purpose (FRONT = shutter, else loading door); mid/cap
	# variation from the id bit so neighbours don't read identical.
	var ground: StringName = &"ground_frontage_b" if venue.type == BM.VenueType.FRONT else &"ground_frontage"
	var mid: StringName = &"mid_floor_b" if v == 1 else &"mid_floor"
	var cap: StringName = &"roof_cap_b" if v == 1 else &"roof_cap"
	var mids: Array = []
	for i in floors:
		mids.append(mid)
	return {"family": fam, "floors": floors, "ground": ground, "mids": mids, "cap": cap}

## --- NODE BUILDING ---------------------------------------------------------------------------

## Load a module GLB once (cached), return a fresh duplicated instance ready to parent.
static func _instance_module(key: StringName) -> Node3D:
	if not _scene_cache.has(key):
		var path: String = MODULES[key]
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_file(path, state)
		if err != OK:
			push_error("KitAssembler: failed to load %s (err %d)" % [path, err])
			_scene_cache[key] = null
		else:
			_scene_cache[key] = doc.generate_scene(state)
	var cached: Node = _scene_cache[key]
	if cached == null:
		return null
	return cached.duplicate() as Node3D

## Build the tile stack for a plan under a fresh Node3D (base-center at origin, y=0 = ground).
## Placement = P13 grid contract: each band at cell_index × CELL, tiles butt flush.
static func assemble(plan: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Building"

	if plan.family == Family.TRANSIT:
		# Pier at ground, deck bearing on top of it (deck sits at the pier's height band).
		var pier := _instance_module(plan.ground)
		if pier:
			root.add_child(pier)
		var deck := _instance_module(plan.cap)
		if deck:
			deck.position = Vector3(0.0, CELL, 0.0)
			root.add_child(deck)
		return root

	# Warehouse / tower: ground (band 0), mids (bands 1..N), cap (band N+1).
	var ground := _instance_module(plan.ground)
	if ground:
		root.add_child(ground)
	var band := 1
	for mid_key in plan.mids:
		var mid := _instance_module(mid_key)
		if mid:
			mid.position = Vector3(0.0, CELL * band, 0.0)
			root.add_child(mid)
		band += 1
	var cap := _instance_module(plan.cap)
	if cap:
		cap.position = Vector3(0.0, CELL * band, 0.0)
		root.add_child(cap)
	return root

## Total build height (m) for a plan — for sizing the pickable collider.
static func building_height(plan: Dictionary) -> float:
	if plan.family == Family.TRANSIT:
		return CELL * 2.0
	return CELL * (plan.floors + 2)  # ground + N mids + cap bands
