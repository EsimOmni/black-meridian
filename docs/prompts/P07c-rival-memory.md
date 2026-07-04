# P07c — Rival memory (the feud loop)

**Month:** 2 (deferred slice) · **Brief:** §7.4 (rival AI), §7.6 (deterministic + telegraphed, no
rolls), §6 pillar 1 (the player is a problem architect — consequences must return to their author).
Depends on: P07 (RivalDirector + RivalScoring), P08 (retaliation job), P06 (single-writer settle).

## The gap this closes

P07's rival is **stateless** — `RivalScoring.choose_move` scores every target purely on *current*
visible weakness, with no history (the P07 spec itself parks memory for P07c: *"scores from current
state only, no history"*). And there is a **dead signal**: `JobResolution` produces `rival_suspicion`
on every resolved job, `job_lifecycle.apply_outcome` explicitly records it *"for the P07/P08/P10
systems"* — but nothing ever consumes it for the rival. The feud is one-directional: rival hits you →
"Answer in Kind" job spawns (P08) → you answer → **the rival never learns.**

P07c makes the loop a **feud**: they hit you → you answer → *that specific rival remembers* → it targets
you sooner and harder next cycle → which cools if you leave it alone. Player agency drives it; the
grudge is a pure function of the player's own retaliation.

## The one rule (unchanged from P07)

**Deterministic + telegraphed, zero RNG.** Grudge is a scalar written only by the resolution loop and
decayed only by the rival tick — same single-writer discipline as P06/P07. It biases scores; it never
introduces a roll. `test_rival_ai`'s source scan for randomness must still pass.

## The mechanism

A per-rival **`grudge` toward the player**, 0..1, on `FactionData` (additive save field, like the P07
intent fields).

1. **Accumulate (consume the dead signal).** When the player resolves a job whose `origin` is
   `RIVAL_PROVOCATION` (the "Answer in Kind" retaliation the rival's own sabotage spawned), the
   resolving rival's `grudge` rises by that job's `rival_suspicion` outcome. The provocateur is
   identifiable from the generated job id (`gen@retaliation@<venue>@<rival>@<tick>` — the rival id is
   embedded, already parsed by `JobGenerator.rehydrate`). This is the ONLY writer of grudge upward.

2. **Bias scoring (the memory shows up).** `RivalScoring` reads the acting rival's grudge and:
   - **Lowers the effective commit bar** — a grudge-holding rival crosses `COMMIT_THRESHOLD` on a
     weaker target (it *wants* to act against you). Implement as a grudge-scaled score bonus on
     player-owned venues, NOT by mutating the shared constant.
   - **Sharpens the strike** — grudge adds to the SABOTAGE score more than PROBE (a grudge wants to
     hurt, not poke). Still bounded; personality (aggression/cunning) still dominates.
   - Fairness (§7.4) preserved: grudge is the rival's memory of *the player's visible act against it*,
     not a peek at hidden GameState. It reads its own scalar, nothing hidden about the player.

3. **Decay (a grudge cools).** Each rival tick, `grudge` decays by a fixed step toward 0 (leave a rival
   alone and it forgets). Decay is in `RivalDirector._act` (the tick owner), bounded at 0. This makes
   the feud a *loop with a half-life*, not a ratchet — the player can de-escalate by not answering.

## Files

- `src/core/faction_data.gd` — add `@export var grudge: float = 0.0` (0..1). Save-additive.
- `src/ai/rival_scoring.gd` — `choose_move` / `score_action` take the rival's grudge into account
  (grudge-scaled bonus on player venues + SABOTAGE lean). Add `GRUDGE_*` weight consts. Pure, static,
  still unit-testable. New signature threads grudge through (or reads `rival.grudge` — rival already
  passed in). Prefer reading `rival.grudge` inside — no signature churn.
- `src/ai/rival_director.gd` — `_act` decays `rival.grudge` each tick (fixed step, clamp 0). This is
  the tick-owner, consistent with where intent countdown already lives.
- `src/jobs/job_lifecycle.gd` (or wherever a resolved `RIVAL_PROVOCATION` job settles) — on resolve of a
  `RIVAL_PROVOCATION` job, add its `rival_suspicion` to the provocateur rival's grudge. Identify the
  rival from the job id (reuse `JobGenerator`'s parse) or from a field on the job. Single writer up.
- `src/save/save_codec.gd` — persist/restore `grudge` (additive, defaulted for old saves).
- `tests/unit/test_rival_ai.gd` (+ `.tscn`) — extend: (a) a grudge-holding rival scores a player venue
  higher than an identical rival with grudge 0 (memory changes the argmax); (b) grudge lifts a
  sub-threshold target over `COMMIT_THRESHOLD` (memory makes it act when it otherwise wouldn't);
  (c) decay reduces grudge over ticks toward 0; (d) the RNG source scan still passes (zero randomness).

## Verify — Done when

- `--import` clean; `test_rival_ai` green with the new memory assertions; **full prior suite green**
  (grudge is additive — economy/loyalty/job/save tests must not regress).
- **Save roundtrip green** — a mid-feud grudge survives save/load (it's new save state).
- Boot smoke clean.
- A short accept note: show the feud closing — rival sabotages, player answers, that rival's grudge
  rises, next `choose_move` targets the player harder; then decays when left alone. A headless probe
  (like P07's) that drives the loop and prints grudge rising→biasing→decaying is the proof.

## Out of scope (P07c stays tight)

- No new rival ACTIONS (still PROBE + SABOTAGE — extra actions are P07b). No ownership shift (its own
  slice). No dialogue/vignette surfacing of the grudge (narrative later). No second grudge source —
  ONLY player retaliation feeds it (own-humiliation was considered and cut to keep the loop clean and
  player-driven). No hidden-motive / multi-lieutenant work (that's P10b). No tie-break hash noise
  (P07b). No UI beyond what already telegraphs intent.
