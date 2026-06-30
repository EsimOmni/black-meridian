# P01 — GDGS splat technical spike + mesh fallback (the kill criterion)

**Month:** 1 · **Risk:** HIGHEST · **Brief:** §14, §7.7, §19 (Month 1 kill criterion)

## Why this is first

Godot has no built-in Gaussian-splat support. The whole cinematic layer depends on the community
**GDGS** plugin actually rendering a Marble splat at acceptable performance. The brief is explicit:
**if 500k splats can't run on the target desktop, switch to the mesh provider immediately — do not
postpone.** Resolving this now prevents months of work on a dead technique.

## Scope

1. Add the **GDGS** plugin under `addons/gdgs/` (Godot 4.4+, Forward+, PLY-family). Document the exact
   version + source in `docs/prompts/notes/`.
2. Get **one** Marble-exported splat into a test scene. If no Marble world exists yet, use any public
   sample PLY/SPZ to prove the renderer; swap in a real Marble export when available.
3. Build the **`CinematicWorldProvider`** abstraction in `src/presentation/`:
   ```
   CinematicWorldProvider (interface)
     ├── SplatWorldProvider   (loads PLY via GDGS)
     └── MeshWorldProvider    (loads Marble high-quality GLB + collider GLB)
   ```
   A scene asks the provider for a world; the rest of the cinematic code never knows which backend rendered it.
4. A `scenes/cinematic/cinematic_test.tscn` that loads a splat through `SplatWorldProvider`, drops a
   simple first-person camera inside a validated camera volume, and shows an on-screen FPS readout.
5. Wire the **fallback switch**: a single flag / setting that routes to `MeshWorldProvider`.

## Coordinate + visual rules (brief §14.2, §7.7)

- Export Marble assets in **OpenGL** coordinates; standardize scale + origin in Blender before Godot.
  If the splat imports upside-down, apply the documented OpenCV→OpenGL Y/Z flip.
- Splats carry **baked illumination** — dynamic lights illuminate characters/props, not the environment.
- Only **one** splat environment resident at a time. Expose 500k / 2M as a performance setting.

## Acceptance / kill criterion

- A 500k-splat scene renders and is navigable on the target desktop class (RTX-5060-Ti-class).
- Record measured FPS at 1080p in `docs/prompts/notes/P01-splat-benchmark.md`.
- **Decision gate:** if 500k can't hold the brief's threshold (45–60 fps in a 2M scene; 500k must be
  comfortably above), flip the default to `MeshWorldProvider` and note it. Either outcome PASSES this
  slice — the deliverable is *a decision backed by a measurement*, not splats-at-all-costs.

## Verify

- Headless import clean.
- `cinematic_test.tscn` opens in editor and runs (F5) without script errors.
- Benchmark note committed with real numbers + the provider decision.
