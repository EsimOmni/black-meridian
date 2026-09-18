# 08 — Test Strategy

How the Unreal build proves it reproduces a simulation that already works.

Tags: `[V]` Verified from repository · `[I]` Inferred · `[P]` Proposed

---

## 1. The premise

`[V]` The Godot build is not a sketch — it is a **passing test suite**: 24/24 unit tests, 2 integration
runners, and a 1800-tick probe that produced **byte-identical output across two independent runs**
(all executed and recorded in [01_SOURCE_AUDIT.md](01_SOURCE_AUDIT.md) §3).

That converts the port from "re-implement a design" into "**satisfy an existing oracle**." The
strategy follows from that: extract the oracle first, then build against it.

---

## 2. Test layers

| Layer | Framework | Runs | Scope |
|---|---|---|---|
| **Unit (BMCore)** | Automation, `ATF_ApplicationContextMask` | Headless, no world, no RHI | Pure math and rules |
| **Golden vectors** | Automation + JSON fixtures | Headless | Numeric equivalence with Godot |
| **Subsystem integration** | Automation, `EngineFilter` | Headless with a minimal world | Tick order, save, events |
| **Functional** | `AFunctionalTest` in a test map | PIE / `-nullrhi` | Transitions, scenes, verbs |
| **Replay/determinism** | Automation + probe harness | Headless | Long-run stability |
| **Performance** | `AFunctionalTest` + `FAutomationPerformanceData` | PIE + packaged | Budgets ([06](06_VERTICAL_SLICE.md) §9) |
| **Packaging smoke** | BuildCookRun + launch script | Packaged | Ships and runs |

**Naming.** `BM.<Area>.<Behavior>` — e.g. `BM.Economy.DirtyIncomeMatchesGolden`. Enables
`Automation RunTests BM.Economy`.

---

## 3. Determinism contract

### 3.1 Must be deterministic

Every formula and threshold · all iteration and tie-break order · hash-derived variety · tick counts ·
phase transitions · job generation and rebuild · betrayal and rival selection · save/load round-trips.

### 3.2 Explicitly allowed to be non-deterministic

Animation blending · particles (rain, steam) · audio timing and voice · camera interpolation ·
crowd/traffic visual phase · UI transitions and tweens · LOD and streaming timing · Sequencer
sub-frame evaluation.

`[P]` **The boundary is architectural, not a convention**: BMCore has no Engine dependency, so it
*cannot* reach `FMath::Rand`, `GWorld` or frame time. Enforced by `Test_Determinism_NoRandomInSimModule`,
a static scan — `[V]` the same technique the Godot suite uses (`test_rival_ai` source-scans for RNG).

### 3.3 What we do NOT promise

> **We do not promise bit-identical cross-engine floating-point results.**

`[P]` GDScript floats are IEEE-754 doubles; Unreal gameplay floats are typically 32-bit. Compilers,
FMA contraction and math-library differences make bit-identity across engines an unprovable claim.
Claiming it would be dishonest and would fail at the first `roundf`.

**We promise behavioral equivalence instead** (§5).

---

## 4. The hash problem — the port's single highest risk

`[V]` Determinism depends on `_avalanche()`, a splitmix64 finalizer over Godot's `String.hash()`:

```gdscript
x = (x ^ (x >> 30)) * -49064778989728563     # 0xBF58476D1CE4E5B9
x = (x ^ (x >> 27)) * -4265267296055464877   # 0x94D049BB133111EB
return x ^ (x >> 31)
```

It drives **rival tie-breaking** and **job-variant selection** — i.e. *which venue the rival attacks*
and *which job text the player reads*. Get it subtly wrong and the game is still perfectly
deterministic, just **different** — a failure mode with no symptom until someone compares against the
Godot build.

### 4.1 The three hazards

> **RESOLVED EMPIRICALLY IN S1 (2026-09-18).** Hazards 1 and 2 below were open questions when this
> was written; both are now answered, and **both resolve against what this section originally
> prescribed.** The corrected answers are inline. Full evidence:
> `D:\black-meridian-ue\Docs\gates\S1.md`.

