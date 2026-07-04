# Asset Standard — OMNI: BLACK MERIDIAN

The single gauntlet every asset passes before entering the game (brief §10.2–§10.4: *do not
use raw generated GLBs directly*). The executable side of this document is
`tools/validation/glb_validator.gd` — its `SPECS` table and this file must stay in sync.
Established by P15; the Month-3 gate is *repeatable delivery without reinventing the pipeline*.

## Naming

Canonical pattern: `<district>_<kit>_<part>_LODn`, lowercase snake_case.

- Example: `glasswharf_dock_warehouse_a_LOD0`, `glasswharf_dock_warehouse_a_LOD1`.
- `LOD0` is full detail; higher `n` = cheaper. The suffix is **case-insensitive** and matched
  on MeshInstance3D node names (`*_LOD<digits>` at the end of the name).
- Why names, not importer data: a runtime `GLTFDocument` load produces **no** importer LODs,
  so LOD validation is this naming convention — or manual `visibility_range_begin/end` on the
  mesh instances, which the validator accepts as the alternative.

## Layout

Under `/assets/<category>/…` (categories already scaffolded):

```text
/assets
  characters/   rigged character bases + animation
  city/         buildings + modular kits, grouped per kit: city/<district>_<kit>/
  props/        standalone set dressing
  vehicles/     static vehicle shells (no drivable vehicles — brief §12.3)
  splat/        Gaussian-splat cinematic worlds (+ mesh fallback)
  ui/           theme + 2D assets (generated theme.tres lives here)
  audio/        music + sfx
```

## Geometry rules

- **Meters scale.** 1 Godot unit = 1 meter. A cm/inch export shows up as an absurd AABB and
  fails the `scale` check outright (extent > 1000 m or < 0.01 m).
- **Base-center pivot.** Origin at the footprint center, y = 0 at the base
  (`abs(center.x/z) < 0.05 m`, `abs(base y) < 0.05 m`). Kit parts snap to the grid this way.
- **Trim-sheet UVs.** UV1 is mandatory on every surface. UV2 only matters for lightmaps —
  its absence is a warn, never a block.
- **Normals** on every surface — a stripped surface fails.
- **Material consolidation.** Budgets below count *distinct baked materials*
  (`mesh.surface_get_material`), not instance overrides. One glTF surface ≈ one draw call.
- **Collision policy is advisory** (warn only): buildings/vehicles are expected to ship a
  collider, characters must not (the engine adds capsules).

## Per-category budgets

Soft cap = warn, hard cap = fail. Mirrors `GLBValidator.SPECS` — edit there first.

| Category | Height (m) | Tris (soft/hard) | Surfaces | Materials | LOD levels | Collision |
|---|---|---|---|---|---|---|
| building | 3–120 | 15k / 30k | 4 / 8 | 3 / 6 | 2 | required |
| prop | 0.05–8 | 2k / 6k | 2 / 4 | 2 / 4 | 1 | allowed |
| vehicle | 0.8–5 | 10k / 20k | 3 / 6 | 3 / 5 | 2 | required |
| character | 0.5–3 | 20k / 40k | 2 / 5 | 2 / 4 | 0 (deferred) | forbidden |

## Running the gate

```gdscript
var report := GLBValidator.validate_file("res://assets/city/glasswharf_dock/warehouse_a.glb",
    GLBValidator.spec_for(&"building"))
# report = { "pass": bool, "checks": [ {name, level: "pass"|"warn"|"fail", detail}, … ] }
```

`pass` is true iff no check failed; warns never block. The wrapper loads via `GLTFDocument`
(headless-safe, bypasses the editor `.import` pipeline); `validate_scene(root, spec)` is the
pure core for already-loaded scenes. Self-test:

```sh
"D:/Godot/Godot_v4.7-stable_win64.exe" --headless --path . tests/unit/test_glb_validator.tscn
```

## License log

Every external asset (Sketchfab or otherwise) is recorded in `assets/ATTRIBUTIONS.md`
(create on first use): URL + license + required attribution text. **CC0 and CC-BY are
usable (track CC-BY attribution); CC-BY-NC is forbidden** — the game ships commercially on
Steam. License-check *before* download, per CLAUDE.md. A validated GLB with an unlogged or
non-commercial license is still an unusable asset.
