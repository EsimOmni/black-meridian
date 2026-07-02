# P07 — RivalDirector: the first system that reacts to the player

**Month:** 2 · **Brief:** §7.4 (Rival-Family utility AI), §7.6 (telegraphed, never a hidden roll), §17.5 (first rival response within 15 min)

## Why

Right now the world has only one *intent* — the player's. Corvine Assembly is a passive exposure
source: it never decides, never reacts. P06 closed the economy/heat loop but the tension is still
*impersonal* — a system punishes you, not an adversary. P07 gives the world a second will: Corvine
watches for the player's weak moment and moves on it. This is what makes the cubes feel alive and
what the Month-2 gate's "fun with cubes" needs (brief §17.5: first visible rival response within 15
minutes).

The hooks are already in place: `TimeService.rival_tick` fires every ~10 strategic ticks and
**nothing consumes it yet**. P06 exposed exactly the vulnerability signals a rival should read
(`inspection_started/ended`, a venue's `disruption`, `control_state`, active `inspection_ticks`).
`BM.RivalAction` enum already exists. This slice connects them.

## The one hard rule (brief §7.6) — deterministic + telegraphed, ZERO noise

**Decided 2026-07-03:** the rival is **purely deterministic** — same world state → same chosen action,
every time. No `randf()`, no `randi()`, no seeded jitter. This mirrors P06's already-proven
heat/inspection pattern (warn at 0.38, fire at 0.45, latched, no RNG). Brief §7.4 mentions
"controlled noise" for variety/difficulty — that is **explicitly deferred to P07b** as a *deterministic*
tie-break (e.g. hash of tick+faction), NOT real randomness. For P07, argmax the score. A rival move
must be **telegraphed before it lands** — the player sees it coming and can act. Never an untelegraphed
surprise (brief §7.6 verbatim: "should never be resolved by an untelegraphed random roll").

## Scope — a reacting rival, PROBE/SABOTAGE only

Create `src/ai/rival_director.gd` (autoload or a node wired at bootstrap; keep the scoring math pure
and testable — split a `RivalScoring` static like `EconomyMath`/`JobResolution` so it unit-tests
headless without autoloads). Driven by `TimeService.rival_tick`.

1. **Read player vulnerability (imperfect info, fairness rule §7.4).** Each rival tick, the rival
   scans the player's owned venues for a weak target: high `disruption`, low `control_state`, and/or
   its district under active inspection (`district.inspection_ticks > 0`). The rival reads only what
   it could plausibly know (visible venue/district state), NOT hidden GameState. Higher difficulty
   later improves planning — never invisible income multipliers (§7.4). For P07, one difficulty.

2. **Score the two core actions deterministically.** Scope the action set to **PROBE** and
   **SABOTAGE** only (the rest of `BM.RivalAction` is P07b). Score from: target weakness, leader
   personality (`FactionData.aggression/caution/cunning`), current heat (a cautious rival avoids a
   hot district), expected retaliation. Aggressive/high-cunning Corvine (aggr 0.7, cunning 0.8) should
   skew toward SABOTAGE on a weak target. Pick argmax — deterministic, no noise.

3. **Telegraph, then land (two-phase, like the inspection beat).** When the rival commits to a target,
   first emit a **telegraph** (`rival_intent_telegraphed(faction, venue, action)`) — the HUD/city
   surfaces "Corvine is moving on `<venue>`". After a fixed lead of K rival-ticks (player's window to
   respond — e.g. pause the venue, pressure a front, reduce heat), the move **lands**: SABOTAGE adds
   `disruption` to the target venue (reuse P06's disruption→income hook — least new plumbing);
   PROBE is a cheaper info/pressure move (e.g. a smaller disruption bump or a heat nudge). Emit
   `rival_action_landed(faction, venue, action)`. Both phases deterministic + visible.

4. **Minimal rival state on FactionData.** Add only what P07 needs: a current-intent field (target
   venue id + action + ticks-until-land), so the telegraph→land window survives ticks and saves.
   Add as **additive** save fields (like P06's inspection state) so old saves load with defaults —
   do not break the save version.

## Deferred (do NOT build here) — decided 2026-07-03

- **Controlled noise / tie-break** → P07b (deterministic hash-based, not RNG).
- **The other 9 RivalActions** (EXPAND, RECRUIT, BRIBE, RETALIATE, NEGOTIATE, FRAME, REDUCE_HEAT,
  DEFEND, EXPLOIT_GRIEVANCE) → P07b+. P07 ships PROBE + SABOTAGE only.
- **Ownership transfer / control_state shift** (EXPAND/CONTEST changing `owner_faction` or
  `control_state`) → its own slice. P07's SABOTAGE only touches `disruption`, never ownership — that
  keeps it to the P06 hook and avoids net-new ownership plumbing.
- **Rival memory** (`rival_memory.gd` — humiliations, kept promises, contested territory altering
  future scores + dialogue) → P07c. P07 scores from current state only, no history.
- **The §7.6 betrayal / loyalty-network system** (BetrayalPressure over lieutenants) is a *character*
  system, not the rival-faction AI — separate track, not P07.

## Out of scope (hard)

- Noise, extra actions, ownership shift, memory, betrayal (above). Job generation (P08). Evidence
  chains (P06b). Central Pressure (P06c). Operative pool (P05b). Real art (Month 3).
- NO `randf()`/`randi()`/seeded jitter anywhere in rival decision-making (brief §7.6).
- Do NOT let the rival read hidden state or get invisible income buffs (fairness rule §7.4).
- Do NOT recompute economy in the AI; SABOTAGE writes `disruption`, the economy consumes it as it
  already does. Keep the sim authoritative (§13.2).

## Verify (headless is truth)

Unit tests under `tests/unit/` (run as `.tscn` scenes — `-s` skips autoloads, false-fails on
`GameState`; this bit us in P04):

- **Determinism:** `RivalScoring` returns identical scores for identical inputs across repeated calls;
  the chosen action is a pure argmax (same state → same action). No RNG anywhere (grep the AI files
  for `randf`/`randi` in the test's own assertion or a manual check).
- **Personality skew:** an aggressive/high-cunning leader on a weak target scores SABOTAGE above
  PROBE; a cautious leader in a hot district de-scores acting there.
- **Telegraph→land window:** committing fires `rival_intent_telegraphed` once, and the action only
  lands (disruption applied) after the fixed K-tick lead — never on the same tick as the telegraph.
- **The hit bites:** a landed SABOTAGE raises the target's `disruption` and thus lowers its
  `compute_dirty_income` (reuses the P06 regression path).
- **Regression:** P06 heat/inspection, P05 verbs, P04b resolution tests all still pass.

Then the standard chain:

```sh
GODOT="D:/Godot/Godot_v4.7-stable_win64_console.exe"
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . tests/unit/<new_test>.tscn --quit-after 300 2>&1 | grep -iE "PASS|FAIL"
"$GODOT" --headless --path . --quit-after 120 2>&1 | grep -iE "SCRIPT ERROR|ERROR:"   # empty = clean
```

Manual (F5 or MCP run): run rackets hot until an inspection weakens a venue → within ~15 min Corvine
telegraphs a move on it ("Corvine is moving on `<venue>`") → the player can respond (pause it, cool the
district) → if ignored, the sabotage lands and income drops. First rival response is visible and
legible, never a surprise.

## Done when

- Corvine deterministically picks a weak player venue and telegraphs a PROBE/SABOTAGE before it lands.
- The player has a real window to respond; ignoring it costs income via disruption.
- Zero RNG in rival decisions; scoring is a pure argmax proven by unit test.
- New tests green; P04b/P05/P06 regressions green; full chain clean. Commit to `master` (no PR).
