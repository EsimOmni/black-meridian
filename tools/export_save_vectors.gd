extends SceneTree
## Save/load golden-vector extractor — the Unreal port's behavioral oracle (reboot S4).
##
## READ-ONLY. It drives SaveCodec (a pure static RefCounted) plus the two halves of the
## registry contract (JobTemplates.by_id, JobGenerator.rebuild) and writes one JSON
## document. It mutates no shipped resource, writes no save file, and touches no autoload.
##
## Run:
##   D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . \
##       -s tools/export_save_vectors.gd -- --out=<abs path>.json
##
## Like S1/S2/S3's extractors it writes the file itself rather than printing to stdout: the
## godot_ai game_helper autoload emits a banner AFTER the script finishes and that trailing
## text corrupts a redirected document.
##
## `[V]` WHY `-s` WORKS HERE. Autoloads do not exist in a `-s` SceneTree script. Verified by
## grep 2026-09-19: `save_codec.gd` contains ZERO autoload references (the single textual hit
## is the word "GameState" inside a doc comment), and so do `job_templates.gd`,
## `narrative_jobs.gd`, `job_generator.gd` and `evidence_math.gd`. `SaveService` IS an
## autoload and is deliberately NOT driven here — its logic (the meta dict, the rebuild loop,
## the pause-first order) is transcribed into the port's UBMSaveSubsystem and pinned by the
## `load_sequence` layer's probe rows rather than executed. Exactly the S3 split, where
## `JobDirector` was the autoload left out and its state moved to FBMJobDirector.
##
## `[V]` Covers plan docs/superpowers/plans/2026-09-19-s4-save-load.md §3.

const SCHEMA := 1
const DEFAULT_OUT := "D:/black-meridian-ue/Tests/Golden/save_vectors.json"

