# P04b — Resolution feel-fix: let suppression dimensions read negative

**Month:** 1 (gate follow-up) · **Brief:** §6 pillar 1 (violence has consequences),
§7.5 (multi-dimensional resolution), §7.6 (telegraphed, deterministic — no hidden rolls)

## Why this exists (measured, not guessed)

During the P04 gate session, a played job (Scout → Quiet re-route → cover-up) resolved to
only `objective_achieved: +0.70` and `new_leverage: +0.10` on the RESOLVED panel. The
player's actual skill — suppressing evidence, protecting operatives — was **invisible**.

A headless probe of `JobResolution.resolve()` across every cover-up path proved the cause:

```
evidence_generated   raw=-0.30 … -0.50   clamped=+0.00   <-- CLAMPED AWAY  (every path)
operative_injury     raw=-0.20           clamped=+0.00   <-- CLAMPED AWAY  (with Post lookouts)
```

`_clamp()` floors every dimension except `relationship_change` to `0.0`. But the authored
data (`placeholder_jobs.gd`) feeds these two dimensions **negative** on purpose:
- `evidence_generated`: Scout −0.1, cover-ups −0.3/−0.4/−0.5 → a clean job should read
  net-negative ("I left no trace"). Clamp erases it. The dimension is effectively **dead** —
  no authored path produces a visible non-zero value, and P06's heat coupling will read 0.
- `operative_injury`: Post lookouts −0.2 → "I protected my people" has zero visible effect.

The clamp isn't the design bug; the design bug is that these are **net axes** (production −
suppression) but the clamp only allows one side. The whole point of a cover-up is to drive
evidence *down*.

## Scope — minimal, do not redesign the model

This is the Month-1 gate fix. The deeper "split production vs suppression into two axes"
work belongs to **P06** (heat/evidence consequence system) — note it there, do NOT do it here.

Here, only widen the clamp for the dimensions the authored data already drives negative:

1. In `src/jobs/job_resolution.gd`:
   - Move `evidence_generated` and `operative_injury` into the `-1..1` clamp branch
     (same branch as `relationship_change`), OR generalize `_clamp` to clamp `-1..1` for a
     small named set of "net" dimensions and `0..1` for the rest. Pick whichever reads
     cleaner; a `SIGNED_DIMENSIONS` set is fine.
   - Update the DIMENSIONS doc comments: `evidence_generated` and `operative_injury` are now
     `-1..1` where **negative = suppressed / mitigated** (net trace, net harm to your people).

2. In `scenes/ui/job_panel.gd._render_resolved()`:
   - It already prints any dimension with `absf(v) > 0.001`, so negative values will now show.
   - Improve the label so negatives read as intent, not error. Suggested: for
     `evidence_generated < 0` show it as e.g. `evidence suppressed: 0.30` (drop the sign,
     use a suppression verb); for `> 0` keep `evidence generated: +0.30`. Same treatment for
     `operative_injury` (`operatives protected` vs `operative injury`). Keep it terse —
     greybox UI, real theme is P11/P19. Don't over-engineer; a small `_dimension_label(dim, v)`
     helper is acceptable since it's used per-line.

## Do NOT

- Do NOT touch the authored effect numbers in `placeholder_jobs.gd` — the data is correct;
  only the clamp + display were wrong.
- Do NOT split evidence into two axes now (that's P06).
- Do NOT add heat/evidence consequence wiring (P06). Negative evidence just needs to be
  *visible and stored* correctly; nothing consumes it yet.
- Do NOT change `relationship_change` (already correct).

## Verify (headless is truth)

Add/extend a unit test under `tests/unit/` for `JobResolution.resolve()`:
- Assert a Quiet + Scout + Paper-it-over path yields `evidence_generated < 0` (e.g. ≈ −0.30),
  NOT 0.0 — this is the exact regression the probe caught.
- Assert Post-lookouts drives `operative_injury` negative and it survives the clamp.
- Assert `relationship_change` still clamps to `[-1, 1]` (Blame-a-dockhand path).
- Assert nothing pushes any dimension past ±1.0.

Then the standard chain:
```
GODOT="D:/Godot/Godot_v4.7-stable_win64_console.exe"
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . <the new/updated unit test as a .tscn scene>   # NOT -s: -s skips autoloads
"$GODOT" --headless --path . --quit-after 120 2>&1 | grep -iE "SCRIPT ERROR|ERROR:"  # empty = clean
```

**Note on running runners:** run test/integration runners as their `.tscn` scene, never via
`-s script.gd` — `-s` does not load autoloads, so `GameState`/`TimeService`/`JobDirector`
resolve as "identifier not found" (a false failure). This bit us in the P04 session.

## Done when

- RESOLVED panel for a clean job shows the suppressed evidence line (player sees "I left no trace").
- The new unit test proves negative evidence/injury survive the clamp.
- Full verify chain clean. Commit directly to `master` (no PR).
