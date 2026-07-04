extends Node
## EconomyService (autoload) — the dirty/clean economy (brief §7.2).
## Settles income on each strategic tick. The pure formulas live in EconomyMath
## (testable in isolation); this node applies them across GameState each tick.

signal economy_settled(faction_id: StringName, dirty_delta: int, clean_delta: int, exposure_delta: float)
signal inspection_started(district: DistrictData)
signal inspection_ended(district: DistrictData)

## "Pressure an existing front" (brief §7.2): clean capital buys laundering capacity.
const FRONT_PRESSURE_STEP := 100    ## +capacity per pressure action
const FRONT_PRESSURE_COST := 400    ## clean_capital spent per action
const FRONT_CAPACITY_MAX := 1500    ## per-front ceiling — a front can only look so legitimate

## Heat lifecycle (brief §7.3, P06). All deterministic — no rolls (brief §7.6).
## Rise ~0.00084/tick in the seeded squeezed world vs decay 0.0006/tick: recovery is
## real but slower than the climb, so causality stays legible.
const HEAT_RISE_SCALE := 0.05          ## heat += district tick exposure * this (P04 tuning kept)
const EXPOSURE_HEAT_FLOOR := 0.008     ## below this district exposure, heat decays instead of rising.
                                       ## Must sit ABOVE the rival's baseline (~0.0053 from gw_clinic)
                                       ## or the player could never recover by backing off.
const HEAT_DECAY_PER_TICK := 0.0006
## Threshold sits just BELOW the measured self-stabilization point (~0.47 in the seeded
## world): the heat→disruption→income feedback throttles exposure under the decay floor
## around there, so a higher threshold (e.g. 0.7) would never fire in normal play.
## At 0.45, sustained ignoring of the squeeze reliably triggers the beat.
const HEAT_INSPECTION_THRESHOLD := 0.45 ## crossing fires the inspection beat (once per excursion)
const HEAT_INSPECTION_WARN := 0.38      ## HUD telegraphs from here — never a surprise
const HEAT_INSPECTION_REARM := 0.30     ## heat must fall below this before another can fire
const INSPECTION_DURATION_TICKS := 30
const INSPECTION_DISRUPTION := 0.8     ## disruption floor while inspectors are on site

## Last settle per faction: {dirty_income, laundering_capacity, overflow, clean_gain}.
## The HUD reads the squeeze from here — presentation never recomputes the economy.
var _last_settle: Dictionary = {}

## Exposure accumulated per district this tick (all factions — police attention is
## district-wide). Consumed by _update_district_heat, cleared each tick.
var _district_tick_exposure: Dictionary = {}

func _ready() -> void:
	TimeService.strategic_tick.connect(_on_strategic_tick)

func settle_info(faction_id: StringName) -> Dictionary:
	return _last_settle.get(faction_id, {})

# --- Player verbs (brief §7.2) -------------------------------------------------

func set_racket_paused(venue: VenueData, paused: bool) -> void:
	if venue.type == BM.VenueType.RACKET:
		venue.paused = paused

## Spend clean_capital to raise a front's laundering capacity. Returns false (no-op,
## never a negative pool) when the venue isn't the faction's front, the ceiling is
## reached, or clean_capital can't cover the cost.
func pressure_front(venue: VenueData, faction: FactionData) -> bool:
	if faction == null or venue.type != BM.VenueType.FRONT or venue.owner_faction != faction.id:
		return false
	if venue.laundering_capacity >= FRONT_CAPACITY_MAX:
		return false
	if faction.clean_capital < FRONT_PRESSURE_COST:
		return false
	faction.clean_capital -= FRONT_PRESSURE_COST
	venue.laundering_capacity = mini(venue.laundering_capacity + FRONT_PRESSURE_STEP, FRONT_CAPACITY_MAX)
	return true

func _on_strategic_tick(_tick: int) -> void:
	_district_tick_exposure.clear()
	for faction in GameState.factions:
		_settle_faction(faction)
	_update_district_heat()