func _init() -> void:
	var out := {
		"schema": SCHEMA,
		"source": "godot-final",
		"godot_version": Engine.get_version_info().string,
		"save_version": SaveCodec.SAVE_VERSION,
		"note": "Save/load vectors for reboot S4. EVERY FLOAT IS A DECIMAL STRING, never a JSON number — JSON.stringify truncates float64 to 15 significant digits (0.1+0.2 is written as \"0.3\", and 1.0/3.0 loses two digits), while var_to_str emits up to 17 and round-trips exactly. This fixture is compared with == , not 1e-5 (plan F-4: a tolerance on a ROUND TRIP hides truncation), so a truncated fixture would fail a CORRECT port — the same trap S1 recorded for 64-bit ints. Read these with a full-precision parser (FCString::Atod / TCString::Atof64), never by taking a JSON number. Discrete fields — version verdicts, defaults, stage ints, id strings, rebuild outcomes, booleans — are compared EXACTLY. The `version` layer records Godot's COERCIVE int() check, which the binary port deliberately does NOT reproduce (plan F-2); only its refusal SEMANTICS port.",
		"float_encoding": "decimal_string",
		"version": _version_vectors(),
		"additive": _additive_vectors(),
		"job_state": _job_state_vectors(),
		"rebuild": _rebuild_vectors(),
		"registry": _registry_vectors(),
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

	print("wrote %s — %d version, %d additive, %d job_state, %d rebuild, %d registry rows" % [
		path,
		out["version"]["rows"].size(), out["additive"]["rows"].size(),
		out["job_state"]["rows"].size(), out["rebuild"]["rows"].size(),
		out["registry"]["rows"].size()])
	quit(0)

func _out_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			return arg.substr(6)
	return DEFAULT_OUT

# --- Layer 1: the version gate ------------------------------------------------
#
# `[V]` save_codec.gd:110 is `int(data.get("version", -1)) != SAVE_VERSION`. That int() is a
# COERCION, so a STRING "1" and a FLOAT 1.0 both LOAD, while "abc" coerces to 0 and refuses.
# A binary FArchive format has no string-vs-int ambiguity, so the port cannot and must not
# reproduce the coercion — it is recorded here as a bounded divergence. What DOES port is the
# refusal semantics: wrong version -> refuse the WHOLE load, state untouched, no partial
# application (plan F-2, and 05 §7's "hard refusal" rule).

func _version_vectors() -> Dictionary:
	var rows: Array = []
	for probe in [
		{"kind": "missing", "data": {}},
		{"kind": "exact_int", "data": {"version": 1}},
		{"kind": "coerced_string", "data": {"version": "1"}},
		{"kind": "coerced_float", "data": {"version": 1.0}},
		{"kind": "non_numeric_string", "data": {"version": "abc"}},
		{"kind": "future", "data": {"version": 2}},
		{"kind": "zero", "data": {"version": 0}},
		{"kind": "negative", "data": {"version": -1}},
	]:
		var decoded := SaveCodec.decode_state(probe["data"])
		rows.append({
			"kind": probe["kind"],
			"accepted": not decoded.is_empty(),
			# `[V]` The port compares a typed int32 read off the archive. These two columns
			# say where the port DIVERGES on purpose: `coerced_string` / `coerced_float` are
			# accepted by the oracle and are UNREPRESENTABLE in the binary format.
			"port_reproducible": probe["kind"] not in ["coerced_string", "coerced_float"],
		})
	return {
		"contract": "int(data.get('version', -1)) != SAVE_VERSION -> return {} (refuse)",
		"rows": rows,
	}

# --- Layer 2: additive-field defaults ----------------------------------------
#
# `[V]` Every `d.get(key, default)` in the decode path, MEASURED by decoding a dict that
# carries only the keys the decoder demands with `d[key]`. These defaults are the mechanism
# by which a save written before a field existed still loads — the port's
# Test_Save_AdditiveField asserts each one. Read off the running codec, not off the source,
# because a default that is wrong in the comment is still right in the code.

func _additive_vectors() -> Dictionary:
	var rows: Array = []

	var dist := SaveCodec.decode_district({
		"id": &"d1", "display_name": "D1",
		"influence": 0.1, "security": 0.2, "prosperity": 0.3,
		"fear": 0.4, "visibility": 0.5,
		"institutional_presence": 0.6, "local_heat": 0.7,
		"faction_pressure": {},
		"venues": [],
	})
	rows.append({
		"shape": "district",
		"required_keys": ["id", "display_name", "influence", "security", "prosperity",
			"fear", "visibility", "institutional_presence", "local_heat",
			"faction_pressure", "venues"],
		"defaults": {
			"inspection_ticks": dist.inspection_ticks,
			"inspection_armed": dist.inspection_armed,
			"evidence_cases_count": dist.evidence_cases.size(),
		},
	})

	var fac := SaveCodec.decode_faction({
		"id": &"f1", "display_name": "F1", "is_player": true, "accent_color": Color.RED,
		"aggression": 0.1, "caution": 0.2, "cunning": 0.3,
		"dirty_cash": 100, "clean_capital": 50,
	})
	rows.append({
		"shape": "faction",
		"required_keys": ["id", "display_name", "is_player", "accent_color",
			"aggression", "caution", "cunning", "dirty_cash", "clean_capital"],
		"defaults": {
			"intent_action": fac.intent_action,
			"intent_venue_id": String(fac.intent_venue_id),
			"intent_ticks_until_land": fac.intent_ticks_until_land,
			"grudge": _f(fac.grudge),
			"intents_committed": fac.intents_committed,
			"operative_pool": fac.operative_pool,
		},
	})

	var ven := SaveCodec.decode_venue({
		"id": &"v1", "display_name": "V1", "type": 0, "owner_faction": &"f1",
		"control_state": 1, "racket_kind": 0, "base_yield": 10,
		"front_kind": 0, "laundering_capacity": 0, "front_efficiency": 0.7,
		"operating_cost": 0.15, "operational_staff": 2, "disruption": 0.0,
		"racket_risk": 0.3, "map_position": Vector2.ZERO,
	})
	rows.append({
		"shape": "venue",
		"required_keys": ["id", "display_name", "type", "owner_faction", "control_state",
			"racket_kind", "base_yield", "front_kind", "laundering_capacity",
			"front_efficiency", "operating_cost", "operational_staff", "disruption",
			"racket_risk", "map_position"],
		"defaults": {
			"paused": ven.paused,
			"sabotage_disruption": _f(ven.sabotage_disruption),
			"sabotage_ticks": ven.sabotage_ticks,
		},
	})

	# `[V]` A version-1 dict with no collections decodes to five EMPTY arrays rather than
	# failing. The port's scratch-state deserialize must do the same, or an empty-campaign
	# save becomes a refusal.
	var empty := SaveCodec.decode_state({"version": 1})
	rows.append({
		"shape": "state_minimal",
		"required_keys": ["version"],
		"defaults": {
			"keys": empty.keys(),
			"factions": empty["factions"].size(),
			"districts": empty["districts"].size(),
			"characters": empty["characters"].size(),
			"jobs": empty["jobs"].size(),
			"meta_empty": (empty["meta"] as Dictionary).is_empty(),
		},
	})

	return {
		"contract": "decode uses d[key] for required fields and d.get(key, default) for fields added after SAVE_VERSION 1 shipped; the defaults below are what a pre-field save loads as",
		"rows": rows,
	}

# --- Layer 3: encode_job's shape ---------------------------------------------
#
# `[V]` The save stores job RUNTIME state only — authored content is rebuilt from the id.
# The load-bearing subtlety is the OUTCOME: Godot tests `outcome.is_empty()` on a Dictionary,
# so "never resolved" (an empty dict) and "resolved to all nine zeros" (a full dict of 0.0)
# are DIFFERENT, and apply_outcome returns early only on the former. The port carries an
# explicit FBMJobOutcome::bResolved for exactly this (BMJobTypes.h:84); a port that inferred
# "all fields zero" would skip the reward gate on a legitimately-zero resolution.

func _job_state_vectors() -> Dictionary:
	var rows: Array = []

	var fresh := JobData.new()
	fresh.id = &"probe_fresh"
	rows.append(_encode_job_row("fresh", fresh))

	var zeroed := JobData.new()
	zeroed.id = &"probe_zeroed"
	zeroed.outcome = {}
	for dim in JobResolution.DIMENSIONS:
		zeroed.outcome[dim] = 0.0
	rows.append(_encode_job_row("resolved_all_zeros", zeroed))

	var mid := JobData.new()
	mid.id = &"probe_midflight"
	mid.stage = BM.JobStage.INTERVENTION
	mid.chosen_prep = [&"prep_lookouts", &"prep_scout"] as Array[StringName]
	mid.chosen_approach = &"appr_deal"
	mid.ticks_remaining = 44
	rows.append(_encode_job_row("midflight", mid))

	# `[V]` Signed dimensions carry NEGATIVE authored values on purpose ("I left no trace").
	# A float that survives the round trip must survive the sign.
	var signed_job := JobData.new()
	signed_job.id = &"probe_signed"
	signed_job.stage = BM.JobStage.RESOLVED
	signed_job.chosen_coverup = &"cover_scapegoat"
	signed_job.outcome = {
		&"objective_achieved": 0.7,
		&"evidence_generated": -0.3,
		&"collateral_damage": 0.25,
		&"operative_injury": -0.2,
		&"rival_suspicion": 0.1,
		&"public_fear": 0.35,
		&"relationship_change": -0.15,
		&"new_leverage": 0.4,
		&"delayed_consequence": 0.5,
	}
	rows.append(_encode_job_row("resolved_signed", signed_job))

	# `[V]` Full-precision floats. var_to_str round-trips float64 EXACTLY (17 sig digits);
	# these rows exist so the port's fixture read cannot silently truncate. 1/3 and 1/7 are
	# the adversarial pair — neither is representable in binary.
	var precise := JobData.new()
	precise.id = &"probe_precision"
	precise.stage = BM.JobStage.RESOLVED
	precise.outcome = {
		&"objective_achieved": 1.0 / 3.0,
		&"evidence_generated": -1.0 / 7.0,
		&"collateral_damage": 0.1 + 0.2,
		&"operative_injury": -0.0,
		&"rival_suspicion": 0.016845,
		&"public_fear": 0.10107,
		&"relationship_change": -0.018664,
		&"new_leverage": 0.9999999,
		&"delayed_consequence": 1e-08,
	}
	rows.append(_encode_job_row("precision", precise))

	# `[V]` apply_job_state overlays saved runtime state ONTO a freshly rebuilt/authored job.
	# Measured here because the order (rebuild THEN overlay) is behavior: a rebuild returns
	# stage=0/ticks=0, and skipping the overlay silently resets every in-flight job.
	var overlay_target := JobTemplates.intercepted_shipment()
	SaveCodec.apply_job_state(overlay_target, {
		"stage": BM.JobStage.COVER_UP,
		"chosen_prep": [&"prep_lookouts"],
		"chosen_approach": &"appr_deal",
		"chosen_coverup": &"cover_scapegoat",
		"ticks_remaining": 17,
		"outcome": {&"objective_achieved": 0.6},
	})
	rows.append({
		"kind": "overlay_onto_authored",
		"id": String(overlay_target.id),
		"stage": overlay_target.stage,
		"chosen_prep": _names(overlay_target.chosen_prep),
		"chosen_approach": String(overlay_target.chosen_approach),
		"chosen_coverup": String(overlay_target.chosen_coverup),
		"ticks_remaining": overlay_target.ticks_remaining,
		"outcome": _outcome_dict(overlay_target.outcome),
		"outcome_empty": overlay_target.outcome.is_empty(),
		# `[V]` The overlay must NOT disturb authored content.
		"authored_intact": overlay_target.prep_actions.size() == 4
			and overlay_target.deadline_ticks == 90
			and overlay_target.reward_dirty == 400,
	})

	return {
		"contract": "encode_job stores {id, stage, chosen_prep[], chosen_approach, chosen_coverup, ticks_remaining, outcome} and NOTHING authored; apply_job_state overlays exactly those seven onto a rebuilt job",
		"dimensions": _dimension_names(),
		"rows": rows,
	}

func _encode_job_row(kind: String, job: JobData) -> Dictionary:
	var e := SaveCodec.encode_job(job)
	return {
		"kind": kind,
		"id": String(e["id"]),
		"stage": e["stage"],
		"chosen_prep": _names(e["chosen_prep"]),
		"chosen_approach": String(e["chosen_approach"]),
		"chosen_coverup": String(e["chosen_coverup"]),
		"ticks_remaining": e["ticks_remaining"],
		"outcome": _outcome_dict(e["outcome"]),
		# `[V]` THE DISCRIMINATOR. Empty != all-zeros. FBMJobOutcome::bResolved is the port's
		# name for this bit; inferring it from "all nine are 0.0" gets `resolved_all_zeros`
		# wrong and skips the reward gate.
		"outcome_empty": (e["outcome"] as Dictionary).is_empty(),
		"encoded_keys": _sorted(e.keys()),
	}

# --- Layer 4: the rebuild contract -------------------------------------------
#
# `[V]` The gate S3 built for. Four generated templates, each round-tripping its id, plus
# every missing-referent path. A job whose referent is GONE must FAIL to rebuild — the
# oracle returns null and that is correct behavior, not an error path (07 §S4, and the
# burycase case is the one 08 §8 names as Test_Save_StaleCaseReference).
#
# `[V]` The SEGMENT COUNTS DIFFER PER TEMPLATE: retaliation 5, contested 5, followup 4,
# burycase 8 (its nested case id is itself 4 segments). job_generator.gd:79-115 returns null
# on any mismatch, so a port using one count fails three templates.

func _rebuild_vectors() -> Dictionary:
	var rows: Array = []

	# Built ids first: build through the generator, then feed the built id back to rebuild.
	var w := _world()
	var districts: Array[DistrictData] = w[0]
	var factions: Array[FactionData] = w[1]
	var venue := _find_venue(districts, &"gw_contraband")
	var district := districts[0]
	var rival := factions[0]
	var evidence_case := district.evidence_cases[0]

	for built in [
		{"kind": "retaliation", "job": JobGenerator.retaliation_job(venue, rival, 240)},
		{"kind": "contested", "job": JobGenerator.contested_ground_job(venue, rival, 240)},
		{"kind": "followup", "job": JobGenerator.followup_job(venue, 301)},
		{"kind": "burycase", "job": JobGenerator.bury_case_job(evidence_case, district, 240)},
	]:
		var job: JobData = built["job"]
		rows.append(_rebuild_row(built["kind"], String(job.id), districts, factions, job))

	# Missing-referent probes. Each must be null; each names WHICH referent was removed.
	for probe in _missing_referent_probes(String(evidence_case.id)):
		var pw := _world()
		var pd: Array[DistrictData] = pw[0]
		var pf: Array[FactionData] = pw[1]
		match probe["remove"]:
			"case":
				pd[0].evidence_cases = [] as Array[EvidenceCaseData]
			"venue":
				pd[0].venues = [] as Array[VenueData]
			"faction":
				pf.clear()
			"district":
				pd.clear()
			"nothing":
				pass
		rows.append(_rebuild_row(probe["kind"], probe["id"], pd, pf, null))

	return {
		"contract": "rebuild(id, districts, factions) -> JobData or null; null when the prefix is wrong, the segment count is wrong for the template, or ANY referent (venue / faction / district / evidence case) is gone",
		"segment_counts": {"retaliation": 5, "contested": 5, "followup": 4, "burycase": 8},
		"rows": rows,
	}

func _rebuild_row(kind: String, id: String, districts: Array[DistrictData],
		factions: Array[FactionData], built: JobData) -> Dictionary:
	var rebuilt := JobGenerator.rebuild(StringName(id), districts, factions)
	var row := {
		"kind": kind,
		"id": id,
		"rebuilt": rebuilt != null,
		"rebuilt_id": String(rebuilt.id) if rebuilt != null else "",
		"id_round_trips": rebuilt != null and String(rebuilt.id) == id,
		"origin": rebuilt.origin if rebuilt != null else -1,
		"deadline_ticks": rebuilt.deadline_ticks if rebuilt != null else -1,
		# `[V]` A fresh rebuild carries NO lifecycle state — the save's runtime state is
		# applied over it. A port that skipped the overlay would look correct here.
		"stage": rebuilt.stage if rebuilt != null else -1,
		"ticks_remaining": rebuilt.ticks_remaining if rebuilt != null else -1,
		"outcome_empty": rebuilt.outcome.is_empty() if rebuilt != null else true,
		"choice_ids": {
			"prep": _choice_ids(rebuilt.prep_actions) if rebuilt != null else [],
			"approach": _choice_ids(rebuilt.approaches) if rebuilt != null else [],
			"coverup": _choice_ids(rebuilt.coverups) if rebuilt != null else [],
		},
		# `[V]` rebuild is PURE: the variant keys on the id string, so two rebuilds of one id
		# land on the same variant forever. Compared via the effect VALUES, not the prose —
		# BMCore has no display names by design (D-S3-2, closes at S14).
		"effects": _choice_effects(rebuilt) if rebuilt != null else {},
	}
	if built != null:
		row["built_origin"] = built.origin
		row["built_deadline_ticks"] = built.deadline_ticks
		row["built_matches_rebuilt"] = rebuilt != null \
			and rebuilt.origin == built.origin \
			and rebuilt.deadline_ticks == built.deadline_ticks \
			and _choice_ids(rebuilt.approaches) == _choice_ids(built.approaches)
	return row

func _missing_referent_probes(case_id: String) -> Array:
	return [
		{"kind": "burycase_case_gone", "remove": "case",
			"id": "gen@burycase@glasswharf@%s@240" % case_id},
		{"kind": "burycase_district_gone", "remove": "district",
			"id": "gen@burycase@glasswharf@%s@240" % case_id},
		{"kind": "burycase_unknown_district", "remove": "nothing",
			"id": "gen@burycase@nosuch@%s@240" % case_id},
		{"kind": "retaliation_venue_gone", "remove": "venue",
			"id": "gen@retaliation@gw_contraband@corvine@240"},
		{"kind": "retaliation_faction_gone", "remove": "faction",
			"id": "gen@retaliation@gw_contraband@corvine@240"},
		{"kind": "retaliation_unknown_venue", "remove": "nothing",
			"id": "gen@retaliation@nosuch@corvine@240"},
		{"kind": "retaliation_unknown_faction", "remove": "nothing",
			"id": "gen@retaliation@gw_contraband@nosuch@240"},
		{"kind": "contested_venue_gone", "remove": "venue",
			"id": "gen@contested@gw_contraband@corvine@240"},
		{"kind": "followup_venue_gone", "remove": "venue",
			"id": "gen@followup@gw_contraband@301"},
		# `[V]` Wrong segment count for the template — the trap a one-count port falls into.
		{"kind": "retaliation_too_few_segments", "remove": "nothing",
			"id": "gen@retaliation@gw_contraband@corvine"},
		{"kind": "followup_too_many_segments", "remove": "nothing",
			"id": "gen@followup@gw_contraband@301@240"},
		{"kind": "unknown_template", "remove": "nothing",
			"id": "gen@nosuchtemplate@gw_contraband@corvine@240"},
		{"kind": "not_generated_prefix", "remove": "nothing",
			"id": "job_intercepted_shipment"},
		{"kind": "empty_id", "remove": "nothing", "id": ""},
	]

# --- Layer 5: the two-half registry contract ---------------------------------
#
# `[V]` SaveService's load loop is: JobTemplates.by_id FIRST, then JobGenerator.rebuild, then
# SKIP WITH A WARNING and `continue` — and the load still RETURNS TRUE. So a save whose job
# id no longer resolves loads successfully with that job ABSENT, and the loaded campaign is
# legitimately NOT equal to the saved snapshot (plan F-5). Conflating that with the
# byte-identical contract produces either a false pass or a false fail.
#
# `[V]` The oracle resolves FOUR authored ids (the P16 chain included); the port's
# FBMJobTemplates::ById resolves ONE and returns false for the other three by design
# (D-S3-4 — S3 ported the registry CONTRACT, not the P16 roster). The
# `port_resolves_authored` column marks the split, so the three P16 ids are usable as
# genuine Test_Save_MissingJobDefinition cases rather than invented ones.

func _registry_vectors() -> Dictionary:
	var w := _world()
	var districts: Array[DistrictData] = w[0]
	var factions: Array[FactionData] = w[1]

	var rows: Array = []
	for id in ["job_intercepted_shipment", "job_inspectors_ledger", "job_lieutenants_debt",
			"job_meridian_accord", "gen@retaliation@gw_contraband@corvine@240",
			"gen@retaliation@nosuch@corvine@240", "job_nope", ""]:
		var authored := JobTemplates.by_id(StringName(id))
		var generated: JobData = null
		if authored == null:
			generated = JobGenerator.rebuild(StringName(id), districts, factions)
		rows.append({
			"id": id,
			"by_id_resolves": authored != null,
			"rebuild_resolves": generated != null,
			"restored": authored != null or generated != null,
			"via": ("by_id" if authored != null
				else ("rebuild" if generated != null else "skipped")),
			# `[V]` The port intentionally resolves only the one S3 ported. See D-S3-4.
			"port_resolves_authored": id == "job_intercepted_shipment",
		})

	return {
		"contract": "by_id FIRST, then rebuild, then skip-with-warning and continue; the LOAD STILL SUCCEEDS with the unresolvable job absent",
		"load_returns_true_when_a_job_is_skipped": true,
		"rows": rows,
	}

# --- Shared world ------------------------------------------------------------
#
# `[V]` Same shape as S3's `_id_world` so the two fixtures agree on ids and the case id is
# generated by the SAME EvidenceMath.deposit call rather than typed by hand.

func _world() -> Array:
	var district := DistrictData.new()
	district.id = &"glasswharf"
	district.display_name = "Glass Wharf"

	var venue := VenueData.new()
	venue.id = &"gw_contraband"
	venue.display_name = "Cargo Terminal"
	venue.owner_faction = &"compact"
	district.venues = [venue] as Array[VenueData]

	EvidenceMath.deposit(district, 0.4, &"seed_job", 120)

	var rival := FactionData.new()
	rival.id = &"corvine"
	rival.display_name = "Corvine Syndicate"

	var districts: Array[DistrictData] = [district]
	var factions: Array[FactionData] = [rival]
	return [districts, factions]

func _find_venue(districts: Array[DistrictData], venue_id: StringName) -> VenueData:
	for d in districts:
		for v in d.venues:
			if v.id == venue_id:
				return v
	return null

# --- Emit helpers ------------------------------------------------------------

func _dimension_names() -> Array:
	var names: Array = []
	for dim in JobResolution.DIMENSIONS:
		names.append(String(dim))
	return names

## `[V]` THE FLOAT ENCODER. Every float in this fixture goes through here.
##
## JSON.stringify writes a float64 with ~15 significant digits: `0.1 + 0.2` comes out as
## "0.3" (a DIFFERENT number) and `1.0/3.0` loses its last two digits. var_to_str emits up to
## 17 and str_to_var reads them back exactly — verified 20/20 on the adversarial set,
## including through a JSON round trip as a string value.
##
## This matters here and not in S2/S3 because THIS fixture is compared with `==`. S2's 2526
## rows survive as JSON numbers only because their 1e-5 tolerance is looser than the
## truncation; at exact equality a truncated fixture FAILS A CORRECT PORT. Same failure class
## as S1's 64-bit avalanche values, same fix.
##
## Note even GDScript's own `%s` / print() truncates to 14 digits — var_to_str is the only
## writer in the engine that tells the truth about a float.
func _f(v: float) -> String:
	return var_to_str(v)

## `[V]` The outcome is emitted with STRING keys in DIMENSIONS order, never by iterating the
## Dictionary: GDScript Dictionary order is insertion order, and the port reads the nine
## fields by name. Ordering the emit makes the fixture's own diff stable across runs.
func _outcome_dict(outcome: Dictionary) -> Dictionary:
	var out := {}
	for dim in JobResolution.DIMENSIONS:
		if outcome.has(dim):
			out[String(dim)] = _f(outcome[dim])
	return out

func _names(arr) -> Array:
	var out: Array = []
	for a in arr:
		out.append(String(a))
	return out

func _sorted(arr) -> Array:
	var out := _names(arr)
	out.sort()
	return out

func _choice_ids(pool: Array) -> Array:
	var out: Array = []
	for c in pool:
		out.append(String(c.id))
	return out

## `[V]` Every choice's effects, keyed by choice id then dimension name. This is what
## "byte-identical rebuild" means for the port: the id, origin, variant, choice IDS and
## effect VALUES must match, while interpolated PROSE is excluded because BMCore carries no
## display names by design (D-S3-2, closes at S14).
func _choice_effects(job: JobData) -> Dictionary:
	var out := {}
	for pool in [job.prep_actions, job.approaches, job.coverups]:
		for c in pool:
			var eff := {}
			for dim in JobResolution.DIMENSIONS:
				if c.effects.has(dim):
					eff[String(dim)] = _f(c.effects[dim])
			out[String(c.id)] = eff
	return out
