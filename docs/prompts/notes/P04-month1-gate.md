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

## Verdict (fill in after the session)

- [ ] All five beats hit without a script error?
- [ ] Save/load survived mid-loop?
- **Is it interesting yet?** —
- **Decision: proceed to Month 2?** —