1. **`String.hash()` is Godot-specific.** `[I]` It is DJB2 (`h = h*33 + c`, seed 5381) — but over the
   string's **UTF-32 code points**, not its bytes, masked to **unsigned 32-bit**.
   `[V]` Verified over 1715 corpus strings: code points match 1715/1715; UTF-8 bytes match 1712/1715
   (failing exactly on the non-ASCII adversarial cases); UTF-16LE matches 1/1715.
   ⚠️ A C++ implementation that hashes `FString`'s UTF-8 bytes passes every id in the current seed and
   **breaks on the first non-ASCII string ever authored.** Iterate `TCHAR` code points.
2. **Signed shift semantics.** GDScript `>>` on a negative int is arithmetic — and the shipped
   behavior **is** that arithmetic shift, which is load-bearing.
   ⚠️ `[V]` The original fix here ("do all of it in `uint64`, where the shift is unambiguous") is
   **WRONG** and produces a silently-different game: pure-`uint64` logical shifts match **0 of 3123**
   vectors, diverging on the very first one. Do the mix in signed `int64` with arithmetic shifts (or
   `uint64` with an explicit sign-extending shift helper) and expose the result as `uint64`.
   ~50% of inputs go negative after the step-1 multiply, so sign extension decides the outcome.
3. **Signed overflow is UB in C++.** The Godot multiplications rely on wraparound. `[P]` Fix: perform
   the multiplication in `uint64` (defined modular arithmetic) and cast back — this is compatible
   with hazard 2, which constrains only the **shifts**, not the multiplies.

### 4.2 Mandated procedure — S1, before any other logic

**Step 1 — extract vectors from Godot.** ✅ **DONE (S1, 2026-09-18).** The script exists:
`D:\black-meridian\tools\export_golden_vectors.gd`, producing `Tests/Golden/hash_vectors.json`
(1715 hash · 1408 tie_jitter · 240 variant_index rows). Two constraints it had to solve, worth
knowing before writing any other oracle script: **autoloads do not exist in a `-s` SceneTree script**
(so ids are parsed out of `world_seed.gd` rather than read from a built `GameState`), and **stdout is
not a safe channel** (the `_mcp_game_helper` autoload prints a banner after the script finishes and
corrupts a redirected document — the script writes its own file). The original sketch:

```gdscript
# tools/export_golden_vectors.gd  — extends SceneTree, run with -s
for s in ["gw_contraband", "compact|gw_clinic|2|0", "gen@retaliation@gw_contraband@corvine@120", ...]:
    print("%s\t%d\t%d" % [s, s.hash(), RivalScoring._avalanche(s.hash())])
```
Cover: every venue/character/faction id in the seed · every generated-job id form · the exact
`"%s|%s|%d|%d"` tie-jitter strings · adversarial cases (empty, unicode, very long, hash-negative).

**Step 2 — implement in C++ as `uint64`, matching the extracted table exactly.**

**Step 3 — `Test_Hash_MatchesGodotVectors` must pass 100%.** Not "mostly."

### 4.3 If the hash cannot be reproduced

> **MOOT AS OF S1 (2026-09-18) — SC-2 NOT TRIGGERED.** The hash was reproduced exactly: 1715/1715 on
> `String.hash()` and 3123/3123 on the avalanche, with the downstream bucket and variant math matching
> with zero mismatches. **No re-baseline decision is needed**, and direct vector comparison stays
> available to §5. This section is retained for the record only.

`[P]` Escalate (stop condition SC-2). The fallback, requiring Cem's sign-off:

> **Re-baseline.** Adopt a clean, documented hash (e.g. FNV-1a 64 + splitmix64), regenerate **all**
> golden vectors from the *Unreal* implementation, and accept that hash-derived choices (rival
> tie-breaks among near-equal candidates; job text variants) differ from the Godot build.

This is **acceptable** — those choices are arbitrary-but-stable by design, not balance-critical. But
it must be a **recorded decision**, because it invalidates direct vector comparison for the two
affected systems and narrows what §5 equivalence can check.

---

## 5. Golden vectors and behavioral equivalence

### 5.1 Vector sets

