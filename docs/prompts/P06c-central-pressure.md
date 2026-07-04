# P06c — Central Pressure (heat stops being local — it climbs to the Compact)

**Runs on: Fable 5** (primary model — see `docs/FABLE.md`). Control tower (this chat) wrote this
spec + owns the gate; Fable executes; Cem accepts. **Month:** 2 (deferred slice) · **Brief:**
§7.3 (police/institutional pressure), §7.5 (consequences), §6 pillar 1 (problem architect — the
pressure now has a *ceiling* above the districts), §7.6 (deterministic + telegraphed, no rolls).
Depends on: P06 (heat + inspection), P06b (evidence cases + combined pressure), P08 (job generation),
the single-writer settle discipline.

## The gap this closes

Today every district lives its own law in isolation. `_update_district_heat`
(`economy_service.gd:125`) loops the districts **independently** — each has its own heat, its own
evidence cases, its own inspection excursion, and there is **no channel between them**. You can run
three districts hot at once and the game treats it exactly like one hot district three times over.
There is no *accumulation upward*: nothing models the Compact drawing institutional heat as a whole,
and nothing makes city-wide sloppiness cost more than the sum of its districts.

Real institutional pressure consolidates. P06c adds the **one scale above the districts**:
`central_pressure` — a single GameState-level axis fed by how much heat and standing evidence sit
across *all* districts at once. When it crosses a telegraphed bar, it lands a **city-wide
consequence** (every district's sweep leans closer), and it decays when the city cools. This is the
police-side capstone: P06 made heat local, P06b gave it roots, P06c gives it a **ceiling that
answers to the whole map**. After P06c the "fun with cubes" loop has its top-level stakes — the
thing that makes a *long* session tighten, not just a short one.

## The one rule (unchanged)

**Deterministic + telegraphed, zero RNG.** Central pressure is a pure derivative of district state;
the city-wide consequence is a pure threshold latch, telegraphed one cadence ahead like every other
beat; decay is fixed-rate. No `randf`/`randi`/`randomize` anywhere in the new code — add the same
source-scan guard the rival/evidence tests use over the new files.

## The model

### 1. Central pressure lives on GameState (the one scale above districts)

`src/core/game_state.gd` — add campaign-level fields next to `night_cycle`/`phase`:

- `var central_pressure: float = 0.0` — 0..1, the consolidated institutional heat on the Compact.
- `var central_alert: bool = false` — latched true while a city-wide consequence is active (the
  telegraph→land state, mirrors the district `inspection_armed`/`inspection_ticks` shape).
- `var central_alert_ticks: int = 0` — countdown of the active city-wide consequence (0 = clear).

These are authoritative simulation state — they belong on GameState, never in a scene (brief §1
corollary). Presentation reads them; it does not own them.

### 2. The math is a pure static (EvidenceMath discipline)

Put the derivation in `src/simulation/pressure_math.gd`, `class_name PressureMath extends RefCounted`
— pure statics, headless-unit-testable exactly like `EconomyMath`/`EvidenceMath`. Reuse
`EvidenceMath.combined_pressure` per district so P06c sits *on top of* P06b, not beside it:

- `static func city_pressure(districts) -> float` — the consolidated raw signal. Define it as the
  **mean of each district's `combined_pressure`** (heat + weighted case pressure), NOT a raw sum:
  a mean keeps it in 0..1 and legible, and it means "the city is broadly hot" reads higher than
  "one district is on fire" — which is the intended shape (one hot district is a *district* problem;
  three simmering districts are a *Compact* problem). Deterministic, pure.
- `static func step_central(current: float, city: float) -> float` — the rise/decay integrator,
  mirroring the district heat rule: when `city >= CENTRAL_RISE_FLOOR`, rise toward `city` by
  `CENTRAL_RISE_SCALE`; else decay by `CENTRAL_DECAY_PER_TICK`. Clamp 0..1. (Rising *toward* the
  city signal rather than adding raw exposure keeps it bounded and makes the ceiling feel like it
  tracks the map, not like it ratchets forever.)
- Constants on `PressureMath` (tune, but start): `CENTRAL_RISE_FLOOR := 0.35`,
  `CENTRAL_RISE_SCALE := 0.15`, `CENTRAL_DECAY_PER_TICK := 0.01` (slower than district decay —
  institutional attention has a long memory), `CENTRAL_ALERT_THRESHOLD := 0.6`,
  `CENTRAL_ALERT_REARM := 0.4`, `CENTRAL_ALERT_DURATION_TICKS := 20`.

### 3. The tick — one new single-writer pass

`economy_service.gd` `_on_strategic_tick` (line 67): after `_update_district_heat()`, call a new
`_update_central_pressure()`. **`_update_district_heat` stays the single writer of district heat /
cases / inspection — do not touch it.** The new pass is the single writer of `central_pressure` /
`central_alert` / `central_alert_ticks`:

- `var city := PressureMath.city_pressure(GameState.districts)`.
- `GameState.central_pressure = PressureMath.step_central(GameState.central_pressure, city)`.
- Latch, mirroring the district inspection excursion exactly (once per excursion, zero RNG):
  - If `central_alert_ticks > 0`: decrement; on reaching 0 emit `central_alert_ended`.
  - Else if `central_alert` **armed** and `central_pressure >= CENTRAL_ALERT_THRESHOLD`: disarm,
    set `central_alert_ticks = CENTRAL_ALERT_DURATION_TICKS`, emit `central_alert_started`.
  - Re-arm when not alert and `central_alert_ticks == 0` and `central_pressure < CENTRAL_ALERT_REARM`.
- Two new signals on `economy_service.gd` (top, next to `inspection_started`): `central_alert_started`
  and `central_alert_ended` (no args, or pass the pressure float — your call, keep it minimal).

### 4. The city-wide consequence (what a Central alert actually DOES)

The alert must *bite*, deterministically and legibly, and it must be the police-side thing the player
feels across the whole map — not a new subsystem. Pick the **minimal** real consequence:

- **While `central_alert_ticks > 0`, every district's inspection arms more easily.** In
  `_update_district_heat`, when `GameState.central_alert_ticks > 0`, lower the effective inspection
  threshold each district is tested against by a fixed `CENTRAL_ALERT_INSPECTION_RELIEF` (say 0.15) —
  i.e. compare `combined >= HEAT_INSPECTION_THRESHOLD - CENTRAL_ALERT_INSPECTION_RELIEF`. This is one
  bounded read of a GameState flag inside the existing latch; it means a Compact-level alert drags
  *every* district toward a sweep at once — the whole map tightens, exactly the "it climbs to the
  Compact" beat. **Do not** add a second disruption writer or a new job type here — the consequence
  is the eased threshold, nothing more. Heat's own rise/decay is still untouched.

That is the entire consequence surface for P06c. (A dedicated "Compact Audit" narrative job, a
clean-capital fine, or a nation-level actor are explicitly deferred — see Out of scope. Keep this
slice to the one axis + the one eased-threshold bite.)

### 5. Telegraph (brief §7.6 — pressure is never a surprise)

The city-wide alert is **armed** state that crosses a **known** threshold as pressure climbs — that
is the telegraph (same as the district inspection: the player can watch `central_pressure` approach
`CENTRAL_ALERT_THRESHOLD` and act before it lands). The `central_alert_started` signal is the fire.
No hidden roll, no ambush. The HUD wiring of the meter is out of scope (P19 polish) — but the signal
must exist so a later HUD slice can surface it, and the probe/test read the value directly.

### 6. Save

`save_codec.gd` — the three campaign scalars ride in the existing `meta` Dictionary
(`encode_state`'s `meta` already carries `night_cycle`/`phase`; find where SaveService populates it).
Add `central_pressure`, `central_alert`, `central_alert_ticks` to that meta payload and restore them
in `decode_state`/SaveService. All additive (`.get(…, default)`): old saves load with pressure 0,
no alert. No new Resource to encode — these are plain scalars on GameState.

## Files (Fable's build list)

- `src/core/game_state.gd` — `central_pressure`, `central_alert`, `central_alert_ticks` fields.
- `src/simulation/pressure_math.gd` — new `PressureMath` statics (`city_pressure`, `step_central` +
  constants). Pure, headless-testable.
- `src/simulation/economy_service.gd` — `_update_central_pressure()` (new single-writer pass) +
  `central_alert_started`/`central_alert_ended` signals + the eased-threshold read inside
  `_update_district_heat` (the ONLY edit to that function — a bounded flag read, no new writer).
- `src/save/save_codec.gd` (+ SaveService where meta is built) — persist the three scalars in `meta`.
- `tests/unit/test_central_pressure.gd` (+ `.tscn`) — the gate (below).

## Gates — Done when (control tower verifies each headless)

- `--import` clean; **new `test_central_pressure` green**; **full prior suite green** (12 existing
  tests — P06c is additive; economy/heat/evidence/rival/loyalty/job/save must not regress —
  `test_heat_consequence` and `test_evidence` especially, since the district latch is touched).
- **RNG source scan** over the new files passes (zero `randf`/`randi`/`randomize`).
- **Save roundtrip green** — a mid-alert campaign (pressure > threshold, alert active, ticks > 0)
  survives save/load; the three scalars restore.
- Boot smoke clean.
- **Acceptance probe** (`tools/validation/central_pressure_probe.tscn`, throwaway like `feud_probe`
  / `evidence_probe`): drive the loop and print it — run several districts hot → `city_pressure`
  climbs → `central_pressure` rises toward it and crosses the bar → `central_alert_started` fires →
  while the alert is up, a *cooler* district crosses its (eased) inspection threshold it would NOT
  have crossed unaided → cool the whole city → central_pressure decays below re-arm → alert lifts,
  re-arms. Verdict line `CENTRAL PRESSURE CLOSES` on success.

### test_central_pressure must assert

1. `city_pressure` = mean of per-district `combined_pressure`; pure and deterministic (N identical
   calls, identical value); one hot district scores *lower* than the whole city warm (the mean shape).
2. `step_central` rises toward the city signal above the floor, decays below it, clamps 0..1, and is
   monotonic in the expected direction.
3. The alert latches once when `central_pressure` crosses `CENTRAL_ALERT_THRESHOLD` (armed→fires
   exactly once, not every tick), and does NOT fire below the bar.
4. **The bite:** with a Central alert active, a district whose `combined` sits *between*
   `HEAT_INSPECTION_THRESHOLD - CENTRAL_ALERT_INSPECTION_RELIEF` and `HEAT_INSPECTION_THRESHOLD`
   arms/fires an inspection it would NOT fire with the alert off. (Prove both: alert-off = no sweep,
   alert-on = sweep, same district state.)
5. Decay + re-arm: leaving the city cool drops `central_pressure` below `CENTRAL_ALERT_REARM` and the
   alert re-arms (only once, only below the rearm bar).
6. Save/load: the three campaign scalars survive a roundtrip mid-alert.
7. RNG source scan clean.

## Out of scope (P06c stays tight — the one axis + the one bite)

- **No dedicated "Compact Audit" job / narrative beat** — the consequence is the eased inspection
  threshold, full stop. (A telegraphed city-wide audit *job* is a natural P06d, deferred.)
- No clean-capital fine, no forced laundering-capacity loss, no ownership shift, no second disruption
  writer. No nation/federal actor above the Compact. No per-faction central pressure (this is the
  *player* Compact's institutional ceiling only — rivals don't have one this slice).
- No HUD meter (P19 polish — the signal + field exist so a later slice surfaces it). No change to how
  district heat or evidence rise/decay (P06c reads them; it never rewrites them). No cross-district
  evidence *linking* (that was P06b's held scope and stays held — central pressure consolidates the
  *pressure*, it does not merge the *cases*). No Fable reasoning echoed into output (per
  `docs/FABLE.md` — hard refusal trigger).

## Handoff note to Fable

Same *shape* as P06b and P07c, one level up: a signal that today acts only locally
(`combined_pressure` per district) is consolidated into **one authoritative scale above the map** that
feeds back a telegraphed, deterministic, city-wide consequence. Build in dependency order (GameState
fields → `PressureMath` statics → the `_update_central_pressure` pass + the eased-threshold read →
signals → save → tests → probe). The single hardest correctness point: **the eased-threshold read
inside `_update_district_heat` is the only edit to that function, and it must be a bounded read of a
GameState flag — it must not become a second writer of heat, cases, or disruption.** Prove the loop
end-to-end with the probe through the *real* settle path (`_on_strategic_tick`), not a shortcut —
that's what caught the loop closing in P06b/P07c. Headless is the truth — `--import`, unit test exit
0, boot smoke clean before you call it done. On any `stop_reason: "refusal"`, fall back to Opus for
that one call and continue.
