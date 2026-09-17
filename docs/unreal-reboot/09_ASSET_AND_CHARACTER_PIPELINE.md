# 09 — Asset and Character Pipeline

How art gets made, validated and imported — and the rule that governs all of it:

> **Generated geometry is provisional until Blender cleanup and engine validation are complete.**
> `[V]` brief §10.1. Nothing is "game-ready" because a tool emitted it.

Tags: `[V]` Verified from repository · `[I]` Inferred · `[P]` Proposed · `[U]` Unverified

---

## 1. The gate that governs everything

`[V]` Locked #15 and brief §12: **no final art production before the Unreal greybox vertical slice
passes its gameplay and technical gates** (Gate A, [07](07_IMPLEMENTATION_ROADMAP.md) S10).

`[V]` The Godot project honoured this at four consecutive gates and it is the single discipline most
responsible for the project still being alive. It is also the one most likely to be quietly abandoned
once Unreal's renderer starts producing pretty frames. **The failure mode is producing assets before
the mechanic is proven** (brief §12).

**Two exceptions, both narrow:**
1. **Greybox/proxy geometry** — needed to play the slice at all.
2. **Concept art and canonical character references** — 2D only, no production geometry; the character
   is the longest-lead item and its identity must be locked before S12 ([07](07_IMPLEMENTATION_ROADMAP.md)).

---

## 2. Production doctrine, carried over

`[V]` Adopted 2026-07-02, validated repeatedly in the Godot build (`tasks/lessons.md`, `CLAUDE.md`):

1. **Concept → asset-split.** Approve a full concept image (keyframe) for a location first, **then**
   generate individual assets to match it. Never generate piecemeal without a master. "Does this asset
   fit?" becomes a mechanical check against the master instead of per-generation taste-testing.
