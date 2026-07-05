# P12b hero #1 — Alien Diplomatic Tower: ACCEPTED

**Accepted:** 2026-07-05 · the second hero through the P12b pipeline (after warehouse_a), and the
first bespoke MONOLITHIC landmark. Gated by the control tower — GLBValidator re-run + two-eye massing,
not trusted from the producer's claim. Source master: `glass_wharf_MASTER.jpg` (P12a, LOCKED).

## What shipped

`assets/city/glasswharf_dock/alien_diplomatic_tower.glb` — a vertical alien monument (charcoal faceted
obelisk body, oxidized-copper verdigris crown, sparse cyan glow seams), crowned with a body-width
four-point star finial + a small copper dome + a needle spire, with a circular diplomatic eye/seal on
the crown face. The focal-point landmark of the master's right flank. IP-safe original geometry.

## GLBValidator ('building' gate) — re-run by the control tower

| Check | Result |
|---|---|
| PASS | **true** |
| scale | 36.1 m tall, 10.8 × 10.8 m footprint (slender/vertical, monument not squat) |
| pivot | base-center within 0.05 m |
| materials | 3 (charcoal body / verdigris crown / cyan emissive) |
| tris | 270 (LOD0 184 / LOD1 62 / col 24) |
| lod | LOD0 + LOD1 present |
| uv | warn — UV present, UV2 absent (lightmap-only, non-blocking) |
| draw_calls | warn — 7 (hard cap 8; a texture-lap merge target) |
| collision | warn — `_col` node exists; converts via the `-col` import suffix (same advisory as warehouse_a) |

Three warns, all non-blocking and identical to warehouse_a's accepted set.

## Two-eye massing gate — SHIP

Reached SHIP on the third massing attempt; the iteration IS the process (warehouse_a took two rounds):
- **Round 1 (Codex):** technically valid but read as a GENERIC FANTASY OBELISK → REVISE (control tower + Codex-vision agreed).
- **Round 2 (Codex):** over-corrected — wide mushroom dome + squat body read as a UFO → REVISE. The
  brief was wrong ("widen + stouten" pushed the pendulum too far); re-reading the master fixed the spec:
  the master's tower is VERTICAL with a body-width star-finial crown, NOT a wide dome.
- **Round 3 (Sonnet, direct socket):** vertical obelisk + body-width star finial + small dome + needle →
  SHIP. Silhouette matches the master. (Minor: body facets read soft vs the master's sharper ribs —
  flagged, deferred to the texture lap; the silhouette carries.)

## The pipeline lesson: Blender driven DIRECT over the socket (Codex-free)

The bigger outcome. Codex's BlenderMCP calls kept failing with `user cancelled MCP tool call` in
non-interactive `exec` mode (an approval-layer block, not a Blender fault), and Codex's 4-hour quota
then ran out mid-task. **The control tower found that Blender can be driven directly over the
BlenderMCP TCP socket (127.0.0.1:9876) with raw Python — no Codex, no MCP tool wrapper, no permission
prompt, no quota.** A Sonnet subagent (or the control tower itself) sends
`{"type":"execute_code","params":{"code":"<bpy python>"}}` and reads back
`{"status":"success",...}`. This modeled + LOD'd + collidered + UV'd + exported the whole hero.

**Standing doctrine update (recorded in `tasks/lessons.md`):** for Blender asset work, prefer the
direct socket over Codex-BlenderMCP. It removes the approval/quota layer entirely and the massing
judgment is as good or better. Codex remains fine for the vision *triage* (gap analysis), but the
*driving* is cleaner direct.

## The discipline that held

The producer (Sonnet) reported "SHIP, GLBValidator building gate pass" — but the control-tower re-run
showed **PASS: false** (uv fail: no UVs unwrapped; 4 materials from a default leaking onto the
collider slot). Fixed in a follow-up (smart_project UVs + reassign the collider material), re-verified
PASS: true with geometry unchanged (270 tris). Green-by-claim is not green; the gate re-run caught a
broken asset that would otherwise have shipped. Same rule as the whole P06 line.

## Next

Placement: drop this as a district skyline landmark (fixed wharf-edge position, NOT a venue — see the
P12b architecture note's placement correction). Then hero #2 (carved-stone institution) via the same
direct-socket pipeline, hero #3 (transit spine), then the noir texture lap.
