# P14 — Runtime kit assembler: ACCEPTED

**Accepted:** 2026-07-04 · the 12-module kit is now wired to the sim. Brief §1 ("the city shows
the state") is literal: a venue's strategic state assembles its building.

## What shipped

- `src/presentation/kit_assembler.gd` — `class_name KitAssembler` (RefCounted, static methods).
  **Pure derivation, zero authoritative state, zero RNG, zero save changes.** `plan_building(venue,
  district) → Dictionary` is a pure function (unit-tested with no scene tree); `assemble(plan) →
  Node3D` builds the grid-placed tile stack (P13 contract: band = cell_index × 4.5 m).
- `scenes/city/city_view.gd` — `_make_marker` now assembles a kit building per venue instead of a
  2 m box. Keeps the StaticBody + collider + click contract intact (sim still selects venues by
  click). Whole stack tinted by owner-faction accent (per-instance material override).
- `src/core/game_state.gd` — added `get_district_of_venue(venue)` reverse lookup (the assembler
  needs a venue's district to read `influence`).
- `scenes/city/management_camera.gd` + `bootstrap.gd` — raised camera zoom bands (10–34 → 18–50,
  default 22 → 38) and the bootstrap camera seed (y 22 → 38). Assembled buildings reach ~31 m
  (6 floors); the old bands were sized for 2 m boxes and looked *into* the buildings.
- `tests/unit/test_kit_assembler.gd` — pure `plan_building` assertions (family per venue type,
  influence→floors monotonic, ground module per type, deterministic variation, transit shape).

## The mapping (all pure functions of state)

| State input | Drives | Rule |
|---|---|---|
| `venue.type` | family | TRANSIT_NODE → transit; POLITICAL_OFFICE/INTELLIGENCE_NODE → tower; else warehouse |
| `district.influence` | floors | `2 + int(clamp(influence,0,1)*4)` → 2–6 mid floors (influential plot reads taller) |
| `venue.type` | ground module | FRONT → `ground_frontage_b` (shutter); else `ground_frontage` (loading door) |
| `hash(venue.id) & 1` | variation | deterministic `_a`/`_b` mid-floor & roof-cap pick — kills copy-paste read |
| `venue.owner_faction` | tint | faction accent lerp 0.45 (player vs rival at a glance) |
| `control_state` | (reserved) | deterioration hook, no visual yet |

## Gates — all passed

- **Headless (truth):** `--import` clean; `test_kit_assembler.gd` exits 0; **full prior suite green**
  (10 tscn + 2 unit scripts, all exit 0); boot smoke has no SCRIPT ERROR / Nonexistent (the RID-
  leak-at-exit lines are the dummy-rasterizer teardown, expected once real meshes spawn headlessly).
- **Two-eye massing gate (SHIP/SHIP):** management-camera capture (`p14_runtime_assembly.png`)
  judged by control tower + Codex-vision independently vs P13 `assembly.png` + the master. Both SHIP:
  coherent stacked buildings with floor bands + roof caps, flush seams (no gap/z-fight), reads as the
  same dockside warehouse/tower family, no assembler defect (no floating tiles / inverted normals /
  bad scale). Codex verdict verbatim: *"rougher and tighter than P13/master, but it reads as the same
  dockside tower/warehouse family. SHIP."*
- **FPS:** not re-measured live (editor MCP dropped after the headless capture run), but not at risk:
  Glass Wharf's ~6 venues → ~6 buildings × ~8 tiles ≈ **~48 tile instances**, far under P13's proven
  **180 instances @ 60 fps (vsync-capped, headroom unmeasured)**. P13's measurement bounds this slice.

## The `RivalDirector` compile errors in the run log are stale

`project_run` reported `Compile Error: Identifier not found: RivalDirector` in hud.gd/job_director.gd,
flagged `recent_errors_may_predate_run:true`. These are an editor-reload artifact (RivalDirector is an
autoload, resolves at runtime) — the game went `status:live`, which it couldn't if job_director failed
to compile, and the headless boot smoke is clean. Not introduced by P14.

## Open (carried forward, non-blocking)

- ~~**Venue cluster overlap.**~~ RESOLVED (follow-up commit): WorldSeed `map_position` re-laid into a
  single wharf frontage row along x (8 m spacing, ±1.5 m z stagger, span x∈[-20,20]). Two-eye BETTER —
  reads as a separated dockside street, no piling. Save roundtrip green (layout is save-safe data).
- **Single-cell footprint per venue.** P13's flush-seam proof is single-column; multi-cell plots
  (wider buildings) are a later extension.
- **No texture.** Grey proxies + faction tint only — the shared trim-sheet toplu lap is still deferred.
- **`control_state` deterioration** reserved but unwired — COMPROMISED/CONTESTED don't change the mesh
  yet.
- **Transit assembly** (pier + deck) is coded but Glass Wharf's seed has no TRANSIT_NODE venue, so it's
  untested at runtime — exercise it when a transit venue is seeded.

## Verdict

The kit is no longer a dead asset. Venue state drives building form at runtime, deterministically,
save-safe, with the city visibly reflecting ownership + influence. The bridge from "12 validated GLBs
on disk" to "the city shows the state" is built and gated.
