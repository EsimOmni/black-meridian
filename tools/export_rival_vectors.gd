extends SceneTree
## Rival-AI golden-vector extractor — the Unreal port's behavioral oracle (reboot S5).
##
## READ-ONLY. It drives RivalScoring (a pure static RefCounted) and writes one JSON
## document. It mutates no shipped resource, drives no autoload and authors no game state.
##
## Run:
##   D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . \
##       -s tools/export_rival_vectors.gd -- --out=<abs path>.json
##
## Like every sibling extractor it writes the file itself rather than printing to stdout:
## the godot_ai game_helper autoload emits a banner AFTER the script finishes and that
## trailing text corrupts a redirected document (S1 lesson).
##
## `[V]` WHY `-s` WORKS HERE. Autoloads do not exist in a `-s` SceneTree script. Verified by
## grep 2026-09-19: `rival_scoring.gd` contains ZERO autoload references — the three textual
## hits ("RivalDirector", "GameState") are all inside doc comments. Exactly the S4 split,
## where `SaveCodec` was driven and the `SaveService` autoload was not.
##
## `RivalDirector` IS an autoload and is deliberately NOT driven here. Its logic — the decay
## -> intent-countdown -> Council-gate -> commit order, the telegraph window, and the six
## landed effects — is transcribed into the port's FBMRivalDirector and pinned by the
## `director` layer's probe rows below rather than executed. Same shape as S3 (JobDirector)
## and S4 (SaveService).
##
## ─────────────────────────────────────────────────────────────────────────────────────
## `[V]` THE ENUM VALUES ARE A HASH CONTRACT — the single most dangerous thing in this file.
##
## tie_jitter composes "%s|%s|%d|%d" % [rival_id, target_id, action, salt] and hashes it, so
## a RivalAction's INTEGER VALUE feeds DJB2 -> avalanche -> the argmax ranking. The enum is
## SPARSE: the five scored actions are EXPAND=0, PROBE=1, SABOTAGE=2, RECRUIT=3 and FRAME=7,
## and the six enumerators between RECRUIT and FRAME (BRIBE, RETALIATE, NEGOTIATE,
## REDUCE_HEAT, DEFEND, EXPLOIT_GRIEVANCE) are read by NO code path in the shipped game.
##
## Those dead enumerators are what hold FRAME at 7. Deleting one as "dead code" — an
## entirely reasonable reflex — shifts FRAME and silently reshuffles every tie-break.
## Measured: FRAME 7 -> 4 moves gw_saltworks's jitter 0.009057 -> 0.000251 and
## gw_protection's 0.000873 -> 0.007252, REVERSING their order. A compiling, deterministic,
## different game with no symptom.
##
## So the `enum_values` layer below pins all eleven enumerators by name AND value, and the
## port asserts FRAME == 7 directly. Reordering, inserting, AND deleting an unused
## enumerator are all save-format AND behavior breaks.
## ─────────────────────────────────────────────────────────────────────────────────────
##
## `[V]` EVERY FLOAT IS A DECIMAL STRING, never a JSON number (S4 Finding 6: JSON.stringify
## truncates float64 to 15 significant digits, so 0.1+0.2 is written "0.3" — a DIFFERENT
## number — while var_to_str emits up to 17 and round-trips exactly). Scores and jitter are
## compared at 1e-9 rather than 1e-5: tie_jitter's whole range is TIE_JITTER_EPSILON = 0.01,
## so a 1e-5 tolerance would swallow a third of the signal this layer exists to measure.

const SCHEMA := 1
const DEFAULT_OUT := "D:/black-meridian-ue/Tests/Golden/rival_vectors.json"


