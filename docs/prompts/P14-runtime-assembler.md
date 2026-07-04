# P14 — Runtime kit assembler (district state → assembled buildings)

**Month:** 3 · **Brief:** §1 ("the city shows the state"), §9.2 (management camera), §10.2 (modular kit)
· Depends on: P13/P13b (12-module kit accepted, grid contract proven), P15 (validator)

## Why this slice

P13 proved the tiles *snap and tile*. But the kit is a **dead asset** until the sim drives it: 12
validated GLBs sit on disk, and `scenes/city/city_view.gd` still spawns a flat 2.2 m box per venue.
This slice is the bridge — the thing that makes brief §1 literal. A venue's state becomes a building's
*form*: an influential plot reads as a taller tower, a warehouse racket as a squat dock building,
ownership as faction tint. **The city stops being menu-only and starts showing the state.**

## The one rule this obeys

**Pure derivation, zero authoritative state.** Building form is a pure function of `DistrictData` +
`VenueData` read at rebuild time. No new save fields, no RNG, no state inside scene nodes (brief §13.2
corollary). Rebuilds byte-identically on load; visibly re-forms when state changes — same discipline as
every Month-2 slice. The assembler is presentation; GameState stays authoritative.

## What replaces the box

`city_view.gd` today: one `BoxMesh` StaticBody per venue at `venue.map_position`, tinted by owner
faction, click-selectable. P14 keeps the StaticBody + click contract (the sim selects venues by click —
do NOT break that) but replaces the single box with a **kit-assembled building**: a stack of grid-placed
kit tiles under one pickable body, collider sized to the whole footprint.

## The mapping (all pure functions of state)

A new `class_name KitAssembler` (util script, `src/presentation/kit_assembler.gd`) with **static**
methods — testable in isolation, no autoload coupling (same split rationale as `EconomyMath`).

| State input | Drives | Rule |
|---|---|---|
| `venue.type` | **family** | `TRANSIT_NODE` → transit family; `POLITICAL_OFFICE`/`INTELLIGENCE_NODE` → tower; else warehouse |
| `district.influence` | **floor count** | `2 + int(clamp(influence,0,1) * 4)` → 2–6 mid floors |
| `venue.type` | **ground module** | `FRONT` → `ground_frontage_b` (shutter); else `ground_frontage` (loading door) |
| `hash(venue.id)` | **variation** | deterministic pick of `_a`/`_b` for mid_floor & roof_cap — kills copy-paste read (P13b) |
| `venue.owner_faction` | **tint** | faction accent, `lerp` 0.45 — identical to today's box tint |
| `control_state` | **(reserved)** | COMPROMISED/CONTESTED hook for later deterioration; no visual yet |

Tower family uses `tower_mid`/`tower_cap`; warehouse uses `mid_floor(_b)`/`roof_cap(_b)`; transit uses
`transit_pier` + `transit_deck` (a different assembly shape — pier then deck, not a floor stack).

### The assembly (warehouse/tower family)

Placement is P13's proven contract — position = `cell_index × 4.5 m`, base-center tiles butt flush:

```
y=0.0            ground module         (1 tile,  4.5 m band)
y=4.5 … 4.5*N    mid_floor × N         (N = floors from influence)
y=4.5*(N+1)      roof_cap              (1 tile, caps the stack)
```

Single-cell footprint per venue for the slice (the P13 flush-seam proof is single-column; multi-cell
plots are a later extension). Each tile is a `GLTFDocument`-loaded MeshInstance3D child; the whole stack
lives under one StaticBody at `map_position`, one BoxShape3D collider spanning the full height.

## Loading discipline

- Load each GLB **once**, cache the loaded scene per module key, `duplicate()` per instance
  (12 modules, ~40 venues → don't re-parse 480 times). Runtime `GLTFDocument.append_from_file` → scene.
- LOD: the tiles carry `*_LOD0`/`*_LOD1` node names (asset-standard). For the slice, instance LOD0;
  visibility-range LOD is a perf pass only if the 40-instance FPS target regresses (P13 held 60 vsync-
  capped at 180 tiles, so headroom exists — measure, don't pre-optimize).

## Files

- `src/presentation/kit_assembler.gd` — `class_name KitAssembler`, static: `plan_building(venue, district)
  → Dictionary` (pure: `{family, floors, ground, mids:[], cap, tint_source}`), `assemble(plan) → Node3D`
  (builds the tile stack), `MODULES` const path table. Pure planning split from node-building so the
  plan is unit-testable with no scene tree.
- `scenes/city/city_view.gd` — `_make_marker` calls `KitAssembler` instead of building a box; keeps the
  StaticBody/collider/click wiring. `rebuild()` unchanged (still driven by `districts_changed`).
- `tests/unit/test_kit_assembler.gd` — pure `plan_building` assertions: influence→floors monotonic,
  family selection per venue type, deterministic variation (same id → same plan twice), ground module
  per venue type. Exit 0 = pass.

## Gates / Verify — Done when

- `--import` clean (no parse errors); `test_kit_assembler.gd` exits 0; prior unit suite green.
- Boot smoke clean (`--quit-after 120`, no SCRIPT ERROR / Nonexistent).
- **Visual gate (two-eye):** run the editor, F5; Glass Wharf venues now read as assembled buildings,
  not boxes; taller where influence is higher; family varies by venue type; faction tint preserved;
  flush seams (no gap/z-fight) — Claude + Codex-vision judge a management-camera screenshot vs the P13
  `assembly.png` + the master. REVISE until both SHIP.
- **FPS:** the assembled Glass Wharf (all venues as buildings) holds the management-camera target;
  record the number (re-measure vsync-off if it approaches the cap).
- Assembler + test committed; a short accept note in `docs/prompts/notes/`.

## Out of scope

- No multi-cell plots (single column per venue — P13 flush proof is single-column). No deterioration
  visual (control_state hook reserved, no mesh change yet). No texture (grey proxies — the toplu lap is
  still deferred). No new districts. No save/sim changes — presentation only. No Fable.
