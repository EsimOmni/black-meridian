class_name SaveCodec
extends RefCounted
## Pure GameState <-> Dictionary serialization (brief §13.2). Kept out of the SaveService
## autoload so it unit-tests headless (tasks/lessons.md). Stores the source of truth only —
## derived values are recomputed by the sim (brief §13.2 determinism note).
##
## Files use var_to_str/str_to_var, not JSON: full float precision (a JSON round-trip
## truncates floats and breaks save→load→same-tick→same-state determinism) and native
## StringName/Color/Vector2 types. str_to_var never instantiates scripts — safe to load.

const SAVE_VERSION := 1

# --- Encode -------------------------------------------------------------------

static func encode_state(districts: Array[DistrictData], factions: Array[FactionData],
		characters: Array[CharacterData], jobs: Array[JobData], meta: Dictionary) -> Dictionary:
	var out := {
		"version": SAVE_VERSION,
		"meta": meta.duplicate(),
		"factions": [],
		"districts": [],
		"characters": [],
		"jobs": [],
	}
	for f in factions:
		out["factions"].append(encode_faction(f))
	for d in districts:
		out["districts"].append(encode_district(d))
	for c in characters:
		out["characters"].append(encode_character(c))
	for j in jobs:
		out["jobs"].append(encode_job(j))
	return out

static func encode_faction(f: FactionData) -> Dictionary:
	return {
		"id": f.id, "display_name": f.display_name, "is_player": f.is_player,
		"accent_color": f.accent_color,
		"aggression": f.aggression, "caution": f.caution, "cunning": f.cunning,
		"dirty_cash": f.dirty_cash, "clean_capital": f.clean_capital,
		"intent_action": f.intent_action, "intent_venue_id": f.intent_venue_id,
		"intent_ticks_until_land": f.intent_ticks_until_land,
		"grudge": f.grudge,
	}

static func encode_character(c: CharacterData) -> Dictionary:
	return {
		"id": c.id, "display_name": c.display_name, "faction_id": c.faction_id,
		"role": c.role, "is_player": c.is_player,
		"public_trust": c.public_trust, "ambition": c.ambition, "fear": c.fear,
		"grievance": c.grievance, "shared_success": c.shared_success,
		"rival_leverage": c.rival_leverage, "survival_pressure": c.survival_pressure,
		"betrayal_threshold": c.betrayal_threshold,
		"relationships": c.relationships.duplicate(),
		"betrayal_ticks_until_land": c.betrayal_ticks_until_land,
	}

static func encode_district(d: DistrictData) -> Dictionary:
	var venues := []
	for v in d.venues:
		venues.append(encode_venue(v))
	var cases := []
	for c in d.evidence_cases:
		cases.append({"id": c.id, "kind": c.kind, "weight": c.weight, "label": c.label})
	return {
		"id": d.id, "display_name": d.display_name,
		"influence": d.influence, "security": d.security, "prosperity": d.prosperity,
		"fear": d.fear, "visibility": d.visibility,
		"institutional_presence": d.institutional_presence, "local_heat": d.local_heat,
		"faction_pressure": d.faction_pressure.duplicate(),
		"inspection_ticks": d.inspection_ticks, "inspection_armed": d.inspection_armed,
		"evidence_cases": cases,
		"venues": venues,
	}

static func encode_venue(v: VenueData) -> Dictionary:
	return {
		"id": v.id, "display_name": v.display_name, "type": v.type,
		"owner_faction": v.owner_faction, "control_state": v.control_state,
		"racket_kind": v.racket_kind, "base_yield": v.base_yield,
		"front_kind": v.front_kind, "laundering_capacity": v.laundering_capacity,
		"front_efficiency": v.front_efficiency, "operating_cost": v.operating_cost,
		"operational_staff": v.operational_staff, "disruption": v.disruption,
		"racket_risk": v.racket_risk, "map_position": v.map_position,
		"paused": v.paused,
		"sabotage_disruption": v.sabotage_disruption, "sabotage_ticks": v.sabotage_ticks,
	}

## Jobs store runtime state only — authored content (text, choice pools) is rebuilt on
## load from the id: JobTemplates.by_id for authored jobs, JobGenerator.rebuild for
## generated ("gen@…") ids whose targeting is encoded in the id itself (P08).
static func encode_job(j: JobData) -> Dictionary:
	return {
		"id": j.id, "stage": j.stage,
		"chosen_prep": j.chosen_prep.duplicate(),
		"chosen_approach": j.chosen_approach, "chosen_coverup": j.chosen_coverup,
		"ticks_remaining": j.ticks_remaining,
		"outcome": j.outcome.duplicate(),
	}

# --- Decode -------------------------------------------------------------------

