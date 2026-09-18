# 07 — Implementation Roadmap

Ordered slices with hard dependencies. **No calendar estimates** — each slice ends at a gate that is
either passed or not.

**Convention:** every slice states its objective, files, tests, validation commands, acceptance gate,
rollback point, and prohibited shortcuts. A slice is complete only when its gate passes with recorded
evidence — `[V]` per the Godot lesson *"green-by-claim is not green."*

**Notation:** `S0 → S1` = S1 depends on S0.

---

## Dependency graph

```
S0 Bootstrap ──► S1 Determinism Core ──► S2 Economy/Heat/Pressure ──► S3 Jobs ──┐
                         │                                                      │
                         └──────────────► S4 Save/Load ◄───────────────────────┘
                                               │
        ┌──────────────────────────────────────┼──────────────────────────┐
        ▼                                      ▼                          ▼
   S5 Rival AI                        S6 Loyalty/Betrayal          S7 Night Cycle
        └──────────────────┬───────────────────┴──────────────────────────┘
                           ▼
                     S8 Narrative Spine
                           ▼
                  S9 Strategic Presentation ──► S10 Playable Greybox  ★ GATE A
                           │
                           ▼
                S11 Transition + Embodied Stub ──► S12 Hero Character
                           │                              │
                           └──────────┬───────────────────┘
                                      ▼
                          S13 Embodied Scene (hero)  ★ GATE B — the reboot thesis
                                      ▼
                         S14 Content → Data Assets
                                      ▼
                            S15 Polish + Settings
                                      ▼
                     S16 Package + QA  ★ GATE C — slice complete
```

★ = **stop-and-review with Cem.**

---

## S0 — Repository and project bootstrap

**Objective.** A compiling, source-controlled, empty-but-correct C++ project.

**Depends on:** Cem's approval (G1) + all go conditions in [00](00_EXECUTIVE_DECISION.md) §9.1.

**Creates.** `../black-meridian-ue/` per [13_REPOSITORY_BOOTSTRAP.md](13_REPOSITORY_BOOTSTRAP.md):
`BlackMeridian.uproject`; modules `BMCore`, `BMSim`, `BMGame`, `BMUI`, `BMEditor`;
`Config/Default{Engine,Game,Input}.ini`; `.gitignore`, `.gitattributes` (LFS); `README.md`.

**Tests.** One trivial Automation test in BMCore proving the test runner works.

**Validation.**
```sh
"C:/Program Files/Epic Games/UE_5.8/Engine/Build/BatchFiles/Build.bat" \
    BlackMeridianEditor Win64 Development -Project="<abs>/BlackMeridian.uproject" -WaitMutex
"C:/Program Files/Epic Games/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" \
    "<abs>/BlackMeridian.uproject" -ExecCmds="Automation RunTests BM.Smoke; Quit" \
    -unattended -nopause -nullrhi -testexit="Automation Test Queue Empty"
git lfs track --verify   # confirm binary patterns are covered BEFORE the first asset lands
```

**Gate.** Editor builds Development; the smoke test runs and passes; `git status` clean; LFS active.

**Rollback.** Delete the new directory. The Godot repo is untouched.

**Prohibited.** Adding plugins "we'll probably need." Creating Blueprints. Importing any asset.
Enabling World Partition.

---

## S1 — Determinism core

**Objective.** The hash, the ordering rules and the golden-vector harness — **before** any game logic,
because everything downstream inherits them.

**Depends on:** S0.

**Creates.** `BMCore/BMHash.{h,cpp}` (`StringHash`, `Avalanche`, `TieJitter`, `VariantIndex`);
`BMCore/BMConstants.h` (the full table from [05](05_DATA_MODEL.md) §3.2);
`BMCore/BMTypes.h` (ids, enums); `BMEditor/BMGoldenVector.{h,cpp}` (load/compare fixtures);
`Tests/Golden/*.json` extracted from Godot.

