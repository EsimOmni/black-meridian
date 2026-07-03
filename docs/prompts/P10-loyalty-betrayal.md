# P10 — Loyalty motive network + telegraphed, preventable betrayal

**Month:** 2 · **Brief:** §6 pillar 3 (loyalty is a network of motives), §7.6 (Loyalty and Betrayal)

## Why

This is the game's signature system and the emotional core of the "problem architect" fantasy. Loyalty
is a **network of motives**, not one number (§6 pillar 3), and betrayal must be **deterministic,
telegraphed, and preventable** — never an untelegraphed random roll (§7.6, verbatim). Right now the
motive network is **write-only scaffolding**, exactly like heat before P06: `CharacterData` already
carries `public_trust`, `ambition`, `fear`, `grievance`, `shared_success`, `rival_leverage`,
`survival_pressure`, `betrayal_threshold`, `relationships`, and even a `betrayal_pressure()` /
`pressure_exceeds_threshold()` — but **nothing calls them** to change behavior. Jobs already nudge
trust/grievance (`job_lifecycle.gd:84-86`). P10 connects the network to a consequence.

## The one hard rule (brief §7.6) — betrayal is PREVENTABLE, telegraphed, zero-RNG

Betrayal requires **BOTH**: (1) pressure above the character's threshold **AND** (2) a viable
**opportunity**. Either alone is not enough — that is *what makes it preventable* (§7.6). And it is
**telegraphed before it lands** — the player sees tells and has a window to defuse. Zero RNG (house
style, P06/P07/P08/P09). Mirror the **P07 telegraph→land pattern** exactly: a two-phase machine, a
lead window, deterministic argmax — a lieutenant's betrayal is always something the player could have
seen coming and prevented, never a surprise dice roll.

## The critical gap to close — the Opportunity term

