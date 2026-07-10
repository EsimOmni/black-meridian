class_name WorldSeed
extends RefCounted
## Month-1 vertical-slice seed (brief §12.1): one district (Glass Wharf), the ruling
## Compact vs the Corvine Assembly rival, 4 rackets + 2 fronts, 4 hero characters.
## Built in code for now; will migrate to typed .tres / JSON under /data later (brief §13.3).
## Names other than Aiko are placeholders until the world bible locks (brief §4).

const COMPACT := &"compact"      ## player — the Meridian Compact
const CORVINE := &"corvine"      ## rival — the Corvine Assembly

## P05b: authored slack on top of each faction's seeded venue staffing. 2 keeps the
## opening board a real choice without being flush: the Compact starts with 7 assigned
## (3+2+2 across its rackets) + 2 free — enough to boost ONE venue meaningfully, not all.
const FREE_RESERVE := 2

static func build() -> void:
	GameState.reset()
	_build_factions()
	_build_characters()
	_build_glass_wharf()
	_seed_operative_pools()
	GameState.player_faction_id = COMPACT
	GameState.districts_changed.emit()
	GameState.factions_changed.emit()

static func _build_factions() -> void:
	var compact := FactionData.new()
	compact.id = COMPACT
	compact.display_name = "Meridian Compact"
	compact.is_player = true
	compact.accent_color = Color(0.79, 0.57, 0.25)  # sodium amber
	compact.aggression = 0.4
	compact.caution = 0.6
	compact.cunning = 0.7
	compact.dirty_cash = 5000
	compact.clean_capital = 1500

	var corvine := FactionData.new()
	corvine.id = CORVINE
	corvine.display_name = "Corvine Assembly"
	corvine.is_player = false
	corvine.accent_color = Color(0.35, 0.45, 0.6)  # petrol blue
	corvine.aggression = 0.7
	corvine.caution = 0.3
	corvine.cunning = 0.8  # raven-led blackmail / social infiltration (brief §4)
	corvine.dirty_cash = 4000
	corvine.clean_capital = 1000

	GameState.factions = [compact, corvine]

static func _build_characters() -> void:
	var aiko := CharacterData.new()
	aiko.id = &"aiko_velora"
	aiko.display_name = "Aiko Velora"
	aiko.faction_id = COMPACT
	aiko.role = "Resolver"
	aiko.is_player = true
	aiko.public_trust = 1.0

	var regent := CharacterData.new()
	regent.id = &"regent"
	regent.display_name = "The Regent"          # Nordic-Alien placeholder (brief §4)
	regent.faction_id = COMPACT
	regent.role = "Regent of the Meridian Compact"
	regent.public_trust = 0.7
	regent.ambition = 0.5

	var bengal := CharacterData.new()
	bengal.id = &"bengal_lt"
	bengal.display_name = "Operations Lieutenant"  # Bengal-Felid placeholder
	bengal.faction_id = COMPACT
	bengal.role = "Operations lieutenant / territorial enforcer"
	bengal.public_trust = 0.6
	bengal.ambition = 0.5
	bengal.grievance = 0.3                          # loyal but increasingly resentful (brief §4)
	bengal.relationships = {&"regent": -0.2, &"aiko_velora": 0.4}

	var raven := CharacterData.new()
	raven.id = &"raven_boss"
	raven.display_name = "Corvine Boss"             # Raven-Woman placeholder
	raven.faction_id = CORVINE
	raven.role = "Boss of the Corvine Assembly"
	raven.public_trust = 0.0
	raven.ambition = 0.9

	GameState.characters = [aiko, regent, bengal, raven]

static func _build_glass_wharf() -> void:
	var d := DistrictData.new()
	d.id = &"glass_wharf"
	d.display_name = "Glass Wharf"   # wet freight + nightlife district (brief §12.1)
	d.influence = 0.4
	d.security = 0.3
	d.prosperity = 0.6
	d.fear = 0.2
	d.visibility = 0.5
	d.institutional_presence = 0.35
	d.local_heat = 0.1
	d.faction_pressure = {COMPACT: 0.4, CORVINE: 0.3}

	# Four rackets (brief §12.1) — 3 player-held, 1 rival-held to make the district contested.
	# Layout: a single wharf frontage along x, ~9 m spacing so the 4.5 m-wide assembled buildings
	# (P14) read as a row of dockside buildings with clear gaps between them, not a pile. Rackets
	# and fronts interleave along the frontage; a shallow z stagger gives the row some depth.
	d.venues = [
		_racket(&"gw_contraband", "Cargo Terminal Contraband", BM.RacketKind.CONTRABAND_LOGISTICS,
			COMPACT, BM.ControlState.CONTROLLED, 220, 3, Vector2(-50, -4.0)),
		_front(&"gw_nightclub", "The Meridian Club", BM.FrontKind.NIGHTCLUB,
			COMPACT, 600, 0.75, 0.18, Vector2(-30, 4.0)),
		_racket(&"gw_protection", "Wharfside Protection", BM.RacketKind.PROTECTION,
			COMPACT, BM.ControlState.INFLUENCED, 140, 2, Vector2(-10, -4.0)),
		_racket(&"gw_gaming", "Underglass Gaming Den", BM.RacketKind.UNDERGROUND_GAMING,
			COMPACT, BM.ControlState.CONTROLLED, 180, 2, Vector2(10, 4.0)),
		_front(&"gw_freight", "Glass Wharf Freight Co.", BM.FrontKind.FREIGHT_COMPANY,
			COMPACT, 450, 0.7, 0.2, Vector2(30, -4.0)),
		_racket(&"gw_clinic", "Backstreet Clinic", BM.RacketKind.ILLEGAL_CLINIC,
			CORVINE, BM.ControlState.CONTROLLED, 160, 2, Vector2(50, 4.0)),
		_racket(&"gw_saltworks", "Abandoned Saltworks", BM.RacketKind.CONTRABAND_LOGISTICS,
			&"", BM.ControlState.CONTESTED, 90, 1, Vector2(20, -3.0)),
	]

	GameState.districts = [d]

## P05b: each faction's finite operative pool = what the seed already assigned to its
## venues + FREE_RESERVE. Runs after the venues exist so the sum is the real one.
static func _seed_operative_pools() -> void:
	for faction in GameState.factions:
		faction.operative_pool = \
			OperativeMath.assigned_sum(faction, GameState.districts) + FREE_RESERVE

# --- Builders ----------------------------------------------------------------

static func _racket(id: StringName, name: String, kind: int, owner: StringName,
		state: int, base_yield: int, staff: int, pos: Vector2) -> VenueData:
	var v := VenueData.new()
	v.id = id
	v.display_name = name
	v.type = BM.VenueType.RACKET
	v.racket_kind = kind
	v.owner_faction = owner
	v.control_state = state
	v.base_yield = base_yield
	v.operational_staff = staff
	v.racket_risk = 0.3
	v.map_position = pos
	return v

static func _front(id: StringName, name: String, kind: int, owner: StringName,
		capacity: int, efficiency: float, op_cost: float, pos: Vector2) -> VenueData:
	var v := VenueData.new()
	v.id = id
	v.display_name = name
	v.type = BM.VenueType.FRONT
	v.front_kind = kind
	v.owner_faction = owner
	v.control_state = BM.ControlState.CONTROLLED
	v.laundering_capacity = capacity
	v.front_efficiency = efficiency
	v.operating_cost = op_cost
	v.map_position = pos
	return v
