# P06c — Central Pressure (heat climbs to the Compact): ACCEPTED

**Accepted:** 2026-07-04 · **Built by:** Fable 5 (commit `5250a53`). **Gated by:** control tower
(this chat) — every check re-run here, plus the economy_service diff read by hand. Spec:
`docs/prompts/P06c-central-pressure.md`. This closes the deferred police-side line: P06 made heat
local, P06b gave it roots, **P06c puts the ceiling on** — pressure consolidates to the Compact.

## What shipped

The one scale above the districts. `_update_district_heat` used to loop the districts in isolation
with no channel between them; now a new single-writer pass consolidates the whole map into one
GameState-level axis that feeds back a telegraphed, city-wide bite.

- `src/core/game_state.gd` — `central_pressure` (0..1), `central_alert`, `central_alert_ticks` —
  authoritative campaign scalars beside `night_cycle`/`phase`.
- `src/simulation/pressure_math.gd` — `PressureMath` pure statics (EconomyMath/EvidenceMath
  discipline, headless-testable). `city_pressure` = **mean** of per-district
  `EvidenceMath.combined_pressure` (sits ON TOP of P06b, not beside it) — one hot district reads
  lower than the whole city warm. `step_central` = rise-toward-city above the floor / fixed 0.01
  decay below (slower than district heat — institutional memory is long), clamped 0..1, never a
  ratchet (tracks a cooling map down too).
- `src/simulation/economy_service.gd` — `_update_central_pressure()` (new pass after
  `_update_district_heat` in `_on_strategic_tick`), the single writer of the three scalars; a
  threshold latch mirroring the district inspection excursion (once per excursion, zero RNG);
  `central_alert_started`/`central_alert_ended` signals.
- **The bite** — the only edit to `_update_district_heat`, verified by reading the diff: while
  `central_alert_ticks > 0`, the district inspection is tested against
  `HEAT_INSPECTION_THRESHOLD - CENTRAL_ALERT_INSPECTION_RELIEF` (0.15). A **bounded read of a
  GameState flag** — zero contact with the heat / case / disruption writers. The map tightens at once.
- `src/save/save_service.gd` — the three scalars ride the existing `meta` payload additively; old
  saves load cold (pressure 0, no alert).

## The gap this closed

Three districts run hot at once and the old game treated it exactly like one hot district three
times over — no accumulation upward, nothing modelling the Compact drawing institutional heat as a
whole. Now city-wide sloppiness costs more than the sum of its districts: broad simmering is a
*Compact* problem, and when it crosses the bar every district's sweep leans closer. The long-session
top-level stakes the "fun with cubes" loop was missing.

## Gate — every check re-run here (not trusted from the report)

| Check | Result |
|---|---|
| `--import` | clean |
| `test_central_pressure` | **[PASS]** — 7 assertions; the bite is double-proved (same 0.38 state: no sweep alert-off, sweep alert-on); test not weakened |
| `test_heat_consequence` + `test_evidence` | **[PASS]** — district latch touched, no regression |
| Full prior suite (remaining 9 unit) | all **[PASS]** |
| Integration | `save_roundtrip` **byte-for-byte** + replay determinism (central scalars included) |
| RNG source scan | `pressure_math.gd` — **0** occurrences |
| Acceptance probe | **CENTRAL PRESSURE CLOSES** — re-run here, report reproduced |
| Boot smoke | **0** script errors; RID leaked-at-exit lines are the known P14 mesh teardown signature |
| **Diff read by hand** | the sole `_update_district_heat` edit is a bounded `central_alert_ticks` flag read — single-writer discipline intact, no second writer of heat/cases/disruption |

## The loop, proven end to end (probe re-run by control tower)

```
city runs hot: 4 districts, city_pressure 0.733 (floor 0.35)
central climbs: 0.609 after 11 ticks -> alert fired once (bar 0.60)
the bite: cooler district combined 0.373 (< 0.45 unaided bar) swept UNDER the alert: YES
  ^ the whole point: a district that would NOT sweep unaided gets dragged over the eased bar
city cooled: central 0.000 (re-arm 0.40) -> alert ended, re-armed, total fires: 1
verdict: CENTRAL PRESSURE CLOSES
```

Climbs → alerts (telegraphed, once) → tightens the whole map → decays → re-arms. Deterministic,
telegraphed, zero rolls. Through the real `_on_strategic_tick` settle path, not a shortcut.

## One implementation note (accepted)

Fable's latch names `central_alert` as "alert active" (true on fire, false on re-arm) rather than the
spec's "armed" framing — inverted naming, but functionally closed and correct: `not central_alert +
pressure >= threshold` fires once, the alert holds while `ticks > 0`, and re-arm only clears below the
rearm bar. One excursion, one fire — verified in test #3 and the probe. Fable also corrected test #3's
countdown assertion to match the actual fire-tick behaviour (same as `test_heat_consequence`); the fix
aligned the assertion to behaviour without weakening it (still proves staying above the bar does not
re-fire). No refusal, no Opus fallback.

## Fable's second accepted slice

The police-side capstone, built on the primary model and gated here. Fable held the hardest point —
the eased-threshold read stayed a bounded flag read, single-writer discipline unbroken. P06→P06b→P06c
is complete: heat is local, rooted, and now answers to a Compact-level ceiling.

## Out of scope (held)

No dedicated "Compact Audit" job (natural P06d, deferred). No clean-capital fine, no forced
laundering loss, no second disruption writer, no nation/federal actor, no per-faction central
pressure (player Compact only). No HUD meter (P19 — the signal + field exist for a later slice). No
change to how district heat/evidence rise/decay. No cross-district case *linking* (P06b's held scope
stays held — the pressure consolidates, the cases don't merge).
