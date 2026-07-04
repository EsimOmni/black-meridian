# P13 — Glass Wharf modular building kit (grid-tile replication)

**Month:** 3 · **Brief:** §9.2 (camera), §10.2 (modular kit — 300–500 instances from ~12 kits)
· Depends on: P12b (warehouse accepted), P15 (validator), P12a (master LOCKED)

## Who runs this

Same as P12b: **Codex (BlenderMCP :9876)** drives the mechanical Blender work; **control tower**
architects the grid contract, gates each GLB through `GLBValidator`, instance-tests a tiled
block in Godot, accepts. AI ~90 / human ~10. Fable idle.

## What changes from P12b

P12b proved the path on ONE monolithic gövde. A kit is different: parts must **snap to a shared
grid** so 300–500 buildings can be assembled from ~12 reusable tiles. The warehouse was one
building; these are **interchangeable modules**.

## The grid contract (the thing that makes it a kit, not 12 boxes)

- **Cell = 4.5 m** on the horizontal (matches the warehouse's proven bay module).
- **Floor band = 4.5 m** tall (so vertical stacking is also grid-aligned).
- Every module's footprint is an integer number of cells; every module's origin is
  **base-center** of its own footprint (same pivot rule the validator checks), so an assembler
  can place a tile at a grid coordinate and it butts flush against its neighbors with **no gap
  and no overlap**. A module that is 1×1 occupies exactly 4.5 × 4.5 m; edges land on cell lines.
- Wall thickness / pilaster proud-depth stay inside the cell envelope so adjacent tiles don't
  z-fight.

## The kit (first pass — 5 modules, not 12)

Start with the minimum set that can assemble a believable dock building, prove tiling, THEN
extend. Each is its own GLB, `building` spec, LOD0+LOD1, base-center, UV1, ≤3 materials:

| Module | Footprint | Role | Note |
|---|---|---|---|
| `ground_frontage` | 1×1 cell, 4.5 m tall | ground floor with a loading door / shopfront recess | the street-level read |
| `mid_floor` | 1×1 cell, 4.5 m tall | stackable middle floor, window row | stacks vertically N times |
| `roof_cap` | 1×1 cell, ~1.5 m | parapet + roof edge, the top of a stack | carries the stepped-parapet silhouette |
| `corner` | 1×1 cell, 4.5 m tall | corner piece, two finished faces | turns the building 90° |
| `roof_prop` | small, <1 cell | vent / housing / rail set dressing | scatter on roof_cap, prop-spec not building |

Naming (asset-standard.md): `glasswharf_dock_<module>_LOD0/_LOD1`, e.g.
`glasswharf_dock_mid_floor_LOD0`. Output under `assets/city/glasswharf_dock/`.

## Kit extension (P13b — the next 7, toward ~12)

The first 5 proved the grid + one warehouse dialect. 300–500 buildings from ONE dialect reads as
copy-paste under the camera. The next 7 close two gaps the master demands, on the SAME grid
contract (4.5 m cell, base-center, integer footprint, LOD0+LOD1, `kit_tile`/`prop` spec):

**Variation (kill the repeat — same slot, different read):**

| Module | slot | differs from base by |
|---|---|---|
| `ground_frontage_b` | ground | shutter/roller door instead of the recessed loading door; no pilaster |
| `mid_floor_b` | mid | 3 narrow windows instead of 2 wide; a service pipe run |
| `roof_cap_b` | roof | stepped/raised parapet variant (carries the warehouse's stepped-silhouette read into the kit) |

**New typology (master has more than warehouses — §9.1):**

| Module | footprint | role |
|---|---|---|
| `tower_mid` | 1×1, 4.5 m | neo-deco waterfront tower floor — taller/leaner read, vertical mullions, setback lip |
| `tower_cap` | 1×1, ~2 m | tower crown — deco stepped top, distinct from the flat warehouse cap |
| `transit_pier` | 1×1, ~6 m | elevated-transit support pier — a column the rail deck sits on |
| `transit_deck` | 1×N span, ~1 m | a spanning rail-deck segment that tiles along its long axis over piers |

`transit_deck` tiles on its LONG axis (a span, not a stack) — the first non-stacking module, so
its seam check is horizontal-along-length, not vertical. Naming: keep the `glasswharf_dock_`
prefix for warehouse-family, use `glasswharf_tower_` and `glasswharf_transit_` for the new
families so the assembler can pick a family per building.

## Assembly proof (the real deliverable — beyond individual validation)

Individual GLBs passing the validator is necessary but NOT sufficient. The kit only works if the
tiles **assemble**. So the acceptance test is a Godot scene that:

1. Instances a building from the kit: `ground_frontage` at the base, `mid_floor` stacked ×3
   above it, `roof_cap` on top, a `corner` at each end — placed purely by grid coordinate
   (position = cell_index × 4.5 m). No hand-nudging.
2. Confirms **flush seams**: no visible gap, no overlap/z-fight at tile boundaries.
3. Renders it under the management camera (~40° down, ~60mm) beside the accepted warehouse for a
   silhouette/scale sanity check.
4. Then a **~40-instance block** (several such buildings tiled across a plot) to confirm the FPS
   target holds under the management camera (brief §9.2 — the whole point of aggressive LODs +
   the top-down read).

## Gates (each module + the assembly)

- Per module: `GLBValidator.validate_file(path, spec_for(&"building"))` (or `&"prop"` for
  `roof_prop`) → `pass:true` required.
- Two-eye massing gate on the ASSEMBLED building (not each tile): Claude + Codex-vision judge the
  assembled silhouette against the master, same as the warehouse. REVISE until both SHIP.
- Assembly gate: flush seams (programmatic AABB-adjacency check, not just eyeballing) + FPS
  target on the 40-instance block.

## Verify / Done when

- 5 module GLBs exist, each `pass:true` on its spec.
- A grid-assembled building shows flush seams (no gap/overlap) placed by cell coordinate alone.
- Two-eye SHIP on the assembled building vs the master.
- 40-instance block holds the FPS target under the management camera (record the number).
- Modules + a saved assembly report committed. Prior suite green, boot smoke clean.

## Out of scope

- No texture/trim-sheet yet — grey proxies (texture is a later toplu lap over the whole kit,
  one shared trim-sheet, per the P12b decision). No hero alien structure. No full 12-kit set
  (this is the first 5; extend after tiling is proven). No src/ sim or save changes. No Fable.
