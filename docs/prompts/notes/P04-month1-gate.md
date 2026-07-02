# P04 — Month-1 gate note: the 15-minute greybox loop

**Gate (brief §19):** a 15-minute greybox loop must be playable. The verdict below is the
honest read that decides whether Month 2 proceeds.

## Status: READY FOR THE GATE SESSION — verdict pending (Cem plays ~15 min)

Prepared 2026-07-02. P00–P03 integrated; P02 save/load survives mid-loop (proven by
`tests/integration/bootstrap_smoke_runner` — 14 assertions through the full presentation
stack, and `save_roundtrip_runner` — deterministic save→load→same-tick→same-state).

## What was tuned for the session

- **Heat coupling ×5** (`economy_service.gd`): unmanaged laundering overflow now climbs Glass
  Wharf heat ~10% → ~60% over ~15 min at 1x. The economic squeeze (brief §7.2): player rackets
  yield ~1,307 dirty/tick vs 1,050 laundering capacity → +257 dirty piles up every tick.
- **First decision within 3 minutes** (brief §17.5): the game boots PAUSED with the
  Intercepted Shipment job open and a "FIRST DECISION" nudge on the intake panel.
- Quick-save **F9** / quick-load **L** (not F8/F10 — editor debug shortcuts kill/swallow those).

## The five loop beats to hit while playing

1. **Detect a change** — heat readout climbs; the job deadline (90 ticks) counts down.
2. **Inspect context** — click venues (cubes) for state; read the job panel.
3. **Make one commitment** — take the job: ≤3 prep actions, one approach, one cover-up.
4. **Watch the city react** — cash/heat move; marker tints show ownership.
5. **Absorb the consequence** — resolution dimensions land on cash/heat/trust; play on.

Also worth testing mid-session: F9 → keep playing → L (state + HUD must snap back, paused).

## Known limits going into the gate (deliberate, not defects)

- Only ONE authored job; no systemic generation (P08) — after resolving it, tension = economy/heat only.
- No staffing/funding UI yet (P05) — the only real commitment verb is the job.
- Heat has no consequence system yet (P06) — it climbs but nothing raids you.
- `CinematicWorldProvider` + mesh-fallback flag consciously deferred to Month 4 (P17); the
  splat decision itself is resolved (SPLAT_OK, P01 benchmark note).
- Clean capital accumulates with no sinks yet — ignore that number for tension.

## Verdict (2026-07-02, Cem played + Claude verified)

- [x] All five beats hit without a script error? — detect (heat/deadline) → inspect (venues/panel)
  → commit (Scout + Post lookouts → Quiet re-route → cover-up) → react → **absorb** (RESOLVED
  showed the consequence). No script errors.
- [x] Save/load survived mid-loop? — proven by `bootstrap_smoke_runner` (14/14): mid-loop
  save → advance → load restores cash/tick, keeps the game PAUSED, restores job stage, and the
  HUD repaints from restored state. F9 verified live (logged "Quick-saved.").
- **Is it interesting yet?** — **Yes.** The core loop works with cubes and placeholder UI; the
  commitment felt meaningful. The decision carried a real tradeoff and the outcome landed.
- **Decision: proceed to Month 2?** — **PROCEED.**

### One bug found + fixed during the gate (P04b, commit 373a214)

The first play read only `objective achieved: +0.70` / `new leverage: +0.10` — half the
player's skill (evidence suppression, operative protection) was invisible. A headless probe
proved `JobResolution._clamp()` floored `evidence_generated` and `operative_injury` to 0.0,
erasing the negative (suppression/mitigation) side the authored data drives on purpose. P04b
made those net axes clamp `-1..1`. Re-verified: the same played path now reads
**`evidence suppressed: 0.30` / `operatives protected: 0.20`** on the RESOLVED panel — the
"I left no trace" feel is back. Without this fix the gate read would have been dishonest.

### Next: P05 — rackets/fronts/laundering UI (the second real commitment verb)
