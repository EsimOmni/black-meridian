# 03 — Behavioral Port Matrix

Every system in the Godot build, classified. This is the contract between the validated reference and
the Unreal implementation.

**Dispositions:** `PRESERVE` (behavior carries over intact) · `ADAPT` (behavior carries, mechanism
changes) · `REDESIGN` (the reboot deliberately changes the behavior) · `CUT` (does not come across) ·
`DEFER` (out of slice scope, revisit later).

**Unreal owner** names the class that owns the behavior. Full architecture:
[04_UNREAL_ARCHITECTURE.md](04_UNREAL_ARCHITECTURE.md). Acceptance tests:
[08_TEST_STRATEGY.md](08_TEST_STRATEGY.md).

Tags: `[V]` = Verified from repository · `[I]` = Inferred · `[P]` = Proposed

---

## 1. Time, tick and pause

| System | Existing behavior | Evidence | Disposition | Unreal owner | Acceptance test |
|---|---|---|---|---|---|
| **Real-time with pause** | Sim advances only while unpaused; game starts **PAUSED** so the player makes the first move | `[V]` `time_service.gd`; `bootstrap.gd` ends `_ready` with `set_speed(PAUSED)` | **PRESERVE** | `UBMTimeSubsystem` | `Test_Time_StartsPaused`, `Test_Time_NoTickWhilePaused` |
| **Three speeds** | `PAUSED 0.0 / NORMAL 1.0 / FAST 2.0 / FASTER 4.0`; `cycle_speed` never reaches PAUSED; un-pausing always returns to NORMAL (not the prior speed) | `[V]` `BM.SPEED_SCALE`, `time_service.gd::toggle_pause/cycle_speed` | **PRESERVE** incl. the quirk | `UBMTimeSubsystem` | `Test_Time_SpeedCycleOrder`, `Test_Time_UnpauseReturnsNormal` |
| **1 s strategic tick** | `STRATEGIC_TICK_SECONDS = 1.0`; accumulator drains in a **while-loop**, so several ticks may fire in one frame after a hitch | `[V]` `time_service.gd::_process` | **PRESERVE** — the drain loop is required for tick-count identity under frame hitches | `UBMTimeSubsystem` | `Test_Time_DrainLoopCatchUp` (simulate 3.5 s delta → exactly 3 ticks, 0.5 s retained) |
| **Rival tick every 10 ticks** | Fires on the *same* tick when `tick_index % 10 == 0`, after `strategic_tick` | `[V]` `BM.RIVAL_TICK_INTERVAL`, `_do_tick` | **PRESERVE** | `UBMTimeSubsystem` | `Test_Time_RivalTickCadence` |
| **Listener order across systems** | Determined by Godot autoload order — implicit and fragile | `[V]` `project.godot` order; noted in the source spec as a dependency to verify | **ADAPT** — replace with an **explicit, declared** tick order | `UBMSimulationCoordinator` | `Test_Tick_ExplicitOrder` |

**Port note `[P]`:** the single most important change in this table is the last row. Godot's ordering
was *incidental*; Unreal's must be **declared in one place** and asserted by a test. Order:
`Economy → Heat → CentralPressure → Jobs → NightCycle → Narrative`, then on rival ticks
`Relationships → Rival`. See [04_UNREAL_ARCHITECTURE.md](04_UNREAL_ARCHITECTURE.md) §5.

---

## 2. Economy

