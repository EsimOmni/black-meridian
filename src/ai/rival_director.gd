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
	var pick := RivalScoring.choose_move(GameState.districts, GameState.player_faction_id, rival)
	if pick.is_empty():
		return
	rival.intent_action = pick["action"]
	rival.intent_venue_id = pick["venue"].id
	rival.intent_ticks_until_land = RivalScoring.TELEGRAPH_LEAD_RIVAL_TICKS
	rival_intent_telegraphed.emit(rival, pick["venue"], pick["action"])

## The landed effect only writes the venue's sabotage component — the economy composes
## it into disruption at settle (P06's single-writer pass) and income drops from there.
## Never touches owner_faction/control_state (ownership shift is its own future slice).
func _land(rival: FactionData) -> void:
	var venue := _find_venue(rival.intent_venue_id)
	var action := rival.intent_action
	rival.intent_action = -1
	rival.intent_venue_id = &""
	rival.intent_ticks_until_land = 0
	if venue == null:
		return
	match action:
		BM.RivalAction.SABOTAGE:
			venue.sabotage_disruption = RivalScoring.SABOTAGE_DISRUPTION
			venue.sabotage_ticks = RivalScoring.SABOTAGE_DURATION_TICKS
		BM.RivalAction.PROBE:
			venue.sabotage_disruption = RivalScoring.PROBE_DISRUPTION
			venue.sabotage_ticks = RivalScoring.PROBE_DURATION_TICKS
	rival_action_landed.emit(rival, venue, action)

func _find_venue(venue_id: StringName) -> VenueData:
	for district in GameState.districts:
		for venue in district.venues:
			if venue.id == venue_id:
				return venue
	return null
