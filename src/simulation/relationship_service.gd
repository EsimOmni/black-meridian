class_name RelationshipService
extends Node
## RelationshipService (P10) — connects the motive network (CharacterData, brief §7.6)
## to a consequence: telegraphed, PREVENTABLE betrayal. Bootstrap-wired node, NOT an
## autoload (the P09 lesson: a driver that mutates shared state must not run under
## other systems' test scenes). Two-phase like RivalDirector: both gates hold →
## TELEGRAPH (tells appear, the defusal window opens) → after a fixed lead, LAND.
## Gates are re-checked every rival tick of the window — raise trust/shared_success
## or remove the opportunity and the intent DEFUSES. Zero RNG anywhere: betrayal is
## never an untelegraphed random roll (§7.6, verbatim).
##
## Intent state lives ON CharacterData (betrayal_ticks_until_land, like FactionData's
## rival intent in P07) so saves stay additive and this node stays stateless.

signal betrayal_telegraphed(character: CharacterData)
signal betrayal_defused(character: CharacterData)
signal betrayal_committed(character: CharacterData, venue: VenueData)

func _ready() -> void:
	TimeService.rival_tick.connect(_on_rival_tick)

func _on_rival_tick(_tick: int) -> void:
	# Open intents first (P10b: each lieutenant's intent is independent) — every one
	# advances on its own gate re-check: defuse, count down, or land. A char whose
	# intent defused this tick fails the same gates below; one that landed has its
	# motives discharged — no same-tick re-open by construction.
	for c in GameState.characters:
		if c.betrayal_ticks_until_land >= 0:
			_advance_intent(c)
	# Council modulation (P09 pattern): the setup beat — no NEW betrayal telegraph
	# opens mid-Council. Already-open intents (above) still count down and land.
	if GameState.phase == BM.Phase.COUNCIL:
		return
	# Bounded escalation: at most MAX_NEW_INTENTS_PER_RIVAL_TICK new telegraphs per
	# rival tick — multiple crises stack across ticks, never all at once.
	var candidates := LoyaltyScoring.choose_betrayers(GameState.characters,
		GameState.districts, GameState.factions, GameState.player_faction_id,
		LoyaltyScoring.MAX_NEW_INTENTS_PER_RIVAL_TICK)
	for candidate in candidates:
		candidate.betrayal_ticks_until_land = LoyaltyScoring.TELEGRAPH_LEAD_RIVAL_TICKS
		# P10b hidden motives: capture what drove THIS intent; every new intent starts hidden.
		candidate.betrayal_driving_motive = LoyaltyScoring.driving_motive(candidate)
		candidate.motive_revealed = false
		betrayal_telegraphed.emit(candidate)

## The preventability contract (§7.6): gates are re-checked every rival tick of the
## window INCLUDING the landing one — defusal always wins over the countdown.
func _advance_intent(c: CharacterData) -> void:
	if not LoyaltyScoring.gates_hold(c, GameState.districts, GameState.factions):
		c.betrayal_ticks_until_land = -1
		betrayal_defused.emit(c)
		return
	c.betrayal_ticks_until_land -= 1
	if c.betrayal_ticks_until_land <= 0:
		_land(c)

## One bounded, legible effect (P10 scope): the lieutenant's ground defects to
## CONTESTED — income drops to the 0.3× control modifier and the venue now reads as
## a prime rival target. The act discharges the motives that drove it (the grievance
## spent, the rival's leverage cashed in), so the crisis doesn't instantly re-arm.
func _land(c: CharacterData) -> void:
	c.betrayal_ticks_until_land = -1
	var venue := LoyaltyScoring.betrayal_target(GameState.districts, c.faction_id)
	if venue != null:
		venue.control_state = BM.ControlState.CONTESTED
	c.grievance = 0.0
	c.rival_leverage = 0.0
	betrayal_committed.emit(c, venue)

## The player's defusal verb (greybox): spend clean capital to raise trust and shared
## success — cut the lieutenant back in. Whether that defuses the intent is decided by
## the same gate re-check as everything else; there is no special-case path.
func reassure(c: CharacterData) -> bool:
	var pf := GameState.player_faction()
	if pf == null or pf.clean_capital < LoyaltyScoring.REASSURE_COST_CLEAN:
		return false
	pf.clean_capital -= LoyaltyScoring.REASSURE_COST_CLEAN
	c.public_trust = clampf(c.public_trust + LoyaltyScoring.REASSURE_TRUST_GAIN, 0.0, 1.0)
	c.shared_success = clampf(c.shared_success + LoyaltyScoring.REASSURE_SHARED_GAIN, 0.0, 1.0)
	# P10b: the reassure IS the sit-down — it reveals what's eating them whether or not
	# the money moves them. Deterministic player-driven reveal, never a roll.
	c.motive_revealed = true
	return true