func _init() -> void:
	var out := {
		"schema": SCHEMA,
		"source": "godot-final",
		"godot_version": Engine.get_version_info().string,
		"note": _note(),
		"float_encoding": "decimal_string",
		"constants": _constants(),
		"enum_values": _enum_values(),
		"weakness": _weakness_vectors(),
		"susceptibility": _susceptibility_vectors(),
		"score": _score_vectors(),
		"unscored": _unscored_vectors(),
		"jitter": _jitter_vectors(),
		"choose": _choose_vectors(),
		"director": _director_vectors(),
	}

	var path := _out_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		quit(1)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()

	print("wrote %s — %d enum, %d weakness, %d susceptibility, %d score, %d unscored, %d jitter, %d choose, %d director rows" % [
		path,
		out["enum_values"]["rows"].size(), out["weakness"]["rows"].size(),
		out["susceptibility"]["rows"].size(), out["score"]["rows"].size(),
		out["unscored"]["rows"].size(), out["jitter"]["rows"].size(),
		out["choose"]["rows"].size(), out["director"]["rows"].size()])
	quit(0)


func _out_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			return arg.trim_prefix("--out=")
	return DEFAULT_OUT


func _note() -> String:
	return ("Rival-AI vectors for reboot S5 (GV-RIVAL-01..08), extracted from the shipped " +
		"RivalScoring. EVERY FLOAT IS A DECIMAL STRING, never a JSON number — JSON.stringify " +
		"truncates float64 to 15 significant digits while var_to_str emits up to 17 and " +
		"round-trips exactly (S4 Finding 6). Read these with a full-precision parser " +
		"(FCString::Atod), never by taking a JSON number. Scores and jitter compare at 1e-9, " +
		"NOT the 1e-5 used by S2's state vectors: tie_jitter's entire range is " +
		"TIE_JITTER_EPSILON = 0.01, so 1e-5 would swallow a third of the measured signal. " +
		"Discrete fields — action ints, target ids, candidate counts, commit verdicts, " +
		"telegraph/land ticks — compare EXACTLY. THE ACTION ENUM VALUES ARE PART OF THE HASH: " +
		"tie_jitter hashes the action's INTEGER value, the enum is sparse (FRAME=7 with six " +
		"unread enumerators before it), and deleting an unused enumerator reshuffles every " +
		"tie-break. See the enum_values layer and the file header.")


## Every constant the rival's behavior depends on, read LIVE off the class that owns it —
## no transcription (S1's lesson: a transcribed constant is the silently-wrong-but-
## deterministic failure) and no regex parse (S2's extractors were forced into that; here
## RivalScoring is reachable directly under `-s`, which is strictly stronger).
func _constants() -> Dictionary:
	return {
		"sabotage_disruption": var_to_str(RivalScoring.SABOTAGE_DISRUPTION),
		"sabotage_duration_ticks": RivalScoring.SABOTAGE_DURATION_TICKS,
		"probe_disruption": var_to_str(RivalScoring.PROBE_DISRUPTION),
		"probe_duration_ticks": RivalScoring.PROBE_DURATION_TICKS,
		"recruit_leverage": var_to_str(RivalScoring.RECRUIT_LEVERAGE),
		"frame_heat": var_to_str(RivalScoring.FRAME_HEAT),
		"commit_threshold": var_to_str(RivalScoring.COMMIT_THRESHOLD),
		"telegraph_lead_rival_ticks": RivalScoring.TELEGRAPH_LEAD_RIVAL_TICKS,
		"tie_jitter_epsilon": var_to_str(RivalScoring.TIE_JITTER_EPSILON),
		"grudge_score_bonus": var_to_str(RivalScoring.GRUDGE_SCORE_BONUS),
		"grudge_sabotage_lean": var_to_str(RivalScoring.GRUDGE_SABOTAGE_LEAN),
		"grudge_decay_per_tick": var_to_str(RivalScoring.GRUDGE_DECAY_PER_TICK),
		"rival_tick_interval": BM.RIVAL_TICK_INTERVAL,
	}