**Tests.**
- `Test_Hash_MatchesGodotVectors` — the `GV-HASH-*` set.
- `Test_Hash_SingleImplementation` — no duplicate avalanche (TD-05).
- `Test_Determinism_NoRandomInSimModule` — static scan of BMCore/BMSim for `FMath::Rand`,
  `RandRange`, `FRandomStream`, `FDateTime::Now`, `GetTimeSeconds`.

**Validation.**

> ✅ **`tools/export_golden_vectors.gd` EXISTS as of 2026-09-18** and has been run;
> `Tests/Golden/hash_vectors.json` is populated (1715 + 1408 + 240 rows). Evidence and the resulting
> spec corrections: `D:\black-meridian-ue\Docs\gates\S1.md`. Use the **`_console`** binary: the plain
> `.exe` detaches from the console on Windows. The script **writes its own output file** via `--out=`
> rather than printing to stdout — the `_mcp_game_helper` autoload emits a banner after the script
> finishes, which corrupts a redirected document.

```sh
# 1) EXTRACT vectors from the Godot build (read-only; run in D:\black-meridian)
D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . -s tools/export_golden_vectors.gd \
    -- --out=D:/black-meridian-ue/Tests/Golden/hash_vectors.json
# 2) COMPARE in Unreal
UnrealEditor-Cmd.exe <proj> -ExecCmds="Automation RunTests BM.Determinism; Quit" -unattended -nullrhi
```

**Gate.** **Every hash vector matches exactly.** If Godot's `String.hash()` cannot be reproduced,
**stop and escalate (SC-2 in [00](00_EXECUTIVE_DECISION.md) §9.2)** — do not proceed with a
"close enough" hash. See [08_TEST_STRATEGY.md](08_TEST_STRATEGY.md) §4 for the fallback.

**Rollback.** Tag `s0-bootstrap`.

**Prohibited.** ⛔ **Writing a "temporary" hash and fixing it later.** Every downstream golden vector
would be invalid, and the failure is silent — a different but still-deterministic game.
⛔ Using `TMap` iteration anywhere order matters.

---

## S2 — Economy, heat, evidence, pressure

**Objective.** The economic engine, headless, matching Godot numerically.

**Depends on:** S1.

**Creates.** `BMCore`: `FBMEconomyMath`, `FBMEvidence`, `FBMPressureMath`, `FBMOperativeMath`,
state structs. `BMSim`: `UBMCampaignSubsystem`, `UBMTimeSubsystem`, `UBMSimulationCoordinator`,
`UBMEconomySubsystem`, `UBMHeatSubsystem`, `UBMPressureSubsystem`.

**Tests.** `GV-ECON-01..05`, `GV-HEAT-01..02`, `GV-EVID-01..03`, `GV-PRESS-01`;
`Test_Economy_SettleOrder`, `Test_Economy_OverflowPressure`, `Test_Economy_PressureFrontCapAndCost`,
`Test_Heat_InspectionHysteresis` (full fire→cool→re-arm→re-fire), `Test_Pressure_AlertLifecycle`,
`Test_Operatives_Conservation`, `Test_Time_DrainLoopCatchUp`, `Test_Tick_ExplicitOrder`.

**Validation.** `Automation RunTests BM.Economy+BM.Heat+BM.Pressure+BM.Time`

**Gate.** All golden vectors match. A 1800-tick headless run reproduces the Godot probe's economic
trajectory within tolerance ([08](08_TEST_STRATEGY.md) §5).

**Rollback.** Tag `s1-determinism`.

**Prohibited.** ⛔ Deriving inspection thresholds from literals in tests — read `BMConst`
(`[V]` the P06d instrument-error lesson). ⛔ Parking a test value exactly on a float threshold;
≥0.05 margin, boundaries get integer-only dedicated tests.

---

## S3 — Job system

**Objective.** Four-stage lifecycle, nine-dimension resolution, generation, cadence cap.

**Depends on:** S2.

**Creates.** `BMCore`: `FBMJobLifecycle`, `FBMJobResolution`, `FBMJobGenerator`, `FBMJobIdParser`.
`BMSim`: `UBMJobSubsystem`. Job content stays **temporarily** in C++ tables (moved to Data Assets in S14).

