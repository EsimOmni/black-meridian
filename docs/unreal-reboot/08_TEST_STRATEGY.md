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

`[V]` Determinism depends on `_avalanche()`, a 64-bit bit-mix finalizer over Godot's `String.hash()`:

```gdscript
x = (x ^ (x >> 30)) * -49064778989728563     # 0xFF51AFD7ED558CCD
x = (x ^ (x >> 27)) * -4265267296055464877   # 0xC4CEB9FE1A85EC53
return x ^ (x >> 31)
```

> ⚠️ **CORRECTED (S1, 2026-09-18) — the hex comments above were wrong, and so is the name.** Both
> the Godot source and earlier versions of this document call this "splitmix64". It is
> **MurmurHash3's `fmix64`**: the decimal literals are `0xFF51AFD7ED558CCD` / `0xC4CEB9FE1A85EC53`,
> whereas splitmix64 uses `0xBF58476D1CE4E5B9` / `0x94D049BB133111EB` — different constants
> entirely. Writing the splitmix64 values compiles, runs, stays deterministic, and mismatches
> **every** avalanche vector; it cost a red gate before being caught.
> **Take the decimal literals as authoritative — the algorithm's name here is not evidence.**

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
| `GV-SAVE-*` `[V]` | Round trip, version refusal, additive defaults, job rebuild, registry split | **EXACT (`==`) on floats too** — a round trip, not a formula. Fixture floats are **decimal strings**; see below |

`[P]` **Float tolerance is `1e-5` for state values** — far tighter than any gameplay-visible
difference, loose enough for a double→float transition. **Discrete outcomes are exact**: which action,
which candidate, which stage, which variant, which case. *A tolerance on a decision is not a
tolerance, it is a bug.*

`[V]` **One vector set does NOT use `1e-5`: `GV-SAVE-*` compares floats with `==`.** A save/load
round trip is not a formula comparison — `FArchive` on a `float` is a bit-exact 4-byte copy, so *a
tolerance on a round trip is not a tolerance either; it is a bug that hides truncation.*

> ⛔ **THE FIXTURE-ENCODING RULE, added after S4 and it applies to every extractor written from here on.**
>
> **`JSON.stringify` truncates float64 to ~15 significant digits.** `0.1 + 0.2` is written as `"0.3"` —
> **a different number** — and `1.0/3.0` loses two digits. `var_to_str` emits up to 17 and round-trips
> exactly (verified 20/20 on the adversarial set, including through a JSON round trip).
>
> **So any fixture that will be compared at EXACT equality must carry its floats as DECIMAL STRINGS,
> never as JSON numbers,** and the reader must parse them with a full-precision parser
> (`FCString::Atod`). The S4 extractor emits `"float_encoding": "decimal_string"` and its test
> **refuses** a numeric field outright, so a regenerated fixture fails loudly instead of silently losing
> two digits.
>
> **`hash_vectors.json`, `sim_vectors.json`, `job_vectors.json` and `trajectory.json` all use JSON
> numbers and are SAFE ONLY BECAUSE they compare at `1e-5`** — looser than the truncation. Do not
> tighten any of them to `==` without re-emitting the fixture as strings first.
>
> Same failure class as S1's 64-bit avalanche values rounding through a double, and the same lesson in a
> new costume: **GDScript's own `print()` and `%s` truncate to 14 digits, so the printed value is not
> evidence.** `var_to_str` is the only writer in the engine that tells the truth about a float.

### 5.2 Behavioral equivalence — the real bar

`[P]` Beyond per-formula vectors, a **trajectory test**: run the Unreal sim **1800 ticks** from the
seeded world with a scripted policy, and compare against the Godot probe.

