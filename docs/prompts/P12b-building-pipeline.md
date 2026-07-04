# P12b — Glass Wharf modular building pipeline (first asset: warehouse gövde)

**Month:** 3 · **Brief:** §9.1–§9.2 (visual thesis + camera), §10.2 (modular kit)
· Depends on: P12a (master LOCKED), P15 (validator gate — independently probed OK)

## Who runs this

**Not a Fable slice.** This is the control-tower's Codex-driven pipeline. Division of labor:

- **Codex (BlenderMCP :9876)** — the mechanical Blender work: model the box gövde, retopo,
  trim-sheet UV, author LOD0/LOD1, add a collider, export GLB. Bills to ChatGPT, not Opus.
- **Control tower (me)** — architect + gate: anchor to the master, hand Codex the spec, run
  the GLB through `GLBValidator` (P15), load it in Godot at the management camera, accept or
  bounce. AI ~90 / human(=Codex-Blender + my taste) ~10.

Fable is idle this slice.

## The one asset (locked scope)

**`glasswharf_dock_warehouse_a`** — a single harbor warehouse gövde from the master
(`docs/prompts/notes/concept/glass_wharf_MASTER.jpg`). NOT the full kit. Prove the whole path
end-to-end on one module, THEN replicate to the ~12-kit set in a later slice. This is the first
stone; keep it boring.

Why a warehouse and not the hero alien structure: cleanest `building` spec match, lowest
variable count, and the P12a watch-item (alien structure too bright) stays out of the first
pipeline test. Hero identity assets come after the pipeline is proven, never during.

## Target spec (the acceptance contract)

From `GLBValidator.SPECS[&"building"]` / `docs/asset-standard.md` — Codex must hit these or the
gate bounces it:

| Rule | Target |
|---|---|
| scale | meters; height 3–120 m (a dock warehouse ≈ 8–14 m). 1 Blender unit = 1 m. |
| pivot | base-center: origin at footprint center, y=0 at the base (`abs(center.x/z)<0.05`, `abs(base y)<0.05`) |
| normals | present on every surface |
| uv | UV1 mandatory (trim-sheet); UV2 optional (warn only) |
| materials | ≤3 distinct baked (soft) / ≤6 hard |
| draw calls | ≤4 surfaces (soft) / ≤8 hard |
| tris | ≤15k (soft) / ≤30k hard — a gövde should be far under, ~1–3k |
| LOD | ≥2 levels via node names `*_LOD0` / `*_LOD1` (case-insensitive) |
| collision | a collider node present (advisory warn if absent) |

Naming (asset-standard.md): meshes `glasswharf_dock_warehouse_a_LOD0`, `..._LOD1`.
Output path: `res://assets/city/glasswharf_dock/warehouse_a.glb`
(`assets/city/glasswharf_dock/` — new folder, matches the doc's own example).

## Art anchor (§9.1)

Read the master before modeling. The gövde is rain-lacquered noir infrastructure, not
cyberpunk: weathered charcoal concrete + oxidized metal cladding, muted petrol trim, sparse
sodium-amber only at a door/window. NO purple/magenta/neon-cyan. Under the near-ortho
management camera (§9.2, ~40° down, ~60mm) the read is a premium diorama, so:

- Rear/side façades can be simplified — the camera rarely sees them.
- Underside geometry minimal.
- Detail lives in the trim-sheet + a few rooftop props (vents, a rail), not in polycount.

Material/texture is Codex-first-pass; final grade is a control-tower curation pass. First
milestone is a **validated grey gövde with correct topology/UV/LOD**, texture is the second lap.

## Pipeline (the repeatable path — the real deliverable)

1. **Codex models** the gövde in Blender via :9876: base box massing → panel/parapet detail →
   retopo to a clean low-poly → unwrap to a single trim-sheet UV → duplicate+decimate for LOD1
   → add a box collider mesh → set object origin to base-center → export
   `warehouse_a.glb` (Y-up, meters, +materials as a placeholder StandardMaterial is fine).
2. **Control tower gates** it: `GLBValidator.validate_file(path, spec_for(&"building"))`.
   `pass:true` required — every `fail` goes back to Codex with the exact check detail. Warns
   are noted, not blocking.
3. **Godot instance test**: drop the passed GLB into a test scene under the management camera,
   confirm scale/pivot read correctly against a reference cube, eyeball the silhouette against
   the master. (Later slice: a ~40-instance block at the FPS target — not this first module.)
4. **Accept**: commit the GLB + its validator report. The gövde becomes the reference the rest
   of the kit is built against.

## Codex delegation shape

`codex exec --sandbox workspace-write "via BlenderMCP on port 9876: <model/retopo/UV/LOD/
export spec>, export to <abs path>" < /dev/null` — PROMPT first, close stdin, never taskkill a
running exec. One bounded Blender task per call; iterate on gate failures.

## Verify / Done when

- `warehouse_a.glb` exists at the target path and `GLBValidator.validate_file` returns
  `pass:true` (no `fail`; warns allowed).
- Loads in Godot at correct meters scale + base-center pivot under the management camera; the
  silhouette reads as the master's warehouse, palette in-family (no forbidden colors).
- GLB + a saved validator report committed. `assets/ATTRIBUTIONS.md` updated only if any
  external asset was pulled (this is generated, so likely none).
- Prior suite (9 unit + 2 integration + P15 test) stays green; boot smoke clean.

## Out of scope

- No full kit (that is the replicate-slice after this). No hero alien structure. No drivable
  vehicles / interiors. No final texture-grade pass beyond a first-pass material (second lap).
  No src/ sim or save changes. No Fable involvement.