## GV-RIVAL-01 — the enum is a hash contract. All eleven enumerators by name and value,
## plus which five are scored. A port that renumbers (or deletes an unused one, shifting
## FRAME) fails here BEFORE any jitter vector has a chance to look mysterious.
func _enum_values() -> Dictionary:
	var scored := [BM.RivalAction.EXPAND, BM.RivalAction.PROBE, BM.RivalAction.SABOTAGE,
		BM.RivalAction.RECRUIT, BM.RivalAction.FRAME]
	var rows: Array = []
	for name in BM.RivalAction.keys():
		var value: int = BM.RivalAction[name]
		rows.append({
			"name": name,
			"value": value,
			"scored": value in scored,
		})
	return {
		"id": "GV-RIVAL-01",
		"what": ("Every RivalAction enumerator by name and integer value. The value feeds " +
			"tie_jitter's hashed string, so it is a BEHAVIOR contract, not just a save " +
			"contract. The enum is SPARSE — six enumerators between RECRUIT(3) and FRAME(7) " +
			"are read by no code path, and they are the only thing holding FRAME at 7. " +
			"Deleting one as dead code reshuffles every tie-break silently."),
		"scored_count": scored.size(),
		"total_count": BM.RivalAction.keys().size(),
		"rows": rows,
	}


## GV-RIVAL-02 — target_weakness across every control state, with and without inspection,
## and the clamp. `[V]` Note COMPROMISED(0.35) sits between CONTESTED(0.4) and
## INFLUENCED(0.3) in weight while being LAST in enum order: weight order and enum order
## differ, exactly as BMTypes.h already warns for the control-state modifier.
func _weakness_vectors() -> Dictionary:
	var rows: Array = []
	var states := {
		"UNKNOWN": BM.ControlState.UNKNOWN,
		"CONTESTED": BM.ControlState.CONTESTED,
		"INFLUENCED": BM.ControlState.INFLUENCED,
		"CONTROLLED": BM.ControlState.CONTROLLED,
		"FORTIFIED": BM.ControlState.FORTIFIED,
		"COMPROMISED": BM.ControlState.COMPROMISED,
	}
	# Disruption values chosen to include 0, a mid value, and one that forces the clamp
	# to bite when combined with CONTESTED + inspection (0.5 + 0.4 + 0.3 = 1.2 -> 1.0).
	for disruption in [0.0, 0.35, 1.0]:
		for state_name in states:
			for inspection in [0, 12]:
				var venue := VenueData.new()
				venue.disruption = disruption
				venue.control_state = states[state_name]
				var district := DistrictData.new()
				district.inspection_ticks = inspection
				rows.append({
					"disruption": var_to_str(disruption),
					"control_state": state_name,
					"control_state_value": states[state_name],
					"inspection_ticks": inspection,
					"weakness": var_to_str(
						RivalScoring.target_weakness(venue, district)),
				})
	return {
		"id": "GV-RIVAL-02",
		"what": ("target_weakness over all six control states x three disruptions x " +
			"inspection on/off. FORTIFIED and UNKNOWN add nothing (the `_:` arm). The " +
			"CONTESTED + full disruption + inspection rows force the [0,1] clamp."),
		"rows": rows,
	}


## GV-RIVAL-03 — recruit_susceptibility. The FAIRNESS rule in numeric form: only the three
## PUBLIC motive fields are read. The rows deliberately vary the hidden block
## (rival_leverage, survival_pressure) while holding the public fields fixed, so a port
## that reads a hidden field produces a DIFFERENT number and fails — the leak becomes a
## measured failure rather than a code-review opinion (brief §7.4).
func _susceptibility_vectors() -> Dictionary:
	var rows: Array = []
	for trust in [0.0, 0.5, 1.0]:
		for grievance in [0.0, 0.6, 1.0]:
			for ambition in [0.0, 0.4, 1.0]:
				var c := CharacterData.new()
				c.public_trust = trust
				c.grievance = grievance
				c.ambition = ambition
				# Hidden block: set to NON-default values that a leaking port would read.
				c.rival_leverage = 0.9
				c.survival_pressure = 0.8
				rows.append({
					"public_trust": var_to_str(trust),
					"grievance": var_to_str(grievance),
					"ambition": var_to_str(ambition),
					"hidden_rival_leverage": var_to_str(0.9),
					"hidden_survival_pressure": var_to_str(0.8),
					"susceptibility": var_to_str(
						RivalScoring.recruit_susceptibility(c)),
				})
	return {
		"id": "GV-RIVAL-03",
		"what": ("recruit_susceptibility over the public motive grid. The hidden block is " +
			"set to non-default values on EVERY row: a port that reads rival_leverage or " +
			"survival_pressure yields a different number and fails here. That makes the " +
			"§7.4 fairness rule a measured property, not a review comment."),
		"rows": rows,
	}


