extends Node
## GameState (autoload) — the authoritative container for the strategic simulation
## (brief §13.2). Presentation reads from here; it never owns simulation state.
## Deterministic: same state + same ticks => same outcome.

signal districts_changed
signal factions_changed
signal night_cycle_advanced(cycle: int, phase: int)

## --- World data (seeded by WorldSeed in Month 1) ---
var districts: Array[DistrictData] = []
var factions: Array[FactionData] = []
var characters: Array[CharacterData] = []

## The player faction id (the Meridian Compact).
var player_faction_id: StringName = &""

## --- Campaign clock ---
var night_cycle: int = 1
var phase: int = BM.Phase.OPERATIONS
## Elapsed strategic ticks in the current phase (advanced by the NightCycle machine, P09).
var phase_ticks: int = 0

## --- Central pressure (P06c) — the one scale above the districts (brief §7.3) ---
## Consolidated institutional heat on the Compact, 0..1. Single writer:
## EconomyService._update_central_pressure (derived via PressureMath each tick).
var central_pressure: float = 0.0
## Latched true from the tick a city-wide alert fires until pressure falls below the
## re-arm bar (false = armed — the district inspection_armed shape, inverted polarity).
## The active consequence itself is central_alert_ticks > 0.
var central_alert: bool = false
var central_alert_ticks: int = 0

## --- Narrative progression (P16) — authored beat chain state (brief §13.2) ---
## Written only by the NarrativeDirector (fired@/resolved@ flags, accord stance).
## Lives here (not on the director node) so it saves additively and survives loads.
var narrative_flags: Dictionary = {}

func _ready() -> void:
	# Autoload order in project.godot guarantees GameState is ready before services use it.
	pass

# --- Lookups -----------------------------------------------------------------

func get_faction(id: StringName) -> FactionData:
	for f in factions:
		if f.id == id:
			return f
	return null

func get_district(id: StringName) -> DistrictData:
	for d in districts:
		if d.id == id:
			return d
	return null

func get_character(id: StringName) -> CharacterData:
	for c in characters:
		if c.id == id:
			return c
	return null

## The district a venue belongs to (venues live in district.venues) — null if unplaced.
func get_district_of_venue(venue: VenueData) -> DistrictData:
	for d in districts:
		if venue in d.venues:
			return d
	return null

func player_faction() -> FactionData:
	return get_faction(player_faction_id)

## All venues across all districts owned by a given faction.
func venues_owned_by(faction_id: StringName) -> Array[VenueData]:
	var out: Array[VenueData] = []
	for d in districts:
		for v in d.venues:
			if v.owner_faction == faction_id:
				out.append(v)
	return out

# --- Reset / load ------------------------------------------------------------

func reset() -> void:
	districts.clear()
	factions.clear()
	characters.clear()
	player_faction_id = &""
	night_cycle = 1
	phase = BM.Phase.OPERATIONS
	phase_ticks = 0
	central_pressure = 0.0
	central_alert = false
	central_alert_ticks = 0
	narrative_flags = {}