2. **AI ~90% / human ~10%.** AI does first-pass everything; the human 10% is curation, cleanup,
   integration and taste. **Don't automate the last 10%** (that's where quality lives) and don't
   hand-do the first 90% (that's where time dies).
3. **Prefer ready plugins/templates** over bespoke code for anything that isn't the game's identity.
   The simulation is core; plumbing is not.
4. **The source-seer does the cleanup.** `[V]` A costly lesson: hero-tower GLB cleanup was delegated as
   "mechanical work" to an agent without the visual context; decimation wasn't UV-aware, the silhouette
   collapsed to a blob, the texture was lost on export, and there was no re-import verification →
   **total re-do**. Blender cleanup *looks* mechanical and is not.
5. **Verify by rendering, and always re-import the export.** Never accept a producer's claim.

---

## 3. Canonical reference intake

`[V]` **The cast is placeholders.** Brief §4: *"Names other than Aiko Velora are role placeholders
until canonical names and visual masters are approved."* Brief §20 #5 lists this as a required
approval. `docs/NOW.md` confirms the four shipped portraits are *"swappable placeholders pending the
world-bible identity lock."*

**Therefore:** `[P]` **no hero-character production may begin** until the intake in
[11_CANONICAL_REFERENCE_INTAKE.md](11_CANONICAL_REFERENCE_INTAKE.md) is satisfied for that character.

**Nothing in this package invents** facial anatomy, body architecture, species rules, wardrobe, logos
or relationships. Where the repository is silent, the intake manifest records a **gap**, not a guess.

### 3.1 Required before any character geometry

`[V]` brief §10.4 step 1–2:
1. Approved **front, side and three-quarter** canonical references.
2. **Immutable properties defined**: facial structure, body architecture, species traits, wardrobe,
   faction markings.
3. Written approval recorded (a dated note, as the Godot project did for its gates).

---

## 4. Character pipeline

`[V]` brief §10.4, adapted to Unreal. **Applies to `bengal_lt` only in the slice** ([06](06_VERTICAL_SLICE.md) §3.3).

```
1  Canonical references approved (front / side / 3-4)      ← BLOCKING, §3
2  Immutable property sheet written                        ← BLOCKING
3  Base mesh generated from multi-view references
      Local Hunyuan3D 2.1 first (zero cost, proven on the 5060 Ti)
      Paid tools only if local provably fails a specific bar
4  Retopologize in Blender — manual or semi-automatic
5  Rebuild face and hands as required
6  UV: clean unwrap, no overlaps, consistent texel density
7  PBR texture set (baseColor / normal / ORM), ≤2K for a hero
8  Skeleton: UE5 humanoid-compatible where anatomy permits;
      species extensions only where necessary
9  Skin weights + validation in Blender
10 Export FBX or glTF → Unreal import
11 Control Rig for face + body adjustment
12 Animation Blueprint + the controlled animation set
13 Identity QA under BOTH roster and cinematic lighting     ← BLOCKING, §7
14 Promote to canonical only after explicit approval
```

### 4.1 Animation set for the slice

`[V]` Brief §10.4 lists ten states. The slice needs the subset the warehouse scene actually uses:
**idle · speak · threaten · turn · gesture · sit**. Cut for the slice: walk, inspect, injured, roster
pose (`[P]` the roster is 2D portraits; Aiko is first-person).

`[V]` **"Do not attempt seven unique bespoke animation rigs during the vertical slice."** The slice
rigs **one**.

### 4.2 Hard rules

- ⛔ **No MetaHuman without a licensing review.** `[U]` MetaHuman licence terms for a commercial Steam
  release have **not been verified** in this session. Flagged as **D-02**.
- ⛔ No generated mesh ships without Blender cleanup + validation.
- ⛔ No identity change after canonical approval without re-validating every derived asset
  (`[V]` brief §9.3: portraits *"should not be independently regenerated after a 3D character is
  approved unless the identity is explicitly revalidated"*).
- ⛔ One hero rig in the slice.

---

## 5. Environment pipeline

### 5.1 Modular building kit `[V]` brief §10.2

```
1 District visual grammar sheet (the concept master)
2 Define the kit: ground frontage · middle floors · roof · corner ·
  fire stairs · vents · signs · awnings · rooftop props
3 Generate or model high-level source shapes
4 Retopologize in Blender
5 Standardize TRIM-SHEET UVs               ← the multiplier; makes 12 kits read as 40 buildings
6 Produce three LODs
7 Collision only where required
8 Export GLB/FBX
9 Validate scale, pivot, normals, materials, draw calls in Unreal
10 Façade variants through material, signage and prop combinations
```

`[V]` **12 kit modules → ~40 building instances** for the slice; the full game targets 300–500
instances from 50–60 components. The camera makes this affordable (§5.3).

`[V]` **Assets already produced and validated in Godot:** 10 kit module GLBs (8/8 through
`GLBValidator`), 4 textured hero landmarks, 5 dock props. These are **re-importable** — the source
GLBs and their licenses carry over (§10).

### 5.2 Props and vehicles `[V]` brief §10.3

AI generation is appropriate for dumpsters, barriers, kiosks, benches, containers, rooftop machinery,
faction cargo and non-hero vehicles. **Never use raw generated GLBs directly.** Each asset needs:
geometry cleanup · origin/pivot correction · real-world scale · material consolidation · UV check ·
LODs · collision policy · import test.

`[V]` No drivable vehicles (brief §12.3). Traffic is a visual proxy — in Godot a single MultiMesh with
GPU-driven flow and zero RNG; in Unreal, ISM/HISM with the same approach.

### 5.3 What the camera buys `[V]` brief §9.2

The fixed 35–45° management camera permits: simplified rear façades · reduced underside geometry ·
lower street-level texture resolution · modular roof assets · repeated window/trim systems ·
aggressive LOD transitions hidden by rain, darkness and atmospheric perspective.

**This is a production decision, not just an aesthetic one.** Changing the camera invalidates the
environment budget.

### 5.4 The embodied location — the exception

`[P]` `L_Warehouse_Embodied` is the **one space built to hero fidelity**, because it is where the
reboot's thesis is tested. Unlike the city it is seen close, in first person, under dynamic light.

Budget: ~10×8 m · real materials (wet concrete, rusted steel, worn wood) · Lumen GI + VSM · rain
through a skylight · one practical sodium lamp + bounce · 4–6 authored interaction points.
`[V]` Brief §11 allows 50–70 reusable props for the slice — a small fraction dresses this room, and
several already exist under CC-BY (crates, pallets, fishing supplies).

---

## 6. Asset validation

`[V]` The Godot `GLBValidator` gate (`tools/validation/glb_validator.gd`, `test_glb_validator`) checked
scale, pivot, normals, material count, draw calls and UVs, with per-category specs (`building`,
`kit_tile`, `prop`). It **caught a broken hero asset that a producer had claimed was shippable** — no
UVs unwrapped, and a stray default material pushing it over the 3-material cap.

`[P]` **Unreal equivalent:** `UBMAssetValidator` (Editor module) built on Unreal's Data Validation
framework, so it runs on save, on cook, and in the test suite.

| Check | Rule `[P]` (from the Godot specs) |
|---|---|
| Scale | Real-world metres; no non-uniform scale baked |
| Pivot | Base-centred for placeable geometry |
| Normals | Recalculated outward; no inverted faces |
| Materials | ≤3 per kit module; ≤4 per prop; ≤6 per hero |
| Triangles | Kit ≤5k · prop ≤3k · landmark ≤50k · hero character ≤80k |
| UVs | UV0 present, no overlap; UV2 only if lightmapped |
| LODs | ≥2 for buildings; ≥1 for props |
| Collision | Simple primitives; complex only where required |
| Textures | Power-of-two, ≤1K city, ≤2K hero |
| Naming | Prefix convention ([13](13_REPOSITORY_BOOTSTRAP.md) §5) |

**Accepted-warn set `[V]`** (non-blocking in the Godot build, carried over): UV2 absent;
draw calls ≤8; a `_col` mesh with no collision node.

### 6.1 The validation rule that matters most

`[V]` **"Green-by-claim is not green."** Re-run the validator yourself and look at the asset against
the concept master. This is the same discipline as the mechanic gates and it exists because it caught
a real failure.

---

## 7. Identity QA

`[V]` Brief §18 requires: *"Four character identities remain stable across portrait, roster and
cinematic use."*

`[P]` For the slice's one hero, a three-way check:

| Context | Lighting | Check |
|---|---|---|
| Portrait (2D) | Authored | The canonical reference |
| Roster (UI) | Flat | Recognizably the same person |
| Cinematic | Sodium lamp + Lumen bounce | Still the same person |

`[V]` **Warning from the Godot build:** *specular on a hero under Blender's hard directional light is
not what the game's environment lighting shows.* Don't chase specular in the DCC tool — the real test
is in the game scene, under the actual scene lights. The alien tower read as a metallic mirror in
Godot until the glTF `metallicFactor=1.0` + ORM issue was diagnosed; the *texture* was never the problem.

**Failing identity QA is a blocking defect**, not a polish item.

---

## 8. AI generation tooling

`[V]` Available and proven in this environment:

| Tool | Status | Use |
|---|---|---|
| **Local Hunyuan3D 2.1** (ComfyUI, port 7821) | `[V]` PROVEN 2026-07-08 — hero geometry **and** texture end-to-end, zero credit, no OOM on the 16 GB 5060 Ti | **Default** for any hero where a concept image beats box-modelling |
| **Blender + BlenderMCP** (port 9876) | `[V]` Proven; drive directly over the socket | All production cleanup |
| **Sketchfab (free, CC-BY)** | `[V]` Proven; 8 assets already used and logged | Proxy/greybox enrichment **only**, never hero identity |
| **PolyHaven (CC0)** | `[V]` HDRI in use | Environment lighting |
| Magnific / Meshy / Tripo | `[V]` Credit-metered | Only when local provably fails a specific bar |

### 8.1 The image→3D recipe `[V]` — PROVEN 2026-07-10, don't rediscover it

For an organic + hard-surface hybrid, or anything tall and thin:

1. **Root-cause first.** Single-view image→3D is strong on organic form, **weak** on hard-surface
   (flat walls, sharp edges, windows) and on tall narrow verticals — it squashes the body. Naming the
   failure beats re-rolling the same job.
2. **Fix proportion in 2D before 3D.** Re-interpret the concept into a proportion-correct image first.
3. **Kill the shadow.** The #1 cause of "relief/slab" output is a ground/drop shadow surviving the
   cutout — the tool reads grey as volume. Prompt on **pure solid white, floating, no cast shadow**,
   so a white-threshold alpha cuts cleanly.
4. **Always feed a transparent cutout, never flat RGB.** Flat RGB produced a bas-relief with a flatness
   ratio of 0.11; rembg cutout took it to 0.588.
5. **Single clean view beats native multi-view** for shape. (Multi-view nodes are for *texturing*.)
6. **Decimate UV-aware**, preserve silhouette over triangle count, recalc normals, base-centre the
   pivot, convex collider, and **re-import to verify**.

### 8.2 The glTF metallic trap `[V]`

Hunyuan's glTF ships `metallicFactor = 1.0` plus an ORM map, producing a metallic mirror that HDRI
lighting blows out to white. Godot needed a code-side fix that stripped metallic while preserving
baked emission. `[P]` In Unreal, fix it **at import** via a material instance / import rule — and
**emission belongs in the asset** (authored in Blender), not injected in code.

---

## 9. What is NOT allowed

`[V]` Brief §12.3 + locked decisions:
- ⛔ **Runtime** AI generation of any kind — image, mesh, video, or LLM calls (Locked #13).
- ⛔ Raw generated GLBs used directly.
- ⛔ Final art before Gate A.
- ⛔ More than one hero rig in the slice.
- ⛔ Third-party series imagery in any mood board, store asset or trailer (IP boundary, brief §2).

---

## 10. Licensing and attribution

`[V]` The existing ledger `assets/ATTRIBUTIONS.md` is real, maintained and correct. It **migrates**
into the new repository — it is not restarted.

**Policy (unchanged):** Black Meridian ships commercially on Steam, therefore **CC0 and CC-BY only**.
**CC-BY-NC (NonCommercial) and CC-BY-SA (ShareAlike) are forbidden** — an NC asset in a commercial
build is a legal liability.

**Currently logged `[V]`:** 8 Sketchfab models under CC BY 4.0 (Old Warehouse / AlanTinka ·
Old Industrial Building / gazdahrco · Dock House Pier / voyoo · Industry Crane / ribot02 ·
Rope with Bollards / Axius · Fishing Supplies / FrodoUndead · Night market stall / alen60303 ·
Pallet Pack / caboose3d), plus a PolyHaven CC0 HDRI.

**Required in the Unreal build `[P]`:**
1. Every CC-BY credit line reproduced **verbatim** in the in-game credits.
2. `Test_Asset_LicenseLedgerComplete` — every imported third-party asset has a ledger entry.
3. Licence recorded **at import time**, not retroactively.
4. `[V]` Brief §18 Commercial acceptance: *"All generated and purchased asset licenses are recorded."*

### 10.1 AI-generated asset provenance `[P]`

Record for each: tool + version, the input concept, the date, and cleanup performed. Locally generated
assets (Hunyuan3D) carry no third-party licence but **do** need provenance, both for the IP review
(brief §2) and so a future identity revalidation can retrace the source.

---

## 11. Subscription discipline

`[V]` Brief §16 + the standing doctrine. Total targeted external spend for a six-month slice was
**$55–90**. The reboot does not change the economics of asset generation.

- **Local first, always.** Hunyuan3D + Blender cover hero geometry and texture at zero cost — proven.
- **Marble Pro** (~$35/mo) was scoped for splat worlds. `[P]` **Splats are CUT**, so this is **$0**
  unless D-07 reverses it.
- **Meshy Pro** (~$20/mo) — one burst month, only if the local pipeline fails a specific bar on the
  hero character.
- **Tripo** — $0; never pay Meshy and Tripo simultaneously.
- **Magnific MCP** — ⚠️ `[V]` every MCP generation **burns credits**; the unlimited tier applies only in
  the web UI. Use MCP for automation and QA, never for cheap generation.

`[P]` **Reboot estimate: $0–20.** One hero character is the only likely spend, and the local pipeline
may well cover it.

---

**Next:** [10_RISK_REGISTER.md](10_RISK_REGISTER.md)
