# P10b — Multi-lieutenant betrayal + hidden motives (design spec)

**Slice:** P10b · **Brief:** §6 pillar 3, §7.6 · **Parent:** P10 (loyalty motive network, shipped)
**Invariants in force:** zero RNG in `src/` (enforced by test_loyalty's source scan), sim state lives
on Resources/autoloads, saves stay additive, betrayal is deterministic + telegraphed + preventable.

## Part 1 — Multi-lieutenant betrayal

Today `RelationshipService._on_rival_tick` locks to one crisis: `if any_open: return` blocks scoring
while any intent is open. P10b removes the lock; each lieutenant holds an independent intent.

**Pure layer (`loyalty_scoring.gd`):**
- New const `MAX_NEW_INTENTS_PER_RIVAL_TICK := 1` — the bound. Already-open intents always advance;
  at most ONE new telegraph opens per rival tick. Two armed lieutenants therefore open on
  *consecutive* rival ticks, never all at once — the crisis escalates legibly instead of exploding.
- `choose_betrayer` (singular) is **replaced** by
  `choose_betrayers(characters, districts, factions, player_faction_id, max_new) -> Array[CharacterData]`
  (single caller today, deleted cleanly). Same two gates per candidate
  (`pressure_exceeds_threshold()` AND `betrayal_opportunity >= OPPORTUNITY_THRESHOLD`), plus a new
  exclusion: `betrayal_ticks_until_land >= 0` (an open intent can't re-open). Candidates are sorted
  by `score = betrayal_pressure() + opportunity` **descending**, ties broken by authored
  `GameState.characters` order (ascending index) — a total order, so the result is deterministic
  regardless of sort stability. Returns the top `max_new`.

**Driver (`relationship_service.gd`):**
```
every rival tick:
  1. advance EVERY open intent (own gate re-check → defuse | countdown | land)  — unconditional
  2. if phase == COUNCIL: return                       — Council blocks NEW opens only (P10 rule kept)
  3. for each of choose_betrayers(..., MAX_NEW_INTENTS_PER_RIVAL_TICK): open intent, emit telegraph
```
Each intent counts down, defuses, and lands on its own per-character gate re-check exactly as in P10
(`_advance_intent` unchanged in shape). A char whose intent defused this tick fails the same gates in
step 3, and a char whose intent landed has its motives discharged — no same-tick re-open by
construction, no snapshot needed. `betrayal_target` is already per-faction/first-non-CONTESTED, so a
second landing deterministically takes the *next* racket.

Signals unchanged in signature (`betrayal_telegraphed/defused/committed`) — they simply fire per
character now; the HUD connections keep working.

## Part 2 — Hidden motives

**New fields on `CharacterData` (both additive):**
- `betrayal_driving_motive: StringName = &""` — the single largest contributor to this character's
  `betrayal_pressure()`, captured **at telegraph time** (the motive that drove THIS intent; landing
  discharges motives, so a live recompute would lie mid-window).
- `motive_revealed: bool = false` — hidden/revealed state, reset to `false` on every NEW telegraph
  (each intent starts hidden; per-intent secrecy, not per-character omniscience).

**Pure argmax (`loyalty_scoring.gd`):**
`driving_motive(c) -> StringName` — strict argmax over the four POSITIVE pressure terms in fixed
order `[ambition, grievance, rival_leverage, survival_pressure]`; strict `>` comparison means ties
resolve to the earlier term. (The suppressors — trust/shared_success/fear — reduce pressure; they
never "drive" a betrayal.) Deterministic: same floats → same StringName, no state, no RNG.

**Reveal verb — DECISION: the existing `reassure` reveals as a side effect.**
`reassure(c)` (on success — capital paid) additionally sets `c.motive_revealed = true`.
Justification over a dedicated `investigate(c)` verb:
1. **Minimal footprint** — zero new verbs, zero new HUD buttons, zero new cost constants; P10b is a
   sim slice, not a UI slice (P19 owns UI polish).
2. **Fictionally coherent** — the reassure IS the sit-down; you buy the lieutenant a drink and learn
   what's eating them, whether or not the money fixes it.
3. **It creates a real diagnostic loop** — reveal matters most when reassure does NOT defuse: the
   player learns "money didn't move them — it's rival_leverage; kill the opportunity instead."
   First reassure = partial treatment + diagnosis. A separate investigate verb would just be a
   cheaper button pressed immediately before reassure every time — a non-decision.
Hidden→revealed is a pure state transition driven by a player verb — no roll anywhere.

**Presentation (`scenes/ui/hud.gd`, read-only):** `_refresh_betrayal` lists every open intent (one
line per lieutenant, multi-intent now possible); while hidden the line stays the P10 generic tells
(SOMETHING is wrong, not why); once revealed it appends the driving motive. The reassure button
targets the first open intent (existing behavior, adequate for greybox).

## Determinism argument
Every new element is a pure function of existing sim state: `choose_betrayers` is a filtered sort
under a total order (score desc, authored index asc); the per-tick cap is a constant; the driving
motive is a strict argmax under a fixed term order; reveal is set by a player verb. No `randf/randi/
randomize` introduced anywhere — the existing source scan in test_loyalty plus the same scan in the
new test file enforce it.

## Save-additivity argument
Two new keys in `SaveCodec.encode_character`; `decode_character` reads them with
`d.get("betrayal_driving_motive", &"")` / `d.get("motive_revealed", false)` — P10-era saves load
with the exact class defaults (no intent metadata, hidden), and `SAVE_VERSION` stays 1. All other
shapes untouched.

## Test plan — `tests/unit/test_loyalty_p10b.gd` (+ .tscn, same scene/exit-0 shape)
1. RNG source scan of loyalty_scoring.gd + relationship_service.gd (same as P10's).
2. `driving_motive` argmax correct; tie resolves to the fixed-order-earlier term.
3. Cap: two lieutenants armed + opportunity → exactly ONE telegraph on the first rival tick, the
   second on the next; both intents simultaneously open.
4. Independence: defuse one (drop its pressure), the other still lands on its own schedule
   (`_defused == 1`, `_committed == 1`), landing takes the next non-CONTESTED racket.
5. Hidden→revealed: telegraph sets driving motive + `motive_revealed == false`; `reassure` sets it
   `true`; a fresh telegraph resets it to `false`.
6. Save round-trip: open intent with driving motive + revealed flag survives save→clobber→load.
7. Determinism: run the multi-lieutenant scenario twice from `_fresh_world()` → identical tuples.
Existing `test_loyalty.gd` must pass unchanged, plus the full unit suite (no regression in economy,
night cycle, jobs, evidence, rival, persistence).