## GV-RIVAL-04 — score_action for the five scored actions across a personality grid and
## a grudge sweep. This is the arithmetic core of the argmax.
func _score_vectors() -> Dictionary:
	var rows: Array = []
	var actions := {
		"EXPAND": BM.RivalAction.EXPAND,
		"PROBE": BM.RivalAction.PROBE,
		"SABOTAGE": BM.RivalAction.SABOTAGE,
		"RECRUIT": BM.RivalAction.RECRUIT,
		"FRAME": BM.RivalAction.FRAME,
	}
	# Two authored personalities (the shipped Compact and Corvine) plus the extremes.
	var personalities := [
		{"name": "corvine_authored", "agg": 0.7, "cau": 0.3, "cun": 0.8},
		{"name": "compact_authored", "agg": 0.4, "cau": 0.6, "cun": 0.7},
		{"name": "all_zero", "agg": 0.0, "cau": 0.0, "cun": 0.0},
		{"name": "all_one", "agg": 1.0, "cau": 1.0, "cun": 1.0},
	]
	for p in personalities:
		for grudge in [0.0, 0.5, 1.0]:
			var rival := FactionData.new()
			rival.id = &"corvine"
			rival.aggression = p["agg"]
			rival.caution = p["cau"]
			rival.cunning = p["cun"]
			rival.grudge = grudge
			for weakness in [0.0, 0.4, 1.0]:
				for heat in [0.0, 0.3, 1.0]:
					var district := DistrictData.new()
					district.local_heat = heat
					for action_name in actions:
						# `[V]` RECRUIT's arm never reads `district` — it is passed null
						# in the shipped call path. Passing the district here instead
						# would hide a port that wrongly dereferences it, so RECRUIT is
						# driven with null exactly as RivalDirector drives it.
						var d = null if actions[action_name] == BM.RivalAction.RECRUIT \
							else district
						rows.append({
							"personality": p["name"],
							"aggression": var_to_str(p["agg"]),
							"caution": var_to_str(p["cau"]),
							"cunning": var_to_str(p["cun"]),
							"grudge": var_to_str(grudge),
							"weakness": var_to_str(weakness),
							"local_heat": var_to_str(heat),
							"action": action_name,
							"action_value": actions[action_name],
							"district_is_null": d == null,
							"score": var_to_str(RivalScoring.score_action(
								actions[action_name], weakness, rival, d)),
						})
	return {
		"id": "GV-RIVAL-04",
		"what": ("score_action across 4 personalities x 3 grudges x 3 weaknesses x 3 heats " +
			"x 5 scored actions. RECRUIT is driven with a NULL district, exactly as " +
			"RivalDirector drives it — a port that dereferences district in the RECRUIT " +
			"arm crashes or diverges here rather than in a later integration."),
		"rows": rows,
	}


