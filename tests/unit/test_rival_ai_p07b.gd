extends Node
## P07b unit test — EXPAND / RECRUIT / FRAME + deterministic tie-break jitter.
## Run as a scene, NOT via -s (-s skips autoloads):
##   Godot --headless --path . res://tests/unit/test_rival_ai_p07b.tscn

var _failures := 0
var _telegraphs := 0
var _landings := 0
var _last_telegraph_action := -1
var _last_telegraph_target: StringName = &""
var _last_land_action := -1

func _ready() -> void:
	RivalDirector.rival_intent_telegraphed.connect(func(_f, v, a):
		_telegraphs += 1
		_last_telegraph_action = a
		_last_telegraph_target = v.id if v != null else &"")
	RivalDirector.rival_action_landed.connect(func(_f, _v, a):
		_landings += 1
		_last_land_action = a)
	_test_no_rng_in_ai_files()
	_test_expand_full_loop()
	_test_recruit_full_loop()
	_test_frame_full_loop()
	_test_caution_likes_frame_hates_sabotage()
	_test_jitter_is_deterministic()
	_test_jitter_cannot_flip_clear_winner()
	_test_jitter_breaks_near_ties()
	_test_probe_sabotage_regression()
	_test_intents_committed_save_round_trip()
	if _failures == 0:
		print("[PASS] all P07b rival tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d P07b rival assertion(s) failed" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("  assertion failed: ", msg)

func _fresh_world() -> DistrictData:
	WorldSeed.build()
	TimeService.set_speed(BM.Speed.PAUSED)
	TimeService.tick_index = 0
	JobDirector.active_jobs = []
	_telegraphs = 0
	_landings = 0
	_last_telegraph_action = -1
	_last_telegraph_target = &""
	_last_land_action = -1
	var d := GameState.get_district(&"glass_wharf")
	_drop_neutral_bait(d)  # baseline a calm world with NO free neutral ground; the EXPAND test injects its own
	return d

## The seed ships one neutral EXPAND-bait venue (gw_saltworks, P08b). These tests baseline a calm
## world with no free ground (the EXPAND test injects gw_union_hall itself); drop the seeded bait.
func _drop_neutral_bait(d: DistrictData) -> void:
	for i in range(d.venues.size() - 1, -1, -1):
		if d.venues[i].owner_faction == &"":
			d.venues.remove_at(i)

func _pump(n: int) -> void:
	for i in n:
		TimeService._do_tick()

func _corvine() -> FactionData:
	return GameState.get_faction(&"corvine")

## Brief §7.6: still zero RNG after P07b — the jitter is a string hash, not a generator.
func _test_no_rng_in_ai_files() -> void:
	for path in ["res://src/ai/rival_scoring.gd", "res://src/ai/rival_director.gd"]:
		var text := FileAccess.get_file_as_string(path)
		_check(text != "", "%s readable" % path)
		_check(not ("randf" in text) and not ("randi" in text) and not ("randomize" in text)
			and not ("RandomNumberGenerator" in text), "%s contains no RNG" % path)

## EXPAND: the rival plants its flag on injected NEUTRAL ground in an otherwise calm
## world (nothing player-side clears the commit threshold), telegraph → land →
## owner_faction + control_state written. Also: without neutral ground, calm = no move.
func _test_expand_full_loop() -> void:
	var d := _fresh_world()
	var pick := RivalScoring.choose_move(GameState.districts, GameState.player_faction_id,
		_corvine(), GameState.characters, 0)
	_check(pick.is_empty(), "calm world without neutral ground: rival still waits")
	var neutral := VenueData.new()
	neutral.id = &"gw_union_hall"
	neutral.display_name = "Dockside Union Hall"
	neutral.type = BM.VenueType.NEUTRAL_INSTITUTION
	neutral.owner_faction = &""
	neutral.control_state = BM.ControlState.CONTESTED  # visibly soft neutral ground
	d.venues.append(neutral)
	pick = RivalScoring.choose_move(GameState.districts, GameState.player_faction_id,
		_corvine(), GameState.characters, 0)
	_check(not pick.is_empty() and pick["action"] == BM.RivalAction.EXPAND,
		"soft neutral ground draws EXPAND")
	_check(pick["target_id"] == &"gw_union_hall", "EXPAND targets the neutral venue, never the player's")
	_pump(10)  # rival tick #1: telegraph
	_check(_telegraphs == 1 and _last_telegraph_action == BM.RivalAction.EXPAND,
		"EXPAND telegraphs through the existing signal (got action %d)" % _last_telegraph_action)
	_check(_corvine().intent_venue_id == &"gw_union_hall", "intent stores the venue target id")
	_check(neutral.owner_faction == &"", "no ownership shift during the telegraph window")
	_pump(30)  # rival tick #4: lands
	_check(_landings == 1 and _last_land_action == BM.RivalAction.EXPAND, "EXPAND lands after the lead")
	_check(neutral.owner_faction == &"corvine", "landed EXPAND shifts the neutral venue to the rival")
	_check(neutral.control_state == BM.ControlState.INFLUENCED, "landed EXPAND plants the LOWEST tier")

## RECRUIT: a visibly disgruntled lieutenant (public motives only) draws the lean;
## the landed effect writes rival_leverage, which provably raises betrayal_pressure
## AND feeds LoyaltyScoring's OPP_LEVERAGE_PRESSED opportunity term (P10b cross-system).
func _test_recruit_full_loop() -> void:
	_fresh_world()
	var bengal := GameState.get_character(&"bengal_lt")
	bengal.public_trust = 0.1
	bengal.grievance = 0.9
	bengal.ambition = 0.8
	var pick := RivalScoring.choose_move(GameState.districts, GameState.player_faction_id,
		_corvine(), GameState.characters, 0)
	_check(not pick.is_empty() and pick["action"] == BM.RivalAction.RECRUIT,
		"a visibly disgruntled lieutenant draws RECRUIT over every venue action")
	_check(pick["character"] == bengal and pick["venue"] == null,
		"RECRUIT pick carries the character, no venue")
	_pump(10)  # telegraph
	_check(_telegraphs == 1 and _last_telegraph_action == BM.RivalAction.RECRUIT,
		"RECRUIT telegraphs (venue=null crosses every consumer safely)")
	_check(_corvine().intent_venue_id == &"bengal_lt", "intent stores the CHARACTER id as target")
	_check(bengal.rival_leverage == 0.0, "no leverage during the response window")
	_pump(30)  # lands
	_check(_landings == 1 and _last_land_action == BM.RivalAction.RECRUIT, "RECRUIT lands after the lead")
	_check(absf(bengal.rival_leverage - RivalScoring.RECRUIT_LEVERAGE) < 0.0001,
		"landed RECRUIT writes the bounded leverage increment (got %f)" % bengal.rival_leverage)
	# Cross-system proof 1: the leverage raises betrayal_pressure by exactly its value.
	var p_with := bengal.betrayal_pressure()
	var lev := bengal.rival_leverage
	bengal.rival_leverage = 0.0
	var p_without := bengal.betrayal_pressure()
	bengal.rival_leverage = lev
	_check(absf(p_with - p_without - RivalScoring.RECRUIT_LEVERAGE) < 0.0001,
		"leverage raises betrayal_pressure by +%f (got %f)"
		% [RivalScoring.RECRUIT_LEVERAGE, p_with - p_without])
	# Cross-system proof 2: while the rival's NEXT intent is open, the pressed leverage
	# feeds the P10b opportunity gate (OPP_LEVERAGE_PRESSED × leverage).
	_pump(10)  # rival tick #5: the still-disgruntled lieutenant draws the next lean
	_check(_corvine().intent_action >= 0, "a next rival intent is open")
	var opp := LoyaltyScoring.betrayal_opportunity(bengal, GameState.districts, GameState.factions)
	var expected := RivalScoring.RECRUIT_LEVERAGE * LoyaltyScoring.OPP_LEVERAGE_PRESSED
	_check(absf(opp - expected) < 0.0001,
		"pressed leverage feeds betrayal opportunity (%f, expected %f)" % [opp, expected])
	_check(bengal.rival_leverage <= 1.0, "leverage stays clamped")

## FRAME: on a simmering district (heat 0.7, latch spent) the deniable play wins;
## the landed effect bumps district heat through the accumulate/decay integrator and
## deals NO direct venue damage.
func _test_frame_full_loop() -> void:
	var d := _fresh_world()
	d.local_heat = 0.7
	d.inspection_armed = false  # the latch already fired this excursion — no sweep mid-test
	_pump(10)  # rival tick #1
	_check(_telegraphs == 1 and _last_telegraph_action == BM.RivalAction.FRAME,
		"a simmering district draws FRAME (got action %d)" % _last_telegraph_action)
	var target_id := _corvine().intent_venue_id
	_pump(29)  # ride the window to just before the landing tick
	var heat_before := d.local_heat
	_pump(1)   # rival tick #4: lands
	_check(_landings == 1 and _last_land_action == BM.RivalAction.FRAME, "FRAME lands after the lead")
	_check(d.local_heat - heat_before >= 0.2,
		"landed FRAME bumps district heat by ~%f (got +%f)"
		% [RivalScoring.FRAME_HEAT, d.local_heat - heat_before])
	_check(d.local_heat <= 1.0, "heat stays clamped")
	for v in d.venues:
		if v.id == target_id:
			_check(v.sabotage_ticks == 0 and v.sabotage_disruption == 0.0,
				"FRAME deals no direct venue damage (deniable, unlike SABOTAGE)")

## Personality inversion (§7.4): caution LIKES the frame (deniable) and hates the
## strike in a hot district — the same knob pushes opposite ways per action.
func _test_caution_likes_frame_hates_sabotage() -> void:
	var d := _fresh_world()
	d.local_heat = 0.5
	var timid := FactionData.new()
	timid.aggression = 0.5
	timid.cunning = 0.5
	timid.caution = 0.9
	var bold := FactionData.new()
	bold.aggression = 0.5
	bold.cunning = 0.5
	bold.caution = 0.1
	var w := 0.5
	_check(RivalScoring.score_action(BM.RivalAction.FRAME, w, timid, d)
		> RivalScoring.score_action(BM.RivalAction.FRAME, w, bold, d),
		"caution raises the FRAME score (deniable)")
	_check(RivalScoring.score_action(BM.RivalAction.SABOTAGE, w, timid, d)
		< RivalScoring.score_action(BM.RivalAction.SABOTAGE, w, bold, d),
		"caution lowers the SABOTAGE score in a hot district")

# --- Jitter (pure, synthetic worlds — no autoload state) -----------------------

func _jitter_rival() -> FactionData:
	var r := FactionData.new()
	r.id = &"jt_rival"
	r.aggression = 0.7
	r.caution = 0.3
	r.cunning = 0.8
	return r

func _jitter_world(v2_state: int) -> Array[DistrictData]:
	var d := DistrictData.new()
	d.id = &"jt_district"
	d.local_heat = 0.0
	var v1 := VenueData.new()
	v1.id = &"jt_alpha"
	v1.type = BM.VenueType.RACKET
	v1.owner_faction = &"jt_player"
	v1.control_state = BM.ControlState.CONTESTED
	var v2 := VenueData.new()
	v2.id = &"jt_beta"
	v2.type = BM.VenueType.RACKET
	v2.owner_faction = &"jt_player"
	v2.control_state = v2_state
	d.venues = [v1, v2]
	var out: Array[DistrictData] = [d]
	return out

## Same inputs (state + salt) → the identical pick, every time. Zero-RNG determinism.
func _test_jitter_is_deterministic() -> void:
	var world := _jitter_world(BM.ControlState.CONTESTED)
	var rival := _jitter_rival()
	var no_chars: Array[CharacterData] = []
	var first := RivalScoring.choose_move(world, &"jt_player", rival, no_chars, 7)
	_check(not first.is_empty(), "near-tie world commits a move")
	for i in 25:
		var again := RivalScoring.choose_move(world, &"jt_player", rival, no_chars, 7)
		if again["venue"] != first["venue"] or again["action"] != first["action"] \
				or again["score"] != first["score"]:
			_check(false, "jittered choose_move diverged on repeat %d" % i)
			return
	for salt in 64:  # jitter is bounded: it can never manufacture or veto a commit
		var j := RivalScoring.tie_jitter(&"jt_rival", &"jt_alpha", BM.RivalAction.SABOTAGE, salt)
		_check(j >= 0.0 and j < RivalScoring.TIE_JITTER_EPSILON,
			"tie_jitter out of [0, epsilon) at salt %d: %f" % [salt, j])

## A clearly-better target (raw gap >> epsilon) wins for EVERY salt — the jitter only
## orders near-equals, it never overrides real utility. The weak venue never clears
## the RAW commit threshold, so no salt can make it the pick either.
func _test_jitter_cannot_flip_clear_winner() -> void:
	var world := _jitter_world(BM.ControlState.CONTROLLED)  # beta is clearly harder ground
	var rival := _jitter_rival()
	var no_chars: Array[CharacterData] = []
	for salt in 64:
		var pick := RivalScoring.choose_move(world, &"jt_player", rival, no_chars, salt)
		_check(not pick.is_empty() and pick["venue"].id == &"jt_alpha",
			"clear winner flipped at salt %d (got %s)"
			% [salt, pick["venue"].id if not pick.is_empty() else &"none"])

## Two identical targets = an exact raw tie. The hash decides it — stably per salt,
## and across salts the decision actually VARIES (the anti-robotic feel, zero RNG).
func _test_jitter_breaks_near_ties() -> void:
	var world := _jitter_world(BM.ControlState.CONTESTED)
	var rival := _jitter_rival()
	var no_chars: Array[CharacterData] = []
	var base := RivalScoring.choose_move(world, &"jt_player", rival, no_chars, 0)
	_check(not base.is_empty(), "tied world commits")
	var varied := false
	for salt in range(1, 64):
		var pick := RivalScoring.choose_move(world, &"jt_player", rival, no_chars, salt)
		if pick["venue"] != base["venue"] or pick["action"] != base["action"]:
			varied = true
			break
	_check(varied, "some salt in 1..63 resolves the exact tie differently than salt 0")

## P07 contract untouched: the legacy 3-arg call still compiles and still picks
## SABOTAGE on the softest player venue under an inspection; calm world still waits.
func _test_probe_sabotage_regression() -> void:
	var d := _fresh_world()
	d.inspection_ticks = 100
	var pick := RivalScoring.choose_move(GameState.districts, GameState.player_faction_id, _corvine())
	_check(not pick.is_empty() and pick["action"] == BM.RivalAction.SABOTAGE
		and pick["venue"].id == &"gw_protection",
		"P07 regression: inspection world still argmaxes SABOTAGE on gw_protection")
	_fresh_world()
	_check(RivalScoring.choose_move(GameState.districts, GameState.player_faction_id,
		_corvine()).is_empty(), "P07 regression: calm world still yields no move")

## The new jitter salt persists (save-additive, SAVE_VERSION unchanged) and an
## old save without the key decodes to the default.
func _test_intents_committed_save_round_trip() -> void:
	_fresh_world()
	_corvine().intents_committed = 7
	_check(SaveService.save_game("p07b_test"), "save with salt state")
	_corvine().intents_committed = 0  # clobber to prove load restores it
	_check(SaveService.load_game("p07b_test"), "load with salt state")
	_check(_corvine().intents_committed == 7,
		"intents_committed survives save/load (got %d)" % _corvine().intents_committed)
	var enc := SaveCodec.encode_faction(_corvine())
	enc.erase("intents_committed")  # simulate a pre-P07b save
	var f := SaveCodec.decode_faction(enc)
	_check(f.intents_committed == 0, "pre-P07b save decodes to the default salt")