| System | Existing behavior | Evidence | Disposition | Unreal owner | Acceptance test |
|---|---|---|---|---|---|
| **Dirty / clean two-currency** | Dirty is immediate + creates exposure; clean is slow + required for upgrades | `[V]` brief §7.2; `economy_service.gd` | **PRESERVE** | `FBMEconomy` (static) | `Test_Economy_TwoCurrencySettle` |
| **DirtyIncome formula** | `BaseYield × DistrictDemand × OperationalStaff × ControlModifier × (1−disruption)`, rounded to int; 0 if paused or not a racket | `[V]` `economy_math.gd::compute_dirty_income` | **PRESERVE** exactly | `FBMEconomyMath::ComputeDirtyIncome` | Golden vector `GV-ECON-01` |
| **ControlModifier table** | FORTIFIED 1.2 · CONTROLLED 1.0 · INFLUENCED 0.6 · COMPROMISED 0.4 · CONTESTED 0.3 · UNKNOWN 0.0 | `[V]` `economy_math.gd::control_modifier` | **PRESERVE** | same | `GV-ECON-02` |
| **DistrictDemand** | `0.5 + prosperity` (0.5–1.5) | `[V]` `district_data.gd` | **PRESERVE** | `FBMDistrictState` | `GV-ECON-03` |
| **CleanCapital formula** | `LaunderingCapacity × FrontEfficiency × (1 − OperatingCost)` | `[V]` `economy_math.gd::compute_front_clean` | **PRESERVE** | `FBMEconomyMath` | `GV-ECON-04` |
| **ExposureGain** | `UnlaunderedOverflow × RacketRisk × DistrictVisibility × 0.0001` | `[V]` `economy_math.gd::compute_exposure` | **PRESERVE** incl. the 1e-4 scalar | `FBMEconomyMath` | `GV-ECON-05` |
| **Laundering as the real constraint** | `overflow = max(0, dirty_income − laundering_capacity)`; player usually holds more dirty than launderable | `[V]` `_settle_faction`; brief §7.2 "economic tension" | **PRESERVE** — this *is* the economic game | `FBMEconomy` | `Test_Economy_OverflowPressure` |
| **Front pressure verb** | +100 capacity per action, costs 400 clean, hard cap 1500 | `[V]` `FRONT_PRESSURE_STEP/COST`, `FRONT_CAPACITY_MAX` | **PRESERVE** | `UBMEconomySubsystem::PressureFront` | `Test_Economy_PressureFrontCapAndCost` |
| **Pause-racket verb** | Paused racket yields 0 but stops generating exposure | `[V]` `set_racket_paused` | **PRESERVE** | `UBMEconomySubsystem` | `Test_Economy_PausedRacketZeroYield` |
| **Per-tick settle order** | clear exposure → settle each faction (**array order**) → district heat → central pressure | `[V]` `_on_strategic_tick` | **PRESERVE** — order is load-bearing | `UBMEconomySubsystem` | `Test_Economy_SettleOrder` |
| **Operative pool** | Conserved; `free = pool − assigned`; assign/recall move staff, never mint it | `[V]` `operative_math.gd` | **PRESERVE** | `FBMOperativeMath` | `Test_Operatives_Conservation` |

---

## 3. Heat, evidence, pressure

| System | Existing behavior | Evidence | Disposition | Unreal owner | Acceptance test |
|---|---|---|---|---|---|
| **Local heat rise/decay** | Rise `+= tick_exposure × 0.05` when `exposure ≥ 0.008`; else decay `−0.0006`, **only when no inspection is running** | `[V]` `_update_district_heat` | **PRESERVE** | `UBMHeatSubsystem` | `GV-HEAT-01` |
| **Heat → disruption** | 0 below heat 0.3; then linear `(h−0.3)/0.7 × 0.6` | `[V]` `disruption_from_heat` | **PRESERVE** | `FBMEconomyMath` | `GV-HEAT-02` |
| **Inspection latch/re-arm** | Fires once per excursion at combined ≥ 0.45; runs 30 ticks; disruption floor 0.8; re-arms only below **0.30** | `[V]` `HEAT_INSPECTION_*`, `INSPECTION_*` | **PRESERVE** — hysteresis is the point | `UBMHeatSubsystem` | `Test_Heat_InspectionHysteresis` (must exercise a full fire→cool→re-arm→re-fire cycle) |
| **Evidence cases** | Max 4 per district; `combined = heat + 0.5 × Σweights`; at cap the **oldest (index 0)** grows instead of a new case | `[V]` `evidence_math.gd` | **PRESERVE** incl. the index-0 rule | `FBMEvidence` | `GV-EVID-01` |
| **Case kind selection** | `posmod(hash(source_id), 4)` — deterministic hash, explicitly *not* a roll | `[V]` `kind_for` | **ADAPT** — same behavior, hash re-specified (§9) | `FBMEvidence::KindFor` | `GV-EVID-02` |
| **Case id format** | `case@<district>@<kind>@<tick>` | `[V]` `deposit` | **PRESERVE** — parsed by job ids | `FBMEvidence` | `GV-EVID-03` |
| **Erode vs remove** | Job resolution *erodes the strongest* case passively; EVIDENCE_CHAIN jobs *remove a targeted* case | `[V]` `erode_strongest` vs `JobDirector` `remove_case` | **PRESERVE** — two distinct mechanisms | `FBMEvidence` | `Test_Evidence_ErodeVsRemove` |
| **Central Pressure** | City signal = **mean** of district combined pressure; rises `+ (city−cur) × 0.15` when city ≥ 0.35; else `−0.01`/tick | `[V]` `pressure_math.gd` | **PRESERVE** — mean, not sum, is deliberate | `FBMPressureMath` | `GV-PRESS-01` |
| **Central alert** | Fires at 0.6, runs 20 ticks, re-arms below 0.4, relieves district inspection threshold by 0.15 while active | `[V]` `CENTRAL_ALERT_*` | **PRESERVE** | `UBMPressureSubsystem` | `Test_Pressure_AlertLifecycle` |
| **Evidence chains as named investigations** | Brief §7.3 wants linked people/vehicles/venues; implementation is a **flat weighted case**, not a graph | `[V]` `evidence_case_data.gd` has only `{id, kind, weight, label}` | **DEFER** — flat model ships the slice; the graph is full-game work | `FBMEvidence` | n/a (scope note) |
| **Pressure endgame conditions** | Brief §7.3 lists freezes/raids/defections; **not implemented** | `[V]` absent | **DEFER** | — | n/a |

