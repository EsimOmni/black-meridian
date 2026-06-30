# P15 — GLB import-validation tooling + asset standard

**Month:** 3 · **Brief:** §10.2–§10.4 (validation steps), §13.4 (/tools)

## Why

Every generated/purchased asset must pass the same gauntlet before it's allowed into the game (brief
§10.3: "Do not use raw generated GLBs directly"). A tool makes this repeatable — the Month 3 gate is
*repeatable delivery without reinventing the pipeline each time*.

## Scope

`tools/validation/validate_glb.gd` (+ optional editor plugin) that checks an imported GLB for:

1. **Scale** (real-world meters), **origin/pivot** correctness, **normals**, **material consolidation**,
   **UV** presence, **LOD** count, **collision policy**, **draw-call** budget.
2. Reports pass/warn/fail per asset; fails block import into a scene.
3. **Asset naming + folder standard** (brief Month 3 deliverable): document the canonical naming +
   `/assets/<category>/...` layout in `docs/asset-standard.md`.
4. A small **import test harness** under `tests/integration/` that runs the validator over the kit assets.

## Verify

- The validator flags a deliberately-broken GLB (wrong scale / missing LOD) and passes a clean one.
- The kit building (P12), a prop, a vehicle, and a character anim update each pass — proving the Month 3
  gate: repeatable delivery of one of each without manual pipeline reinvention.
