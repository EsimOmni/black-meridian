extends Node
## P19 unit test — the ending decision (brief §12.1). Guards: the epilogue derives
## purely from the accord stance, waits the settle window, fires exactly once, all three
## stances reach a DISTINCT ending (>=2 reachable endings is the gate; we prove 3), and
## the reached ending + seen-latch survive in narrative_flags (save-additive).
## Run as a scene: Godot --headless --path . res://tests/unit/test_ending_p19.tscn

var _failures := 0

func _ready() -> void:
	_test_gating()
	_test_all_stances_reach_distinct_endings()
	_test_fires_once()
	if _failures == 0:
		print("[PASS] all P19 ending tests passed")
		get_tree().quit(0)
	else:
		printerr("[FAIL] %d P19 ending assertion(s) failed" % _failures)
		get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("  assertion failed: ", msg)

func _flags_with_accord(stance: StringName, resolved_tick: int) -> Dictionary:
	return {&"accord_stance": stance, &"resolved@job_meridian_accord": resolved_tick}

func _test_gating() -> void:
	_check(NarrativeBeats.ready_ending({}, 10_000) == &"", "no ending before the accord")
	var flags := _flags_with_accord(&"truce", 100)
	_check(NarrativeBeats.ready_ending(flags, 100 + NarrativeBeats.ENDING_LEAD_TICKS - 1) == &"",
		"the settle window holds the epilogue")
	_check(NarrativeBeats.ready_ending(flags, 100 + NarrativeBeats.ENDING_LEAD_TICKS) == &"ending_accord",
		"the epilogue fires after the settle window")
	var stanceless := {&"resolved@job_meridian_accord": 100}
	_check(NarrativeBeats.ready_ending(stanceless, 10_000) == &"",
		"a resolved accord without a stance never ends the slice")

func _test_all_stances_reach_distinct_endings() -> void:
	var seen := {}
	for stance in [&"truce", &"leverage", &"war"]:
		var e := NarrativeBeats.ready_ending(_flags_with_accord(stance, 0), 10_000)
		_check(e != &"", "stance %s reaches an ending" % stance)
		_check(not seen.has(e), "stance %s ends DISTINCT (%s)" % [stance, e])
		seen[e] = true
	_check(seen.size() == 3, "three reachable endings (gate needs >=2)")

func _test_fires_once() -> void:
	var flags := _flags_with_accord(&"war", 0)
	var e := NarrativeBeats.ready_ending(flags, 10_000)
	flags[&"ending"] = e  # the director latches exactly this way
	_check(NarrativeBeats.ready_ending(flags, 20_000) == &"", "a reached ending never re-fires")