> ⚠️ **Corrected 2026-09-18 — this said 1260, which cannot work.** 1260 is the *retuned slice* phase
> budget from [06](06_VERTICAL_SLICE.md) §2 (180/660/300/120), not the oracle's. The Godot probe
> ([`tools/validation/full_cycle_probe.gd`](../../tools/validation/full_cycle_probe.gd)) runs
> **1800** (240+1080+360+120), and every reference value below is sampled from that run. Phase
> transitions must match **exactly**; a 1260-tick Unreal run transitions on different ticks and can
> never match an 1800-tick oracle.
>
> The two coexist because `BMConstants.h` ships the **Godot budgets as the golden-vector baseline**
> ([05](05_DATA_MODEL.md) §3.2: "the C++ values are the defaults and the golden-vector baseline; a
> DataTable override is applied at load"). The 1260 retune arrives later as a `DT_BMBalance`
> override — a pacing decision, not a correctness one. **Equivalence is measured at 1800.**

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
drift slightly from rounding order across 1800 ticks of `roundf`; 0.5% over ~$300k is ≈$1,500, far
below one job's reward and invisible to a player.

### 5.3 Re-running determinism the way this audit did

`[V]` The method that proved Godot determinism, ported:

```sh
UnrealEditor-Cmd.exe <proj> -ExecCmds="BM.RunProbe 1800 -out=A.log; Quit" -unattended -nullrhi
UnrealEditor-Cmd.exe <proj> -ExecCmds="BM.RunProbe 1800 -out=B.log; Quit" -unattended -nullrhi
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

**Save (18 shipped, not 8) `[V]`:** RoundTripIsExact · OutcomeEmptyIsNotAllZeros ·
OutcomeFloatsMatchOracle · VersionMismatchIsRefused · CorruptFileIsRefused · AdditiveFieldDefaults ·
JobRebuildByteIdentical · RebuildThenOverlay · RegistryHalvesAreDisjoint ·
MissingJobDefinitionIsDropped · StaleCaseReferenceFailsRebuild · RestoreRefusalLeavesStateUntouched ·
ReplayAfterLoadMatches · LoadIsNotAffectedByPriorState · FixtureStillLoads · NoUIStateInCampaign ·
SubsystemIsAThinFacade · NoFileIoInBMCore

> `[V]` **The "8" was this document disagreeing with itself.** `07` §S4 named eight and §8 below named
> five migration tests that this line omitted; merged and deduped that is eleven. The other seven came
> out of execution: `04` §8.1's field-order finding needs `FixtureStillLoads`, `04` §2's file-I/O ban
> needs `NoFileIoInBMCore`, and the registry-order and replace-not-merge properties each needed their
> own test. **`LoadLeavesPaused` is NOT in this list** — it has no automated coverage and cannot have
> one at this layer; see §8.

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
| **`FT_Save_LoadLeavesPaused`** `[V]` | **Inherited from S4, which could not write it.** Load → the clock is PAUSED, asserted through a live `UBMTimeSubsystem`. This family is the first place a real `GameInstance` exists, and that is the entire blocker — see §8 item 6. **Whoever builds this family owns closing that hole**; do not treat §8's list as complete without it |
| `FT_Embodied_AllVerbs` | Inspect, plant, take, stand, speak, walk away |
| `FT_Embodied_WalkAwayWritesNothing` | `[V]` Verified Godot behavior |
| `FT_Embodied_ConsequenceVisibleOnReturn` | HUD reflects the change |
| `FT_Transition_ExclusiveResidency` | City and embodied never co-resident |
| `FT_Onboarding_RefundTimeline` | `[V]` brief §17.5 beats |
| `FT_Character_AnimationSet` | Every anim state plays |

---

## 8. Save migration tests

`[V]` The policy is **hard refusal, no migration** — so the tests verify *refusal*, not upgrade paths.

*`[V]` All five shipped in S4, under the names in brackets. They are **not** additional to `07` §S4's
eight — they were missing FROM it, which is what made the "8" wrong in both directions.*

1. `Test_Save_VersionRefusal` → **`BM.Save.VersionMismatchIsRefused`** — bad version → refused, state
   untouched, warning logged. `[V]` Versions 0, −1, 2 and 999 all refuse: the comparison is `!=`, not
   `<`, so a *future* version refuses exactly like a past one.
2. `Test_Save_AdditiveField` → **`BM.Save.AdditiveFieldDefaults`** — a save written before a defaulted
   field still loads. `[V]` Nine defaults, **measured off the running oracle** rather than read from the
   GDScript, including the two that surprise: a district loads **armed** (`bInspectionArmed = true`), and
   `intent_action` defaults to the **−1 sentinel**, not 0.
3. `Test_Save_CorruptFile` → **`BM.Save.CorruptFileIsRefused`** — truncated/garbage → refuse cleanly,
   never crash. `[V]` Five shapes, and the campaign is asserted byte-identical after each. Needs the
   `BMSV` magic tag to work at all: the oracle gets this free because `str_to_var` yields a
   non-Dictionary, but an arbitrary file's first four bytes are a plausible version int.
4. `Test_Save_MissingJobDefinition` → **`BM.Save.MissingJobDefinitionIsDropped`** — a save referencing a
   removed job id drops that job with a warning, `[V]` matching Godot's forward-compat behavior.
   ⚠️ **And the load SUCCEEDS.** That is the whole of `05` §7.2 and the reason `07` §S4's
   "byte-identical state" is conditional. Asserted on `FBMSaveLoadReport::SkippedJobIds`, not on a log
   line, and the siblings are asserted intact and in order.
5. `Test_Save_StaleCaseReference` → **`BM.Save.StaleCaseReferenceFailsRebuild`** — a `burycase` job whose
   case is gone fails to rebuild and is dropped `[V]` ("the job can't be rebuilt honestly").
6. ⛔ `[V]` **`Test_Save_LoadLeavesPaused` belongs in this list and CANNOT be written at this layer.**
   Measured in S4, not assumed: moving the pause after the restore leaves the suite **green**. Reaching
   `UBMTimeSubsystem` needs a live `GameInstance`, and `NewObject`'ing a `UGameInstanceSubsystem` into
   the transient package trips the CoreUObject `ClassWithin` ensure that the framework promotes to a
   failure *while every assertion passes*. Every **other** load assertion escaped that by moving to
   static `RestoreInto` / `RebuildJob`; a pause has nothing to assert on outside a `GameInstance`.
   **Closure is §7's `FT_Save_*` family.** Until then the ordering is protected by review and a comment
   on `UBMSaveSubsystem::LoadGame`. **Do not tick it off as done.**

**Fixture policy `[P]` → `[V]`, and it survived contact:** commit a real **`.bmsav`** per shipped
version under `Tests/Fixtures/Saves/`. When the version bumps, the old fixture stays and its test flips
to expecting refusal. Shipped in S4 as `v1.bmsav` (782 B, deliberately **not** LFS-routed so it stays
diffable and versioned inline). *(The extension is `.bmsav`, not `.sav` — `13` §4's tree says `.sav`
too and is equally stale.)*

⛔ **The policy needs one rule it did not state: NEVER REGENERATE A FIXTURE TO MAKE ITS TEST PASS.**
Regenerating it is precisely the act that destroys its value — the new bytes agree with the new field
order **by construction**. If the format changed deliberately, bump `BMSave::CurrentVersion` and add a
new fixture *alongside* the old one.

> `[V]` **Why this fixture is not optional, and why no other test can replace it (S4 Finding 3).** Field
> order **is** the binary format, and the failure is silent: `FArchive::operator<<` is bidirectional, so
> the reader and the writer are **the same function body** and a reorder moves both together. Measured —
> swapping two **same-type** fields in `SerializeVenue` turns **exactly one test red and leaves 55
> green**, and because the types match the byte *count* is unchanged, so even a size check misses it.
>
> The Godot build has no counterpart because `var_to_str` **SORTS dictionary keys**: field order is not
> part of the oracle's format at all, and its own round-trip runner *could not* have caught this. **The
> port's gate is therefore STRICTER than the oracle's**, and needed a test the oracle never had.

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
| Byte-identical save round-trip | `[V]` **`BM.Save.RoundTripIsExact`** + **`BM.Save.FixtureStillLoads`** — the second has no Godot counterpart and cannot: `var_to_str` sorts keys, so field order is not part of the oracle's format (§8, `04` §8.1) |
| Replay-after-load determinism | `[V]` **`BM.Save.ReplayAfterLoadMatches`** |
| Version refusal + untouched state | `[V]` **`BM.Save.VersionMismatchIsRefused`** + **`RestoreRefusalLeavesStateUntouched`** — the oracle's bool hid the difference between a version refusal and a parse refusal; `EBMLoadResult` separates them |
| Full-cycle probe with a verdict line | `BM.RunProbe` + `FT_FullCycle_Headless` |
| Double-run determinism comparison | §5.3 |
| Gate notes with recorded evidence | `docs/gates/S<n>.md` |
| "Loop alive" liveness check (dead stretches, pressure plateaus) | `Test_Probe_LoopAlive` — `[V]` the Godot probe measures 0/15 dead stretches; a loop that stops generating problems is a design failure a green unit suite would not catch |

---

**Next:** [09_ASSET_AND_CHARACTER_PIPELINE.md](09_ASSET_AND_CHARACTER_PIPELINE.md)
