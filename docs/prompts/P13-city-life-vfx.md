# P13 — Rain/wet-surface VFX + traffic + crowd proxy

**Month:** 3 · **Brief:** §6 pillar 2 (the city shows the state), §15 (performance — crowd illusion)

## Why

The city must read as alive and reflect district state — without simulating a city (brief §1, pillar 2).
This is the "premium diorama" illusion, built cheaply.

## Scope

1. **Rain + wet surfaces**: rain particles, wet-asphalt reflections of faction-controlled signage,
   steam, road reflections (brief §12.1 VFX package).
2. **Traffic**: **spline traffic**, NOT vehicle physics (brief §15). Pooled, distance-based update rates.
3. **Crowds — illusion not simulation** (brief §15): 20–40 near pedestrians with simple navigation +
   100–200 distant MultiMesh crowd instances + looping crosswalk/platform groups + audio beds to imply
   population beyond the rendered area. Spawn density driven by district state.
4. **State manifestation** (pillar 2): when a district changes, legitimate traffic ↑/↓, police presence
   changes, neon/business activity changes, rival colors appear, crowds occupy/avoid streets, venue types
   open/close. The city IS the strategic dashboard.

## Performance rules (brief §15)

MultiMesh for repeated props/crowds; occlusion culling; fixed camera bands; material consolidation;
district streaming ONLY if profiling proves it necessary. Target 60 fps in city view at 1080p.

## Verify

- A district state change (e.g. losing a venue to the rival) visibly changes the proxy city.
- City view holds the FPS target with traffic + crowds active.
