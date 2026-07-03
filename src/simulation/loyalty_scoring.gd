class_name LoyaltyScoring
extends RefCounted
## Pure loyalty/betrayal scoring (brief §7.6) — split from RelationshipService so it
## unit-tests headless, like RivalScoring/EconomyMath (tasks/lessons.md). PURELY
## DETERMINISTIC: same inputs → same opportunity → same candidate; no random number
## generation anywhere (enforced by test_loyalty's source scan). Betrayal requires
## BOTH gates — pressure above the character's threshold AND a viable opportunity —
## which is exactly what makes it preventable (§7.6): the player can defuse either side.

## The Opportunity gate: below this the moment isn't viable and betrayal cannot open,
## no matter how high the pressure sits.
const OPPORTUNITY_THRESHOLD := 0.3
## Betrayal lead in rival ticks (~10 strategic ticks each): the player's defusal window.
const TELEGRAPH_LEAD_RIVAL_TICKS := 6

## The reassure verb (the defusal lever): clean capital buys the lieutenant back in.
const REASSURE_COST_CLEAN := 200
const REASSURE_TRUST_GAIN := 0.15
const REASSURE_SHARED_GAIN := 0.15

## Opportunity components (summed, clamped to 0..1).
const OPP_INSPECTION := 0.35        ## the faction is pinned by an active inspection
const OPP_SABOTAGE := 0.3           ## an open wound — a faction venue under sabotage
const OPP_LEVERAGE_PRESSED := 0.5   ## × rival_leverage while a rival intent is open

## Brief's Opportunity term (§7.6), derived from VISIBLE sim state only: the
## character's faction is weak right now (an active inspection pins it down, a venue
## sits sabotaged) or the leverage a rival holds on them is being actively pressed
## (an open rival intent). The player removes the opening → this drops → an open
## intent defuses. No hidden state, no roll.
static func betrayal_opportunity(c: CharacterData, districts: Array[DistrictData],
		factions: Array[FactionData]) -> float:
	var opp := 0.0
	var inspected := false
	var wounded := false
	for d in districts:
		for v in d.venues:
			if v.owner_faction != c.faction_id:
				continue
			if d.inspection_ticks > 0:
				inspected = true
			if v.sabotage_ticks > 0:
				wounded = true
	if inspected:
		opp += OPP_INSPECTION
	if wounded:
		opp += OPP_SABOTAGE
	if c.rival_leverage > 0.0:
		for f in factions:
			if not f.is_player and f.intent_action >= 0:
				opp += c.rival_leverage * OPP_LEVERAGE_PRESSED
				break
	return clampf(opp, 0.0, 1.0)

## Both-gates candidate pick (§7.6): pressure above threshold AND opportunity present.
## Deterministic argmax over the player faction's lieutenants; ties resolve to the
## first in iteration order (stable — GameState order is authored), like RivalScoring.
static func choose_betrayer(characters: Array[CharacterData], districts: Array[DistrictData],
		factions: Array[FactionData], player_faction_id: StringName) -> CharacterData:
	var best: CharacterData = null
	var best_score := -INF
	for c in characters:
		if c.is_player or c.faction_id != player_faction_id:
			continue
		if not c.pressure_exceeds_threshold():
			continue
		var opp := betrayal_opportunity(c, districts, factions)
		if opp < OPPORTUNITY_THRESHOLD:
			continue
		var score := c.betrayal_pressure() + opp
		if score > best_score:
			best_score = score
			best = c
	return best

## Gate re-check for an OPEN intent — the moment either gate stops holding, it defuses.
static func gates_hold(c: CharacterData, districts: Array[DistrictData],
		factions: Array[FactionData]) -> bool:
	return c.pressure_exceeds_threshold() \
		and betrayal_opportunity(c, districts, factions) >= OPPORTUNITY_THRESHOLD

## The landed effect's deterministic target: the first player racket not already
## CONTESTED — the lieutenant takes their ground with them (one bounded effect, P10).
static func betrayal_target(districts: Array[DistrictData], faction_id: StringName) -> VenueData:
	for d in districts:
		for v in d.venues:
			if v.owner_faction == faction_id and v.type == BM.VenueType.RACKET \
					and v.control_state != BM.ControlState.CONTESTED:
				return v
	return null
