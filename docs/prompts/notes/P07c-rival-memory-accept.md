# P07c — Rival memory (the feud loop): ACCEPTED

**Accepted:** 2026-07-04 · the stateless rival now remembers. Closes the one-directional
provocation loop into a feud, and consumes the previously-orphaned `rival_suspicion` signal.

## What shipped

A per-rival **`grudge`** toward the player (0..1), deterministic, save-safe, zero RNG.

- `src/core/faction_data.gd` — `@export var grudge: float` (save-additive).
- `src/ai/rival_scoring.gd` — `score_action` adds a grudge bonus on player targets
  (`GRUDGE_SCORE_BONUS` 0.35) + a SABOTAGE lean (`GRUDGE_SABOTAGE_LEAN` 0.15). Because
  `choose_move` already filters to player-owned venues, the bonus is player-only by construction.
  Pure/static, still unit-testable. No RNG (source scan green).
- `src/ai/rival_director.gd` — `_act` decays grudge each rival tick (`GRUDGE_DECAY_PER_TICK` 0.05,
  clamp 0). The tick owner, same place the intent countdown lives.
- `src/jobs/job_director.gd` — `_apply_and_emit`: on resolving a `RIVAL_PROVOCATION` job, the
  provocateur's grudge rises by that job's `rival_suspicion`. **Single writer up.** Provocateur
  identified from the generated id (`gen@retaliation@<venue>@<rival>@<tick>`) via `_provocateur_of`.
- `src/save/save_codec.gd` — encode/decode `grudge` (`.get(…, 0.0)` — additive for old saves).
- `tests/unit/test_rival_ai.gd` — +4 tests: grudge lifts a player-venue score; grudge crosses
  `COMMIT_THRESHOLD` in a world a grudge-0 rival ignores; grudge decays over ticks toward 0 (never
  negative); grudge survives save/load.

## The dead signal, now live

`JobResolution` produces `rival_suspicion` on every job; `job_lifecycle.apply_outcome` recorded it
*"for the P07/P08/P10 systems"* — but nothing consumed it for the rival. P07c is its consumer. The
feud was one-directional (rival hits → "Answer in Kind" job spawns → player answers → rival never
learns); now the answer feeds the grudge and the rival escalates.

## The loop, proven end to end

`tools/validation/feud_probe.tscn` drives the loop through the **real** settle path
(`JobDirector._apply_and_emit`, not a shortcut):

```
corvine grudge at start:                              0.000
SABOTAGE score, grudge 0.00:                          0.067
corvine grudge after player answers (suspicion 0.40): 0.400
SABOTAGE score, grudge 0.40:                          0.267  (delta +0.200)
choose_move in a calm world WITH grudge:              acts
corvine grudge after ~3 rival ticks alone:            0.250  (cooled from 0.400)
verdict: FEUD CLOSES (rises->bites->decays)
```

They hit you → you answer → they remember (+suspicion) → they bite harder (+0.200 on the same
target, and act where they'd otherwise wait) → the grudge cools if you de-escalate (0.40 → 0.25).

## Gates — all passed

- `--import` clean; `test_rival_ai` green incl. the 4 grudge tests + the unchanged RNG source scan.
- **Full prior suite green** (12 tests, all exit 0) — grudge is additive, no economy/loyalty/job/save
  regression.
- **Save roundtrip green** — a mid-feud grudge survives save/load (new save state, verified in both
  the unit test and the integration save_roundtrip runner).
- Boot smoke clean.

## Out of scope (held)

- No new rival actions (PROBE + SABOTAGE only — P07b). No ownership shift. No grudge dialogue/vignette
  (narrative later). No second grudge source — ONLY player retaliation feeds it (own-humiliation was
  considered and cut to keep the loop player-driven). No hidden motives / multi-lieutenant (P10b). No
  tie-break hash noise (P07b).

## Verdict

The rival is no longer a stateless raid generator. It remembers the player's answer, escalates
against the one who hit back, and forgets if left alone — a feud with a half-life, fully
deterministic and telegraphed (brief §7.4/§7.6). The retaliation loop is now bidirectional.
