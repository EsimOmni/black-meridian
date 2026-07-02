extends Node
## SaveService (autoload) — serializes/restores the entire authoritative GameState
## (brief §13.2, §18). Presentation rebuilds itself from the restored state via the
## districts_changed/factions_changed signals; it owns nothing. Pure codec: SaveCodec.

signal game_saved(slot: String)
signal game_loaded(slot: String)

const SAVE_DIR := "user://saves"

func save_path(slot: String) -> String:
	return "%s/%s.bmsave" % [SAVE_DIR, slot]

func save_game(slot: String = "quick") -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var meta := {
		"player_faction_id": GameState.player_faction_id,
		"night_cycle": GameState.night_cycle,
		"phase": GameState.phase,
		"tick_index": TimeService.tick_index,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
	}
	var data := SaveCodec.encode_state(
		GameState.districts, GameState.factions, GameState.characters,
		JobDirector.active_jobs, meta)
	var f := FileAccess.open(save_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("SaveService: cannot open %s for write (%s)" % [save_path(slot), FileAccess.get_open_error()])
		return false
	f.store_string(var_to_str(data))
	f.close()
	game_saved.emit(slot)
	return true

func load_game(slot: String = "quick") -> bool:
	var path := save_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("SaveService: no save at %s" % path)
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("SaveService: cannot open %s for read" % path)
		return false
	var parsed = str_to_var(f.get_as_text())
	f.close()
	if not parsed is Dictionary:
		push_warning("SaveService: %s is not a valid save file" % path)
		return false
	var state := SaveCodec.decode_state(parsed)
	if state.is_empty():
		push_warning("SaveService: version mismatch in %s (have %s, expected %d) — refusing to load"
			% [path, parsed.get("version", "?"), SaveCodec.SAVE_VERSION])
		return false

	# Pause first so nothing settles against half-restored state.
	TimeService.set_speed(BM.Speed.PAUSED)

	GameState.districts = state["districts"]
	GameState.factions = state["factions"]
	GameState.characters = state["characters"]
	var meta: Dictionary = state["meta"]
	GameState.player_faction_id = meta["player_faction_id"]
	GameState.night_cycle = meta["night_cycle"]
	GameState.phase = meta["phase"]
	TimeService.tick_index = meta["tick_index"]

	# Rebuild in-flight jobs: authored content from the registry, runtime state from the save.
	var jobs: Array[JobData] = []
	for jd in state["jobs"]:
		var job := PlaceholderJobs.by_id(jd["id"])
		if job == null:
			push_warning("SaveService: unknown job id '%s' in save — skipped" % jd["id"])
			continue
		SaveCodec.apply_job_state(job, jd)
		jobs.append(job)
	JobDirector.restore_jobs(jobs)

	GameState.districts_changed.emit()
	GameState.factions_changed.emit()
	game_loaded.emit(slot)
	return true