| Set | Covers | Tolerance |
|---|---|---|
| `GV-HASH-*` | String hash + avalanche + jitter + variant index | **Exact** (integers) |
| `GV-ECON-*` | DirtyIncome, CleanCapital, Exposure, ControlModifier, Demand | Exact on ints; `1e-5` on floats |
| `GV-HEAT-*` | Heat rise/decay, disruption ramp | `1e-5` |
| `GV-EVID-*` | Case pressure, combined pressure, kind selection, cap-overflow | Exact on kind/id; `1e-5` on weights |
| `GV-PRESS-*` | City mean, central step | `1e-5` |
| `GV-RIVAL-*` | All five scoring formulas, threshold, landing effects | `1e-4` on scores; **exact** on the chosen action |
| `GV-LOYAL-*` | Betrayal pressure, opportunity, candidate order, driving motive | `1e-5`; **exact** on ordering |
| `GV-JOB-*` | Outcome accumulation, clamping, expiry, follow-up threshold | `1e-5`; **exact** on stage |

`[P]` **Float tolerance is `1e-5` for state values** — far tighter than any gameplay-visible
difference, loose enough for a double→float transition. **Discrete outcomes are exact**: which action,
which candidate, which stage, which variant, which case. *A tolerance on a decision is not a
tolerance, it is a bug.*

### 5.2 Behavioral equivalence — the real bar

`[P]` Beyond per-formula vectors, a **trajectory test**: run the Unreal sim 1260 ticks from the seeded
world with a scripted policy, and compare against the Godot probe.

| Property | Requirement |
|---|---|
| Phase transitions | **Exact** — same ticks |
| Jobs offered/resolved | **Exact** counts and ids |
| Inspections fired | **Exact** count and ticks |
| Rival actions | **Exact** sequence of (action, target, tick) |
| Betrayal telegraph/land/defuse | **Exact** ticks |
| Ending reached | **Exact** |
| Dirty cash at each 120-tick sample | Within **0.5%** |
| Heat / central pressure at each sample | Within **0.01** absolute |

`[V]` The Godot reference trajectory is recorded and reproducible — e.g. tick 120 `dirty $36,540`,
tick 1800 `dirty $298,022`, `clean $1,119,300`, central peak `0.420`, heat `0.411`, 40 jobs offered /
40 resolved. Re-extract it from a probe run rather than transcribing by hand.

`[P]` **Rationale for tolerances:** discrete events must match exactly because they are *decisions* —
if the Unreal rival attacks a different venue, the games are not equivalent. Accumulated currency may
drift slightly from rounding order across 1260 ticks of `roundf`; 0.5% over ~$300k is ≈$1,500, far
below one job's reward and invisible to a player.

### 5.3 Re-running determinism the way this audit did

`[V]` The method that proved Godot determinism, ported:

```sh
UnrealEditor-Cmd.exe <proj> -ExecCmds="BM.RunProbe 1260 -out=A.log; Quit" -unattended -nullrhi
UnrealEditor-Cmd.exe <proj> -ExecCmds="BM.RunProbe 1260 -out=B.log; Quit" -unattended -nullrhi
fc /b A.log B.log        # must be identical
```

---

## 6. Test inventory by system

`[P]` Consolidated from [03_BEHAVIORAL_PORT_MATRIX.md](03_BEHAVIORAL_PORT_MATRIX.md).

**Time (5):** StartsPaused · NoTickWhilePaused · SpeedCycleOrder · UnpauseReturnsNormal ·
DrainLoopCatchUp · RivalTickCadence · `Test_Tick_ExplicitOrder`

**Economy (8):** golden vectors ×5 · SettleOrder · OverflowPressure · PressureFrontCapAndCost ·
PausedRacketZeroYield · Operatives_Conservation

**Heat/Evidence (7):** golden ×5 · **InspectionHysteresis** (full fire→cool→re-arm→re-fire) ·
ErodeVsRemove

**Pressure (2):** golden · AlertLifecycle

**Rival (8):** golden ×8 · TelegraphWindow · TieBreakStability · CandidateOrder ·
GrudgeSingleWriter · NoHiddenFieldReads · UnscoredActionsNeverChosen

**Loyalty (6):** golden ×4 · DefuseDuringWindow · ReassureCostAndEffect · NoNewTelegraphsInCouncil ·
OneIntentPerTick · BetrayalLanding · DefuseThenRescore

