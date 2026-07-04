# P12a — Glass Wharf art-direction master: APPROVED

**Month:** 3 · **Brief:** §9.1 (visual thesis) + §9.2 (management camera) · Recorded 2026-07-04.

The concept→asset-split doctrine (`tasks/lessons.md`, CLAUDE.md §"AI asset pipeline"): approve a full
master keyframe for a location FIRST, then generate individual assets to match it. This note is that
approval. **P12b (modular building pipeline) builds against this frame — not against a blank brief.**

## Approved master

`docs/prompts/notes/concept/glass_wharf_MASTER.jpg` (1920², Magnific/Seedream-4).

A rain-lacquered interspecies-noir harbor block read as a **premium architectural diorama** under the
near-ortho management camera. It carries the full §9.1 inventory: neo-deco waterfront tower, elevated
transit rail + train, one alien diplomatic structure (non-human geometry), an old carved-stone
institution, wet black asphalt with reflections, wharf water, polluted atmospheric fog.

## Why this frame passed (two-eye gate)

The art bible has one hard rule (§9.1): restrained **charcoal / petrol-blue / oxidized-metal / sodium-
amber**, and **generic purple cyberpunk is explicitly forbidden**. The palette anchor is the code
`Palette` (`src/core/palette.gd`) — CHARCOAL #14161a, PETROL #2e4b58, OXIDIZED #6f695a, SODIUM_AMBER
#e5a54e — so concept and code speak the same color language.

The frame was judged by two independent eyes (Claude + Codex-vision delegate), both applying the same
strict rule:

| Criterion | Verdict |
|---|---|
| Purple / magenta present? | **None** — the forbidden color is absent |
| Blue accents | **Muted petrol / oxidized-patina**, reads as weathered painted steel — NOT neon-cyan |
| Sodium amber | Sparse, the only warm accent (street lamps + low windows) |
| Near-ortho diorama camera (§9.2, ~40° down, ~60mm) | **Correct** — miniature read, no street-level eye |
| §9.1 inventory | All present in one frame |

**The signal that makes this trustworthy:** the same two eyes *rejected* the first pass (`v1`, deleted)
for a purple violation + cyan drift. The prompt was hardened (explicit negative-prompt ban on
purple/magenta/neon-cyan; petrol pinned as "muted, low-saturation, matte weathered steel"), the second
pass cleared both, and the same strict graders flipped to keep. A gate that only ever says "yes" proves
nothing; this one demonstrated it can say "no."

## One watch-item carried into P12b (not blocking)

The alien diplomatic structure (upper-right) reads slightly too bright/metallic against the dark
surround. When that hero structure gets its own asset in P12b, tone it down into the charcoal so it
doesn't pop out of the diorama. Keep all future blue accents this muted — do not let them creep toward cyan.

## Cost

~100 credits, 2 passes (Magnific MCP; unlimited does not apply to MCP calls — every gen bills the pool).
Negligible against the 43K pool. Low-volume hero keyframe — the one place MCP credit spend is justified.

## Green light

Master **LOCKED**. P12b (modular building kit + Blender→Godot pipeline + P15 validation) proceeds against
this frame. No GLB replaces a validated mechanic; generated geometry stays provisional until Blender
cleanup + Godot validation; AI ~90 / human ~10.
