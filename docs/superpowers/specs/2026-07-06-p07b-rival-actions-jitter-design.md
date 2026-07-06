# P07b — Rival actions EXPAND / RECRUIT / FRAME + deterministic tie-break jitter

Extends the rival's repertoire from {PROBE, SABOTAGE} (both hit a player venue) to three
new threat vectors, and replaces "ties resolve to iteration order forever" with a
deterministic hash jitter. Zero RNG anywhere; save-additive; SAVE_VERSION unchanged.

## Part 1 — the three actions

### EXPAND — the rival grows its own power

- **Candidate set:** venues whose `owner_faction` is neither the player's nor the rival's
  (neutral ground / third parties). Distinct from PROBE/SABOTAGE/FRAME, which target
  player venues. The rival never EXPANDs onto its own or the player's property.
- **Scoring arm:** `(0.35 + 0.25·weakness) · (0.4 + 0.6·aggression) − heat·caution·0.25`.
  Weakness is the same visible `target_weakness` read (§7.4 fairness — control posture,
  disruption, active inspection). Aggression-weighted (FactionData has no ambition knob;
  aggression is the growth drive). **No grudge term** — this move isn't about the player.
- **Landed effect (one bounded write):** `venue.owner_faction = rival.id`,
  `venue.control_state = INFLUENCED`. Justification: the target is unowned/undefended, so
  a single landed action planting the rival's flag at the *lowest meaningful tier* is
  bounded and legible — nothing is taken from the player, and a multi-step control ladder
  on ground nobody defends is process without a payoff. Lifting the old `_land` doc
  comment ("ownership shift is its own future slice") — this IS that slice.
- **Target selection determinism:** same total-order argmax as everything else (below).
- **Note:** the current WorldSeed has zero neutral venues, so EXPAND is latent in the
  shipped slice until a district with neutral ground exists. The mechanic is proven in
  tests via an injected neutral venue; no WorldSeed change (out of scope).

### RECRUIT — the rival leans on a player lieutenant

- **Candidate set:** characters in the player faction, excluding the player herself.
- **Scoring arm:** `susceptibility · (0.2 + 0.6·cunning) + grudge_bonus`, where
  `recruit_susceptibility(c) = clamp(0.4·(1−public_trust) + 0.4·grievance + 0.2·ambition)`.
  **Public motive network only** (§7.4 fairness: CharacterData's hidden block —
  rival_leverage, survival_pressure — is read by no scoring path). Cunning-weighted (an
  indirect play); grudge applies (it IS an anti-player move); **placeless** — no district,
  no heat penalty (a back-room approach is deniable), `score_action` receives `null` for
  the district and the RECRUIT arm never touches it.
- **Target selection determinism:** susceptibility feeds the same single argmax; ties
  break by jitter, then first-in-authored-order (GameState.characters order).
  ("Highest susceptibility" ≈ the "lowest trust" guidance, blended with the visibly
  disgruntled signal — grievance/ambition are the *public* halves of what betrayal
  pressure reads.)
- **Landed effect:** `c.rival_leverage = clampf(c.rival_leverage + 0.15, 0, 1)`.
  P10b integration is direct and double-barreled: `betrayal_pressure()` sums
  `rival_leverage` linearly (+0.15 pressure per landed RECRUIT), and
  `LoyaltyScoring.OPP_LEVERAGE_PRESSED` contributes `0.5·rival_leverage` to the
  opportunity gate while any rival intent is open. Betrayal's `_land` discharges leverage
  to 0 — RECRUIT is the refill loop.
- **Intent storage:** the character id goes in the existing `intent_venue_id`
  (StringName — save schema unchanged; the field is documented as a generic target id).

### FRAME — deniable police attention on a player district

- **Candidate set:** player venues (the venue is the pretext; the effect lands on its
  district). Keeps intent/telegraph venue-shaped and the HUD legible.