**Tests.** `GV-JOB-01..04`; `Test_Job_StageMachine`, `Test_Job_CoverUpAtomic`,
`Test_Job_PrepCapAndToggle`, `Test_Job_CadenceCap`, `Test_Job_GenerationTriggers`,
`Test_Job_IdRoundTrip`, `Test_Job_OriginBranches`.

**Gate.** A generated job's id round-trips byte-identically through rebuild. All four origins fire.

**Rollback.** Tag `s2-economy`.

**Prohibited.** ⛔ Changing the id format (the save contract parses it). ⛔ Queueing jobs at the cap —
Godot **drops** them; reproduce that. ⛔ Clamping outcome dimensions per-term instead of once at the end.

---

## S4 — Save / load

**Objective.** The full save contract, early — because every later slice must stay save-safe.

**Depends on:** S3.

**Creates.** `BMSim`: `UBMSaveSubsystem`, `UBMSaveGame`, `FBMJobSave`, `UBMContentRegistry`.

**Tests.** `Test_Save_FloatExactRoundTrip`, `Test_Save_RebuildContract`,
`Test_Save_JobRebuildByteIdentical`, `Test_Save_VersionRefusal`, `Test_Save_AdditiveField`,
`Test_Save_LoadLeavesPaused`, `Test_Save_ReplayAfterLoad`, `Test_Save_NoUIStateInCampaign`.

**Gate.** Save → diverge → load → **byte-identical state**; replay after load reproduces the same
trajectory; a bad version is refused with state untouched. `[V]` This mirrors
`save_roundtrip_runner`, which passes in the Godot build.

**Rollback.** Tag `s3-jobs`.

**Prohibited.** ⛔ Serializing authored job content. ⛔ Writing a migration path — refusal is the
design. ⛔ Holding pointers across a load; re-resolve by Id (`[V]` the P16 probe lesson).

---

## S5 — Rival AI

**Depends on:** S4.

**Creates.** `BMCore/FBMRivalScoring`, `BMSim/UBMRivalSubsystem`.

**Tests.** `GV-RIVAL-01..08`; `Test_Rival_TelegraphWindow` (never lands on the telegraph tick),
`Test_Rival_TieBreakStability`, `Test_Rival_CandidateOrder`, `Test_Rival_GrudgeSingleWriter`,
`Test_Rival_NoHiddenFieldReads`, `Test_Rival_UnscoredActionsNeverChosen`.