---

## 4. Rival AI

| System | Existing behavior | Evidence | Disposition | Unreal owner | Acceptance test |
|---|---|---|---|---|---|
| **Utility scoring** | Per-action formulas over weakness, aggression, caution, cunning, heat, grudge | `[V]` `rival_scoring.gd::score_action` | **PRESERVE** all five implemented formulas verbatim | `FBMRivalScoring` | `GV-RIVAL-01..05` |
| **Action set** | 10 declared, **only 5 scored** (EXPAND, PROBE, SABOTAGE, RECRUIT, FRAME); the rest return `-INF` | `[V]` `default: -INF` | **ADAPT** — port the 5 exactly; keep the enum open; do **not** treat 5 as the design | `FBMRivalScoring` | `Test_Rival_UnscoredActionsNeverChosen` |
| **Commit threshold** | Candidate discarded below score 0.3 | `[V]` `COMMIT_THRESHOLD` | **PRESERVE** | `FBMRivalScoring` | `GV-RIVAL-06` |
| **Telegraph → land** | Intent commits, waits `TELEGRAPH_LEAD_RIVAL_TICKS = 3` rival ticks (~30 s), then lands; never lands on the telegraph tick | `[V]` `rival_director.gd`; verified by `test_rival_ai` | **PRESERVE** — the player's warning window | `UBMRivalSubsystem` | `Test_Rival_TelegraphWindow` |
| **Deterministic tie-break** | Strict `>` in argmax ⇒ **first candidate in authored order wins exact ties**; hash jitter in `[0, 0.01)` salted by `intents_committed` | `[V]` `choose_move`, `tie_jitter` | **PRESERVE** — both the jitter and the first-wins rule | `FBMRivalScoring` | `GV-RIVAL-07`, `Test_Rival_TieBreakStability` |
| **Candidate generation order** | districts (authored) → venues (authored) → actions `[PROBE, SABOTAGE, FRAME]` in literal order; then EXPAND for non-owned; then RECRUIT over characters | `[V]` `choose_move` | **PRESERVE** — order *is* the tie-break | `FBMRivalScoring` | `Test_Rival_CandidateOrder` |
| **Landing effects** | SABOTAGE 0.35/40t · PROBE 0.10/20t · EXPAND flips owner to INFLUENCED · FRAME +0.25 district heat · RECRUIT +0.15 leverage | `[V]` `_land`, `RivalScoring` constants | **PRESERVE** | `UBMRivalSubsystem` | `GV-RIVAL-08` |
| **Grudge** | Raised only by job resolution (`rival_suspicion`); decays 0.05/rival tick; adds 0.35 score bonus + 0.15 sabotage lean | `[V]` `JobDirector` (sole raiser), `RivalDirector` (decay) | **PRESERVE** — single-writer discipline | `UBMRivalSubsystem` | `Test_Rival_GrudgeSingleWriter` |
| **Fairness rule** | `recruit_susceptibility` reads only public fields (trust, grievance, ambition) — never hidden ones | `[V]` `rival_scoring.gd` comment + code | **PRESERVE** — an explicit design ethic | `FBMRivalScoring` | `Test_Rival_NoHiddenFieldReads` |
| **Rival memory** | Brief §7.4 wants promises/humiliations/spared characters; implemented as a **single `grudge` float** | `[V]` `faction_data.gd` | **DEFER** — grudge ships the slice | `UBMRivalSubsystem` | n/a |
| **Difficulty levels** | Not implemented | `[V]` absent | **DEFER** | — | n/a |

