# P08b — Territory-Loss origin: "Contested Ground" fixer job

**Date:** 2026-07-08 · **Slice:** P08b (job origins, territory-loss branch) · **Author:** Claude (Fable/Opus)
**Status:** approved, ready for plan

> Sibling of the already-shipped `2026-07-06-p08b-job-template-variety-design.md` (which added
> per-origin *variants*). This one adds a NEW job **origin** — the first fixer job driven by the
> player LOSING territory. Independent branch; does not touch the variety work.

## Problem

Today the rival AI runs five scored actions (EXPAND, PROBE, SABOTAGE, RECRUIT, FRAME) but only
**SABOTAGE** produces a fixer job (the retaliation trigger, P08). The rival can take ground and the
player just watches — no "problem to architect" is offered. This breaks brief §6 pillar 1 (the player
is a problem architect) and §5.1 (a resolved problem should spawn a new one, the loop never empties).

Two facts established by investigation (Fable subagent, read-only trace):

1. **EXPAND is currently dead in real play.** `rival_scoring.gd:129` makes EXPAND eligible only for
   venues where `owner_faction != player AND != rival` (i.e. unowned / third-faction). The WorldSeed
   ships all six venues owned (5 Compact + 1 Corvine, `world_seed.gd:105-118`), so there are **zero
   EXPAND-eligible venues** and EXPAND never fires.
2. **No mechanic removes a venue from the player.** The only runtime `owner_faction` write is rival
   EXPAND (`rival_director.gd:76`). Betrayal (`relationship_service.gd:65`) sets `control_state =
   CONTESTED` only and **leaves `owner_faction = player`** — so a betrayed venue is never
   EXPAND-eligible either. Inspection/heat/evidence never touch ownership.

So to make territory loss a real, recurring beat we must (a) give EXPAND something to take, and
(b) make betrayal actually cost the player the venue.

## Design

### 1. Make territory loss possible (the bait)

- **Static seed bait:** add ONE neutral venue to WorldSeed — `owner_faction = &""`,
  `control_state = CONTESTED`. The rival EXPANDs it at the first opportunity → first Contested-Ground
  loop fires early, deterministically, from a clean seed.
- **Dynamic bait (betrayal):** change `relationship_service.gd` betrayal `_land` so a landed betrayal
  hands the venue to the rival: `owner_faction = rival.id`, `control_state = INFLUENCED` (today it only
  sets CONTESTED and keeps player ownership). Narratively correct — a turncoat lieutenant delivers the
  venue to the enemy. This is a bounded change to one existing write; P10's telegraph/defuse window is
  untouched.
  - The betraying rival is the faction the lieutenant's `rival_leverage` points to. If the model has
    no explicit "which rival," use the single non-player faction (vertical slice has one). The plan
    step resolves this against the actual RelationshipService fields.

### 2. Trigger — one job, two source arms

The job template is generated identically from both arms; only the entry point differs.

