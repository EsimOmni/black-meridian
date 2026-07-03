# P08 — Systemic job generation: problems that emerge from the sim

**Month:** 2 · **Brief:** §7.5 (jobs generated from simulation state, never disconnected side-missions), §5.2 (pacing), §6 pillar 1 (problem architect)

## Why

The world now has an economy (P05), a heat consequence (P06), and a reacting rival (P07) — but the
job flow is still **one hand-authored Intercepted Shipment offered once at boot** (`bootstrap.gd:68`).
Resolve it and no new problem arrives; the Night Cycle runs dry. The Month-2 gate needs a full 25–30
min cycle (brief §12), and brief §7.5 is explicit: *"Fixer jobs are generated from the current
simulation state. They are not disconnected side missions."* Core loop (§5.1): *"a new problem is
created rather than every problem simply disappearing."*

The hooks are already in place — this is the same "half-wired, connect it" shape as P04b/P05/P06/P07:

- Trigger signals exist: `rival_action_landed` (`rival_director.gd:9`), `inspection_started`
  (`economy_service.gd:8`), overflow via `settle_info()`.
- `JobResolution` already produces `delayed_consequence` / `rival_suspicion` / `new_leverage`, and
  `JobLifecycle.apply_outcome` (`job_lifecycle.gd:66`) **deliberately leaves them unconsumed "for the
  P07/P08 systems."** P08 is where `delayed_consequence` finally spawns the follow-up problem.

## The house rule — deterministic emergence, ZERO RNG

**Decided 2026-07-03:** a job's *emergence* is deterministic and causal — same sim state → same job,
every time. No `randf()`/`randi()`/seeded jitter in generation. This mirrors P06/P07. Brief §7.6
mandates determinism for betrayal; §7.5 doesn't spell it out for job *selection*, but the house style
is zero-RNG and the design goal is legibility: the player must read the new problem as *following from
what just happened* ("Corvine sabotaged my contraband racket → here's a retaliation opportunity"),
never a random pop-up. Template variety within an origin (if multiple ever exist) is deferred to P08b
as a deterministic hash tie-break, NOT randomness. For P08, one template per trigger.

## Scope — a thin vertical slice: template layer + two triggers

1. **Job template layer.** Introduce a `JobTemplate` (a typed builder / data resource) that supplies
   the *authored* JobData fields (title, apparent_problem, origin, evidence, stakes, prep_actions,
   approaches, coverups, reward, deadline) and leaves runtime state default. Migrate the existing
   `PlaceholderJobs.intercepted_shipment()` to be **the first template** (keep its `by_id` registry
   working for save/load — a generated job still stores runtime state only and rebuilds content from
   its template id). This replaces imperative one-off construction with a reusable shape.

2. **A `JobGenerator` (pure + testable, like `EconomyMath`/`RivalScoring`).** Maps a **sim trigger →
   a job**, deterministically. Build exactly TWO triggers this slice:
   - **Rival retaliation** (origin `RIVAL_PROVOCATION`): when `rival_action_landed` fires a SABOTAGE
     on a player venue, generate a "retaliation opportunity" job targeting that venue/faction. The job
     is the player's *architected response* to the rival's move — problem-architect fantasy (§6).
   - **Delayed-consequence follow-up** (origin `FAILED_RACKET` or a fitting existing origin): when a
     resolved job's `outcome.delayed_consequence` exceeds a threshold, spawn a follow-up problem after
     a lead of K ticks. This finally consumes the dimension `apply_outcome` was holding, and makes the
     loop *never empty* (§5.1).

3. **JobDirector owns generation + a cadence gate.** `JobDirector` listens for the triggers and calls
   `JobGenerator`, then `offer()`s the result — but **never floods**: cap concurrent active jobs (an
   overlap gate, e.g. ≤ 2–3 at once; brief §5.2 "run four to six" across a phase, not all at once).
   A trigger that fires while at cap is dropped or queued deterministically — pick the simpler
   (drop-with-log) and note it. Generation is telegraphed by the existing `job_offered` signal the
   HUD/panel already shows.

