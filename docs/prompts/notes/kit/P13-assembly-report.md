# P13 — Glass Wharf modular kit: assembly gate PASSED

**Accepted:** 2026-07-04 · first 5-module kit through the Codex-driven pipeline.
Anchored to `glass_wharf_MASTER.jpg` (P12a). Gated by `GLBValidator` (P15).

## Modules (5, all grey proxies)

| Module | spec | LOD0 tris | LOD1 tris | footprint | validator |
|---|---|---:|---:|---|---|
| ground_frontage | kit_tile | 228 | 84 | 4.5 × 4.5 m | pass |
| mid_floor | kit_tile | 300 | 96 | 4.5 × 4.5 m | pass |
| roof_cap | kit_tile | 84 | 12 | 4.5 × 4.5 m | pass |
| corner | kit_tile | 228 | 96 | 4.5 × 4.5 m | pass |
| roof_prop | prop | 72 | 24 | 3.18 × 1.5 m | pass |

## What P13 proved

- **Grid contract works.** 4.5 m cell / 4.5 m floor band, base-center per tile. A building
  assembled purely by cell coordinate (position = cell_index × 4.5 m) shows **flush seams**:
  every vertical seam gap = 0.000 m, horizontal overlap = 0.000 m. No hand-nudging, no z-fight.
- **Replication works.** A 2×2-footprint building (4 columns × 4 floors + roof caps) reads as a
  coherent dock tower (`assembly.png`). 9 such buildings (180 tile instances) tile across a plot
  from the same 5 modules (`block_9x.png`).
- **FPS holds.** 180 low-poly instances held **60.0 fps** under the management camera on the
  5060 Ti — but that is the **vsync cap**, not the true ceiling (no frame drop observed; the real
  headroom is higher and was not measured because vsync was on). Sufficient proof: no drop at 180
  instances; the aggressive-LOD + top-down budget (§9.2) has margin.

## The spec P13 forced into the validator

A single grid tile is NOT a whole building — a 1.5 m roof cap is legitimately short and failed
the `building` height floor (3 m). Added `GLBValidator.SPECS[&"kit_tile"]`: no lower height
bound, upper = one floor band (6 m), require_lods 2, collision allowed. Tiles validate for
topology/pivot/UV/LOD; the **assembled** result carries the building-height read. This is a real
granularity fix P13 surfaced, not a bypass. Validator unit test + full prior suite (8 tscn) green.

## Open (carried forward, non-blocking)

- **Per-tile roof caps read as 4 open boxes** on a 2×2 building — each column carries its own
  parapet ring, so the roof top isn't one unified parapet. Fix in the texture lap or add a
  `roof_full` tile later. Cosmetic under grey; visible in `assembly.png`.
- **Assembler is a test harness, not a game system.** Tile placement/rotation logic lives in
  `kit_gate.gd` (a probe, not committed). A real in-game building assembler (data-driven from
  district state) is a later slice — this proved the tiles *can* assemble, not the runtime that
  assembles them.
- **Texture** — grey proxies only. One shared trim-sheet over the whole kit is the deferred
  toplu lap (per the P12b decision). Massing + tiling locked first.
- **True FPS ceiling** unmeasured (vsync-capped). Re-measure with vsync off when the block scales
  toward the 300–500-instance target.

## Verdict

Grid + tiles + seams + replication + FPS-margin proven. The riskiest part of a modular kit — do
the parts actually snap and tile — is answered YES. Ready to extend the kit (toward ~12 modules)
and, separately, to build the data-driven runtime assembler.

## P13b extension — 12 modules total (accepted 2026-07-04)

Added 7 more, all `pass=true` on `kit_tile`/`prop`, all on the same grid contract:

| Module | LOD0 | LOD1 | footprint | family |
|---|---:|---:|---|---|
| ground_frontage_b | 192 | 24 | 4.5 × 4.5 | warehouse (variation: shutter door) |
| mid_floor_b | 264 | 60 | 4.5 × 4.5 | warehouse (variation: 3 narrow windows + pipe) |
| roof_cap_b | 132 | 60 | 4.5 × 4.5 | warehouse (variation: stepped parapet) |
| tower_mid | 204 | 72 | 4.5 × 4.5 | **tower** (deco mullions + setback) |
| tower_cap | 72 | 36 | 4.5 × 4.5 | **tower** (stepped deco crown) |
| transit_pier | 84 | 56 | ~2.8 in cell | **transit** (tapered support pier) |
| transit_deck | 84 | 36 | 4.5 × 3.0 | **transit** (spanning rail deck) |

New this pass:

- **A second seam axis proven.** `transit_deck` tiles along its LONG axis (a span, not a stack):
  4 segments butt end-to-end with gap 0.000 m. First non-stacking module — horizontal-along-length
  seam works, not just vertical.
- **Variation kills copy-paste.** A building mixing `mid_floor` / `mid_floor_b` / `roof_cap_b`
  reads differently floor-to-floor (`extension.png`), and the tower + transit families give the
  block more than one typology (§9.1: not only warehouses).
- **Two more families** under distinct name prefixes intent (`tower_`, `transit_`) so a future
  assembler picks a family per building. (Files currently all under `glasswharf_dock/`; split into
  family folders when the assembler lands.)

Open (added): the pier→deck vertical contact reads slightly gapped in `extension.png` (the span
seam is horizontal and flush; the pier-top bearing vs deck-underside is eyeballed, not gated) —
tighten when the transit assembler is built. Non-blocking.
