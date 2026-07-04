# glasswharf_dock_warehouse_a — validator acceptance report

**Accepted:** 2026-07-04 · first asset through the P12b Codex-driven Blender pipeline.
Source master: `docs/prompts/notes/concept/glass_wharf_MASTER.jpg` (P12a, LOCKED).

## GLBValidator report (P15 gate) — spec `building`

```
PASS: true
  scale       pass  height 17.70 m, footprint 36.60 × 9.60 m
  pivot       pass  base-center within 0.05 m
  normals     pass  all 3 surfaces carry normals
  uv          warn  UV1 present; UV2 absent (lightmap-only, non-blocking)
  materials   pass  2 distinct baked materials (caps 3 soft / 6 hard)
  draw_calls  pass  3 surfaces (caps 4 soft / 8 hard)
  tris        pass  1606 triangles (caps 15000 soft / 30000 hard)
  lod         pass  2 *_LODn levels found (required 2)
  collision   warn  no collision node; policy advisory — collider mesh
                    (_col) is present, engine converts it via -col on import
```

LOD0 ~1258 tris, LOD1 ~336 tris, `_col` 12 tris.

## Two-eye art gate (massing fidelity to master)

Round 1: both Claude and Codex-vision → **REVISE** (stepped parapet read as flat).
Round 2 (after exaggerating the parapet to `low,low,tall,tall,low,tallest,tallest,low`):
both → **SHIP**. The distinctive stepped-parapet silhouette survives to LOD1.

## Open (carried to the texture lap, not blocking acceptance)

- **UV2 absent** — add only if this building gets baked lightmaps.
- **collider** — `_col` box mesh exists but is a plain MeshInstance3D in the GLB; when
  instanced in-game, rely on the `-col`/`-colonly` import suffix or a StaticBody wrapper
  so it becomes a real collision node. Not a geometry defect.
- **Texture/material** — grey placeholder only. Trim-sheet + noir grade is the second lap
  (charcoal concrete + oxidized metal, muted petrol trim, sparse sodium amber; no
  purple/cyan). Massing is locked; texturing builds on this accepted proxy.