---

## 5. Jobs

| System | Existing behavior | Evidence | Disposition | Unreal owner | Acceptance test |
|---|---|---|---|---|---|
| **Four-stage lifecycle** | INTAKE → PREPARATION → INTERVENTION → COVER_UP → RESOLVED; COVER_UP is **transient**, resolved in the same call | `[V]` `job_lifecycle.gd` | **PRESERVE** — a save can never observe COVER_UP split from its outcome | `FBMJobLifecycle` | `Test_Job_StageMachine`, `Test_Job_CoverUpAtomic` |
| **Prep cap** | Max 3 (`JOB_MAX_PREP_ACTIONS`), toggle-select, re-selecting deselects | `[V]` `choose_prep` | **PRESERVE** | `FBMJobLifecycle` | `Test_Job_PrepCapAndToggle` |
| **Nine outcome dimensions** | 3 signed (−1..1), 6 unsigned (0..1); resolution = sum of prep+approach+coverup, clamped **once at the end** | `[V]` `job_resolution.gd` | **PRESERVE** | `FBMJobResolution` | `GV-JOB-01` |
| **Expiry outcome** | Fixed `{evidence 0.3, public_fear 0.1, delayed_consequence 0.5}` | `[V]` `expired()` | **PRESERVE** | `FBMJobResolution` | `GV-JOB-02` |
| **Concurrency cap** | `MAX_CONCURRENT_JOBS = 3`; a trigger at cap is **dropped**, not queued | `[V]` `_try_offer` | **PRESERVE** (with the narrative exception below) | `UBMJobSubsystem` | `Test_Job_CadenceCap` |
| **Systemic generation** | 4 origins wired: rival SABOTAGE→retaliation · EXPAND→contested ground · inspection→bury case · betrayal→contested ground · delayed_consequence→follow-up | `[V]` `job_director.gd` triggers | **PRESERVE** | `UBMJobSubsystem` | `Test_Job_GenerationTriggers` |
| **Follow-up scheduling** | `delayed_consequence ≥ 0.25` schedules a follow-up 20 ticks later | `[V]` `FOLLOWUP_THRESHOLD/LEAD_TICKS` | **PRESERVE** | `UBMJobSubsystem` | `GV-JOB-03` |
| **Id-encoded targeting** | Generated ids encode template + targets + tick; content is a pure function of the id | `[V]` `job_generator.gd` | **PRESERVE** — this is what makes save/rebuild work | `FBMJobGenerator` | `Test_Job_IdRoundTrip` |
| **Rebuild-from-save** | `JobTemplates.by_id` → else `JobGenerator.rebuild(id)` → else drop with warning; burycase returns null if the case is gone | `[V]` `save_service.gd` load path | **PRESERVE** incl. the honest-null | `UBMSaveSubsystem` | `Test_Save_JobRebuildByteIdentical` |
| **Variant selection** | `avalanche(id.hash()) mod variant_count` — deterministic text variety | `[V]` `_variant_index` | **ADAPT** — hash re-specified (§9) | `FBMJobGenerator` | `GV-JOB-04` |
| **Authored job content** | Code-as-data in GDScript; the `.tres` migration was **explicitly CUT** ship-first | `[V]` `job_templates.gd`, `narrative_jobs.gd`; `docs/NOW.md` | **REDESIGN** → `UBMJobDefinition : UPrimaryDataAsset` | Data Asset | `Test_Content_NoHardcodedJobs` |
| **Post-outcome origin branches** | EVIDENCE_CHAIN burns the targeted case · RIVAL_PROVOCATION raises grudge · TERRITORY_LOSS reclaims to CONTESTED (not fully) | `[V]` `_apply_and_emit` | **PRESERVE** incl. "reclaim to CONTESTED" | `UBMJobSubsystem` | `Test_Job_OriginBranches` |

