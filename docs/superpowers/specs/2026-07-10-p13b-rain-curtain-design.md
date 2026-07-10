# P13b — Rain Curtain (atmosphere, phase 1) — design

**Date:** 2026-07-10 · **Slice:** P13b (city-life VFX), phase 1 of N
**Brief:** §6 pillar 2 (the city shows the state), §9.1 (rain-lacquered noir), §15 (performance)
**Master ref:** `assets/concept/glass_wharf/glasswharf_master.png`

## Scope (locked)

A single **static rain curtain** over the Glass Wharf city view — the highest-value slice of the
P13b VFX package, taken alone. It carries the master's rain-lacquered noir mood.

**In scope:** one diagonal, continuous rain-streak particle system covering the full camera-pan area.

**Explicitly OUT of scope (deferred to P13c+):** steam/fog, rain-on-ground ripples/splashes,
wet-ground reflection tuning, sim-reactive rain intensity, traffic, crowds, state manifestation.

**No sim integration.** The rain does not react to district/global state. That is a separate slice
(P13c). This slice is purely visual atmosphere.

## Why this shape

- The master is a rain-soaked noir dockside; the wet-ground *material* already exists
  (`city_view._build_ground`, `bootstrap` HDRI + reflection), but there is **no rain itself** —
  no falling water. This slice adds the missing falling curtain and nothing else.
- Rain reacting to the sim is meaningful but is state-manifestation work (pillar 2), which is its own
  slice. Keeping this one static gives a clean boundary: **atmosphere only, zero sim coupling**, so it
  cannot regress the deterministic simulation or save/load.

## Architecture

One new unit: `scenes/city/rain_curtain.gd` (a `GPUParticles3D`-based node), added as a **sibling of
the venue markers / landmarks / props** under `city_view`.

- `city_view.gd` `_ready()` gains **one line** — spawn the rain curtain, exactly like
  `DistrictLandmarks.spawn_all(self)` / `DockProps.spawn_all(self)`. No other existing code changes.
- **Presentation-only.** Holds no authoritative state, connects no signals, is never rebuilt on
  `districts_changed`. It does not touch `GameState` → cannot affect save/load or determinism.
- Not tied to `rebuild()` — rain is independent of venue state.

**Dependencies:** only Godot's `GPUParticles3D` + `ParticleProcessMaterial`. No new assets, no new
autoload, no external dependency.

### Why GPUParticles3D, fixed box (approach A)

Rejected alternatives:
- **Full-scene / camera-following emitter** — wasteful: the camera pan is clamped to a known box, so
  a following emitter is needless complexity (YAGNI). A fixed box that covers the whole pan area is
  simpler and sufficient.
- **Screen-space shader rain (fullscreen quad)** — cheapest but reads as "rain on the lens," no 3D
  depth; wrong aesthetic for the master's world-depth diagonal curtain.

Brief §15 asks for exactly approach A: fixed camera bands, GPU-side particles. The camera pan is
clamped to `x,z ∈ [-100, 100]` (`management_camera.gd`), zoom `y ∈ [18, 120]`, so the playable region
is a known, bounded box — a single static rain volume covers it with margin.

## The particle system

**Node:** one `GPUParticles3D`, positioned at the pan-box center, high above the tallest building.

- `amount ≈ 2000–4000` (GPU-side, effectively free; final count tuned by eye against the master).
- `lifetime` sized so a drop crosses the volume top-to-bottom.
- Emitter node y ≈ 55 (above the ~31 m assembled buildings + zoom headroom) so rain descends through
  the whole camera band.

**Emitter volume (`ParticleProcessMaterial`):**
- `emission_shape = BOX`, `emission_box_extents ≈ (110, 1, 110)` — the full ±100 pan area + margin.

**Motion (the master's diagonal curtain):**
- `gravity = (small −x, large −y, 0)` → a slight diagonal fall (~15° top-left to bottom-right, as in
  the master), not vertical.
- Low `initial_velocity`; drops accelerate under gravity. No damping.

**Look (streak, not dots):**
- Draw-pass mesh = a thin tall `QuadMesh` (≈ 0.02 × 0.6 m) so each drop reads as a **line**, not a
  point.
- Material: `StandardMaterial3D`, **Y-billboard** (stays near-vertical, doesn't flatten fully toward
  camera), cool light grey-blue, faint `emission` (streaks catch the neon), semi-transparent
  (`alpha ≈ 0.35`), `unshaded`. `transparency = ALPHA`, depth-write off → it lays a thin veil over the
  scene without drowning reflections or buildings.

**Master fidelity:** thin-to-medium, continuous — not a downpour. Density tuned via `amount` + `alpha`
by eye against the master.

## Verification

Performance (brief §15 — 60 fps @ 1080p):
- Single `GPUParticles3D`, GPU-side → ~zero CPU cost. `amount` 4000 is trivial on the target 5060 Ti.
- Fixed volume = the camera-band optimization (only the played box rains, not the whole scene).

Verification chain:
1. `--import` + boot smoke clean (no parse/script errors) — headless, mandatory.
2. Run the game (`project_run`); in city view the rain is **visible, diagonal, at the master's
   density** — editor screenshot or Codex-vision eyeball vs the master.
3. Save/load round-trip test still green (proves the presentation node carries no state — guaranteed
   since we don't touch `GameState`, but run it anyway).
4. Rain covers the whole area across the camera pan/zoom limits — no visible edge/margin gap.

**Acceptance:** the master's rainy noir mood reads in city view + 60 fps held + save/load green.
