extends Node
## EconomyService (autoload) — the dirty/clean economy (brief §7.2).
## Settles income on each strategic tick. The pure formulas live in EconomyMath
## (testable in isolation); this node applies them across GameState each tick.

signal economy_settled(faction_id: StringName, dirty_delta: int, clean_delta: int, exposure_delta: float)

func _ready() -> void:
	TimeService.strategic_tick.connect(_on_strategic_tick)

func _on_strategic_tick(_tick: int) -> void:
	for faction in GameState.factions:
		_settle_faction(faction)

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

	# Exposure accrues per racket venue from its unlaundered share (simplified per-faction rollup).
	for district in GameState.districts:
		for venue in district.venues:
			if venue.owner_faction == faction.id and venue.type == BM.VenueType.RACKET:
				exposure += EconomyMath.compute_exposure(venue, district, unlaundered_overflow)

	var dirty_delta := dirty_income - laundered
	faction.dirty_cash += dirty_delta
	faction.clean_capital += clean_gain

	# Local heat rises with exposure where the faction operates (visualized by the city later).
	# 0.05 (P04 tuning): unmanaged laundering overflow climbs Glass Wharf ~10%→~60% across a
	# 15-minute session at 1x — the Month-1 gate needs the squeeze to be visible (brief §7.2).
	if exposure > 0.0:
		for district in GameState.districts:
			for venue in district.venues:
				if venue.owner_faction == faction.id and venue.type == BM.VenueType.RACKET:
					district.local_heat = clampf(district.local_heat + exposure * 0.05, 0.0, 1.0)
					break

	economy_settled.emit(faction.id, dirty_delta, clean_gain, exposure)
