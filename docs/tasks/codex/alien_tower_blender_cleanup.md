# Codex Blender Brief — Alien Diplomatic Tower: crown emission + base cleanup

**Goal:** Take the existing Hunyuan3D-textured alien tower GLB and produce a
game-ready hero landmark for Godot 4.7. The mesh + base texture are GOOD (faithful
to the concept). The one real gap is that the **crown does not glow** — in the
concept it is a bioluminescent blue-green coral flame lit from *within*; right now
it only reflects light. Add self-emission to the crown, fix a base texture artifact,
and re-export clean. **Do NOT re-generate geometry. Do NOT decimate below 120k verts
(a past 44k decimate distorted the UV and mapped the crown to a white atlas patch —
silhouette + UV fidelity matter more than tri-count for a landmark).**

This is driven via **BlenderMCP on port 9876** (`execute_blender_code`). Blender 5.1.
EEVEE engine enum in this build is `BLENDER_EEVEE` (NOT `BLENDER_EEVEE_NEXT`).

---

## Verified inputs (measured, do not re-derive)

- **Source GLB:** `D:\black-meridian\assets\_generated\hunyuan3d\alien_tower_hero_001\v002\alien_tower_hero_001_v002_tex.glb`
- **Mesh:** single object `alien_tower_hero_001_v002_tex.obj`, 129,978 verts / 199,994 polys, one `UVMap`, ONE material slot.
- **Material:** `PBR_Material`, Principled BSDF. baseColor = `Image_0` (1024², sRGB). ORM = `Image_1` (1024², Non-Color; R=occlusion, G=roughness≈0.57, B=metallic≈0.04). metallic=0, emissionStrength=0.
- **Object local Z range:** zmin=-0.995, zmax=+0.887, height=1.882 (object space, before any transform).
- **Crown/base transition:** the organic flame crown is roughly the **top 55%** of height → local **z ≥ -0.148** is crown, below is the brutalist base. (top-55% ≈ 30% of verts.)
- The base texture is NOT washed out — measured top-half albedo luma = 0.135 (dark, correct). The "white crown" seen in Godot is a *scene-lighting* blowout, not a texture defect. So DON'T brighten the texture.
- The existing emissive mask `assets/city/glasswharf_dock/alien_tower_hero_0_emissive.png` is **effectively black (mean 0.02)** — useless, ignore it. We generate emission from geometry Z instead.

---

## Tasks (in order)

### 1. Import + split crown from base by Z
```
Import the GLB. On the single mesh, create a vertex group "crown" containing every
vertex with local z >= -0.148. Assign a SECOND material slot to the crown faces
(faces whose centroid z >= -0.148). Keep the base faces on the original PBR_Material.
```
Use bmesh or `object.vertex_groups` + a face-material assignment loop. Result: two
material slots — slot 0 `PBR_Material` (base, unchanged), slot 1 a new `Crown_Emissive`.

### 2. Crown_Emissive material — bioluminescent
Duplicate `PBR_Material` → `Crown_Emissive`, keep its baseColor (Image_0) and ORM
(Image_1) links so surface detail survives, then ADD emission driven by the SAME
baseColor texture masked to a cyan-green tint:
```
- Emission Color: multiply Image_0 by a cyan-green tint (0.0, 0.85, 0.75) so the
  glow follows the texture's own light/dark variation (veins glow, troughs stay dim)
  — a flat emission color reads as plastic.
- Emission Strength: ~2.5 (bright enough to read as self-lit in a dark night scene,
  not a nuclear blowout).
- Keep Roughness from ORM (do NOT drop it to 0 — a mirror crown is what blows out).
  If anything, RAISE the crown roughness floor to ~0.5 so it can't specular-blow.
```

### 3. Base texture artifact
There is a vertical **white streak** down the front center of the base (visible in a
neutral render — a Hunyuan bake seam / stretched UV). Inspect Image_0 in the base's
front-center UV region; if it's a bright band, paint/clamp it down toward the
surrounding bronze (a simple: clamp base albedo max to ~0.4 luma in that region, or
darken the specific UV island). Low priority — if it's not trivially fixable in
Blender, note it and leave it; the scene camera is distant.

### 4. Validate in Blender (render a check)
Render one EEVEE frame, dark world (0.05,0.06,0.08 @ 0.3), one SUN key @ energy 3,
camera at object front. Confirm: crown reads as glowing cyan-green (not white, not
flat black), base reads as dark brutalist bronze with legible facets. Save to
`D:\black-meridian\scratchpad\tower_codex_check.png` and report the path.

### 5. Export game-ready GLB
```
export_scene.gltf(
    filepath=r"D:\black-meridian\assets\city\glasswharf_dock\alien_tower_hero.glb",
    export_format='GLB',
    export_yup=True,
    export_apply=True,
    export_image_format='AUTO',          # AUTO = PNG for baseColor/emissive
    export_draco_mesh_compression_enable=False,
)
```
This OVERWRITES the tower GLB the game already points at
(`district_landmarks.gd` → `AlienDiplomaticTower`). Base must stay base-centered
(pivot at base, y=0 = ground). If the import shifted the pivot, re-center: XY at
mesh centroid, zmin at origin, BEFORE export.

---

## Hard rules
- **No geometry regen, no decimate below 120k.** Preserve the UVMap exactly.
- **Do NOT touch** any other file — only produce the one GLB + the check render.
- Emission strength is the knob most likely to need tuning — if unsure, err LOWER
  (2.0) and note it; Claude does the final Godot-side lighting match.
- Report back: (a) final vert/poly count, (b) the two material slot names, (c) the
  check-render path, (d) emission strength used, (e) whether the base streak was fixed.

## What Claude does after (not your job)
Claude re-imports the GLB in Godot, drops the now-obsolete `_apply_matte` emission
hack in `district_landmarks.gd` (the mesh carries its own emission now), and tunes
the scene glow HDR threshold so the crown blooms without the base blowing out.
