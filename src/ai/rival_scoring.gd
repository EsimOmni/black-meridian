class_name RivalScoring
extends RefCounted
## Pure rival utility scoring (brief §7.4) — split from RivalDirector so it unit-tests
## headless, like EconomyMath/JobResolution (tasks/lessons.md). PURELY DETERMINISTIC:
## same inputs → same scores → same argmax. No random number generation anywhere
## (brief §7.6); the P07b tie-break "noise" is a fixed hash of authored ids — a pure
## function, not randomness. Enforced by test_rival_ai's source scan.

## Effect + timing constants.
const SABOTAGE_DISRUPTION := 0.35        ## disruption added on top of the heat-driven base
const SABOTAGE_DURATION_TICKS := 40      ## strategic ticks the hit lingers
const PROBE_DISRUPTION := 0.10           ## a probe is pressure, not a strike
const PROBE_DURATION_TICKS := 20
const RECRUIT_LEVERAGE := 0.15           ## P07b: leverage gained on the lieutenant per landed lean
const FRAME_HEAT := 0.25                 ## P07b: district heat bump — tips a simmering P06 latch,
                                         ## never an instant sweep from calm (threshold 0.45)
const COMMIT_THRESHOLD := 0.3            ## below this best RAW score, the rival waits
const TELEGRAPH_LEAD_RIVAL_TICKS := 3    ## ~30 strategic ticks — the player's response window

## P07b tie-break jitter: max score nudge, applied to RANKING only (never to the commit
## threshold, never to the reported score). Any raw gap above this is undisturbable.
const TIE_JITTER_EPSILON := 0.01

## P07c memory weights. Grudge (0..1) is the rival's memory of the player answering the
## retaliation it provoked; it biases the score toward the player without a roll.
const GRUDGE_SCORE_BONUS := 0.35         ## max score lift on a player venue at grudge = 1
const GRUDGE_SABOTAGE_LEAN := 0.15       ## grudge favours the strike (SABOTAGE) over the poke
const GRUDGE_DECAY_PER_TICK := 0.05      ## a grudge cools each rival tick (RivalDirector applies)

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

## P07b: how leanable a player lieutenant looks — PUBLIC motive network only (§7.4
## fairness: the hidden block — rival_leverage, survival_pressure — is read by no
## scoring path). Low trust + visible grievance + visible ambition = an open door.
static func recruit_susceptibility(c: CharacterData) -> float:
	return clampf((1.0 - c.public_trust) * 0.4 + c.grievance * 0.4 + c.ambition * 0.2, 0.0, 1.0)

## P07b tie-break jitter: a pure function of authored identity (faction id + target id
## + action + a persisted per-faction decision counter). Zero RNG: no generator, no
## seed, no state. Save-safe: the salt (intents_committed) persists, so save → load →
## replay reproduces the same pick bit-for-bit.
##
## Godot's String.hash() (DJB2) has almost no avalanche — bumping the salt by 1 bumps
## the raw hash by ~1, so h%997 climbs in lockstep and the GAP between two targets stays
## constant across salts. That would freeze the tie-break to one direction forever (the
## anti-robotic feel dies). We run the string hash through a splitmix64-style integer
## bit-mix so every input bit avalanches across the whole word; the salt then actually
## reshuffles the winner. Still a pure function — same inputs → same float, no randomness.
static func tie_jitter(rival_id: StringName, target_id: StringName, action: int, salt: int) -> float:
	var m := _avalanche(("%s|%s|%d|%d" % [rival_id, target_id, action, salt]).hash())
	var bucket := ((m % 997) + 997) % 997  # non-negative modulo (m can be negative)
	return float(bucket) / 997.0 * TIE_JITTER_EPSILON

## splitmix64 finalizer — deterministic integer bit-mix giving full avalanche. Constants
## are the standard 0xbf58476d1ce4e5b9 / 0x94d049bb133111eb as signed 64-bit ints;
## GDScript int math wraps mod 2^64, which is exactly what the mix needs.
static func _avalanche(x: int) -> int:
	x = (x ^ (x >> 30)) * -49064778989728563
	x = (x ^ (x >> 27)) * -4265267296055464877
	return x ^ (x >> 31)

