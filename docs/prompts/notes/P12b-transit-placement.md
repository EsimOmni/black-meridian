# P12b hero #3 — Transit spine: ACCEPTED (skyline landmark) — Glass Wharf SEALED

**Accepted:** 2026-07-06 · the third and final Glass Wharf hero — an elevated lattice rail bridge
with a train, built through the same direct-socket Blender pipeline, placed as the district's
transit landmark out on the water. Gated by the control tower (GLBValidator re-run + own-eye massing
+ own-eye placement vs the master), not trusted from the producer's claim. Source: `glass_wharf_MASTER.jpg`.

## What shipped

`assets/city/glasswharf_dock/transit_spine.glb` — a horizontal hero: a rusted-steel truss bridge on
piers over the water, with real cross-braced (X) truss sides, catenary poles + cross-arms + contact
wire, twin rails, and a three-car metro train mid-crossing. The master's raised rail spine. IP-safe
original geometry.

Placement: `Vector3(10, 0, -40)`, rotation_y −0.85 — deep on the open water between the venue row and
the right-rear tower, angled as a diagonal crossing toward the tower. Trim weathering applies (rusted
steel takes the cold stain directly; patina 0).

## GLBValidator ('building' gate) — re-run by the control tower

| Check | Result |
|---|---|
| PASS | **true** (first try — the institution's 4-fail lesson was baked into the build) |
| scale | 12.88 m tall, 44.22 × 5.40 m footprint (long horizontal spine) |
| pivot | base-center within 0.05 m |
| materials | 3 (rusted steel / dark pier / train shell) |
| tris | 996 (LOD0 + LOD1 + collider) |
| lod | LOD0 + LOD1 present |
| uv / draw_calls / collision | three warns, all non-blocking, identical to the other two heroes |

## Two-eye massing gate — SHIP (1 revise)

- **Round 1:** the truss diagonals were axis-aligned box approximations (`add_beam` collapsed them to
  thin horizontal bars) → no cross-brace, read as a plain viaduct, missing the bridge's identity. REVISE.
- **Round 2:** rewrote `add_beam` to build TRUE oriented beams (unit box rotated to align p0→p1) → real
  X cross-bracing; thickened catenary poles + fuller train. Front render (own eye): the lattice rail
  bridge + train reads as the master's spine. SHIP. (Train body still a touch boxy vs a round metro —
  silhouette carries, deferred like the tower's soft facets.)

## Two-eye placement gate — PASS (1 reframe)

- **Round 1:** at (6,0,−22)/−0.5 the spine sat buried right behind the venue row, the deck crossing at
  the boxes' own height — read as tangled with the row, not a bridge on the water. REVISE.
- **Round 2:** pushed deep to (10,0,−40)/−0.85 — out on the OPEN water, clear of the row, a steeper
  diagonal reaching toward the tower. Own-eye re-capture: the bridge + train read as a distinct span on
  the water, the three landmarks compose like the master (institution left / spine centre-right / tower
  right-rear). PASS. (Minor: the spine's far end nears the tower base — the master's bridge reaches the
  tower zone too; silhouette carries, not forced further to protect the row/tower gap.)

## Glass Wharf — SEALED

This closes the district's skyline. The full P12b arc, all control-tower gated (own-eye, every claim
re-run, never trusted):
- **3 bespoke hero landmarks** — alien diplomatic tower, carved-stone institution, transit spine.
- **Noir atmosphere pass** — ACES + glow + sodium key/shadows + cold rim/fill + wet ground; lifts every
  landmark out of silhouette while keeping the brief-§9.2 top-down management read clean.
- **Trim texture lap** — triplanar weathering (rain-run streaks, grain, wet water-line) on the stone/steel.
- **Verdigris pass** — light-teal patina for the tower's dark charcoal where the cold stain was invisible.

The concept→model→validate→place→light→weather pipeline is proven end-to-end on one district. Per the
brief's discipline (mechanic first, assets don't run away), the polish stops here — the next district
reuses this exact pipeline, and the immediate priority returns to mechanics (P10b hidden motives, P07b
rival actions, the splat scene), not more Glass Wharf cosmetics.

## Deferred (a later pass, NOT blocking)

Train body rounding + a district atmosphere shader (water/fog) + the tower's soft facets — all cosmetic
refinements, correctly below the mechanic work in priority.
