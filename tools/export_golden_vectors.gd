extends SceneTree
## Golden-vector extractor — the Unreal port's behavioral oracle (reboot S1).
##
## READ-ONLY. It seeds the world in memory, enumerates every string the shipped hash
## paths actually consume, and prints one JSON document to stdout. It writes no file,
## mutates no resource and must never be given a reason to.
##
## The two hash sites in the shipped build are RivalScoring.tie_jitter (which venue the
## rival attacks) and JobGenerator._variant_index (which job text the player reads).
## Both run String.hash() through the same splitmix64 finalizer. Reproducing that pair
## bit-for-bit in C++ is the S1 gate; this file produces the table it is measured against.
##
## Run:
##   D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . \
##       -s tools/export_golden_vectors.gd -- --out=<abs path>.json
##
## It writes the file itself rather than printing to stdout, because the godot_ai
## game_helper autoload emits a banner line after the script finishes and that trailing
## text corrupts a redirected document. `--out` defaults to the path below.
##
## Ids are read out of src/core/world_seed.gd at run time rather than transcribed here,
## so the corpus cannot drift from the game as the seed changes. They are parsed from the
## source rather than taken from a built world because WorldSeed.build() writes into the
## GameState autoload, and autoloads do not exist in a `-s` SceneTree script — the main
## loop that instantiates them never runs. The existing unit tests avoid autoloads for the
## same reason.

const SCHEMA := 2
const SEED_PATH := "res://src/core/world_seed.gd"
const DEFAULT_OUT := "D:/black-meridian-ue/Tests/Golden/hash_vectors.json"

var _ids: Dictionary = {}