---

## 6. Loyalty and betrayal

| System | Existing behavior | Evidence | Disposition | Unreal owner | Acceptance test |
|---|---|---|---|---|---|
| **Motive network** | 7 public/hidden motive fields + relationship edges; **not** one loyalty number | `[V]` `character_data.gd`; brief §7.6 | **PRESERVE** | `FBMCharacterState` | `Test_Loyalty_MotiveFields` |
| **BetrayalPressure** | `ambition + grievance + rival_leverage + survival_pressure − trust − shared_success − fear`, clamped 0..4 | `[V]` `betrayal_pressure()` | **PRESERVE** | `FBMCharacterState` | `GV-LOYAL-01` |
| **Two gates** | Gate 1 pressure ≥ `threshold × 2.0`; Gate 2 opportunity ≥ 0.3 (inspection +0.35, sabotage +0.3, leverage ×0.5) | `[V]` `loyalty_scoring.gd` | **PRESERVE** — both gates or no betrayal | `FBMLoyaltyScoring` | `GV-LOYAL-02` |
| **Telegraph + preventability** | 6 rival ticks (~60 s) of warning; gates **re-checked every tick**; failing either defuses | `[V]` `relationship_service.gd::_advance_intent` | **PRESERVE** — this is what makes it preventable | `UBMRelationshipSubsystem` | `Test_Loyalty_DefuseDuringWindow` |
| **Reassure verb** | 200 clean capital, +0.15 trust, +0.15 shared_success, reveals the motive | `[V]` `reassure()` | **PRESERVE** | `UBMRelationshipSubsystem` | `Test_Loyalty_ReassureCostAndEffect` |
| **COUNCIL gate** | No *new* telegraphs during COUNCIL; open intents still advance | `[V]` `_on_rival_tick` | **PRESERVE** | `UBMRelationshipSubsystem` | `Test_Loyalty_NoNewTelegraphsInCouncil` |
| **One new intent per tick** | `MAX_NEW_INTENTS_PER_RIVAL_TICK = 1` | `[V]` constant | **PRESERVE** | `UBMRelationshipSubsystem` | `Test_Loyalty_OneIntentPerTick` |
| **Deterministic candidate order** | Sort by score DESC, ties by **ascending authored index** | `[V]` `choose_betrayers` comparator | **PRESERVE** — explicit rule, not sort stability | `FBMLoyaltyScoring` | `GV-LOYAL-03` |
| **Driving motive** | Strict argmax over `[ambition, grievance, rival_leverage, survival_pressure]`; ties → earliest term | `[V]` `driving_motive` | **PRESERVE** | `FBMLoyaltyScoring` | `GV-LOYAL-04` |
| **Landing effect** | Venue flips to the rival as INFLUENCED; grievance/leverage zeroed | `[V]` `_land` | **PRESERVE** | `UBMRelationshipSubsystem` | `Test_Loyalty_BetrayalLanding` |
| **Hidden motives never rendered** | Roster shows public fields only | `[V]` `roster_panel.gd`; `docs/NOW.md` | **PRESERVE** — the asymmetry is the design | UI layer | `Test_UI_NoHiddenMotiveLeak` |
| **Re-score after defuse (same tick)** | A just-defused character can be re-scored as a fresh candidate in the same rival tick | `[V]` ordering in `_on_rival_tick` | **PRESERVE** *deliberately*, with a test that pins it | `UBMRelationshipSubsystem` | `Test_Loyalty_DefuseThenRescore` |
| **Multi-lieutenant / hidden motives (P10b)** | Partially deferred in Godot | `[V]` `docs/NOW.md` open list | **DEFER** | — | n/a |

---

## 7. Night Cycle and narrative

