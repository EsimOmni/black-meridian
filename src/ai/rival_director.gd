extends Node
## RivalDirector (autoload) — the first system that reacts to the player (brief §7.4).
## Consumes TimeService.rival_tick (fired every ~10 strategic ticks, previously unread).
## Two-phase like P06's inspection beat: commit → TELEGRAPH (the player sees it coming
## and can respond) → after a fixed lead, LAND. Deterministic end to end — the scoring
## is a pure argmax in RivalScoring; this node only holds the window state (brief §7.6).

signal rival_intent_telegraphed(faction: FactionData, venue: VenueData, action: int)
signal rival_action_landed(faction: FactionData, venue: VenueData, action: int)

func _ready() -> void:
	TimeService.rival_tick.connect(_on_rival_tick)

func _on_rival_tick(_tick: int) -> void:
	for faction in GameState.factions:
		if not faction.is_player:
			_act(faction)

func _act(rival: FactionData) -> void:
	# P07c: a grudge cools each rival tick — leave a rival alone and it forgets. Decay runs
	# every tick regardless of intent state (the memory fades whether or not it's mid-plan).
	rival.grudge = maxf(0.0, rival.grudge - RivalScoring.GRUDGE_DECAY_PER_TICK)
	if rival.intent_action >= 0:
		rival.intent_ticks_until_land -= 1
		if rival.intent_ticks_until_land <= 0:
			_land(rival)
		return
	# P09 Council modulation (brief §5.2): the setup beat — no NEW telegraph opens
	# mid-Council. An already-telegraphed intent (above) still counts down and lands;
	# the promise made to the player stays deterministic (§7.6).
	if GameState.phase == BM.Phase.COUNCIL:
		return
	var pick := RivalScoring.choose_move(GameState.districts, GameState.player_faction_id,
		rival, GameState.characters, rival.intents_committed)
	if pick.is_empty():
		return
	rival.intent_action = pick["action"]
	rival.intent_venue_id = pick["target_id"]  # venue id, or character id for RECRUIT
	rival.intent_ticks_until_land = RivalScoring.TELEGRAPH_LEAD_RIVAL_TICKS
	rival.intents_committed += 1  # P07b jitter salt advances per decision, persisted
	rival_intent_telegraphed.emit(rival, pick["venue"], pick["action"])

## Landed effects, one bounded write each. PROBE/SABOTAGE arm the venue's sabotage
## component — the economy composes it into disruption at settle (P06's single-writer
## pass). EXPAND (P07b) plants the rival's flag on NEUTRAL ground at the lowest tier —
## the one place ownership shifts; player property is never taken here. FRAME (P07b)
## bumps district heat additively (the JobLifecycle pattern) so the P06 latch reacts
## through its normal, telegraphed path. RECRUIT (P07b) targets a CHARACTER: bounded
## leverage gain feeding the P10b motive network; its landed signal carries venue=null
## (every consumer is audited null-safe).
func _land(rival: FactionData) -> void:
	var action := rival.intent_action
	var target_id := rival.intent_venue_id
	rival.intent_action = -1
	rival.intent_venue_id = &""
	rival.intent_ticks_until_land = 0
	if action == BM.RivalAction.RECRUIT:
		var character := GameState.get_character(target_id)
		if character == null:
			return
		character.rival_leverage = clampf(
			character.rival_leverage + RivalScoring.RECRUIT_LEVERAGE, 0.0, 1.0)
		character.recruited_by_faction = rival.id  # remember the destination for a later betrayal
		rival_action_landed.emit(rival, null, action)
		return
	var venue := _find_venue(target_id)
	if venue == null:
		return
	match action:
		BM.RivalAction.SABOTAGE:
			venue.sabotage_disruption = RivalScoring.SABOTAGE_DISRUPTION
			venue.sabotage_ticks = RivalScoring.SABOTAGE_DURATION_TICKS
		BM.RivalAction.PROBE:
			venue.sabotage_disruption = RivalScoring.PROBE_DISRUPTION
			venue.sabotage_ticks = RivalScoring.PROBE_DURATION_TICKS
		BM.RivalAction.EXPAND:
			venue.owner_faction = rival.id
			venue.control_state = BM.ControlState.INFLUENCED
		BM.RivalAction.FRAME:
			var district := GameState.get_district_of_venue(venue)
			if district != null:
				district.local_heat = clampf(
					district.local_heat + RivalScoring.FRAME_HEAT, 0.0, 1.0)
	rival_action_landed.emit(rival, venue, action)

func _find_venue(venue_id: StringName) -> VenueData:
	for district in GameState.districts:
		for venue in district.venues:
			if venue.id == venue_id:
				return venue
	return null