func _init() -> void:
	_ids = _parse_seed_ids()

	var out := {
		"schema": SCHEMA,
		"source": "godot-final",
		"godot_version": Engine.get_version_info().string,
		"note": "String.hash() (DJB2 over UTF-32 code points, uint32) and the splitmix64 avalanche (arithmetic shifts). Avalanche values are STRINGS: they exceed the 53-bit double mantissa and a JSON number would silently round.",
		"hash": _hash_vectors(),
		"tie_jitter": _tie_jitter_vectors(),
		"variant_index": _variant_index_vectors(),
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

	print("wrote %s — %d hash, %d tie_jitter, %d variant_index rows" % [
		path, out["hash"].size(), out["tie_jitter"]["rows"].size(),
		out["variant_index"]["rows"].size()])
	quit(0)

func _out_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			return arg.trim_prefix("--out=")
	return DEFAULT_OUT

# --- Layer 1: raw String.hash() + avalanche over the full corpus ---------------

## The 64-bit avalanche is emitted as a STRING, not a number. JSON numbers are doubles, and
## 1713 of these 1719 values exceed the 53-bit mantissa — reading them as numbers silently
## rounds (925186133376537099 -> 925186133376537088) and would fail a correct implementation.
func _hash_vectors() -> Array:
	var rows: Array = []
	for s in _corpus():
		rows.append({
			"s": s,
			"hash": s.hash(),
			"avalanche": str(RivalScoring._avalanche(s.hash())),
		})
	return rows

## Every string the two hash paths can see, plus the adversarial cases 08 §4.2 mandates.
func _corpus() -> Array[String]:
	var corpus: Array[String] = []
	corpus.append_array(_ids["factions"])
	corpus.append_array(_ids["characters"])
	corpus.append_array(_ids["districts"])
	corpus.append_array(_ids["venues"])

	# The composed forms: tie-jitter strings, generated job ids, evidence case ids.
	corpus.append_array(_tie_jitter_strings())
	corpus.append_array(_generated_job_ids())
	corpus.append_array(_case_ids())

	# Adversarial: empty, unicode, long, and strings chosen to land a negative hash.
	corpus.append_array([
		"",
		" ",
		"|",
		"@",
		"0",
		"gw_contraband ",   # trailing space — must not collide with the bare id
		"GW_CONTRABAND",    # case — DJB2 is case-sensitive
		"ışık_çürüyen",     # non-ASCII, Turkish
		"黑子午线",           # non-ASCII, CJK
		"héllo wörld",
		# Non-BMP (astral) code points. Godot counts these as ONE code point; a C++ port
		# over FString's UTF-16 must recombine the surrogate pair or it silently diverges
		# (emoji: 306085 as a code point vs 7743522 as a pair). Nothing else in the corpus
		# can catch that, because every other string here is BMP.
		"😀",
		"𐌰",
		"a😀b",
		"😀|😀|0|0",
		"a".repeat(1024),
		"gen@retaliation@" + "x".repeat(512) + "@corvine@120",
	])

	return corpus

# --- Layer 2: tie_jitter — the rival's target choice ---------------------------

## The shipped format is "%s|%s|%d|%d" % [rival_id, target_id, action, salt].
func _tie_jitter_strings() -> Array[String]:
	var rows: Array[String] = []
	for row in _tie_jitter_cases():
		rows.append(row["s"])
	return rows

func _tie_jitter_cases() -> Array:
	var rows: Array = []
	var targets: Array[String] = []
	targets.append_array(_ids["districts"])
	targets.append_array(_ids["venues"])

	# Every faction x every target x every action, over a salt sweep that crosses the
	# boundaries the finalizer has to survive (0, small, large, and a wrap-adjacent one).
	for f in _ids["factions"]:
		for t in targets:
			for action in BM.RivalAction.values():
				for salt in [0, 1, 2, 7, 120, 1260, 65535, 2147483647]:
					var s := "%s|%s|%d|%d" % [f, t, action, salt]
					rows.append({
						"rival_id": f,
						"target_id": t,
						"action": action,
						"salt": salt,
						"s": s,
						"hash": s.hash(),
						"avalanche": str(RivalScoring._avalanche(s.hash())),
						"jitter": RivalScoring.tie_jitter(StringName(f), StringName(t), action, salt),
					})
	return rows

func _tie_jitter_vectors() -> Dictionary:
	return {
		"epsilon": RivalScoring.TIE_JITTER_EPSILON,
		"format": "%s|%s|%d|%d",
		"rows": _tie_jitter_cases(),
	}

# --- Layer 3: _variant_index — which job text the player reads -----------------

## The three generated templates that pick a variant, with their shipped counts.
func _variant_index_vectors() -> Dictionary:
	var rows: Array = []
	for case in _variant_cases():
		rows.append({
			"s": case["s"],
			"count": case["count"],
			"hash": (case["s"] as String).hash(),
			"avalanche": str(RivalScoring._avalanche((case["s"] as String).hash())),
			"index": JobGenerator._variant_index(case["s"], case["count"]),
		})
	return {"rows": rows}

func _variant_cases() -> Array:
	var cases: Array = []
	var ticks: Array = [0, 1, 120, 1260, 65535]

	var venues: Array = _ids["venues"]
	var district_ids: Array = _ids["districts"]

	for v in venues:
		for f in _ids["factions"]:
			for tick in ticks:
				cases.append({
					"s": "gen@retaliation@%s@%s@%d" % [v, f, tick],
					"count": JobTemplates.RETALIATION_VARIANTS,
				})
				cases.append({
					"s": "gen@contested@%s@%s@%d" % [v, f, tick],
					"count": JobTemplates.CONTESTED_VARIANTS,
				})

	for d in district_ids:
		for kind in BM.EvidenceKind.values():
			for case_tick in ticks:
				var cid := "case@%s@%d@%d" % [d, kind, case_tick]
				for tick in ticks:
					cases.append({
						"s": "gen@burycase@%s@%s@%d" % [d, cid, tick],
						"count": JobTemplates.BURY_CASE_VARIANTS,
					})

	return cases

# --- The remaining generated form (followup) has no variant pick, but its id is
#     still hashed nowhere — included in the corpus for completeness of the id shapes.

func _generated_job_ids() -> Array[String]:
	var ids: Array[String] = []
	for case in _variant_cases():
		ids.append(case["s"])
	for v in _ids["venues"]:
		for tick in [0, 120, 1260]:
			ids.append("gen@followup@%s@%d" % [v, tick])
	return ids

func _case_ids() -> Array[String]:
	var ids: Array[String] = []
	for d in _ids["districts"]:
		for kind in BM.EvidenceKind.values():
			for tick in [0, 1, 120, 1260, 65535]:
				ids.append("case@%s@%d@%d" % [d, kind, tick])
	return ids

# --- Seed id inventory --------------------------------------------------------

## Reads the ids straight out of the seed source. Venue ids are the first argument of
## every _racket()/_front() call; character and district ids are plain `x.id = &"..."`
## assignments; the two faction ids are the COMPACT/CORVINE consts. Parsing the source
## keeps this honest: add a venue to the seed and it appears here with no edit.
func _parse_seed_ids() -> Dictionary:
	var src := FileAccess.get_file_as_string(SEED_PATH)
	assert(not src.is_empty(), "cannot read %s" % SEED_PATH)

	var factions: Array[String] = []
	for m in RegEx.create_from_string(
			'const\\s+(?:COMPACT|CORVINE)\\s*:=\\s*&"([^"]+)"').search_all(src):
		factions.append(m.get_string(1))

	var venues: Array[String] = []
	for m in RegEx.create_from_string('_(?:racket|front)\\(&"([^"]+)"').search_all(src):
		venues.append(m.get_string(1))

	# `x.id = &"..."` covers characters and the district; the faction ids go through the
	# consts above, so drop anything already collected as a faction.
	var characters: Array[String] = []
	var districts: Array[String] = []
	for m in RegEx.create_from_string('\\n\\t(\\w+)\\.id = &"([^"]+)"').search_all(src):
		var var_name := m.get_string(1)
		var id := m.get_string(2)
		if factions.has(id):
			continue
		if var_name == "d":
			districts.append(id)
		else:
			characters.append(id)

	assert(factions.size() == 2, "expected 2 factions, got %d" % factions.size())
	assert(not venues.is_empty(), "no venue ids parsed")
	assert(not districts.is_empty(), "no district ids parsed")
	assert(not characters.is_empty(), "no character ids parsed")

	return {
		"factions": factions,
		"characters": characters,
		"districts": districts,
		"venues": venues,
	}
