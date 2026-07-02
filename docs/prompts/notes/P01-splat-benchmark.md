# P01 — GDGS splat benchmark (the kill criterion) — DECISION: SPLAT_OK

**Date:** 2026-07-02 · **Machine:** target desktop class — RTX 5060 Ti 16GB, Ryzen 7 8700F, 64GB DDR5

## Result

| Metric | Value |
|---|---|
| Splat count | **542,246** (2× GDGS `demo.ply`, side-by-side; real 3DGS capture, 62-float standard PLY) |
| Resolution | 1920×1061 (1080p window minus title bar), vsync OFF, orbiting camera |
| Average FPS | **482.9** (5,795 frames over 12s measure window) |
| 1% low FPS | **420.0** |
| GPU | NVIDIA GeForce RTX 5060 Ti (Vulkan 1.4.325, Forward+) |
| Render errors | 0 (after the Godot 4.7 compat patch below) |

Visual proof: [P01-bench-frame.png](P01-bench-frame.png) — captured mid-measure by the bench itself.

**Decision gate (brief §14/§19):** threshold is 45–60 fps in a 2M scene, 500k "comfortably above".
Measured 483 avg / 420 low at 542k — ~8× above threshold. Even at 2M (~4× sort/raster load) the
extrapolated envelope stays >100 fps. **`SplatWorldProvider` stays the default. MESH_FALLBACK not needed**
(the `CinematicWorldProvider` abstraction + mesh fallback still gets built — as insurance, not as default).

## Plugin

- **GDGS v2.2.0** — https://github.com/ReconWorldLab/godot-gaussian-splatting
  (MIT, commit `be61f8fd28cc` 2026-04-26), vendored under `addons/gdgs/`.
- Requirements match us: Godot 4.4+, Forward+, compute shaders. Import via `.ply/.compressed.ply/.splat/.sog`
  → `GaussianResource`; scene node `GaussianSplatNode`; compositing via a `CompositorEffect` on
  `WorldEnvironment.compositor` (script `gaussian_compositor_effect.gd`).

## Local patch — Godot 4.7 push-constant strict validation (REQUIRED)

Stock v2.2.0 spams per-frame `compute pipeline requires (8|4) bytes of push constant data, supplied: (16)`
on Godot 4.7 and renders garbage (measured 16 fps from the error storm). Godot ≤4.6 tolerated 16-byte-padded
push constants; 4.7 validates the exact declared block size per shader. Patched:

1. `gaussian_rendering_device_context.gd` `create_push_constant()` — removed the pad-to-16 (exact `4*n` bytes).
2. `gaussian_renderer.gd` `_rasterize_state()` — the radix sort loop now builds a per-stage push constant
   (upsweep 8B `{pass,in_offset}`, spine 4B `{pass}`, downsweep 12B `{pass,in_offset,out_offset}`) instead
   of one padded 16B blob for all three.

Re-apply (or upstream) this patch on any GDGS update.

## Re-running the benchmark

```sh
python <scratch>/make_bench_ply.py <gdgs-src>/samples/assets/demo.ply assets/splat/bench_542k.ply  # regenerate (gitignored, 134MB)
D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . --import
D:/Godot/Godot_v4.7-stable_win64_console.exe --path . --resolution 1920x1080 res://scenes/cinematic/splat_bench.tscn
# stdout: BENCH_INFO (point count) + BENCH_RESULT (avg/1%-low fps) + saves this folder's PNG, then quits
```

`scenes/cinematic/splat_bench.gd` builds the whole scene in code (GaussianSplatNode + WorldEnvironment
compositor + orbit camera), 3s warmup, 12s measure, vsync off.

## Still open for P01 (deferred by decision of 2026-07-02)

- `CinematicWorldProvider` interface + `SplatWorldProvider`/`MeshWorldProvider` + fallback flag.
- `cinematic_test.tscn` first-person camera volume walk.
- Swap in a real Marble export when one exists (this benchmark used the doubled GDGS sample capture).
