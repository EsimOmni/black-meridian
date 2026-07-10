extends SceneTree
## P08b territory-loss: Contested Ground generation is deterministic, rebuild round-trips,
## and the origin/variant contract holds. Pure JobGenerator/JobTemplates — no autoloads needed.

func _init() -> void:
	var failures := 0
	failures += _test_deterministic()
	failures += _test_rebuild_roundtrip()
	failures += _test_variant_in_range()
	failures += _test_origin()
	if failures == 0:
		print("test_territory_loss_p08b: PASS")
		quit(0)
	else:
		print("test_territory_loss_p08b: FAIL (%d)" % failures)
		quit(1)

func _make_venue() -> VenueData:
	var v := VenueData.new()
	v.id = &"gw_saltworks"
	v.display_name = "Abandoned Saltworks"
	return v

func _make_rival() -> FactionData:
	var f := FactionData.new()
	f.id = &"corvine"
	f.display_name = "Corvine Assembly"
	return f

func _test_deterministic() -> int:
	var a := JobGenerator.contested_ground_job(_make_venue(), _make_rival(), 42)
	var b := JobGenerator.contested_ground_job(_make_venue(), _make_rival(), 42)
	if a.id != b.id or a.title != b.title or a.origin != b.origin:
		print("  deterministic FAIL: %s vs %s" % [a.id, b.id]); return 1
	if a.id != &"gen@contested@gw_saltworks@corvine@42":
		print("  id format FAIL: %s" % a.id); return 1
	return 0

func _test_rebuild_roundtrip() -> int:
	var venue := _make_venue()
	var rival := _make_rival()
	var district := DistrictData.new()
	district.venues = [venue]
	var orig := JobGenerator.contested_ground_job(venue, rival, 7)
	var rebuilt := JobGenerator.rebuild(orig.id, [district], [rival])
	if rebuilt == null:
		print("  rebuild returned null"); return 1
	if rebuilt.id != orig.id or rebuilt.title != orig.title:
		print("  rebuild mismatch: %s/%s vs %s/%s" % [rebuilt.id, rebuilt.title, orig.id, orig.title]); return 1
	return 0

func _test_variant_in_range() -> int:
	var titles := {}
	for t in range(20):
		var j := JobGenerator.contested_ground_job(_make_venue(), _make_rival(), t)
		titles[j.title] = true
		var ids := []
		for a in j.approaches:
			ids.append(a.id)
		if not (&"appr_evict" in ids and &"appr_buyback" in ids and &"appr_rot" in ids):
			print("  choice-id set FAIL at t=%d: %s" % [t, ids]); return 1
	if titles.size() < 2:
		print("  variant coverage FAIL: only %s reached" % [titles.keys()]); return 1
	return 0

func _test_origin() -> int:
	var j := JobGenerator.contested_ground_job(_make_venue(), _make_rival(), 1)
	if j.origin != BM.JobOrigin.TERRITORY_LOSS:
		print("  origin FAIL: %d" % j.origin); return 1
	return 0