func _settle_faction(faction: FactionData) -> void:
	var dirty_income := 0
	var laundering_capacity := 0
	var front_clean := 0
	var exposure := 0.0

	for district in GameState.districts:
		var demand := district.district_demand()
		for venue in district.venues:
			if venue.owner_faction != faction.id:
				continue
			match venue.type:
				BM.VenueType.RACKET:
					dirty_income += EconomyMath.compute_dirty_income(venue, demand)
				BM.VenueType.FRONT:
					laundering_capacity += venue.laundering_capacity
					front_clean += EconomyMath.compute_front_clean(venue)
				_:
					pass

	# Launder as much dirty cash as front capacity allows; overflow stays dirty + raises exposure.
	var available_dirty := faction.dirty_cash + dirty_income
	var laundered := mini(available_dirty, laundering_capacity)
	var clean_gain := mini(front_clean, laundered)  # capped by what fronts can actually convert
	var unlaundered_overflow := maxi(0, dirty_income - laundering_capacity)

	# Exposure accrues per racket venue from its unlaundered share (simplified per-faction
	# rollup), and is attributed to the venue's district for the heat pass below.
	for district in GameState.districts:
		for venue in district.venues:
			if venue.owner_faction == faction.id and venue.type == BM.VenueType.RACKET:
				var venue_exposure := EconomyMath.compute_exposure(venue, district, unlaundered_overflow)
				exposure += venue_exposure
				_district_tick_exposure[district.id] = \
					_district_tick_exposure.get(district.id, 0.0) + venue_exposure

	var dirty_delta := dirty_income - laundered
	faction.dirty_cash += dirty_delta
	faction.clean_capital += clean_gain

	_last_settle[faction.id] = {
		"dirty_income": dirty_income,
		"laundering_capacity": laundering_capacity,
		"overflow": unlaundered_overflow,
		"clean_gain": clean_gain,
	}

	economy_settled.emit(faction.id, dirty_delta, clean_gain, exposure)

## The single writer of local_heat from the economy (P06): rise above the exposure
## floor, slow decay below it, the deterministic inspection beat at the threshold,
## and heat → venue disruption (bites next tick's income — a legible one-tick lag).
func _update_district_heat() -> void:
	for district in GameState.districts:
		var tick_exposure: float = _district_tick_exposure.get(district.id, 0.0)
		if tick_exposure >= EXPOSURE_HEAT_FLOOR:
			district.local_heat = clampf(district.local_heat + tick_exposure * HEAT_RISE_SCALE, 0.0, 1.0)
		elif district.inspection_ticks == 0:  # attention doesn't relax while inspectors are on site
			district.local_heat = maxf(0.0, district.local_heat - HEAT_DECAY_PER_TICK)

		# Inspection lifecycle: threshold-latched, once per excursion, zero randomness.
		# P06b: the latch reads the COMBINED pressure — raw heat plus weighted case
		# pressure (EvidenceMath). Cooling the flow no longer clears you: standing cases
		# keep the sweep coming until the player burns them down. Re-arm mirrors on the
		# same combined value, so the excursion only ends when BOTH sides fall.
		var combined := EvidenceMath.combined_pressure(district.local_heat, district.evidence_cases)
		if district.inspection_ticks > 0:
			district.inspection_ticks -= 1
			if district.inspection_ticks == 0:
				inspection_ended.emit(district)
		elif district.inspection_armed and combined >= HEAT_INSPECTION_THRESHOLD:
			district.inspection_armed = false
			district.inspection_ticks = INSPECTION_DURATION_TICKS
			inspection_started.emit(district)
		if not district.inspection_armed and district.inspection_ticks == 0 \
				and combined < HEAT_INSPECTION_REARM:
			district.inspection_armed = true

		# Heat disrupts every venue in the district — police attention doesn't pick sides.
		# A rival hit (P07) rides on top as a per-venue component that decays over its
		# sabotage_ticks; this pass stays the single writer of venue.disruption.
		var disruption := EconomyMath.disruption_from_heat(district.local_heat)
		if district.inspection_ticks > 0:
			disruption = maxf(disruption, INSPECTION_DISRUPTION)
		for venue in district.venues:
			var venue_disruption := disruption
			if venue.sabotage_ticks > 0:
				venue.sabotage_ticks -= 1
				venue_disruption = clampf(venue_disruption + venue.sabotage_disruption, 0.0, 1.0)
				if venue.sabotage_ticks == 0:
					venue.sabotage_disruption = 0.0
			venue.disruption = venue_disruption