| System | Existing behavior | Evidence | Disposition | Unreal owner | Acceptance test |
|---|---|---|---|---|---|
| **Phase machine** | COUNCIL 240 → OPERATIONS 1080 → CRISIS 360 → RECKONING 120 ticks; wraps and increments cycle | `[V]` `night_cycle.gd` | **PRESERVE** structure; **ADAPT** budgets for the 20–30 min slice | `UBMNightCycleComponent` | `Test_Phase_OrderAndWrap` |
| **Budget-only advance** | Phases advance purely on elapsed ticks, no gating | `[V]` `_on_strategic_tick` | **PRESERVE** | same | `Test_Phase_BudgetBoundary` (integer boundaries, dedicated test) |
| **Cycle summary** | Tracks dirty/clean earned + heat delta; **not saved**; hardcodes `glass_wharf` | `[V]` `_reset_summary` | **ADAPT** — generalize the district reference (TD-06) | `UBMNightCycleComponent` | `Test_Phase_SummaryDistrictAgnostic` |
| **Authored spine** | 4-job chain, strictly sequential, gated on *previous resolved + lead ticks* | `[V]` `narrative_beats.gd` | **PRESERVE** | `UBMNarrativeComponent` | `Test_Narrative_ChainOrder` |
| **Cadence deference** | At job cap the beat retries each tick **without** marking itself fired | `[V]` `narrative_director.gd` | **PRESERVE** — "never let an authored beat die to the cadence cap" | `UBMNarrativeComponent` | `Test_Narrative_BeatSurvivesCap` |
| **Authored setup, systemic resolution** | `beat_debt` raises leverage/survival floors that alone do **not** open the crisis; the player's approach decides | `[V]` `apply_fire`, `apply_resolution` | **PRESERVE** — the model for all authored content | `UBMNarrativeComponent` | `Test_Narrative_DebtBranches` |
| **Narrative flags** | `fired@`, `resolved@`, `ledger_secured`, `accord_stance`, `ending` in a flag bag, saved additively | `[V]` `GameState.narrative_flags` | **ADAPT** — typed `FBMNarrativeState` struct, not a loose map | `FBMNarrativeState` | `Test_Save_NarrativeFlagsRoundTrip` |
| **Three endings** | truce→accord · leverage→armed_peace · war→war (default), latched, 120-tick settle | `[V]` `ready_ending` | **PRESERVE** | `UBMNarrativeComponent` | `Test_Narrative_EndingLatch` |
| **`ending_seen` UI flag in narrative state** | UI bookkeeping stored in campaign flags | `[V]` `ending_panel.gd` | **REDESIGN** — move to UI-state, out of campaign save | UI state | `Test_Save_NoUIStateInCampaign` |

---

## 8. Save / load

| System | Existing behavior | Evidence | Disposition | Unreal owner | Acceptance test |
|---|---|---|---|---|---|
| **Source-of-truth vs rebuilt** | Districts/venues/factions/characters fully serialized; **jobs store runtime state only** and rebuild content from id | `[V]` `save_codec.gd` | **PRESERVE** — the central save idea | `UBMSaveSubsystem` | `Test_Save_RebuildContract` |
| **Float-exact round-trip** | `var_to_str` chosen over JSON *specifically* to preserve replay determinism | `[V]` `save_codec.gd` doc + `tasks/lessons.md` | **ADAPT** — UE `FArchive` binary is exact natively; the *requirement* persists | `UBMSaveSubsystem` | `Test_Save_FloatExactRoundTrip` |
| **Hard version refusal** | Mismatch → refuse whole load, leave state untouched, no migration | `[V]` `decode_state` + `load_game`; verified by the round-trip runner | **PRESERVE** | `UBMSaveSubsystem` | `Test_Save_VersionRefusal` |
| **Additive tolerance** | New fields added within a version via `.get(key, default)` | `[V]` throughout `decode_*` | **ADAPT** — `FArchive` custom version + defaulted UPROPERTYs | `UBMSaveSubsystem` | `Test_Save_AdditiveField` |
| **Load leaves game paused** | Verified assertion in the smoke runner | `[V]` `bootstrap_smoke_runner` "ok: load leaves the game paused" | **PRESERVE** | `UBMSaveSubsystem` | `Test_Save_LoadLeavesPaused` |
| **Cinematic checkpoint** | `checkpoint` slot written **before** any scene mutation | `[V]` `cinematic_transition.gd` | **PRESERVE** | `UBMTransitionSubsystem` | `Test_Transition_CheckpointBeforeMutation` |
| **Deterministic replay after load** | Save → diverge → load → replay reproduces state | `[V]` round-trip runner, run this session | **PRESERVE** — the headline invariant | `UBMSaveSubsystem` | `Test_Save_ReplayAfterLoad` |
| **Auto-load checkpoint on crash** | Checkpoint is written but never auto-restored | `[V]` no handler found | **DEFER** — note the gap | — | n/a |