- **EXPAND arm** — `JobDirector._on_rival_action_landed`: add `action == BM.RivalAction.EXPAND` →
  `JobGenerator.contested_ground_job(venue, rival, tick)`. Sibling of the existing SABOTAGE branch.
  (The SABOTAGE branch keeps its `owner == player` filter; the EXPAND branch has no such filter — the
  venue is now the rival's, which is the whole point.)
- **Betrayal arm** — `JobDirector` subscribes to RelationshipService's betrayal-landed signal and, when
  a venue changed hands, calls the same `contested_ground_job(venue, rival, tick)`.
- Cadence gate (`MAX_CONCURRENT_JOBS = 3`), id-dedupe, telegraph→deadline: all inherited free from
  `_try_offer`. If a venue is taken by both a betrayal and an EXPAND in the same window, dedupe by id
  drops the second (id encodes venue+tick).

### 3. Job content — "Contested Ground"

Two authored variants sharing one choice-id set (the shipped template contract: retaliation/bury_case
both do this), honoring the P06d evidence envelope (loudest lifecycle route nets ≥ +0.25 evidence,
quietest ≤ −0.3; `test_evidence` guards it). Three approaches:

| Approach id | Read | Outcome axes |
|---|---|---|
| `appr_evict` (loud) | Physically drive the rival crew out — open war | `objective_achieved: 0.75`, `evidence_generated: +0.35`, `public_fear: 0.25`, `rival_suspicion: 0.2` |
| `appr_buyback` (deal) | Pay off the rival's new "rent", pull them back quietly | `objective_achieved: 0.55`, `relationship_change: 0.2`, `rival_suspicion: 0.1`, `evidence_generated: -0.1` |
| `appr_rot` (subtle) | Sabotage the rival's new operation from inside so they withdraw | `objective_achieved: 0.5`, `evidence_generated: -0.3`, `new_leverage: 0.2`, `delayed_consequence: 0.2` |

Prep + coverup choices follow the existing template shape (scout/stage/rush prep; deny/flaunt/broker
coverup), tuned so the loudest full lifecycle stays ≥ +0.25 and the quietest ≤ −0.3. `reward_dirty`
in line with peers (~250). Exact per-choice numbers are finalized during implementation against the
`test_evidence` envelope, mirroring how retaliation/bury_case were tuned.

Second variant is a re-skin with the same ids and same axis shape (differing magnitudes inside the
envelope) — e.g. "Reclaim the Wharf" vs "Starve Them Out".

### 4. Sim-write on resolution

New origin branch in `JobDirector._apply_and_emit` (mirrors the existing EVIDENCE_CHAIN remove_case
and RIVAL_PROVOCATION grudge branches — origin-gated, single bounded write):

- If `job.origin == TERRITORY_LOSS` and `job.outcome.objective_achieved >= 0.5`:
  `venue.owner_faction = GameState.player_faction_id`, `venue.control_state = BM.ControlState.CONTESTED`.
- **CONTESTED, not CONTROLLED/UNKNOWN:** the ground is reclaimed but still disputed — the rival can
  target it again (EXPAND needs `!= player`, so a reclaimed CONTESTED venue is player-owned and safe
  from immediate re-EXPAND, but stays a PROBE/SABOTAGE/FRAME target and can be re-lost via betrayal).
  The loop stays alive without an infinite ping-pong.
- Below the threshold (a failed/soft resolution): the venue stays the rival's. The problem persists;
  the player can be offered it again on the next EXPAND tick or accept the loss.

### 5. Determinism & save-safety

- New enum value `BM.JobOrigin.TERRITORY_LOSS` appended at the END of the enum (save codec persists
  origin as int; appending is save-safe, inserting would shift existing saves).
- Generated id: `gen@contested@<venue_id>@<rival_id>@<tick>`. `JobGenerator.contested_ground_job`
  builds it; `JobGenerator.rebuild` parses it back (5-part, like retaliation) → same builder, same
  variant. Variant index = existing `_variant_index(id, CONTESTED_VARIANTS)` avalanche hash. No RNG,
  no stored counter — the P08 house rule, enforced by `test_job_generation`'s source scan.
- Save round-trip: a Contested-Ground job mid-lifecycle survives quicksave/load (rebuild from id +
  runtime state), same as every other generated job.

## Components touched

| File | Change |
|---|---|
| `src/core/enums.gd` | append `TERRITORY_LOSS` to `JobOrigin` |
| `src/core/world_seed.gd` | add one neutral (`owner=&""`, CONTESTED) venue |
| `src/simulation/relationship_service.gd` | betrayal `_land`: hand venue to rival (owner+INFLUENCED) + emit/carry the betrayal-landed signal if not already |
| `src/jobs/job_templates.gd` | `contested_ground()` + 2 variants; `CONTESTED_VARIANTS` const |
| `src/jobs/job_generator.gd` | `contested_ground_job()` + `rebuild` "contested" branch |
| `src/jobs/job_director.gd` | EXPAND arm in `_on_rival_action_landed`; betrayal-signal subscription; TERRITORY_LOSS branch in `_apply_and_emit` |

## Testing / verification

1. **Unit** (`tests/unit/test_job_generation.gd` extension): `contested_ground_job` is deterministic;
   `rebuild` round-trips its id to a byte-identical job; variant index stable across save→load.
2. **Evidence envelope** (`test_evidence`): loudest Contested-Ground lifecycle ≥ +0.25, quietest ≤ −0.3.
3. **Save round-trip** (existing runner): a mid-lifecycle Contested-Ground job survives quicksave/load.
4. **Headless full-cycle probe** (new, `docs/prompts/notes/`): seed neutral venue → rival EXPANDs it →
   Contested-Ground job offered → resolve loud → venue returns to player CONTESTED. Prove the chain.
5. **Betrayal probe:** telegraphed betrayal lands → venue → rival + Contested-Ground job offered.
6. Headless boot smoke clean; no SCRIPT ERROR / Nonexistent.

## Out of scope (explicit cuts)

- FRAME / RECRUIT job origins (separate future branches; this slice is territory only).
- Multi-district territory (vertical slice is one district).
- Betrayal cinematic (Month 4).
- Any change to P08b template-variety work or P10 telegraph/defuse timing.