## GV-RIVAL-05 — the `_:` arm. Every UNSCORED enumerator returns -INF, which is what keeps
## the five future actions out of the argmax. `[V]` The roadmap's Prohibited line says
## "5 unscored actions"; there are SIX (BRIBE, RETALIATE, NEGOTIATE, REDUCE_HEAT, DEFEND,
## EXPLOIT_GRIEVANCE). Correction owed to the plan; the rule itself is unaffected.
func _unscored_vectors() -> Dictionary:
	var scored := [BM.RivalAction.EXPAND, BM.RivalAction.PROBE, BM.RivalAction.SABOTAGE,
		BM.RivalAction.RECRUIT, BM.RivalAction.FRAME]
	var rival := FactionData.new()
	rival.id = &"corvine"
	rival.aggression = 0.7
	rival.caution = 0.3
	rival.cunning = 0.8
	rival.grudge = 1.0   # even a maximal grudge must not lift an unscored action
	var district := DistrictData.new()
	district.local_heat = 0.5
	var rows: Array = []
	for name in BM.RivalAction.keys():
		var value: int = BM.RivalAction[name]
		if value in scored:
			continue
		var s: float = RivalScoring.score_action(value, 1.0, rival, district)
		rows.append({
			"name": name,
			"value": value,
			"score": var_to_str(s),
			"is_neg_inf": s == -INF,
		})
	return {
		"id": "GV-RIVAL-05",
		"what": ("Every UNSCORED enumerator scored at maximum weakness and maximum grudge. " +
			"All must be -INF so they can never enter the argmax. NOTE: there are SIX " +
			"unscored actions, not the five the roadmap's Prohibited line claims — a " +
			"correction owed to the plan."),
		"unscored_count": rows.size(),
		"rows": rows,
	}


## GV-RIVAL-06 — tie_jitter. The S1 hash composed into its rival-facing form.
##
## `[V]` The salt sweep is the point: DJB2 alone has almost no avalanche, so without the
## bit-mix a +1 salt moves the bucket by ~1 and the GAP between two targets stays constant
## forever — the tie-break freezes to one direction and the anti-robotic feel dies. These
## rows pin that the salt genuinely reshuffles.
func _jitter_vectors() -> Dictionary:
	var rows: Array = []
	for rival_id in [&"corvine", &"compact"]:
		for target_id in [&"gw_saltworks", &"gw_protection", &"gw_contraband", &""]:
			for action in [BM.RivalAction.EXPAND, BM.RivalAction.PROBE,
					BM.RivalAction.SABOTAGE, BM.RivalAction.RECRUIT, BM.RivalAction.FRAME]:
				for salt in [0, 1, 2, 7, 41, 1000]:
					rows.append({
						"rival_id": String(rival_id),
						"target_id": String(target_id),
						"action": action,
						"salt": salt,
						"composed": "%s|%s|%d|%d" % [rival_id, target_id, action, salt],
						"jitter": var_to_str(
							RivalScoring.tie_jitter(rival_id, target_id, action, salt)),
					})
	return {
		"id": "GV-RIVAL-06",
		"what": ("tie_jitter over 2 rivals x 4 targets (including the empty id) x 5 actions " +
			"x 6 salts. `composed` carries the EXACT hashed string so a port that formats " +
			"it differently fails with a readable diff instead of a mystery float. Every " +
			"value lies in [0, TIE_JITTER_EPSILON). The salt sweep pins that the bit-mix " +
			"actually reshuffles — raw DJB2 would move the bucket by ~1 per salt and freeze " +
			"the tie-break direction forever."),
		"rows": rows,
	}


