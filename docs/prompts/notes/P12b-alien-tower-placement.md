# P12b hero #1 — Alien Tower placement: ACCEPTED (skyline landmark + cinematic camera)

**Accepted:** 2026-07-05 · the accepted alien diplomatic tower (commit 848ff5a) placed in-engine as a
district skyline landmark, gated by the control tower (live node read + two-eye framing vs the master),
not trusted from the producer's claim.

## What shipped

- `src/presentation/district_landmarks.gd` — a new, ADDITIVE placement layer. Hero landmarks are
  district-level SCENERY, independent of the venue system: bespoke monolithic meshes placed at fixed
  positions echoing the LOCKED master. `KitAssembler` and the venue → building path are UNTOUCHED
  (per the P12b architecture note's placement correction — Glass Wharf has no political/intel venue to
  anchor the tower to; it stands out on the water as skyline, not on a gameplay lot). No gameplay state,
  no RNG, no districts_changed rebuild — static skyline.
- `scenes/city/city_view.gd` — one line: `DistrictLandmarks.spawn_all(self)` at build.
- `scenes/city/skyline_camera.gd` — a SECOND, non-gameplay camera at the master's cinematic 3/4 diorama
  angle. The management camera (brief §9.2 near-ortho top-down) stays authoritative; toggled with C.
- `scenes/bootstrap/bootstrap.gd` — builds the skyline camera + `_toggle_skyline_camera()` on C.

Alien tower final placement: `Vector3(26, 0, -30)`, rotation_y −0.35 — right flank, deep out on the
water, a distant skyline landmark.

## The problem this gate caught

The tower spawned correctly (node confirmed at `/Bootstrap/CityView/AlienDiplomaticTower`, 3 children,
zero errors) but did NOT appear in the game screenshot. Root cause (Codex diagnosed via live godot-ai
unproject, control tower verified against the camera source): the management camera sits at z≈+52.6
(bootstrap z=26 + `management_camera.gd` back-offset height×0.7), centering the ground read at z≈+20.7,
so a 36 m vertical landmark at negative z has its TOP pushed above the screen — off-frame, not missing.
Placement tweaks alone couldn't fix it: the fix is a camera, not a coordinate.

## The decision (Cem): a second cinematic camera

Not "shorten the tower to fit the top-down read" and not "change the default management view" — both
compromise a pillar. Instead: the management camera stays a pure brief-§9.2 top-down mechanic view, and
a separate `SkylineCamera` presents the heroes at the master's 3/4 angle (C to toggle). Mechanic view
and cinematic view are different cameras — the right architectural split.

## Two-eye framing gate — PASS

Live projection (Codex, from the running camera) + control-tower eyeball of the saved framebuffer:
- Tower screen bbox clears the right HUD panel (HUD at x=1524; tower right edge ~x=1377 → ~146 px clear).
- Full 36 m in frame, top not clipped (~80 px headroom).
- After a reframe (tower z −14 → −30, camera EYE/LOOK pulled back), the tower reads as a DISTANT skyline
  landmark behind the venue row — the master's "rising out on the water" depth, not a building-in-the-row.

## Known deferred (NOT this slice)

The tower reads very dark — near-silhouette; the master's verdigris crown + body ribs don't yet read.
That is a MATERIAL / LIGHTING problem, owned by the noir texture lap (a later P12b slice), not placement.
The silhouette is correct and the composition matches the master; forcing lighting in here would be scope
creep. Placement mechanic (spawn + cinematic framing + toggle + pure management view) is what this slice
proved, and it holds.

## Next

Hero #2 (carved-stone institution) via the same direct-socket Blender pipeline, then transit spine, then
the noir texture lap (which also lifts this tower out of silhouette).
