# Glass Wharf — full asset buildout plan

Goal: take the whole researched asset library (`docs/glass-wharf-asset-research.md`)
through the proven Sketchfab→Blender→Godot pipeline and dress the Glass Wharf district
to match the approved master keyframe (`assets/concept/glass_wharf/glasswharf_master.png`).

Pipeline per asset (proven on `warehouse_hero.glb`, commit ae48666):
1. `download_sketchfab_model(uid, target_size)` into Blender.
2. Cleanup: delete import clutter, join meshes → one object, base-center pivot (y=0),
   scale to grid footprint, downscale any >1K textures to 1K.
3. Export GLB: `export_yup=True`, JPEG textures, **Draco OFF** (Godot 4.7 can't read it).
4. Godot `--import`; validate against `GLBValidator.spec_for(building|prop)`.
5. Wire: landmarks → `DistrictLandmarks.PLACEMENTS`; props → a scatter list.
6. Log CC-BY attribution in `assets/ATTRIBUTIONS.md`.

## Roles

### A. Landmarks (fixed placement, hand-composed — human 10%)
Big, individually-placed structures echoing the master. Go in `DistrictLandmarks.PLACEMENTS`
with position/rotation/scale/patina. One-of-a-kind, camera-composed.

| Asset | UID | target_size (m) | Placement intent |
|---|---|---|---|
| Old Warehouse (DONE) | 17f9bd62… | 9 | front-left freight depot ✅ shipped |
| Old Industrial Building | 0dafa7aa… | 14 | mid-ground red-brick block, behind venue row |
| Dock Pier / stilt house | 9528bbe1… | 10 | right-front on the water's edge |
| Dock House stilt pier | 4f0df975… | 8 | left waterfront, near warehouse |
| Gotham tenement | 0c63358d… | 12 | back-row nightlife strip density |

### B. Props (repeatable set-dressing, scatter placement)
Small, repeatable. New `DockProps` placer (mirrors DistrictLandmarks but a scatter list,
prop spec, no patina shader — props keep their own material). Positions are still authored
(no RNG — brief: zero RNG in src, but this is presentation; use a fixed authored array).

| Asset | UID | target_size (m) | Count / intent |
|---|---|---|---|
| Dock Crane | 5b620e1a… | 12 | 1–2, waterfront silhouette (RE-VERIFY thumbnail first) |
| Industrial Crane compact | 647872b8… | 10 | 1, back-right |
| Shipping Container (clean) | 772f4be3… | 2.5 | stacks of 3–4 near warehouse |
| Freight Container rusted | 2b787d1a… | 2.5 | stacks, palette variety |
| Fishing Boat | cc4200e4… | 4 | 1–2 on the water |
| Street Lamp lowpoly | 15205597… | 3 | line the pier edge |
| Vintage Lamp Post | 56f6dcb3… | 4 | 2–3 street lighting |
| Steel Stair fire-escape | 3a664dcd… | 4 | 1–2 on warehouse flanks |
| Dumpster | 23f0a1c5… | 1.5 | 2–3 alley clutter |
| Astro neon squiggle | 810cf16f… | 2 | emissive accents on facades |

### Deferred / re-verify before download
- Trihuslab Pier (9dc3ddd2…) — possible "Troll Island" branded sign, re-check solo.
- Row Boat w/ lantern (8c20b2b6…) — 204k faces, hero-only, likely over prop budget.
- Rusty crane beam (22256077…), Dirty Plaster wall (06b7fb82…), Warehouse compact
  (0c37b0f9…) — promote in if the scene needs more density after the first pass.

### PolyHaven (CC0, no attribution) — materials/lighting, applied after geometry
Re-skin + light the geometry above. Not a download-per-object step; applied as materials
in Blender or Godot. Priority: `cobblestone_street_night` HDRI (rainy-noir light ref),
`rusty_corrugated_iron` + `rusty_metal_02` (warehouse/container palette), wet ground already
in city_view.

## Execution order (this session)
1. Batch-download + clean + export the **5 landmarks** (Group A) — biggest visual payoff.
2. Wire all 5 into DistrictLandmarks, screenshot vs master, adjust positions (human 10%).
3. Batch the **props** (Group B), build `DockProps` placer, scatter.
4. Lighting/neon polish pass (patina tune + emissive) once geometry composition reads right.
5. Commit per group (landmarks, then props), attribution logged each time.
