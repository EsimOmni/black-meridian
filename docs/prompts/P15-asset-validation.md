# P15 — GLB import-validation tooling + asset standard

**Month:** 3 · **Brief:** §10.2–§10.4 (validation steps), §13.4 (/tools)

## Gate dependency & ordering

Month-2 gate PASSED (`P11-month2-gate.md`) — asset production is authorized. **This slice runs BEFORE
P12b (the modular building kit).** Reason: a kit asset can only be called "validated" once a tool exists
to measure it. P15 builds that gate; P12b's assets then pass through it. P15 is pure plumbing — it is
NOT coupled to the Glass Wharf master (`P12a-concept-master.md`); it is tested against code-built
fixtures, so it does not wait on any concept approval.

## Why

Every generated/purchased asset passes the same gauntlet before entering the game (brief §10.3: "Do not
use raw generated GLBs directly"). A repeatable tool IS the Month-3 gate: *repeatable delivery without
reinventing the pipeline each asset.*

## Architecture — mirror the EconomyMath pattern

- `tools/validation/glb_validator.gd` — `class_name GLBValidator extends RefCounted`, **pure static
  methods**, no autoload, no scene deps. This is the same discipline as `EconomyMath` (split out
  precisely so it is headless-testable; an autoload referenced via preload resolves to the singleton and
  static calls fail). Everything testable lives here.
- The validator takes an **already-loaded scene root `Node3D`** (not a path) as its core input, so tests
  can feed it a code-built scene with zero file I/O. A thin `validate_file(path) -> Dictionary` wrapper
  does the GLTFDocument load and delegates to the pure core.

## Confirmed Godot 4.7 API (use these exact names — verified, do not invent)

Runtime GLB load (headless-safe, bypasses the editor `.import` pipeline — this is the point):
```gdscript
var doc := GLTFDocument.new()
var state := GLTFState.new()
var err := doc.append_from_file(abs_path, state)   # returns Error int, OK == 0
var root := doc.generate_scene(state)              # returns a detached Node3D; walk it directly
```
Walk `root` recursively via `get_children()`, test `node is MeshInstance3D`, guard `mi.mesh != null`.

Per `MeshInstance3D.mesh` (an `ArrayMesh`, but use the `Mesh` base API):
- surfaces / draw-call proxy: `mesh.get_surface_count() -> int` (one glTF surface = one draw call)
- local bounds: `mesh.get_aabb() -> AABB` → `.position`, `.size`, `.get_center()`
- world bounds (if needed): `mi.global_transform * mi.get_aabb()`
- surface arrays: `mesh.surface_get_arrays(i) -> Array`, indexed by **`Mesh.ARRAY_*`** constants
  (canonical names, NOT `ArrayMesh.*`): `Mesh.ARRAY_VERTEX` (Packed**Vector3**Array),
  `Mesh.ARRAY_NORMAL`, `Mesh.ARRAY_TEX_UV`, `Mesh.ARRAY_INDEX` (Packed**Int32**Array).
- presence test: slot `!= null and not slot.is_empty()`.
- verts: `arrays[Mesh.ARRAY_VERTEX].size()`; tris: indexed → `ARRAY_INDEX.size()/3`, else
  `ARRAY_VERTEX.size()/3`.
- baked material (validate THIS, not the instance override): `mesh.surface_get_material(i) -> Material`.
- pivot: node origin is `mi.transform.origin` / `mi.position`; base-center in local space is
  `Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z)`.

**LOD reality (do NOT get this wrong):** there is **no** `mesh.get_lod_count()`. Runtime `GLTFDocument`
loading generates **no** importer LODs at all. So LOD validation MUST be a **convention**: count sibling
`MeshInstance3D` children whose names match `*_LOD0/_LOD1/_LOD2` (case-insensitive), OR read the real,
readable `visibility_range_begin/end` if the asset uses manual visibility-range LOD. Pick the naming
convention; document it. Never claim to read importer-generated LODs.

## Scope

### 1. `GLBValidator` static checks — return a structured report
`validate_scene(root: Node3D, spec: Dictionary) -> Dictionary` producing per-asset:
`{ pass: bool, checks: [ {name, level: "pass"|"warn"|"fail", detail} ] }`. Checks:

| Check | Rule | Level on violation |
|---|---|---|
| **scale** | overall AABB within meters bounds from `spec` (e.g. building 3–120 m tall); absurd (>1000 or <0.01) | **fail** |
| **pivot/origin** | base-center convention: `abs(aabb.center.x) < eps`, `abs(aabb.center.z) < eps`, `abs(aabb.position.y) < eps` | **fail** |
| **normals** | every surface has non-empty `ARRAY_NORMAL` | **fail** |
| **uv** | every surface has non-empty `ARRAY_TEX_UV` | **fail** (warn if UV2 absent) |
| **material consolidation** | distinct baked materials ≤ `spec.max_materials` | **warn** over soft, **fail** over hard cap |
| **draw calls** | total `get_surface_count()` across meshes ≤ `spec.max_surfaces` | **warn**/**fail** by cap |
| **poly budget** | total tris ≤ `spec.max_tris` | **warn**/**fail** by cap |
| **LOD** | `spec.require_lods` → count `*_LODn` nodes ≥ required | **fail** if required and missing |
| **collision policy** | collision nodes present only if `spec.collision` says so | **warn** |

`pass` is `true` iff no check is `fail`. Warns never block.

### 2. Deterministic, file-free fixtures — the proof
Because the repo has **zero GLBs** and P15 must not depend on the master or any hand-made asset, build
fixtures **in code** as `ArrayMesh` scenes:
- **`_make_clean_building()`** — a box mesh with correct meters scale, normals + UVs present, pivot at
  base-center, one material, named with a `_LOD0` child (+ a cheaper `_LOD1`). Must **pass**.
- **`_make_broken_building()`** — deliberately wrong: 500× scale, a surface with normals stripped
  (`ARRAY_NORMAL = null`), pivot at center-of-mass not base, no `_LODn`. Must produce ≥3 `fail`s.

Use `SurfaceTool` or a raw `arrays: Array` + `ArrayMesh.add_surface_from_arrays()` to construct these —
no external files. (Optional: also round-trip one through `GLTFDocument` save→`append_from_file` to prove
the `validate_file` wrapper, but the pure-core test is the gate.)

### 3. Asset standard doc
`docs/asset-standard.md`: canonical naming (`<district>_<kit>_<part>_LODn`), the `/assets/<category>/…`
layout (categories already scaffolded: characters, city, props, vehicles, splat, ui, audio), the
meters-scale + base-center-pivot + trim-sheet-UV rules, per-category `spec` budgets, and the license log
pointer (`assets/ATTRIBUTIONS.md`, per CLAUDE.md Sketchfab rules — CC0/CC-BY ok, CC-BY-NC forbidden).

### 4. Test harness
`tests/unit/test_glb_validator.tscn` + `.gd` runner (a `.tscn`, NOT `-s script.gd` — the `.tscn` runner
is the established pattern so autoloads load; this validator needs none but keep the convention). Runner
asserts clean-fixture `pass == true` and broken-fixture has the expected `fail` set; exit 0 = pass.

## Out of scope (do NOT do here)
- No actual kit geometry (that is P12b). No editor plugin UI (the static tool + runner is the gate; an
  editor button is P19 polish at most). No importer-`.import` pipeline changes. No download/fetch of any
  asset. Do not touch `src/` sim or save code.

## Verify
```sh
GODOT="D:/Godot/Godot_v4.7-stable_win64.exe"
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . tests/unit/test_glb_validator.tscn        # clean passes, broken fails: exit 0
"$GODOT" --headless --path . --quit-after 120 2>&1 | grep -iE "SCRIPT ERROR|ERROR:|Nonexistent"  # empty = clean
```
Full prior suite (9 unit + 2 integration) must stay green — P15 adds, never regresses.

## Done when
- `GLBValidator` grades the code-built clean fixture `pass` and the broken fixture `fail` (≥3 fails),
  with a per-check report.
- `docs/asset-standard.md` documents naming + layout + per-category specs + license rule.
- New test green, prior suite green, boot clean. Committed. The gate P12b will pass through now exists.
