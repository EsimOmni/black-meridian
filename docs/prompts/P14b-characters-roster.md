# P14b — Character bases + shared animation + roster screen

> **Renumbered 2026-07-10:** was `P14`, but P14 is the runtime KitAssembler (`P14-runtime-assembler.md`,
> accepted — the sim drives the kit). This character/roster slice is a distinct, not-yet-built
> deliverable → `P14b`.

**Month:** 3 · **Brief:** §9.3 (portraits/roster), §10.4 (character pipeline), §4 (vertical-slice roster)

## Why

Hero characters are identity-sensitive assets. The vertical slice needs **4** hero-grade characters only:
Aiko, the Regent, the Bengal lieutenant, the Raven rival (brief §4). The other three appear as portraits/
references only — do NOT make full models for them yet.

## Gate dependency

Requires the **canonical character names + visual masters approved** (brief §20 #5). Lock the world bible
identities before producing hero meshes. (Until then these stay role placeholders.)

## Scope

1. **Aiko canonical references**: approve front / side / 3-quarter; define immutable facial/body/wardrobe/
   species properties (brief §10.4).
2. **4 character base models**: generate base mesh from multi-view refs → retopo → rebuild face/hands →
   shared humanoid skeleton (species extensions only where needed). Generated mesh is INPUT to Blender
   reconstruction, never a final asset (brief §10.4 restriction).
3. **Shared animation set** (one rig, NOT 7 bespoke rigs — brief §10.4): idle, inspect, speak, threaten,
   sit, walk, turn, gesture, injured, roster pose.
4. **2D portraits** derived from approved 3D renders; don't regenerate after a 3D char is approved unless
   identity is explicitly revalidated (brief §9.3).
5. **Roster screen**: per principal — 3D turntable, idle anim, close portrait, faction background,
   relationship graph, current status, injury/wardrobe variants where needed (brief §9.3).

## Asset route

Meshy Pro (one burst month) for character bases + animation transfer to Godot; Blender for identity
repair + retopo; Photoshop for portrait/texture repair (brief §16). Validate facial identity under both
roster AND cinematic lighting before promoting to canonical.

## Verify

- 4 hero models import into Godot, share the skeleton, play the animation set without skeleton errors.
- Roster screen shows all 4 with stable identity across portrait + 3D + (later) cinematic use.
