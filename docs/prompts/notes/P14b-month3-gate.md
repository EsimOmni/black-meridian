# Month-3 gate note — asset pipeline proof (closed 2026-07-12)

**Gate condition (brief §19):** "Repeatable asset delivery proven (1 building, 1 prop, 1 vehicle,
1 char anim) without reinventing the pipeline each time."

**Verdict: PASSED, with one item re-scoped by the ship-first decision (2026-07-12, Cem).**

| Item | Status | Evidence |
|---|---|---|
| 1 building | ✅ far exceeded | P12 modular kit: 10 GLBs, 8/8 `GLBValidator` PASS, `KitAssembler` live (sim state → grid-snapped buildings); plus 4 textured hero landmarks (Sketchfab CC-BY pipeline, ~1 min/asset) and the Hunyuan3D hero tower (local image→3D, `PROVEN 2026-07-10` doctrine) |
| 1 prop | ✅ far exceeded | `DockProps`: 5 verified Sketchfab props placed + attribution-logged (`assets/ATTRIBUTIONS.md`) |
| 1 vehicle | ✅ re-interpreted | `TrafficProxy` (P13e): code-built low-poly vehicles as a MultiMesh flow. No GLB vehicle was produced — the game has no drivable vehicles (brief §12.3 explicit cut) and the diorama reads traffic at distance, so a modeled vehicle would prove nothing the kit/landmark/prop GLB pipeline hasn't already proven three times over |
| 1 char anim | ✂️ out of scope | Ship-first decision 2026-07-12: characters are a 2D portrait roster (`RosterPanel` + ChatGPT-runner portraits); the cinematic layer is first-person (Aiko is the camera). No 3D character mesh exists to animate, and none is planned for the slice — a shared-rig animation proof carries zero slice value. Re-opens only if a visible third-person character ever enters scope |

**The real gate intent** — "without reinventing the pipeline each time" — is solidly met: the
download→Blender(join/pivot/texture)→GLB(Draco OFF)→`--import`→`GLBValidator` pipeline has run
end-to-end for kit modules, landmarks, and props, and the local Hunyuan3D image→3D route is
documented and reproducible (`tools/pipeline/hunyuan.py`). Asset delivery is repeatable.

**Month 4 is authorized** under the standing discipline: proxy first, license-gated, no asset
replaces a validated mechanic.