---

## 9. Determinism mechanics

| System | Existing behavior | Evidence | Disposition | Unreal owner | Acceptance test |
|---|---|---|---|---|---|
| **Zero gameplay RNG** | No RNG anywhere in the simulation; enforced by source-scanning tests | `[V]` `test_rival_ai`, `test_job_generation` scan for RNG use | **PRESERVE** + keep the scanning test | `FBMDeterminism` | `Test_Determinism_NoRandomInSimModule` (static scan of the sim module) |
| **splitmix64 avalanche over string hash** | Drives rival tie-jitter **and** job-variant selection; relies on signed 64-bit wraparound + Godot's `String.hash()` | `[V]` `rival_scoring.gd::_avalanche`, duplicated in `job_generator.gd` | **ADAPT** — re-specify as explicit `uint64`; **highest-risk item in the port** | `FBMHash` (one shared impl) | `GV-HASH-01..N` (extracted vectors) |
| **Duplicated `_avalanche`** | Byte-identical copy in two files, deliberate, comment demands they stay in sync | `[V]` both files | **REDESIGN** — single `FBMHash` utility (TD-05) | `FBMHash` | `Test_Hash_SingleImplementation` |
| **Iteration-order dependence** | Faction array order drives settle order; district→venue order drives rival tie-breaks; evidence index 0 = oldest | `[V]` throughout | **PRESERVE** — use ordered containers, never unordered maps, on these paths | data structs | `Test_Determinism_StableOrdering` |
| **Float threshold comparisons** | Exact operators matter (`>=` vs `>`) at every gate | `[V]` enumerated in the source spec | **PRESERVE** exactly | all math | golden vectors |
| **Never test on a threshold** | `tasks/lessons.md`: a value landing exactly on the 1.4 gate flaked | `[V]` lesson entry | **PRESERVE** as a test-authoring rule: ≥0.05 margin, boundaries get integer-only dedicated tests | test suite | convention |

---

## 10. Presentation

