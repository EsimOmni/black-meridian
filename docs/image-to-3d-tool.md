# Image-to-3D — Magnific 3D Generator (tool + real pricing)

An **alternative asset-entry path** alongside Codex-Blender. Where Codex models geometry from a
metric spec, this turns an approved concept image straight into a GLB (Trellis 2 / Tripo).
Output is **provisional** — input to Blender cleanup + the `GLBValidator` gate, never a
game-ready asset (brief §10, `docs/asset-standard.md`). It does not bypass the gates.

## When to reach for it vs Codex-Blender

| Situation | Path |
|---|---|
| Grid-tile kit module (must hit exact 4.5 m cell, base-center, flush seams) | **Codex-Blender** — image→3D can't guarantee grid contract |
| One-off hero prop / silhouette-driven set piece with a strong concept image | **image→3D** — fast first-pass mass, then retopo in Blender |
| Organic / irregular geometry hard to box-model | **image→3D** |
| Anything needing precise metric dimensions up front | **Codex-Blender** |

Both feed the same gate. image→3D's raw output is high-poly, ungridded, single-material-ish —
Blender cleanup (retopo → base-center pivot → trim-sheet UV → LOD0/LOD1 → collider) is
mandatory before validation, same 90/10 as everywhere.

## THE PRICING RULE — MCP always charges, unlimited does NOT apply

Account is Premium+ `isUnlimitedMode: true` — but `unlimitedAppliesHere: false` on **every MCP
call**. Confirmed live: balance API returns the unlimited flag *and* the "will consume credits"
instruction in the same response. The `∞` / credit-range badges in the web picker are
**misleading** — they are not the MCP cost. Always warn Cem before a paid generation.

## Real MCP costs (probed via `simulate_cost`, not the UI badge)

Single image → 1 GLB. UI badge shown for contrast — trust the MCP column.

| Model | slug | UI badge | **Real MCP** | certainty | notes |
|---|---|---|---:|---|---|
| **Trellis 2** | `trellis-2` | 610–850 | **610** @512 · **730** @1024 · **850** @1536 | **exact** | only model with a stable, resolution-driven price |
| Tripo v3.1 | `tripo-v31` | 580–1160 | **580** (none/standard tex) · **1160** (detailed tex) | variable | HQ; up to 2M faces; `detailed` tex doubles cost |
| Tripo P1 | `tripo-p1` | 775 | **580** | variable | default/fast; UI badge overstates by ~34% |
| Meshy 6 | — | 1160 (in UI) | **not exposed via MCP** | — | UI-only; MCP has only the three above |

\* Tripo "variable": a single-image run detects persons at runtime and reroutes to the
person-to-3D pipeline, which charges a different key. For **buildings/props (no person)** the
base estimate holds. Trellis 2 has no such reroute → the only `exact` price.

Current balance at time of probe: **43,050 / 45,000** credits (1,950 spent).

### The two hard takeaways

1. **Default to Trellis 2 @512 (610 cr) for first-pass proxies.** It's the only predictable
   price and cheapest usable tier. Bump resolution only for an approved hero.
2. **Texture is not free — defer it.** Tripo `detailed` texture doubles the cost (580→1160).
   The kit doctrine is "grey proxy, texture as a later toplu lap" (P12b/P13) — so first-pass
   image→3D should use `textureQuality: none` / low res and burn the minimum. Texture is the
   final lap, not the first generation.

## Model choice is a USER decision (ask, don't assume)

Because the price spread is real (610 → 1160, ~2×) and certainty differs, **do not pick the
model unilaterally.** Before any paid `models3d_generate`, surface the choice to Cem with the
real costs, e.g.:

- **Cheap proxy** → Trellis 2 @512 (610 cr, exact) — the default first pass.
- **Balanced** → Trellis 2 @1024 (730 cr, exact) or Tripo v3.1 no-tex (580 cr, variable).
- **Hero, textured** → Tripo v3.1 detailed (1160 cr, variable) — only after the mass is approved.

State the credit cost + certainty, get a yes, then run. Same discipline as any paid generation.

## Pipeline (image → game-ready)

1. **Approve the concept image first** (the P12a "concept → asset-split" rule — a master
   keyframe or a clean single-object concept, in-palette: charcoal / oxidized / petrol / sparse
   amber, no purple/cyan).
2. **Upload** the image to Magnific (`creations_upload_image` / `_upload_file`) → get a
   `creationIdentifier`.
3. **Ask Cem the model** (table above) with real credit cost. Default Trellis 2 @512.
4. **Generate**: `models3d_generate(creationIdentifier, model, resolution|textureQuality)`.
   `simulate_cost` first if unsure; `creations_wait` for the GLB URL; download immediately
   (Magnific URLs are signed/expiring).
5. **Blender cleanup (Codex, :9876)** — the mandatory 10%: retopo to low-poly, set base-center
   origin, trim-sheet UV1, author `*_LOD0`/`*_LOD1`, add a collider. Raw image→3D output is
   NOT gridded and NOT game-ready.
6. **Gate**: `GLBValidator.validate_file(path, spec_for(&"building"|&"prop"|…))` → `pass:true`.
7. **Godot instance test** under the management camera; accept; commit GLB + report.

## Guardrails

- **Does NOT bypass the gates.** Free/paid geometry is still provisional until Blender + the
  validator pass (brief §12 — no GLB replaces a validated mechanic; Month-2 gate already
  passed, so Month-3 asset production is authorized, but the discipline holds).
- **Credits are real money-adjacent.** 45k/mo pool; a hero at 1160 cr is ~2.6% of the month.
  Batch/high-volume geometry stays cheaper on local Hunyuan3D/TripoSR or Codex-Blender — MCP
  image→3D is for the low-volume hero/organic case where a concept image beats box-modeling.
- **License**: generated geometry has no third-party license issue, so no `ATTRIBUTIONS.md`
  entry — but if the source concept image derives from any external asset, that provenance
  still applies.

## MCP tool reference

- `mcp__magnific__models3d_generate(creationIdentifier, model?, resolution?, textureQuality?,
  faceLimit?, folderReference?)` — models: `tripo-p1` (default), `tripo-v31`, `trellis-2`.
  Trellis res: 512 / 1024 / 1536. Tripo tex: none / standard / detailed (v31 only).
- `mcp__magnific__simulate_cost(tool="models3d_generate", arguments={…})` — read-only price
  check, never charges. Run before any generate when the price isn't already known.
- `mcp__magnific__account_balance()` — confirms `unlimitedAppliesHere: false` + remaining
  credits before a paid run.
