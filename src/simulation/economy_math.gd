class_name EconomyMath
extends RefCounted
## Pure economy formulas (brief §7.2), separated from the EconomyService autoload so they
## can be unit-tested in isolation and reused without touching engine singletons.

## ControlModifier from a venue's control state.
static func control_modifier(state: int) -> float:
	match state:
		BM.ControlState.FORTIFIED: return 1.2
		BM.ControlState.CONTROLLED: return 1.0
		BM.ControlState.INFLUENCED: return 0.6
		BM.ControlState.CONTESTED: return 0.3
		BM.ControlState.COMPROMISED: return 0.4  # still earns, but exposed
		_: return 0.0  # UNKNOWN

## DirtyIncome = BaseYield * DistrictDemand * OperationalStaff * ControlModifier * DisruptionModifier
static func compute_dirty_income(venue: VenueData, district_demand: float) -> int:
	if venue.type != BM.VenueType.RACKET:
		return 0
	if venue.paused:  # brief §7.2: a stopped racket earns nothing (and creates no exposure)
		return 0
	var staff_factor := float(maxi(0, venue.operational_staff))
	var disruption_mod := 1.0 - venue.disruption
	var raw := float(venue.base_yield) * district_demand * staff_factor \
		* control_modifier(venue.control_state) * disruption_mod
	return int(roundf(raw))

## CleanCapital contribution = LaunderingCapacity * FrontEfficiency * (1 - OperatingCost)
static func compute_front_clean(venue: VenueData) -> int:
	if venue.type != BM.VenueType.FRONT:
		return 0
	var raw := float(venue.laundering_capacity) * venue.front_efficiency * (1.0 - venue.operating_cost)
	return int(roundf(raw))

## Heat → operational disruption (brief §7.3: patrols, inspections, scared customers).
## No effect below a grace band, then a linear, legible ramp. Heat alone never fully
## kills a venue (max 0.6) — the inspection beat does the spiking (EconomyService).
const HEAT_DISRUPTION_GRACE := 0.3
const HEAT_DISRUPTION_MAX := 0.6

static func disruption_from_heat(local_heat: float) -> float:
	if local_heat <= HEAT_DISRUPTION_GRACE:
		return 0.0
	return (local_heat - HEAT_DISRUPTION_GRACE) / (1.0 - HEAT_DISRUPTION_GRACE) * HEAT_DISRUPTION_MAX

## ExposureGain share for a racket from the faction's unlaundered overflow.
static func compute_exposure(venue: VenueData, district: DistrictData, unlaundered_overflow: int) -> float:
	if venue.type != BM.VenueType.RACKET:
		return 0.0
	return float(unlaundered_overflow) * venue.racket_risk * district.visibility * 0.0001