**Gate.** Two identical runs pick identical actions 50/50 `[V]` (the Godot test's own bar).
Telegraph→land window exact.

**Rollback.** Tag `s4-save`.

**Prohibited.** ⛔ Behavior Trees (Locked; it is a scored argmax). ⛔ Adding RNG "for variety" —
jitter is hash-derived. ⛔ Implementing the 5 unscored actions in this slice.

---

## S6 — Loyalty and betrayal

**Depends on:** S4 (parallel with S5).

**Creates.** `BMCore/FBMLoyaltyScoring`, `BMSim/UBMRelationshipSubsystem`.

**Tests.** `GV-LOYAL-01..04`; `Test_Loyalty_DefuseDuringWindow`, `Test_Loyalty_ReassureCostAndEffect`,
`Test_Loyalty_NoNewTelegraphsInCouncil`, `Test_Loyalty_OneIntentPerTick`,
`Test_Loyalty_BetrayalLanding`, `Test_Loyalty_DefuseThenRescore`.

**Gate.** Betrayal is telegraphed, gates re-check every rival tick, and reassurance inside the window
**prevents** it. Both gates required.

**Rollback.** Tag `s4-save`.

**Prohibited.** ⛔ Any untelegraphed betrayal path (brief §7.6 — non-negotiable).
⛔ Exposing hidden motives to the rival scorer or the UI.

---

## S7 — Night Cycle

**Depends on:** S4.

**Creates.** `BMGame/UBMNightCycleComponent`; `DT_BMBalance` phase budgets.

**Tests.** `Test_Phase_OrderAndWrap`, `Test_Phase_BudgetBoundary` (integer-only),
`Test_Phase_SummaryDistrictAgnostic` (fixes TD-06).

**Gate.** Four phases in order, wrapping and incrementing the cycle; COUNCIL gates new betrayal
telegraphs but not open ones.

**Rollback.** Tag `s4-save`.

**Prohibited.** ⛔ StateTree (four states on a tick budget). ⛔ Hardcoding a district id.

---

## S8 — Narrative spine

**Depends on:** S5, S6, S7.

**Creates.** `BMGame/UBMNarrativeComponent`, `BMCore/FBMNarrativeBeats`, `FBMNarrativeState`.

**Tests.** `Test_Narrative_ChainOrder`, `Test_Narrative_BeatSurvivesCap`,
`Test_Narrative_DebtBranches`, `Test_Narrative_EndingLatch`, `Test_Save_NarrativeFlagsRoundTrip`.

**Gate.** The four-job chain completes in order and reaches an ending; a beat blocked by the job cap
**retries rather than dying**; mid-chain save/load is byte-identical `[V]` (the Godot narrative probe's bar).

**Rollback.** Tag `s7-nightcycle`.

**Prohibited.** ⛔ Letting a beat fire out of order. ⛔ Marking a beat fired when the cap blocked it.

---

## S9 — Strategic presentation

**Objective.** The city reads state. Greybox only.

**Depends on:** S8.

**Creates.** `BMGame`: `ABMStrategicCamera`, `ABMCityView`, `UBMCityBuilder`, `ABMVenueMarker`.
`BMUI`: `WBP_HUD`, `WBP_JobPanel`, `WBP_Roster` + view models. Enhanced Input contexts. Common UI stack.

**Tests.** `Test_View_RebuildOnEvents`, `Test_City_FloorsTrackInfluence`, `Test_Camera_ClampsAndBands`,
`Test_UI_NoHiddenMotiveLeak`, `Test_Arch_NoStateWritesFromPresentation`.

**Gate.** Every strategic verb is reachable from the UI; the city visibly changes on ownership flips,
inspections, sabotage and pauses; **no hidden motive is rendered anywhere.**

**Rollback.** Tag `s8-narrative`.

**Prohibited.** ⛔ Authoritative state in a widget or actor. ⛔ Final art. ⛔ Blueprint tick driving sim.

---

## S10 — Playable greybox ★ GATE A

**Objective.** The Godot Month-2 bar, re-cleared in Unreal: **is it still fun with cubes?**

**Depends on:** S9.

**Creates.** `L_BM_Persistent`, `L_GlassWharf_Strategic` (greybox), `DA_WorldSeed_Slice`,
`UBMDebugSubsystem` + `BM.RunProbe`.

**Tests.** `FT_FullCycle_Headless` (functional test, complete cycle, no errors);
`Test_Probe_DeterministicTwice` (two runs, byte-identical — `[V]` the method used in this audit).

**Validation.**
```sh
UnrealEditor-Cmd.exe <proj> -ExecCmds="Automation RunTests BM.; Quit" -unattended -nullrhi
UnrealEditor-Cmd.exe <proj> L_BM_Persistent -ExecCmds="BM.RunProbe 1260; Quit" -unattended -nullrhi
```

**★ GATE A — human judgement required.** Cem plays a full cycle on greybox and answers:
1. Is the strategic loop still enjoyable? (*Godot bar: "fun, stress, very good"*)
2. Is it **at least as good** as the Godot build? — **if worse, SC-3 fires** ([00](00_EXECUTIVE_DECISION.md) §9.2).
3. Can the four legibility questions be answered (money cleaned / heat / rival / loyalty)?

`[V]` **This gate must be a full 20–30 minute session, not a short one.** The Godot Month-2 verdict was
a ~35-tick session and the note says so itself — that debt is repaid here, not inherited.

**Rollback.** Tag `s9-presentation`.

**Prohibited.** ⛔ Entering S11+ without passing Gate A. ⛔ Producing any final art (Locked #15).

---

## S11 — Transition + embodied stub

**Objective.** The round-trip, proven with a *stub* room — persistence before fidelity.

**Depends on:** Gate A passed.

**Creates.** `BMGame`: `UBMTransitionComponent`, `IBMCinematicWorldProvider`,
`ABMAuthoredLevelProvider`, `ABMPlayerPawn` (FP), `ABMInteractionPoint`, `UBMCheatManager`.
`L_Warehouse_Embodied` (greybox box room — deliberately the Godot equivalent, for the S13 A/B).

**Tests.** `FT_Transition_RoundTrip`, `Test_Transition_CheckpointBeforeMutation`,
`Test_Transition_ExclusiveResidency`, `FT_Save_DuringEmbodied`, `Test_Provider_ContractShape`,
`Test_Shipping_NoCheats`.

**Gate.** `[V]` The Godot Month-4 bar: the scene **changes persistent strategic state** and survives
save/load taken before, during and after. Checkpoint written before any mutation. City and embodied
level never co-resident.

**Rollback.** Tag `s10-greybox`.

**Prohibited.** ⛔ Simulation logic inside the scene — verbs only. ⛔ Authoritative state in the Level
Blueprint. ⛔ Art before persistence passes.

---

## S12 — Hero character production

**Objective.** One rigged, animated, identity-stable character (`bengal_lt`).

**Depends on:** Gate A; **blocked on canon** ([11](11_CANONICAL_REFERENCE_INTAKE.md)) and **D-02**.

**Creates.** `SK_BengalLt`, `ABP_BengalLt`, `CR_BengalLt_Face`, animation set (idle, speak, threaten,
turn, gesture, sit), `DA_Char_BengalLt` updated with the actor class.

**Tests.** `Test_Asset_CharacterValidation` (skeleton, LODs, material count, texture budget);
`FT_Character_AnimationSet` (every state plays without error).

**Gate.** Identity is stable across portrait, roster and cinematic lighting `[V]` (brief §18).
Performance budget met. **Cem approves the face** — this is a taste gate, not a technical one.

**Rollback.** Tag `s11-transition`. Falls back to a greybox actor; S13 then cannot pass Gate B.

**Prohibited.** ⛔ Starting before canonical references are approved (brief §20 #5 — an identity
mistake here is expensive to unwind). ⛔ Shipping generated geometry without Blender cleanup +
validation `[V]` (*"green-by-claim is not green"* — a producer's "SHIP" claim hid a broken asset).
⛔ Rigging more than one character.

---

## S13 — The embodied scene ★ GATE B — the reboot thesis

**Objective.** Make the warehouse confrontation *land*.

**Depends on:** S11, S12.

**Creates.** `L_Warehouse_Embodied` at hero fidelity (lighting, materials, rain, atmosphere);
`LS_Warehouse_Entry`, `LS_Confrontation_*`; `WBP_Interact` + dialogue choices; the six verbs
including **plant**; audio (rain, room tone, footsteps, voice).

**Tests.** `FT_Embodied_AllVerbs` (incl. plant), `FT_Embodied_WalkAwayWritesNothing`,
`FT_Embodied_ConsequenceVisibleOnReturn`, `Test_Perf_EmbodiedScene` (60 fps, ≤10 GB VRAM).

**★ GATE B — the decisive gate.** Cem plays the Godot back-room (`cinematic_view_probe.tscn`) and the
Unreal warehouse back to back and answers one question:

> **Does the Unreal scene deliver something the Godot version could not?**

**If no → SC-1 fires: stop. The reboot has no justification.** This must be a real question with a real
possible "no", or the gate is theatre.

**Rollback.** Tag `s12-character`.

**Prohibited.** ⛔ Scope-creeping into a second location, combat, or free roam. ⛔ Letting Sequencer
decide outcomes (it stages; the sim decides). ⛔ Passing the gate on "it looks nicer" — the test is
dramatic weight, not fidelity.

---

## S14 — Content to Data Assets

**Objective.** Pay the data-driven debt (TD-02, TD-03) **before** polish, while content is small.

**Depends on:** Gate B passed.

**Creates.** All `DA_*` assets ([05](05_DATA_MODEL.md) §10); `UBMAssetValidator`;
`BM.MigrateContent` commandlet.

**Tests.** `Test_Content_NoHardcodedJobs`, `Test_Content_WorldFromData`,
`Test_Content_AllDefinitionsValid`, `Test_Asset_ValidationGate`, **full golden-vector re-run**.

**Gate.** Zero authored content in C++; **every golden vector still passes after migration** (proving
the move changed nothing); the validator rejects a deliberately broken asset.

**Rollback.** Tag `s13-embodied`.

**Prohibited.** ⛔ Reordering any contract array during migration ([05](05_DATA_MODEL.md) §4.1) — it
changes tie-breaks and therefore the game. ⛔ "Improving" balance values mid-migration; migrate first,
verify equivalence, tune separately.

---

## S15 — Polish, settings, accessibility

**Depends on:** S14.

**Creates.** `WBP_Settings`, `WBP_Nudges`, `WBP_Ending`; Enhanced Input rebinding; text-size and
subtitle support; performance tiers; audio mix; `L_Council_Embodied` (per D-03).

**Tests.** `FT_Onboarding_RefundTimeline` (`[V]` brief §17.5: decision ≤3 min, operation ≤8 min,
rival ≤15 min, loyalty ≤30 min); `Test_Settings_Persist`, `Test_Input_RebindPersists`,
`Test_Perf_AllTiers`.

**Gate.** All refund-timeline beats hit in a fresh playthrough; rebinding and text size work and persist.

**Rollback.** Tag `s14-content`.

**Prohibited.** ⛔ New mechanics. ⛔ Opening the polish notebook on the city
(`[V]` the ship-first discipline: *"polish defteri AÇILMAZ"*).

---

## S16 — Package and QA ★ GATE C

**Depends on:** S15.

**Creates.** Shipping config, packaged Windows build, crash reporting + version display,
`ATTRIBUTIONS.md` migrated, known-limitations record, performance report.

**Validation.**
```sh
"C:/Program Files/Epic Games/UE_5.8/Engine/Build/BatchFiles/RunUAT.bat" BuildCookRun \
  -project="<abs>/BlackMeridian.uproject" -noP4 -platform=Win64 \
  -clientconfig=Shipping -cook -allmaps -build -stage -pak -archive \
  -archivedirectory="<abs>/Builds"
```

**★ GATE C.** `[V]` Brief §19 Month-6 bar: on a **clean machine without the editor**, the build
launches, saves, loads, completes a Night Cycle, enters and exits the embodied scene, and reaches an
ending — with **no critical defects** and all §9 performance budgets met.

**Rollback.** Tag `s15-polish`.

**Prohibited.** ⛔ Shipping with a failing test. ⛔ Shipping a CC-BY asset whose attribution is not in
the credits (`[V]` commercial release; NC and SA are forbidden outright).

---

## Cross-cutting rules

1. **Every slice ends green.** Full suite + golden vectors pass before the tag.
2. **Tag before starting the next slice** — that tag is the rollback point.
3. **Commit directly to the current branch**, no PRs unless asked (user's standing rule).
4. **Record gate evidence in a note file** (`docs/gates/S<n>.md`), the Godot practice that made this
   audit possible.
5. **Update a living `NOW.md`** in the new repo at the end of each slice.
6. **Never claim a gate passed without recorded command output.**

## Parallelization

`[P]` S5/S6/S7 are independent after S4 and can run concurrently. S12 (character) can run in parallel
with S11 once canon is approved — it is the longest-lead item and the most likely schedule risk, so
start it as early as its blockers allow.

---

**Next:** [08_TEST_STRATEGY.md](08_TEST_STRATEGY.md)
