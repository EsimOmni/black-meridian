class_name RivalScoring
extends RefCounted
## Pure rival utility scoring (brief §7.4) — split from RivalDirector so it unit-tests
## headless, like EconomyMath/JobResolution (tasks/lessons.md). PURELY DETERMINISTIC:
## same inputs → same scores → same argmax. No random number generation or seeded
## jitter anywhere (brief §7.6; controlled tie-break noise is P07b, as a
## deterministic hash — still not randomness). Enforced by test_rival_ai's source scan.

## Effect + timing constants (P07 ships PROBE + SABOTAGE only; the rest is P07b+).
const SABOTAGE_DISRUPTION := 0.35        ## disruption added on top of the heat-driven base
const SABOTAGE_DURATION_TICKS := 40      ## strategic ticks the hit lingers
const PROBE_DISRUPTION := 0.10           ## a probe is pressure, not a strike
const PROBE_DURATION_TICKS := 20
const COMMIT_THRESHOLD := 0.3            ## below this best score, the rival waits
const TELEGRAPH_LEAD_RIVAL_TICKS := 3    ## ~30 strategic ticks — the player's response window

## Visible weakness only (fairness rule §7.4): the rival reads venue disruption,
## control posture and an active inspection — never hidden GameState internals.
static func target_weakness(venue: VenueData, district: DistrictData) -> float:
	var w := venue.disruption * 0.5
	match venue.control_state:
		BM.ControlState.CONTESTED:
			w += 0.4
		BM.ControlState.COMPROMISED:
			w += 0.35
		BM.ControlState.INFLUENCED:
			w += 0.3
		BM.ControlState.CONTROLLED:
			w += 0.1
		_:
			pass  # FORTIFIED / UNKNOWN add nothing
	if district.inspection_ticks > 0:
		w += 0.3  # inspectors on site: the target is pinned down
	return clampf(w, 0.0, 1.0)

## Personality-weighted action score. Aggression drives the strike, cunning helps
## both, caution makes a hot district unattractive (getting caught in the sweep).
static func score_action(action: int, weakness: float, rival: FactionData, district: DistrictData) -> float:
	var heat_penalty := district.local_heat * rival.caution
	match action:
		BM.RivalAction.SABOTAGE:
			return weakness * (0.6 * rival.aggression + 0.5 * rival.cunning) - heat_penalty * 0.5
		BM.RivalAction.PROBE:
			return (0.25 + weakness * 0.3) * (0.4 + 0.6 * rival.cunning) - heat_penalty * 0.25
		_:
			return -INF  # other actions are P07b+

## Deterministic argmax over the player's venues × {PROBE, SABOTAGE}. Ties resolve
## to the first candidate in iteration order (stable — GameState order is authored).
## Returns {} when nothing clears COMMIT_THRESHOLD (a rival that always acts is noise).
static func choose_move(districts: Array[DistrictData], player_faction_id: StringName,
		rival: FactionData) -> Dictionary:
	var best := {}
	var best_score := -INF
	for district in districts:
		for venue in district.venues:
			if venue.owner_faction != player_faction_id:
				continue
			var weakness := target_weakness(venue, district)
			for action in [BM.RivalAction.PROBE, BM.RivalAction.SABOTAGE]:
				var s := score_action(action, weakness, rival, district)
				if s > best_score:
					best_score = s
					best = {"venue": venue, "action": action, "score": s}
	if best_score < COMMIT_THRESHOLD:
		return {}
	return best