4. **`JobOrigin` enum** currently has 5 of the brief's 10 values (`enums.gd:81-87`). Use the existing
   values that fit the two triggers (`RIVAL_PROVOCATION`, `FAILED_RACKET`). Do NOT add the missing 5
   origins here — that's P08b when their triggers get built.

## Deferred (do NOT build here) — decided 2026-07-03

- **The other 8 job origins** (compromised operative, disloyal lieutenant, witness, missing payment,
  police investigation, political request, family scandal, internal dispute) and their triggers →
  **P08b.** P08 ships exactly two triggers.
- **Multiple templates per origin + deterministic variety tie-break** → P08b.
- **Job difficulty scaling / duration tiers** (minor 60–90s vs story 5–10min, §7.5) → P08b tuning.
- **Authored story jobs / the 3-authored-vs-5-systemic mix** (§12.1) → later; P08 proves the systemic
  path with the migrated Intercepted Shipment as the seed template.
- Evidence chains (P06b), Central Pressure (P06c), operative pool (P05b), rival noise/memory
  (P07b/c) — all still deferred.

## Out of scope (hard)

- NO `randf()`/`randi()`/seeded jitter in generation (house rule). Same-state → same-job.
- Do NOT let generation invent content the template didn't author (no procedural text soup) — a
  generated job = a template + sim-derived targeting (which venue/faction/deadline), not AI-written prose.
- Do NOT recompute economy/heat/rival state in the generator; it READS sim state, writes only new jobs.
- Do NOT break the save version — a generated job saves runtime state only and rebuilds from its
  template id (extend the `by_id` registry additively, like P02).
- Keep the sim authoritative (§13.2): generator reads GameState, JobDirector owns the job list.

## Verify (headless is truth)

Unit tests under `tests/unit/` (run as `.tscn` scenes — `-s` skips autoloads, false-fails on
`GameState`/`JobDirector`; this bit us in P04):

- **Deterministic emergence:** the same trigger on the same sim state produces an identical job
  (same origin, target venue, deadline, choices) across repeated calls. No RNG (grep generator for
  `randf`/`randi`).
- **Rival trigger:** a `rival_action_landed` SABOTAGE on a player venue generates a
  `RIVAL_PROVOCATION` job targeting that venue; the job is a valid, playable JobData (has prep/
  approaches/coverups, non-zero deadline).
- **Follow-up trigger:** resolving a job with high `delayed_consequence` spawns a follow-up job after
  the K-tick lead — and one with low/zero delayed_consequence does NOT.
- **Cadence gate:** with the active-job cap reached, a further trigger does not exceed the cap.
- **Save/load:** a generated (non-authored) job round-trips — its runtime state saves and it rebuilds
  content from its template id.
- **Regression:** P03 lifecycle, P04b resolution, P05 verbs, P06 heat, P07 rival tests all still pass.

Then the standard chain:

```sh
GODOT="D:/Godot/Godot_v4.7-stable_win64_console.exe"
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . tests/unit/<new_test>.tscn --quit-after 300 2>&1 | grep -iE "PASS|FAIL"
"$GODOT" --headless --path . --quit-after 120 2>&1 | grep -iE "SCRIPT ERROR|ERROR:"   # empty = clean
```

Manual (F5 or MCP run): let Corvine sabotage a venue → a retaliation job appears, clearly caused by
that move → take and resolve it heavily (high delayed_consequence) → a follow-up problem surfaces
later. The loop never empties, and each new problem reads as *caused*, not random.

## Done when

- Jobs emerge deterministically from two sim triggers (rival sabotage, delayed-consequence follow-up).
- The Intercepted Shipment is a template; generated jobs save/load via template id.
- A cadence gate prevents flooding; each new problem is legibly caused by the sim.
- New tests green; P03/P04b/P05/P06/P07 regressions green; full chain clean. Commit to `master` (no PR).