**Jobs (7):** golden ×4 · StageMachine · CoverUpAtomic · PrepCapAndToggle · CadenceCap ·
GenerationTriggers · IdRoundTrip · OriginBranches

**Night Cycle (3):** OrderAndWrap · BudgetBoundary · SummaryDistrictAgnostic

**Narrative (5):** ChainOrder · BeatSurvivesCap · DebtBranches · EndingLatch · FlagsRoundTrip

**Save (8):** FloatExactRoundTrip · RebuildContract · JobRebuildByteIdentical · VersionRefusal ·
AdditiveField · LoadLeavesPaused · ReplayAfterLoad · NoUIStateInCampaign

**Architecture (5):** NoStateWritesFromPresentation · NoRandomInSimModule · SingleHashImplementation ·
StableOrdering · Shipping_NoCheats

**Content (4):** NoHardcodedJobs · WorldFromData · AllDefinitionsValid · ValidationGate

---

## 7. Functional tests

`[P]` `AFunctionalTest` actors in `L_BM_FunctionalTests`, plus map-specific tests.

| Test | Asserts |
|---|---|
| `FT_FullCycle_Headless` | A complete Night Cycle runs with no errors/warnings above threshold |
| `FT_Transition_RoundTrip` | City → warehouse → city; camera, HUD and input restored |
| `FT_Save_BeforeTransition` | Save → enter → load → consistent pre-scene state |
| `FT_Save_DuringEmbodied` | Save inside the scene → load → correct level and state |
| `FT_Save_AfterTransition` | Consequences persist through save/load |
| `FT_Checkpoint_Recovery` | Checkpoint restores pre-scene state (the crash path) |
| `FT_Embodied_AllVerbs` | Inspect, plant, take, stand, speak, walk away |
| `FT_Embodied_WalkAwayWritesNothing` | `[V]` Verified Godot behavior |
| `FT_Embodied_ConsequenceVisibleOnReturn` | HUD reflects the change |
| `FT_Transition_ExclusiveResidency` | City and embodied never co-resident |
| `FT_Onboarding_RefundTimeline` | `[V]` brief §17.5 beats |
| `FT_Character_AnimationSet` | Every anim state plays |

---

## 8. Save migration tests

`[V]` The policy is **hard refusal, no migration** — so the tests verify *refusal*, not upgrade paths.

1. `Test_Save_VersionRefusal` — bad version → refused, state untouched, warning logged.
2. `Test_Save_AdditiveField` — a save written before a defaulted field still loads.
3. `Test_Save_CorruptFile` — truncated/garbage → refuse cleanly, never crash.
4. `Test_Save_MissingJobDefinition` — a save referencing a removed job id drops that job with a
   warning, `[V]` matching Godot's forward-compat behavior.
5. `Test_Save_StaleCaseReference` — a `burycase` job whose case is gone fails to rebuild and is
   dropped `[V]` ("the job can't be rebuilt honestly").

**Fixture policy `[P]`:** commit a real `.sav` per shipped version under `Tests/Fixtures/Saves/`.
When the version bumps, the old fixture stays and its test flips to expecting refusal.

---

## 9. Performance tests

`[P]` Budgets from [06](06_VERTICAL_SLICE.md) §9, measured in the **packaged** build (editor numbers
are for trend only).

| Test | Method | Budget |
|---|---|---|
| `Perf_CityView_FrameTime` | Scripted camera path, 60 s | ≥60 fps avg, ≥45 1%-low |
| `Perf_EmbodiedScene_FrameTime` | Scripted walk, 60 s | ≥60 fps avg, ≥45 1%-low |
| `Perf_SimTick_CPU` | 1000 ticks, `-nullrhi`, timed | ≤2.0 ms/tick |
| `Perf_Transition_Latency` | Enter/exit ×10 | ≤3.0 s |
| `Perf_SaveLoad_Latency` | Save/load ×20 | ≤250 ms / ≤1.5 s |
| `Perf_VRAM_Embodied` | `stat RHI` peak | ≤10 GB |
| `Perf_PackageSize` | Archive size | ≤8 GB |