## Returns {} when the save version doesn't match (refuse cleanly — no crash).
static func decode_state(data: Dictionary) -> Dictionary:
	if int(data.get("version", -1)) != SAVE_VERSION:
		return {}
	var districts: Array[DistrictData] = []
	var factions: Array[FactionData] = []
	var characters: Array[CharacterData] = []
	for fd in data.get("factions", []):
		factions.append(decode_faction(fd))
	for dd in data.get("districts", []):
		districts.append(decode_district(dd))
	for cd in data.get("characters", []):
		characters.append(decode_character(cd))
	return {
		"meta": data.get("meta", {}),
		"factions": factions,
		"districts": districts,
		"characters": characters,
		"jobs": data.get("jobs", []),  # raw runtime dicts; caller rebuilds via the job registry
	}

static func decode_faction(d: Dictionary) -> FactionData:
	var f := FactionData.new()
	f.id = d["id"]
	f.display_name = d["display_name"]
	f.is_player = d["is_player"]
	f.accent_color = d["accent_color"]
	f.aggression = d["aggression"]
	f.caution = d["caution"]
	f.cunning = d["cunning"]
	f.dirty_cash = d["dirty_cash"]
	f.clean_capital = d["clean_capital"]
	f.intent_action = d.get("intent_action", -1)                    # additive since P07
	f.intent_venue_id = d.get("intent_venue_id", &"")
	f.intent_ticks_until_land = d.get("intent_ticks_until_land", 0)
	f.grudge = d.get("grudge", 0.0)                                 # additive since P07c
	return f

static func decode_character(d: Dictionary) -> CharacterData:
	var c := CharacterData.new()
	c.id = d["id"]
	c.display_name = d["display_name"]
	c.faction_id = d["faction_id"]
	c.role = d["role"]
	c.is_player = d["is_player"]
	c.public_trust = d["public_trust"]
	c.ambition = d["ambition"]
	c.fear = d["fear"]
	c.grievance = d["grievance"]
	c.shared_success = d["shared_success"]
	c.rival_leverage = d["rival_leverage"]
	c.survival_pressure = d["survival_pressure"]
	c.betrayal_threshold = d["betrayal_threshold"]
	c.relationships = d["relationships"].duplicate()
	c.betrayal_ticks_until_land = d.get("betrayal_ticks_until_land", -1)  # additive since P10
	return c

static func decode_district(d: Dictionary) -> DistrictData:
	var dist := DistrictData.new()
	dist.id = d["id"]
	dist.display_name = d["display_name"]
	dist.influence = d["influence"]
	dist.security = d["security"]
	dist.prosperity = d["prosperity"]
	dist.fear = d["fear"]
	dist.visibility = d["visibility"]
	dist.institutional_presence = d["institutional_presence"]
	dist.local_heat = d["local_heat"]
	dist.faction_pressure = d["faction_pressure"].duplicate()
	dist.inspection_ticks = d.get("inspection_ticks", 0)     # additive since P06
	dist.inspection_armed = d.get("inspection_armed", true)  # pre-P06 saves: armed, no inspection
	var cases: Array[EvidenceCaseData] = []
	for cd in d.get("evidence_cases", []):                   # additive since P06b
		var c := EvidenceCaseData.new()
		c.id = cd["id"]
		c.kind = cd["kind"]
		c.weight = cd["weight"]
		c.label = cd["label"]
		cases.append(c)
	dist.evidence_cases = cases
	var venues: Array[VenueData] = []
	for vd in d["venues"]:
		venues.append(decode_venue(vd))
	dist.venues = venues
	return dist

static func decode_venue(d: Dictionary) -> VenueData:
	var v := VenueData.new()
	v.id = d["id"]
	v.display_name = d["display_name"]
	v.type = d["type"]
	v.owner_faction = d["owner_faction"]
	v.control_state = d["control_state"]
	v.racket_kind = d["racket_kind"]
	v.base_yield = d["base_yield"]
	v.front_kind = d["front_kind"]
	v.laundering_capacity = d["laundering_capacity"]
	v.front_efficiency = d["front_efficiency"]
	v.operating_cost = d["operating_cost"]
	v.operational_staff = d["operational_staff"]
	v.disruption = d["disruption"]
	v.racket_risk = d["racket_risk"]
	v.map_position = d["map_position"]
	v.paused = d.get("paused", false)  # additive since P05; pre-P05 saves default to running
	v.sabotage_disruption = d.get("sabotage_disruption", 0.0)  # additive since P07
	v.sabotage_ticks = d.get("sabotage_ticks", 0)
	return v

## Overlay saved runtime state onto a freshly authored job (from the registry).
static func apply_job_state(job: JobData, d: Dictionary) -> void:
	job.stage = d["stage"]
	var prep: Array[StringName] = []
	for p in d["chosen_prep"]:
		prep.append(p)
	job.chosen_prep = prep
	job.chosen_approach = d["chosen_approach"]
	job.chosen_coverup = d["chosen_coverup"]
	job.ticks_remaining = d["ticks_remaining"]
	job.outcome = d["outcome"].duplicate()
