# Codex Brief — Multi-view Hunyuan3D shape gen for the alien tower

**Goal:** Generate a NEW alien-tower mesh whose **proportions are correct** by
conditioning Hunyuan3D shape generation on **4 camera views** instead of one. The
single-view mesh we already have squashed the tall brutalist body (crown ~55% /
base ~45%); the concept wants base ~60% / crown ~40%. Multi-view conditioning should
fix the depth/height guess that single-view got wrong.

Run this against the **local ComfyUI backend** (zero credit). Report the resulting
mesh path + a check render. **Do NOT touch game code or the existing tower GLB** —
this is an experimental channel; Claude picks the winner across channels afterward.

---

## Environment (verified)

- **ComfyUI HTTP:** `http://127.0.0.1:7821` (this is the live one — `OMNI_COMFY_URL`.
  Note the adapter's default of `8188` is stale; 7821 is what's actually up.)
- **ComfyUI root:** `D:\AI\SwarmUI\dlbackend\comfy\ComfyUI`
- **Hunyuan custom node:** `custom_nodes\ComfyUI-Hunyuan3d-2-1` with
  `workflow_examples\*.json` (Mesh_Generation, Full_Workflow, Batch_Generator,
  Apply_8Views_On_Mesh, Mesh_Texturing*).
- **Existing adapter to mimic:** `D:\black-meridian\tools\pipeline\hunyuan.py` — it
  loads a UI-format workflow JSON, converts it to the `/prompt` API graph
  (`_ui_to_api_graph`), snaps combo widgets to this install's real model names
  (`_snap_combo_widgets`, `_fetch_object_info`), and posts to `/prompt`. REUSE these
  helpers — don't reinvent the API-graph conversion.

## The 4 input views (already generated, consistent, concept-faithful)

```
D:\black-meridian\assets\_references\alien_tower_multiview\tower_front.png
D:\black-meridian\assets\_references\alien_tower_multiview\tower_side_left.png
D:\black-meridian\assets\_references\alien_tower_multiview\tower_side_right.png
D:\black-meridian\assets\_references\alien_tower_multiview\tower_back.png
```
They are ~800×449, neutral grey background, same tower each angle. Low-res is
acceptable for a first validation pass — Hunyuan resizes internally. If the mesh is
good but blurry, we regenerate the views at higher res later.

---

## THE KEY DECISION — find the real multi-view SHAPE path

There are two Hunyuan node families in this install and it is easy to pick the wrong one:

1. **`Hy3D21*` / `Hy3DMeshGenerator` family** (what the adapter + `Mesh_Generation.json`
   use). `Hy3DMeshGenerator` conditions shape on a **single** image. Its
   `MultiViews` nodes (`Hy3DMultiViewsGenerator`, `Hy3DBakeMultiViews`,
   `Hy3D21GenerateMultiViewsBatch`, `Apply_8Views_On_Mesh.json`) are for **TEXTURING**
   — baking texture onto an existing mesh from many angles. **They do NOT change the
   shape.** Using these will NOT fix the proportion problem.

2. **Native `Hunyuan3Dv2*` family** — `Hunyuan3Dv2ConditioningMultiView` takes
   optional `front/left/back/right` image inputs and outputs `positive/negative`
   conditioning for **shape** sampling. Chain (verified schemas):
   - `Hunyuan3Dv2ConditioningMultiView(front,left,back,right)` → positive/negative
   - `EmptyLatentHunyuan3Dv2(resolution, batch_size)` → LATENT
   - a KSampler-equivalent for Hunyuan3D → sampled LATENT
   - `VAEDecodeHunyuan3D(samples, vae, num_chunks, octree_resolution)` → VOXEL
   - then voxel → mesh export.
   This is the family that conditions SHAPE on multiple views. **This is the target.**

**Your job:** determine whether the native `Hunyuan3Dv2ConditioningMultiView` shape
path is fully wired in THIS install (it needs a Hunyuan3D checkpoint loader,
clip_vision, a Hunyuan3D-compatible sampler, and the VAE). Query `/object_info` for
every node in the chain, confirm each exists and find the loaders/sampler that feed
it. If the native path is complete, build that graph, feed the 4 views, and run it.

If the native shape-multiview path is NOT fully available in this install (missing a
loader/sampler), FALL BACK to: run single-view `Hy3DMeshGenerator` on `tower_front.png`
alone (it has the best proportions of the 4) and report that you used the fallback —
a good single-view mesh from the corrected front view still beats the old squashed one.

---

## Steps

1. Query `/object_info` for: `Hunyuan3Dv2ConditioningMultiView`,
   `EmptyLatentHunyuan3Dv2`, `VAEDecodeHunyuan3D`, and search for a Hunyuan3D
   checkpoint/clip-vision loader + a sampler that accepts Hunyuan3D latents. Print
   what exists so the graph is grounded in real schemas, not guesses.
2. Build the multi-view shape graph (or the documented fallback). Load the 4 views
   (native nodes may take raw images; if a transparency/cutout is required use
   `Hy3D21LoadImageWithTransparency` per view, same as the adapter).
3. Post to `/prompt` on `127.0.0.1:7821`, poll `/history/{prompt_id}` until done.
4. Export the mesh (GLB or OBJ) to:
   `D:\black-meridian\assets\_generated\hunyuan3d\alien_tower_hero_002_multiview\v001\alien_tower_multiview.glb`
   (create the dir).
5. Render ONE check image of the resulting mesh (Preview3D, or a quick trimesh/Blender
   render) so proportions can be judged, save to
   `D:\black-meridian\scratchpad\tower_multiview_check.png`.

## Report back
- (a) Which path you used: native multi-view SHAPE, or single-view fallback (and why).
- (b) The `/object_info` findings for the multi-view chain — what existed, what was missing.
- (c) Final mesh path + vert/poly count.
- (d) The check-render path.
- (e) The base/crown height ratio of the result if measurable (we're chasing base ~60% / crown ~40%).

## Hard rules
- Zero credit — local ComfyUI only, never a paid API.
- Reuse `tools/pipeline/hunyuan.py` helpers for API-graph conversion + model snapping.
- Touch NO game code, NO existing tower GLB. Output only under
  `assets/_generated/hunyuan3d/alien_tower_hero_002_multiview/` + the scratchpad render.
- Don't `taskkill` a running ComfyUI job; poll `/history`.