## GV-RIVAL-07 — choose_move end to end: candidate construction, the RAW commit filter, the
## jitter-ranked argmax, and the iteration order that breaks exact ties.
##
## `[V]` Worlds are built to exercise four distinct shapes: nothing commits, exactly one
## commits (the shipped seed's own situation), several commit with a clear gap, and two
## commit within TIE_JITTER_EPSILON so the jitter DECIDES. That last shape is the one the
## shipped seed cannot produce — measured: at tick 240 only gw_saltworks EXPAND clears the
## threshold (0.3463 against 0.2765 for the runner-up), so a port with a broken tie-break
## would pass a seed-only comparison. It is constructed here deliberately.
func _choose_vectors() -> Dictionary:
	var rows: Array = []
	for world_name in ["empty", "nothing_commits", "single_commit", "clear_gap", "near_tie"]:
		for salt in [0, 1, 2, 3]:
			var built := _build_choose_world(world_name)
			var pick: Dictionary = RivalScoring.choose_move(
				built["districts"], &"compact", built["rival"],
				built["characters"], salt)
			var candidates := _enumerate_candidates(built, &"compact")
			rows.append({
				"world": world_name,
				"salt": salt,
				"candidate_count": candidates.size(),
				"candidates": candidates,
				"picked": not pick.is_empty(),
				"action": pick.get("action", -1),
				"target_id": String(pick.get("target_id", &"")),
				"score": var_to_str(pick.get("score", 0.0)) if not pick.is_empty() else "",
			})
	return {
		"id": "GV-RIVAL-07",
		"what": ("choose_move over five worlds x four salts. `candidates` lists every " +
			"(action, target) the scorer built, IN ITERATION ORDER, with its raw score and " +
			"commit verdict — so a port with the right winner but the wrong candidate set " +
			"or order still fails. The near_tie world puts two candidates within " +
			"TIE_JITTER_EPSILON so the jitter decides and the salt flips the winner; the " +
			"shipped seed CANNOT produce that shape (only one candidate commits there), so " +
			"a seed-only comparison would pass a broken tie-break."),
		"rows": rows,
	}


## Rebuilds the candidate list the way choose_move does, for the fixture's audit column.
## `[V]` Mirrors choose_move's loop ORDER exactly: districts -> venues -> (player venue:
## PROBE, SABOTAGE, FRAME in that literal array order | non-rival venue: EXPAND), then
## characters -> RECRUIT. Order matters because an exact ranked tie resolves to the FIRST
## candidate (`ranked > best_ranked` is strict).
func _enumerate_candidates(built: Dictionary, player_id: StringName) -> Array:
	var out: Array = []
	var rival: FactionData = built["rival"]
	for district in built["districts"]:
		for venue in district.venues:
			if venue.owner_faction == player_id:
				var w := RivalScoring.target_weakness(venue, district)
				for action in [BM.RivalAction.PROBE, BM.RivalAction.SABOTAGE,
						BM.RivalAction.FRAME]:
					var s := RivalScoring.score_action(action, w, rival, district)
					out.append({
						"target_id": String(venue.id), "action": action,
						"score": var_to_str(s),
						"commits": s >= RivalScoring.COMMIT_THRESHOLD,
					})
			elif venue.owner_faction != rival.id:
				var s := RivalScoring.score_action(BM.RivalAction.EXPAND,
					RivalScoring.target_weakness(venue, district), rival, district)
				out.append({
					"target_id": String(venue.id), "action": BM.RivalAction.EXPAND,
					"score": var_to_str(s),
					"commits": s >= RivalScoring.COMMIT_THRESHOLD,
				})
	for character in built["characters"]:
		if character.is_player or character.faction_id != player_id:
			continue
		var s := RivalScoring.score_action(BM.RivalAction.RECRUIT,
			RivalScoring.recruit_susceptibility(character), rival, null)
		out.append({
			"target_id": String(character.id), "action": BM.RivalAction.RECRUIT,
			"score": var_to_str(s),
			"commits": s >= RivalScoring.COMMIT_THRESHOLD,
		})
	return out


