# P12b hero #2 — Carved-stone institution: ACCEPTED (skyline landmark, control-tower gated)

**Accepted:** 2026-07-06 · the Compact's civic face — a neo-classical stone institution built through the
same direct-socket Blender pipeline as the alien tower, placed as a second district skyline landmark and
gated by the control tower (GLBValidator re-run + own-eye massing + own-eye placement vs the master), not
trusted from the producer's claim. Source master: `glass_wharf_MASTER.jpg` (P12a, LOCKED).

## What shipped

`assets/city/glasswharf_dock/stone_institution.glb` — a low, wide horizontal stone mass: rusticated dark
plinth, pale limestone body, a **projecting portico** (six free-standing columns on a stylobate carrying
an entablature), crowned by a **triangular pediment**, a cornice band over the body, and warm interior
window-glow strips down the long sides + doorway. The ordered / stone / institutional anti-thesis of the
alien tower's vertical-organic-other. IP-safe original geometry.

Placement: `Vector3(-30, 0, -14)`, rotation_y 0.95 — left flank, level with the venue row, portico turned
toward the 3/4 skyline eye. Added to `src/presentation/district_landmarks.gd` (the existing additive
skyline layer; no venue/KitAssembler change).

## GLBValidator ('building' gate) — re-run by the control tower

| Check | Result |
|---|---|
| PASS | **true** |
| scale | 16.60 m tall, 16.80 × 14.90 m footprint (low/wide horizontal mass, not a squat cube) |
| pivot | base-center within 0.05 m |
| normals | pass — all 6 surfaces carry normals |
| materials | 3 (limestone / dark base / warm window emissive) |
| tris | 388 (LOD0 + LOD1 + collider) |
| lod | LOD0 + LOD1 present |
| uv | warn — UV present, UV2 absent (lightmap-only, non-blocking) |
| draw_calls | warn — 6 (soft 4, hard 8; a texture-lap merge target) |
| collision | warn — `-col` mesh present; converts via the import suffix (same advisory as the tower) |

Three warns, all non-blocking and identical to the alien tower's accepted set.

## The build lesson: the gate caught four real fails before ship

Green-by-claim is not green. Attempt 1 exported and the control-tower validator re-run showed **PASS: false**
on four checks — none of which a "looks done" claim would have surfaced:
- **pivot fail** — I modeled UP=+Y but Blender is Z-up; `export_yup=True` then skewed the pivot off base-center.
  Fix: model with UP=+Z (base at z=0), let the exporter convert to Godot Y-up with base y=0.
- **lod fail** — LOD1 exported as `institution_LOD1.001` (stale mesh name collision) → the `_lod(\d+)$` regex
  missed it. Fix: purge same-named mesh/object data before rebuilding so no `.001` suffix appears.
- **uv fail** — the collider mesh had no UVs (validator counts it as a mesh on runtime load). Fix: unwrap it too.
- **pivot (again)** — the projecting portico biased the AABB +0.4 m in depth. Fix: measure combined bounds and
  recenter x/y before export. Re-run → **PASS: true**, geometry unchanged.

## Two-eye massing gate — SHIP (2 rounds)

- **Round 1:** the portico columns were embedded flush in the body face → read as a plain box with a roof, no
  portico. REVISE. Re-read the master: the portico is a **free-standing projecting porch** (columns proud of
  the body, their own stylobate, entablature, pediment crowning THAT). Rebuilt.
- **Round 2:** front render (own eye) — the neo-classical read lands: six columns standing proud with shadow
  between them, pediment on the entablature, rusticated plinth, cornice, side glow. SHIP. (Minor: columns read
  a touch stout, pediment overhangs slightly — silhouette carries; refinement deferred to the texture lap.)

## Two-eye placement gate — PASS (1 reframe)

The discipline that held: Codex's live-unproject verdict said "PASS — in-frame, not clipped." The control
tower's OWN-EYE read of the framebuffer **overruled it** — the numbers were right but the composition was
wrong: the institution loomed in the near-left foreground (screen bbox 649×441, x starting at 4), dominating
the frame and dwarfing the venue row, with the portico turned away from the camera. Unproject measures
"visible"; it cannot measure "sits with the master." Reframed: position (-26,0,6)/rot 0.55 → **(-30,0,-14)/
rot 0.95** — pushed back level with the row, portico turned to the 3/4 eye. Re-capture: screen bbox 456×315,
x starting at 223 — now a left-flank landmark scaled in conversation with the row, the tower reading
separately as the right-rear vertical. Two-pole composition matches the master.

## Known deferred (NOT this slice)

At the skyline distance in placeholder light the portico's columns don't yet resolve — the stone mass +
pediment silhouette reads, the column rhythm is silked out. Same class of deferral as the alien tower's
near-silhouette crown: a MATERIAL / LIGHTING problem owned by the noir texture lap, not placement. The
geometry is correct (proven in the front render + GLBValidator) and the composition matches the master;
forcing column readability at this distance would mean up-scaling the building and breaking the composition
just fixed. Placement mechanic (spawn + level-with-row skyline framing + master two-pole read) holds.

## Next

Hero #3 (transit spine — rail + lattice bridge + train kit pieces), then the noir texture lap (which lifts
both the tower crown and this portico out of silhouette).
