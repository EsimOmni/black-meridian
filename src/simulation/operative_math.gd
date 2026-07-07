class_name OperativeMath
extends RefCounted
## Pure operative-pool rules (P05b, brief §7.2). The faction owns a FINITE pool of
## operatives; assign/recall move them between the free pool and a venue's
## operational_staff (the existing §7.2 DirtyIncome multiplier). Pure clamped
## arithmetic — zero RNG, no engine singletons: callers pass the districts in so
## these functions unit-test headless (same doctrine as EconomyMath).
##
## Conservation invariant: operative_pool is NEVER written here. Assign lowers the
## free pool by raising venue staff; recall does the reverse. Operatives are moved,
## never created or destroyed — the pool total only changes if a future slice adds
## recruitment/injury (out of scope for P05b).

## Sum of operational_staff across every venue this faction owns.
static func assigned_sum(faction: FactionData, districts: Array[DistrictData]) -> int:
	var total := 0
	for district in districts:
		for venue in district.venues:
			if venue.owner_faction == faction.id:
				total += venue.operational_staff
	return total

## Free (unassigned) operatives = pool total - assigned. Derived, never stored
## (single source of truth = pool total + per-venue assignments). Clamped at 0.
static func free_pool(faction: FactionData, districts: Array[DistrictData]) -> int:
	return maxi(0, faction.operative_pool - assigned_sum(faction, districts))

## Move up to n operatives from the free pool onto the venue. Returns the number
## actually assigned: clamped to the free pool (0 when the pool is empty — a no-op,
## never negative). Ownership-gated: only the venue's owner faction can staff it.
static func assign(faction: FactionData, venue: VenueData, n: int,
		districts: Array[DistrictData]) -> int:
	if faction == null or venue == null or n <= 0 or venue.owner_faction != faction.id:
		return 0
	var moved := mini(n, free_pool(faction, districts))
	venue.operational_staff += moved
	return moved

## Move up to n operatives from the venue back to the free pool. Returns the number
## actually recalled (clamped to the venue's current staff; 0 if none). Ownership-gated.
static func recall(faction: FactionData, venue: VenueData, n: int) -> int:
	if faction == null or venue == null or n <= 0 or venue.owner_faction != faction.id:
		return 0
	var moved := mini(n, maxi(0, venue.operational_staff))
	venue.operational_staff -= moved
	return moved