func _build_choose_world(name: String) -> Dictionary:
	var rival := FactionData.new()
	rival.id = &"corvine"
	rival.aggression = 0.7
	rival.caution = 0.3
	rival.cunning = 0.8
	rival.grudge = 0.0

	var district := DistrictData.new()
	district.id = &"glass_wharf"
	district.local_heat = 0.0
	district.inspection_ticks = 0

	var districts: Array[DistrictData] = []
	var characters: Array[CharacterData] = []

	match name:
		"empty":
			pass  # no districts at all — choose_move must return {}
		"nothing_commits":
			# A single FORTIFIED player venue: weakness 0, every score below 0.3.
			districts.append(district)
			district.venues = [_venue(&"gw_vault", &"compact",
				BM.ControlState.FORTIFIED, 0.0)]
		"single_commit":
			# The shipped seed's own shape: one unowned CONTESTED venue -> EXPAND at
			# 0.3463, everything else below threshold.
			districts.append(district)
			district.venues = [
				_venue(&"gw_contraband", &"compact", BM.ControlState.CONTROLLED, 0.0),
				_venue(&"gw_saltworks", &"", BM.ControlState.CONTESTED, 0.0),
			]
		"clear_gap":
			# Two committing candidates whose RAW gap far exceeds TIE_JITTER_EPSILON,
			# so the jitter cannot reorder them at any salt.
			districts.append(district)
			district.venues = [
				_venue(&"gw_weak", &"compact", BM.ControlState.CONTESTED, 1.0),
				_venue(&"gw_mid", &"compact", BM.ControlState.INFLUENCED, 0.0),
			]
		"near_tie":
			# `[V]` Two IDENTICALLY-scored candidates: same control state, same
			# disruption, different ids. The raw scores are equal, so the ranking is
			# decided entirely by tie_jitter and the salt flips the winner. This is the
			# shape the shipped seed cannot produce.
			districts.append(district)
			district.venues = [
				_venue(&"gw_alpha", &"compact", BM.ControlState.CONTESTED, 0.5),
				_venue(&"gw_beta", &"compact", BM.ControlState.CONTESTED, 0.5),
			]
	return {"districts": districts, "rival": rival, "characters": characters}


func _venue(id: StringName, owner: StringName, control: int,
		disruption: float) -> VenueData:
	var v := VenueData.new()
	v.id = id
	v.owner_faction = owner
	v.control_state = control
	v.disruption = disruption
	return v