## Personality-weighted action score. Aggression drives the strike and the land-grab,
## cunning helps every indirect play, caution makes a hot district unattractive for a
## strike (getting caught in the sweep) but LIKES the frame (deniable — the police do
## the work). P07c: grudge (0..1) adds a memory bonus on anti-player actions — EXPAND
## carries none (it isn't about the player). RECRUIT is placeless (a back-room lean):
## its arm never reads `district`, which may be null for that action only.
static func score_action(action: int, weakness: float, rival: FactionData, district: DistrictData) -> float:
	var grudge_bonus := rival.grudge * GRUDGE_SCORE_BONUS
	match action:
		BM.RivalAction.SABOTAGE:
			return weakness * (0.6 * rival.aggression + 0.5 * rival.cunning) \
				- district.local_heat * rival.caution * 0.5 \
				+ grudge_bonus + rival.grudge * GRUDGE_SABOTAGE_LEAN
		BM.RivalAction.PROBE:
			return (0.25 + weakness * 0.3) * (0.4 + 0.6 * rival.cunning) \
				- district.local_heat * rival.caution * 0.25 + grudge_bonus
		BM.RivalAction.EXPAND:
			# weakness here is the NEUTRAL venue's visible softness; no grudge term.
			return (0.35 + weakness * 0.25) * (0.4 + 0.6 * rival.aggression) \
				- district.local_heat * rival.caution * 0.25
		BM.RivalAction.FRAME:
			# District heat is FUEL, not danger: framing pays most when the pot is
			# already simmering (it tips the P06 latch through its normal telegraph).
			return (0.15 + weakness * 0.25 + district.local_heat * 0.3) \
				* (0.3 + 0.4 * rival.cunning + 0.3 * rival.caution) + grudge_bonus
		BM.RivalAction.RECRUIT:
			# weakness here is recruit_susceptibility(lieutenant); district unused.
			return weakness * (0.2 + 0.6 * rival.cunning) + grudge_bonus
		_:
			return -INF  # remaining actions are future slices

## Deterministic argmax across ALL (action, target) candidates in one total order:
## player venues × {PROBE, SABOTAGE, FRAME}, neutral venues × EXPAND, player
## lieutenants × RECRUIT. The COMMIT filter runs on RAW scores (a rival that always
## acts is noise — and jitter can never make it act or wait); the argmax runs on
## raw + tie_jitter, so the hash only orders near-equal committed candidates. Exact
## ranked ties (and the pre-P07b behavior at salt 0 with clear gaps) still resolve to
## the first candidate in authored iteration order. Returns {} when nothing commits.
static func choose_move(districts: Array[DistrictData], player_faction_id: StringName,
		rival: FactionData, characters: Array[CharacterData] = [], salt: int = 0) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for district in districts:
		for venue in district.venues:
			if venue.owner_faction == player_faction_id:
				var weakness := target_weakness(venue, district)
				for action in [BM.RivalAction.PROBE, BM.RivalAction.SABOTAGE, BM.RivalAction.FRAME]:
					var s := score_action(action, weakness, rival, district)
					if s >= COMMIT_THRESHOLD:
						candidates.append({"venue": venue, "character": null,
							"target_id": venue.id, "action": action, "score": s})
			elif venue.owner_faction != rival.id:
				var s := score_action(BM.RivalAction.EXPAND,
					target_weakness(venue, district), rival, district)
				if s >= COMMIT_THRESHOLD:
					candidates.append({"venue": venue, "character": null,
						"target_id": venue.id, "action": BM.RivalAction.EXPAND, "score": s})
	for character in characters:
		if character.is_player or character.faction_id != player_faction_id:
			continue
		var s := score_action(BM.RivalAction.RECRUIT,
			recruit_susceptibility(character), rival, null)
		if s >= COMMIT_THRESHOLD:
			candidates.append({"venue": null, "character": character,
				"target_id": character.id, "action": BM.RivalAction.RECRUIT, "score": s})
	var best := {}
	var best_ranked := -INF
	for c in candidates:
		var ranked: float = c["score"] + tie_jitter(rival.id, c["target_id"], c["action"], salt)
		if ranked > best_ranked:
			best_ranked = ranked
			best = c
	return best