- **Scoring arm:**
  `(0.15 + 0.25·weakness + 0.3·heat) · (0.3 + 0.4·cunning + 0.3·caution) + grudge_bonus`.
  Cunning-weighted; **caution appears POSITIVELY** (deniable — the police do the work,
  no sweep risk), the inverse of SABOTAGE where caution is a penalty. District heat is
  **fuel, not danger**: framing pays most when the pot is already simmering (it tips the
  P06 latch), so there is no heat penalty.
- **Landed effect:** `district.local_heat = clampf(local_heat + 0.25, 0, 1)`.
  Field choice: `local_heat`, NOT `inspection_ticks` (writing the countdown directly
  would bypass the P06 threshold latch + HUD warn telegraph) and NOT `venue.disruption`
  (recomputed each settle by the single-writer pass — a write there is erased next tick).
  Heat is an accumulate/decay integrator with existing precedent for a second additive
  writer (`job_lifecycle.gd:82` bumps it the same way), so the bump composes cleanly:
  EconomyService keeps rising/decaying from the new level and the inspection latch reacts
  through its normal, telegraphed path. Calibration: +0.25 vs `HEAT_INSPECTION_THRESHOLD`
  0.45 — from calm (0.1) it is pressure, not an instant sweep; on a simmering district
  (≳0.2 raw, or less with standing evidence cases) it can tip the latch.
- **No direct damage:** FRAME never touches sabotage fields — asserted in tests.

### Generalized `choose_move` (one total order)

Old shape iterated player venues × {PROBE, SABOTAGE}. New shape builds one candidate list
across all (action, target) pairs, then a single deterministic argmax:

1. Per player venue: score PROBE, SABOTAGE, FRAME (weakness from `target_weakness`).
2. Per non-player non-rival venue: score EXPAND.
3. Per player-faction non-player character: score RECRUIT (susceptibility as the
   weakness input, null district).
4. **Filter on raw score:** only candidates with `raw ≥ COMMIT_THRESHOLD` (0.3) survive —
   the "rival that always acts is noise" rule judged on true utility, never on jitter.
5. **Argmax on `raw + tie_jitter(...)`** over survivors; strict `>` keeps exact-tie
   fallback at first-in-iteration-order (districts → venues → characters, authored order).

Signature grows additively: `choose_move(districts, player_faction_id, rival,
characters := [], salt := 0)` — every existing 3-arg call site (tests, feud_probe)
compiles and behaves as before (no characters → no RECRUIT candidates; salt 0).
Pick dict keeps `venue`/`action`/`score` (existing test contract) and adds
`target_id` (StringName) + `character` (null for venue actions; `venue` is null for
RECRUIT). RivalDirector stores `pick["target_id"]` into `intent_venue_id`.

Threshold semantics are unchanged: the rival acts iff some candidate's RAW score clears
0.3 (previously: best raw ≥ 0.3 — identical decision), and jitter can only choose AMONG
already-committed candidates.

### Signals / consumers (audited)

`rival_intent_telegraphed` / `rival_action_landed` signatures already carry `action: int`
— unchanged. For RECRUIT the `venue` argument is `null`. Every consumer audited:
- `hud.gd:114-115` — arg-ignoring lambdas, safe.
- `job_director.gd:33` — returns before touching `venue` unless action == SABOTAGE, safe.
- `hud.gd:227 _refresh_rival_intent` — venue-name lookup falls through to "?" for a
  character target; **minimal extension**: fall back to `GameState.get_character(id)`
  for the display name. No signal or schema change.
- test lambdas — the new test file guards `v.id` for null; the existing file's scenarios
  never produce a RECRUIT telegraph (verified by scoring arithmetic + suite run).

## Part 2 — deterministic tie-break jitter

- **Function:** `tie_jitter(rival_id, target_id, action, salt) =
  float(("%s|%s|%d|%d" % [...]).hash() % 997) / 997.0 * TIE_JITTER_EPSILON`,
  `TIE_JITTER_EPSILON := 0.01`.