Brief's formula: `BetrayalPressure = Ambition + AccumulatedGrievance + RivalLeverage + SurvivalPressure
+ Opportunity − Trust − SharedSuccess − FearOfConsequences`. The code's `betrayal_pressure()`
(`character_data.gd:30-33`) **omits `+ Opportunity`** (comment: "evaluated elsewhere"). But Opportunity
is the whole point of preventability — without it, betrayal is a pure pressure threshold and can't be
defused by removing the *opening*. P10 must **model Opportunity** and require it as the second gate.
Keep the pressure math where it is; add Opportunity as the service's second condition (see below).

## Scope — a thin vertical slice: Opportunity + betrayal telegraph, ONE lieutenant (Bengal)

Create `src/simulation/relationship_service.gd` (a bootstrap-wired node, NOT an autoload — same reason
as NightCycle P09: an autoload would run its clock under every test scene and break P05–P09
regressions; keep pure scoring in a testable static like `RivalScoring`). Driven by `strategic_tick`
and/or `rival_tick`.

1. **Opportunity, deterministically.** Define what a "viable opportunity" is from *visible sim state*
   (no hidden roll): e.g. the character's faction is weak right now (an active inspection, a sabotaged
   venue, the player distracted / over-committed), or `rival_leverage` is being actively pressed. A
   pure static `betrayal_opportunity(character, game_state) -> float`, zero-RNG, like `target_weakness`.

2. **The betrayal gate.** A character is a betrayal candidate only when **both**
   `pressure_exceeds_threshold()` AND `betrayal_opportunity() >= OPPORTUNITY_THRESHOLD`. Score
   candidates deterministically (argmax if several; first-wins tie-break like RivalScoring).

3. **Two-phase telegraph→land (the P07 pattern).** When a candidate crosses both gates, open a
   **betrayal intent**: emit `betrayal_telegraphed(character)` and surface **tells** (delayed responses,
   unexplained absence, operational mistakes, private meetings, unusual requests — brief's exact list;
   pick 2–3 to represent as HUD/log lines this slice). Hold for a fixed lead of K ticks — the player's
   window. If, before the lead elapses, the player raises `public_trust` / `shared_success` or removes
   the opportunity so the gates no longer both hold, the intent **defuses** (emit `betrayal_defused`).
   Otherwise it **lands**: emit `betrayal_committed(character)` with a concrete effect (this slice:
   a bounded, legible consequence — e.g. the lieutenant's venue defects to CONTESTED, or leaks
   evidence raising heat; keep it one clear effect, not a cascade). Modulate like P07: during Council,
   **no NEW betrayal telegraph opens**, but an already-telegraphed intent still counts down (the
   promise stays deterministic).

4. **Player defusal verbs.** The player must have at least one concrete lever to raise trust /
   shared_success / remove opportunity within the window (a venue/character interaction — reuse an
   existing surface if one fits; a minimal "reassure / cut in / address grievance" action on the
   character panel is acceptable, greybox). Without a lever, "preventable" is a lie.

5. **Save additive.** Betrayal-intent state (candidate id + ticks-until-land + which gates held) rides
   in `meta` or on CharacterData as additive fields with defaults (like P06/P07/P08/P09).
   SAVE_VERSION stays 1.

## Deferred (do NOT build here) — decided 2026-07-03

- **The missing hidden fields** — `secret`, `true_loyalty`, `willingness_to_kill`, `succession_plan`,
  `responsibilities` (§7.6 hidden network) → **P10b.** They have no backing fields yet; P10 works with
  the motive fields that exist. Opportunity is derived from visible sim state, not a new hidden field.
- **Multi-lieutenant + rich relationship graph + cross-loyalty** (loyal to Aiko while betraying the
  Regent) → **P10b.** P10 proves the machine on Bengal (the one existing lieutenant with seeded
  grievance 0.3 and a relationships dict).
- **Betrayal *dialogue* / cinematic beat / the splat confrontation** → Month 4. P10 is the mechanic,
  telegraphed via HUD/log lines, not authored scenes.
- Evidence chains (P06b), Central Pressure (P06c), operative pool (P05b), rival noise/memory (P07b/c),
  extra job origins (P08b), rich phase content (P09 follow-ups) — all still deferred.

## Out of scope (hard)

- NO `randf()`/`randi()` anywhere in betrayal decision or opportunity (house rule — same state → same
  outcome; betrayal is NEVER a dice roll, §7.6).
- Betrayal must NOT fire on pressure alone — the opportunity gate is mandatory (preventability).
- Do NOT rewrite P05–P09; RelationshipService reads GameState/CharacterData and writes only its own
  intent state + the one landed effect. Keep the sim authoritative (§13.2).
- Do NOT add the missing hidden fields or a multi-character graph (→ P10b).
- Bootstrap-wired node, not autoload (protects the verified test suite — the P09 lesson).

## Verify (headless is truth)

Unit/integration tests (run as `.tscn` scenes — `-s` skips autoloads, false-fails on GameState):

- **Both-gates rule:** betrayal opens ONLY when pressure > threshold AND opportunity present. Pressure
  high but no opportunity → no telegraph. Opportunity present but pressure low → no telegraph.
- **Preventability:** with an intent open, raising `public_trust` / `shared_success` (or removing the
  opportunity) within the lead window defuses it (`betrayal_defused`), and it does NOT land.
- **Telegraph→land window:** committing fires `betrayal_telegraphed` once; `betrayal_committed` only
  after the fixed K-tick lead, never on the telegraph tick.
- **Determinism:** same character + same sim state → same decision, repeated. No RNG (grep the service
  + scoring for `randf`/`randi`).
- **Council modulation:** no new betrayal telegraph opens during Council; an open one still lands.
- **Save/load:** an open betrayal intent round-trips (candidate, ticks-left) through save (SAVE_VERSION
  unchanged).
- **Regression:** P04b/P05/P06/P07/P08/P09 tests all still pass (nothing rewired underneath).

Then the standard chain:

```sh
GODOT="D:/Godot/Godot_v4.7-stable_win64_console.exe"
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . tests/unit/<new_test>.tscn --quit-after 600 2>&1 | grep -iE "PASS|FAIL"
"$GODOT" --headless --path . --quit-after 120 2>&1 | grep -iE "SCRIPT ERROR|ERROR:"   # empty = clean
```

Manual (F5 or MCP run): drive Bengal's grievance/ambition up (or let jobs do it) while the player is
weak (active inspection) → tells appear ("Bengal missed a check-in", a private meeting) → the player
has a window to reassure/address the grievance → doing so defuses it; ignoring it lets the betrayal
land with a clear, caused consequence. The crisis is always legible and was always preventable.

## Done when

- Betrayal fires only on pressure AND opportunity, telegraphed with tells, defusable within a window.
- The Opportunity term is modeled and gates the decision; Bengal's loyalty crisis is causal + preventable.
- Zero RNG; deterministic; bootstrap-wired node; per-tick systems untouched.
- New tests green; P04b–P09 regressions green; full chain clean. Commit to `master` (no PR).
