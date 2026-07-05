# P12b — Glass Wharf kit architecture: HYBRID (decided from the master, two-eye gated)

**Decided:** 2026-07-05 · from the LOCKED master `docs/prompts/notes/concept/glass_wharf_MASTER.jpg`
(P12a) vs the current in-engine kit render. Two-eye gate: Codex-vision + Claude (control tower) both
read the master and agreed. **Month:** 3 · **Brief:** §9.1 (visual thesis) + §1 (city shows the state).

## The question this settled

`warehouse_a.glb` (the first asset through the P12b pipeline) is a **monolithic full-building** mesh,
but `KitAssembler` (P14) stacks small **band modules** (ground + N mids + cap) at runtime so a
building's height reads its district influence (brief §1). The two philosophies conflicted. Reading
the master resolves it: **neither alone — hybrid.**

## What the master shows (a diorama with a hierarchy, not a row of buildings)

- **Hero landmarks — bespoke monolithic, CANNOT be band-stacked:** the alien diplomatic tower
  (oxidized-copper dome, non-human geometry, the frame's focal point) and the carved-stone
  neo-classical institution (columned, ornamented). Their silhouette IS the identity; a generic band
  can never produce these shapes.
- **Neo-deco tower — band-stackable with care:** the central petrol-blue/oxidized tower reads as
  stepped setbacks — exactly what `warehouse_a` proved band modules can do (its stepped-parapet
  silhouette survived to LOD1 and passed the art gate).
- **Transit spine — bespoke kit pieces:** elevated rail + train + lattice bridge. Purpose-built
  modules, not building bands.
- **Background density — generic bands suffice:** the fogged black blocks behind. The existing grey
  kit is already enough here; atmosphere swallows the detail.
- **Ground / water / fog / light — a shader + lighting pass, not geometry:** wet reflective asphalt,
  sodium-amber lamps, wharf water, polluted fog.

## Architecture decision

| Layer | Path | Producer |
|---|---|---|
| Hero landmarks (alien tower, stone institution) | bespoke monolithic mesh | Codex-Blender / Magnific image→3D (hero, credit-gated) |
| Neo-deco tower | band modules (careful setbacks) | Codex-Blender — the `warehouse_a` pattern |
| Transit spine (rail + bridge + train) | bespoke kit pieces | Codex-Blender |
| Background towers | generic bands (current kit) | ✅ already exists |
| Ground / water / fog / light | shader + lighting pass | Godot side (control tower / Fable) |

`KitAssembler` stays for the band-stacked buildings (the state-showing mechanic is intact); hero
landmarks are placed as whole meshes keyed to specific venues (the alien diplomatic structure = the
political/intelligence venue, the stone institution = a civic venue) — they don't grow with influence,
they anchor the skyline.

## Priority (two-eye agreed, control-tower refined)

Codex ranked the gaps: (1) missing landmark structures, (2) massing/proportion, (3) lighting/atmosphere,
(4) texture/material — and flagged that texturing the current bands first would "polish the wrong
shapes." Concur. **But** `warehouse_a` already proved the band-tower pipeline works, so the highest-
leverage FIRST step is the single most identity-defining hero: **the alien diplomatic tower.** It is
the frame's focal point, the most "this is no other game" silhouette (IP-safe original geometry), and
building it proves the bespoke-monolithic arm of the pipeline while delivering the biggest "it looks
like the master" jump. Stone institution second, transit spine third, then the noir texture lap across
everything.

## Production order (P12b execution queue)

1. **Alien diplomatic tower** — bespoke hero, Codex-Blender against the master. Two-eye massing gate →
   GLBValidator → placed on the political/intelligence venue.
2. **Carved-stone institution** — bespoke hero, same pipeline.
3. **Transit spine** — rail + lattice bridge + train car kit pieces.
4. **Neo-deco tower band refinement** — extend the `warehouse_a` band pattern to the tower family.
5. **Noir texture lap** — trim-sheet + charcoal/petrol/oxidized-metal/sodium grade across all shipped
   massing (only after shapes are locked — texturing wrong shapes is wasted work).
6. **Ground/water/fog/light shader pass** — the diorama atmosphere (Godot side).

Each hero asset: AI ~90% (Codex-Blender first pass) / human ~10% (Cem's taste + cleanup) → two-eye
massing gate → GLBValidator (P15) → Godot placement test. No GLB ships without the gate.

## Standing constraints (unchanged)

Proxy-first still governed the mechanic gate (now passed). Sketchfab license-check every download
(CC-BY-NC forbidden — commercial Steam). Magnific image→3D always charges credits (unlimited N/A) —
surface cost + get a yes before any paid generate. IP §2: the alien/stone/deco shapes are original
expression, no third-party series geometry.