- **Hash source:** Godot's `String.hash()` — a fixed, documented 32-bit string hash
  (same string → same non-negative int on every run and platform). No RNG object, no
  seed, no hidden state, no `randf/randi/randomize/RandomNumberGenerator` — the source
  scan stays green. It is a pure function of *authored identity*: faction id + target id
  + action + salt.
- **Salt = `FactionData.intents_committed`** (new int field, default 0), incremented at
  each telegraph. Chosen over tick_index because it is persisted: save → load → the same
  board with the same salt reproduces the same pick bit-for-bit, and a replay from any
  save is identical. It also varies per decision, so the same board seen later in a
  campaign can legally resolve a near-tie differently — the anti-robotic feel, with zero
  randomness.
- **Why it cannot flip a clear winner:** jitter ∈ [0, 0.01). Any raw-score gap > 0.01 is
  arithmetically undisturbable; the meaningful gaps in this scoring system are O(0.05+)
  (a control-posture step alone moves weakness by 0.2 → SABOTAGE by ~0.16). And because
  the COMMIT filter runs on raw scores *before* jitter, jitter can neither make the rival
  act nor stop it from acting — it only orders near-equal committed candidates.
- **Determinism argument:** same (state, salt) → same candidates → same raw scores →
  same jitter values → same argmax. All jitter inputs are authored ids + a persisted
  counter; nothing reads wall-clock, frame timing, or process state.

## New constants / fields / persistence

- `RivalScoring`: `RECRUIT_LEVERAGE := 0.15`, `FRAME_HEAT := 0.25`,
  `TIE_JITTER_EPSILON := 0.01`, `recruit_susceptibility()`, `tie_jitter()`.
  EXPAND needs no constants (instant, no duration).
- `FactionData.intents_committed: int = 0` — jitter salt + telemetry.
- `SaveCodec`: encode `intents_committed`; decode `d.get("intents_committed", 0)` —
  additive like every field since P05. SAVE_VERSION stays 1; old saves load with the
  default; new saves add one key that old readers never see (var_to_str dictionary).

## Test plan (`tests/unit/test_rival_ai_p07b.tscn/.gd`, same SceneTree/[PASS]/exit-0 shape)

1. RNG source scan over both rival files incl. `RandomNumberGenerator` token.
2. EXPAND full loop: calm world + injected neutral CONTESTED venue → choose_move picks
   EXPAND on it (nothing else clears 0.3) → telegraph → land → owner = corvine,
   control = INFLUENCED. Also: no neutral venue → calm world still yields no move.
3. RECRUIT full loop: disgruntled lieutenant (trust .1 / grievance .9 / ambition .8) →
   RECRUIT picked over all venue actions → land → `rival_leverage == 0.15`.
   **Cross-system proof:** `betrayal_pressure()` with leverage minus the same character's
   pressure with leverage zeroed == +0.15; and with the next rival intent open,
   `LoyaltyScoring.betrayal_opportunity` gains the `0.5·leverage` OPP_LEVERAGE_PRESSED
   term.
4. FRAME full loop: heat 0.7 (latch disarmed) → FRAME picked → land → district heat
   jumps by ≥0.2 (bump minus one tick of drift); venue sabotage fields untouched.
5. Personality: caution scores FRAME up (deniable) while scoring SABOTAGE down.
6. Jitter determinism: identical (state, salt) twice → identical pick; clear winner
   (raw gap ≫ ε) wins across salts 0..63; two identical near-tie venues → pick is stable
   per salt AND some salt in 0..63 picks the other one (the tie actually breaks).
7. Regression: 3-arg `choose_move` in the inspection world still returns SABOTAGE on
   `gw_protection` (P07 contract), calm world still returns {}.
8. Save: `intents_committed` round-trips; decoding a faction dict without the key
   defaults to 0 (old-save additivity).
9. Existing suites (rival_ai, loyalty P10+P10b, night_cycle, economy, evidence,
   central_pressure, job generation/lifecycle/resolution, persistence smoke) must stay
   green unmodified.
