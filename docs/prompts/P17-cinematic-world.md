# P17 — Marble cinematic world + Aiko first-person controller

**Month:** 4 · **Brief:** §7.7 (cinematic splat sequences), §14 (Marble→Godot integration)

## Dependency

Uses the provider decided in **P01** (`SplatWorldProvider` or `MeshWorldProvider`). If P01 chose mesh,
build this with the mesh fallback — same interaction/camera/anchor data either way (brief §14.3).

## Why

One cinematic splat sequence in the vertical slice (brief §12.1) — the "walk through the consequence"
production-value spike (pillar 4). It is NOT a second game: small, controlled, no combat.

## Scope

1. **The Marble world**: generate via Marble Pro (cinematic production month). Export per brief §14.2:
   500k PLY (min) + 2M PLY (hi) + `collider.glb` + `anchors.json` (interactions/character marks/camera
   limits) + `preview.mp4` (QA/fallback ref). OpenGL coords; standardize scale/origin in Blender.
2. **`CinematicWorld` scene** (`scenes/cinematic/`): loads the splat via the provider, the collider GLB via
   the standard pipeline, instantiates conventional-3D characters + interactive props (splats are static —
   characters/doors/handheld objects/evidence/markers/collision stay conventional 3D, brief §7.7).
3. **Aiko first-person controller**: walk only — **no jumping, no combat** (brief §7.7). Constrained to the
   validated camera volume from `anchors.json`. 3–6 interaction points, 1–3 characters.
4. **Interaction verbs** (brief §6 pillar 4): inspect evidence, choose where to stand, speak privately
   before another arrives, plant/remove/reinterpret an object, decide what Aiko reveals, walk away.
5. **Visual rules** (brief §7.7): baked illumination in the splat — dynamic lights hit characters/props
   only; no large moving doors baked in; one splat resident at a time; 500k/2M as a perf setting.

## Sequence types (brief §7.7)

Crime-scene inspection / walk-and-talk negotiation / private confrontation / dynasty council / aftermath-
or-execution decision. The slice ships ONE (brief §12.3: no more than one splat sequence in the slice).

## Verify

- The cinematic scene loads, Aiko walks the validated volume, all interaction points work, no script errors.
- 500k/2M toggle works; if splat fails the perf gate, the mesh provider renders the same scene.
