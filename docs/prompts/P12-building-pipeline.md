# P12 — Glass Wharf art-direction master + modular building pipeline

**Month:** 3 · **Brief:** §9.1–§9.2 (visual thesis + camera), §10.2 (building pipeline)

## Gate dependency

Do NOT start this until the **Month 2 gate (P11) has passed** — the cube build must be proven fun first.

## Why

The city is a premium diorama under a near-ortho camera. The top-down angle lets us fake detail cheaply
(brief §9.2). We build a **modular kit**, not hundreds of unique buildings: 300–500 instances from ~12
kits (brief §10.2).

## Scope

1. **Art-direction master** for Glass Wharf: rain-lacquered interspecies noir — charcoal, petrol blue,
   oxidized metal, sodium amber, selective faction color. **Avoid generic purple cyberpunk** (brief §9.1).
2. **Modular building kit** (brief §10.2): ground-floor frontage, middle floors, roof modules, corner
   modules, fire stairs, vents, signs, awnings, rooftop props.
3. **Pipeline** (the repeatable path — this is the real deliverable): generate/model source shapes →
   retopo in Blender → trim-sheet UVs → 3 LODs → collision only where required → export GLB → validate
   scale/pivot/normals/materials/draw-calls in Godot → façade variants via material/signage/prop combos.
4. Camera permissions exploited: simplified rear façades, reduced underside geometry, lower street-level
   texture res, aggressive LODs hidden by rain/darkness/atmosphere (brief §9.2).

## Asset route (brief §10.1, §16)

HYBRID. Local Hunyuan3D/TripoSR for proxies; Meshy Pro (one burst month) for hero props; Blender for
**every** production mesh. Generated geometry is **provisional** until Blender cleanup + Godot validation.

## Verify

- One cleaned modular building component imports into Godot at correct scale/pivot, 3 LODs, passes the
  validation tool (P15).
- A test block of ~40 instances renders at the working FPS target under the management camera.