| System | Existing behavior | Evidence | Disposition | Unreal owner | Acceptance test |
|---|---|---|---|---|---|
| **Authority invariant** | Presentation never writes authoritative state; verified zero violations | `[V]` full read of all presentation/UI scripts | **PRESERVE** — hard architectural rule (Locked #8) | all | `Test_Arch_NoStateWritesFromPresentation` |
| **Management camera** | ~40–50° down, height-based zoom 18–120, clamped pan, no rotation | `[V]` `management_camera.gd` | **PRESERVE** the model; retune values | `ABMStrategicCamera` | `Test_Camera_ClampsAndBands` |
| **City as visual proxy** | Rebuilt on signals (districts changed, rival landed, job resolved, inspection start/end, betrayal) — not per-frame polling | `[V]` `city_view.gd` | **ADAPT** — event-driven view model | `UBMCityViewModel` | `Test_View_RebuildOnEvents` |
| **KitAssembler** | `floors = 2 + influence×4`; variant `hash(venue.id) & 1`; grid cell 4.5 | `[V]` `kit_assembler.gd` | **ADAPT** — state→visual mapping preserved, Unreal instancing | `UBMCityBuilder` | `Test_City_FloorsTrackInfluence` |
| **Traffic / crowd illusion** | MultiMesh, GPU vertex-shader flow, **no RNG**, no agents | `[V]` `traffic_proxy.gd`, `crowd_proxy.gd` | **ADAPT** — ISM/HISM + niagara | `ABMCityAmbience` | perf test only |
| **Rain / steam / ripple VFX** | Presentation-only sibling nodes | `[V]` P13b–e | **ADAPT** — Niagara | `ABMWeather` | perf test only |
| **Splat rendering (GDGS)** | 542k splats @ 483 fps, custom 4.7 patch | `[V]` `P01-splat-benchmark.md` | **CUT** — see [00_EXECUTIVE_DECISION.md](00_EXECUTIVE_DECISION.md) §5.1; revisit via D-07 | — | n/a |
| **CinematicWorldProvider seam** | Static factory returning `{center, floor_y, bounds_half}`; one flag swaps backends | `[V]` `cinematic_world_provider.gd` | **PRESERVE the pattern**, drop the splat branch | `IBMCinematicWorldProvider` | `Test_Provider_ContractShape` |
| **Mesh interior (8×6 m box room)** | Code-built primitives, greybox capsule actors, one room for both scene types | `[V]` `mesh_world_provider.gd` | **REDESIGN** — authored Level, real characters, two spaces | authored Levels | slice acceptance |
| **2D portrait roster** | Portraits + public motive network, no 3D cast | `[V]` `roster_panel.gd` | **REDESIGN** — the trim the reboot exists to reverse | UMG + 3D cast | slice acceptance |
| **UI built in code** | Every panel constructed in GDScript | `[V]` all `scenes/ui/*.gd` | **REDESIGN** — UMG assets, Common UI if justified | UMG | `Test_UI_NoLayoutInCpp` |
| **Debug keys mutate sim** | `B` force-arms betrayal, `N` deposits evidence | `[V]` `bootstrap.gd` | **ADAPT** — dev-only cheat manager, stripped from Shipping | `UBMCheatManager` | `Test_Shipping_NoCheats` |

---

## 11. Content and pipeline

| System | Existing behavior | Evidence | Disposition | Unreal owner | Acceptance test |
|---|---|---|---|---|---|
| **World seeded in code** | `WorldSeed.build()` constructs all districts/venues/factions/characters | `[V]` `world_seed.gd` | **REDESIGN** → Data Assets (TD-02, Locked #5) | `UBMWorldSeedDataAsset` | `Test_Content_WorldFromData` |
| **GLB validation gate** | `GLBValidator` checks scale, pivot, materials, draw calls, UVs; "green-by-claim is not green" | `[V]` `glb_validator.gd`; `tasks/lessons.md` | **REDESIGN** — `UBMAssetValidator` (Unreal Data Validation) | validator | `Test_Asset_ValidationGate` |
| **License ledger** | CC0/CC-BY only; credits written verbatim; NC and SA forbidden | `[V]` `assets/ATTRIBUTIONS.md` | **PRESERVE** — migrate the ledger, don't restart it | `ATTRIBUTIONS.md` | `Test_Asset_LicenseLedgerComplete` |
| **AI-assisted asset generation** | Local Hunyuan3D, Sketchfab CC-BY, Blender cleanup; generated geometry is **provisional until validated** | `[V]` `tasks/lessons.md`, `CLAUDE.md` | **ADAPT** — same doctrine, Unreal import gate | pipeline | see [09](09_ASSET_AND_CHARACTER_PIPELINE.md) |
| **Character canon** | Species **placeholders**; portraits explicitly swappable pending the world-bible lock | `[V]` brief §4, §20 #5; `docs/NOW.md` | **DEFER** — blocked on external canon | see [11](11_CANONICAL_REFERENCE_INTAKE.md) | n/a |

---

## 12. Summary

| Disposition | Count | Character of the group |
|---|---|---|
| **PRESERVE** | ~55 | The whole validated simulation: economy, heat, evidence, pressure, rival scoring, jobs, loyalty, phases, narrative spine, save contract, determinism rules |
| **ADAPT** | ~20 | Same behavior, engine-appropriate mechanism: subsystems, binary save, hash re-spec, instancing, explicit tick order |
| **REDESIGN** | ~9 | Content→data, UI→UMG, and the embodied layer the reboot exists for |
| **CUT** | ~5 | GDScript, GDGS/splats, godot-ai rail, Godot test harness, `var_to_str` |
| **DEFER** | ~8 | Evidence graphs, rival memory, difficulty, pressure endgame, multi-lieutenant, loss conditions, crash auto-restore, character canon |

**The shape of the work:** the simulation is a *transcription* problem with a hard determinism
constraint; the embodied layer is a *creation* problem. Budget accordingly — and note that the
transcription half is the part with 24 passing tests and byte-identical golden vectors to check
against, while the creation half is the part that can fail on taste.

---

**Next:** [04_UNREAL_ARCHITECTURE.md](04_UNREAL_ARCHITECTURE.md)