## GV-RIVAL-08 — the RivalDirector decision sequence, TRANSCRIBED not driven (it is an
## autoload). These rows pin the ORDER of its four decisions per rival tick, which is the
## part a port most easily gets subtly wrong.
##
## `[V]` The order is: (1) decay the grudge ALWAYS — even mid-plan, (2) if an intent is
## live, count down and land at <= 0, then RETURN (no new commit this tick), (3) if the
## phase is COUNCIL, return without committing — an ALREADY-telegraphed intent still lands,
## (4) otherwise score and maybe commit, incrementing the salt.
##
## The rows are authored from the shipped source rather than executed, exactly as S4 did
## for SaveService. Each carries the source line it transcribes so a reviewer can check it.
func _director_vectors() -> Dictionary:
	var lead: int = RivalScoring.TELEGRAPH_LEAD_RIVAL_TICKS
	var decay: float = RivalScoring.GRUDGE_DECAY_PER_TICK
	return {
		"id": "GV-RIVAL-08",
		"what": ("The RivalDirector per-rival-tick decision sequence, transcribed from " +
			"src/ai/rival_director.gd (an autoload, so not driven under -s — the S3/S4 " +
			"split). Each row names the source line it encodes."),
		"telegraph_lead_rival_ticks": lead,
		"grudge_decay_per_tick": var_to_str(decay),
		"rows": [
			{
				"step": 1, "name": "grudge_decays_every_tick",
				"source": "rival_director.gd:22",
				"rule": "rival.grudge = max(0, grudge - GRUDGE_DECAY_PER_TICK)",
				"note": ("Runs BEFORE every other branch and regardless of intent state — " +
					"the memory fades whether or not the rival is mid-plan. A port that " +
					"decays only when idle keeps grudges alive through every telegraph."),
				"floor_is_zero": true,
			},
			{
				"step": 2, "name": "live_intent_counts_down_then_returns",
				"source": "rival_director.gd:23-27",
				"rule": ("if intent_action >= 0: --intent_ticks_until_land; " +
					"if <= 0: _land(); return"),
				"note": ("The return is load-bearing: a rival with a live intent commits " +
					"NOTHING new this tick. The sentinel is -1, not 0 — EXPAND is 0, so " +
					"testing `if intent_action:` or `>= 1` breaks EXPAND specifically."),
				"sentinel": -1,
				"lands_at_or_below": 0,
			},
			{
				"step": 3, "name": "council_gates_new_telegraphs_only",
				"source": "rival_director.gd:31-32",
				"rule": "if phase == COUNCIL: return",
				"note": ("Checked AFTER step 2, so an already-telegraphed intent still " +
					"counts down and LANDS during Council — the promise made to the " +
					"player stays deterministic (brief §7.6). A port that gates the whole " +
					"tick on the phase freezes mid-flight intents and changes the game."),
				"phase_value": BM.Phase.COUNCIL,
			},
			{
				"step": 4, "name": "commit_sets_window_and_advances_salt",
				"source": "rival_director.gd:33-40",
				"rule": ("pick = choose_move(..., salt=intents_committed); if empty: return; " +
					"intent_action/venue_id = pick; ticks_until_land = LEAD; " +
					"++intents_committed"),
				"note": ("intents_committed is the jitter SALT and is persisted — omitting " +
					"it from the save changes target selection after a load. It advances " +
					"ONLY on a real commit, never on an empty pick."),
				"salt_field": "intents_committed",
				"lead_ticks": lead,
			},
			{
				"step": 5, "name": "land_clears_intent_before_effects",
				"source": "rival_director.gd:52-58",
				"rule": ("action/target captured, then intent_action = -1, " +
					"intent_venue_id = \"\", intent_ticks_until_land = 0, THEN the effect"),
				"note": ("The intent is cleared BEFORE the effect is applied, and the two " +
					"early returns (missing character, missing venue) leave it cleared — " +
					"so a vanished target consumes the intent rather than retrying forever."),
			},
			{
				"step": 6, "name": "landed_effects",
				"source": "rival_director.gd:59-83",
				"rule": "one bounded write per action",
				"effects": {
					"SABOTAGE": {"venue_sabotage_disruption":
						var_to_str(RivalScoring.SABOTAGE_DISRUPTION),
						"venue_sabotage_ticks": RivalScoring.SABOTAGE_DURATION_TICKS},
					"PROBE": {"venue_sabotage_disruption":
						var_to_str(RivalScoring.PROBE_DISRUPTION),
						"venue_sabotage_ticks": RivalScoring.PROBE_DURATION_TICKS},
					"EXPAND": {"venue_owner_faction": "rival.id",
						"venue_control_state": BM.ControlState.INFLUENCED,
						"note": ("NEUTRAL ground only — the candidate filter never " +
							"offers a player venue to EXPAND, so player property is " +
							"never taken here.")},
					"FRAME": {"district_local_heat_delta":
						var_to_str(RivalScoring.FRAME_HEAT),
						"clamped": "[0,1]",
						"note": "additive on the DISTRICT, not the venue"},
					"RECRUIT": {"character_rival_leverage_delta":
						var_to_str(RivalScoring.RECRUIT_LEVERAGE),
						"clamped": "[0,1]",
						"sets": "recruited_by_faction = rival.id",
						"note": "targets a CHARACTER; the landed signal carries venue=null"},
				},
			},
			{
				"step": 7, "name": "grudge_has_two_writers_by_design",
				"source": "rival_director.gd:22 + job_director.gd:171-176",
				"rule": ("RivalDirector DECAYS it every rival tick; JobDirector RAISES it " +
					"by the job's rival_suspicion on a resolved RIVAL_PROVOCATION job"),
				"note": ("The oracle's own comment says 'Single writer of grudge upward; " +
					"RivalDirector decays it.' The port already shipped the UP writer in " +
					"S3 (BMJobDirector.cpp:187-196). S5 adds the DECAY writer. The " +
					"invariant to test is the SPLIT — raise via jobs, decay via rival, " +
					"nobody else — not single-writership."),
				"up_writer": "jobs (S3, already shipped)",
				"down_writer": "rival (S5, this slice)",
			},
		],
	}