`[V]` The Godot build's benchmarking lesson applies directly: **never pipe a windowed run's stdout
through `grep`/`head`** — write to a file and grep the file. A four-minute "hang" was buffering, not a
hang. Also: **grep the log for errors before trusting a number** — an error storm once produced a fake
16 fps reading that looked like a real result.

---

## 10. Failure injection

`[P]` Each maps to a real observed or plausible failure:

| Injection | Expected |
|---|---|
| Missing job Data Asset at load | Job dropped, warning, no crash `[V]` |
| Missing character actor class | Portrait fallback, scene still playable `[V]` (roster falls back to a monogram) |
| Corrupt save | Refused, campaign untouched |
| Transition interrupted by quit | Checkpoint recoverable |
| Zero free operatives | Assign returns 0, no negative pool `[V]` |
| Clean capital below cost | `PressureFront`/`Reassure` refuse, no negative balance `[V]` |
| Evidence case removed twice | Second call returns false |
| Job cap reached with a beat pending | Beat retries, does not die `[V]` |
| Level fails to stream | Error surfaced, return to city, sim intact |
| 4-hour idle run | No leaks, no drift, no overflow |

---

## 11. CI

`[P]` `[U]` **No CI service is configured or verified for this project.** Proposed local-first
approach, which matches how the Godot build actually operated:

**Pre-commit (local, mandatory):**
```sh
Build.bat BlackMeridianEditor Win64 Development -Project=<proj> -WaitMutex
UnrealEditor-Cmd.exe <proj> -ExecCmds="Automation RunTests BM.; Quit" -unattended -nopause -nullrhi \
    -testexit="Automation Test Queue Empty" -log=Saved/Logs/tests.log
```

**Per-slice (before a gate tag):** full suite + golden vectors + functional tests + a probe
determinism double-run + packaged build + launch smoke.

**If CI is later adopted** `[P]`: a self-hosted runner on the dev machine is the only realistic option —
UE build agents are heavy and the repo will be LFS-large. Decision **D-05**.

---

## 12. Test authoring rules — inherited, hard-won

`[V]` These come from `tasks/lessons.md`, where each cost real debugging time:

1. **Never park a test value exactly on a float threshold.** A betrayal setup summing to exactly the
   1.4 gate landed a hair under in float64 and the telegraph never opened — a flaky-looking hard
   failure. **Give boundary setups ≥0.05 margin on both sides**; exact-boundary behavior gets its own
   dedicated test using integers.
2. **Derive test thresholds from the real constants, never parallel literals.** A probe policy using
   0.35 made inspection recurrence physically unreachable because re-arm needs <0.30 — read as a
   mechanic failure, was an instrument error, cost two runs.
3. **A static extremal policy cannot exercise a hysteresis loop.** Model the player backing off, or
   the latch fires once and never again.
4. **Re-resolve every reference after a load.** A probe cached a character before a mid-run load and
   then acted on a dead object — the assertion failed while the mechanic was correct.
5. **Green-by-claim is not green.** Re-run the gate yourself; a "SHIP" claim once hid an asset that
   failed validation on two counts.
6. **Compare against a clean baseline before blaming your change.** `[V]` The 47 leaked-instance
   warnings are pre-existing since P14, verified on a clean worktree.

---

## 13. What the Godot suite does that must be preserved

| Godot practice | Unreal form |
|---|---|
| Source-scanning for RNG | `Test_Determinism_NoRandomInSimModule` |
| Byte-identical save round-trip | `Test_Save_FloatExactRoundTrip` |
| Replay-after-load determinism | `Test_Save_ReplayAfterLoad` |
| Version refusal + untouched state | `Test_Save_VersionRefusal` |
| Full-cycle probe with a verdict line | `BM.RunProbe` + `FT_FullCycle_Headless` |
| Double-run determinism comparison | §5.3 |
| Gate notes with recorded evidence | `docs/gates/S<n>.md` |
| "Loop alive" liveness check (dead stretches, pressure plateaus) | `Test_Probe_LoopAlive` — `[V]` the Godot probe measures 0/15 dead stretches; a loop that stops generating problems is a design failure a green unit suite would not catch |

---

**Next:** [09_ASSET_AND_CHARACTER_PIPELINE.md](09_ASSET_AND_CHARACTER_PIPELINE.md)
