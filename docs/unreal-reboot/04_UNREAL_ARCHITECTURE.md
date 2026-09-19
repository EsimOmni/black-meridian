# 04 — Unreal Architecture

**Rule for this document:** every recommendation maps to an observed Black Meridian requirement.
Nothing is here because Unreal offers it.

Tags: `[V]` Verified from repository · `[I]` Inferred · `[P]` Proposed · `[U]` Unverified

**Engine:** `[V]` UE **5.8.2** (`++UE5+Release-5.8`, CL 56702186), installed at
`C:\Program Files\Epic Games\UE_5.8`. Project type: **C++** (Locked #5).

---

## 1. The governing principle

> **The strategic simulation is authoritative. Presentation visualizes and interacts with it, but
> never owns it.** `[V]` brief §1, verified to hold with zero violations in the Godot build.

In Unreal terms this becomes three hard rules:

1. **Authoritative state lives in C++ structs owned by subsystems.** Never in an Actor, never in a
   Widget, never in a Blueprint, never in a Level Blueprint (Locked #6, #8).
2. **Presentation reads through view models and writes through verbs.** A widget may call
   `PressureFront(...)`; it may never assign `Venue.LaunderingCapacity`.
3. **The simulation must run headless with no world, no actors and no rendering** — because that is
   how it gets tested (`[V]` the Godot suite does exactly this).

---

## 2. Module structure

`[P]` Four modules. The split exists to make rule 3 enforceable *by the linker*, not by discipline.

```
BlackMeridian.uproject
└─ Source/
   ├─ BMCore/            Runtime  — pure deterministic domain logic. NO Engine dependency.
   ├─ BMSim/             Runtime  — subsystems that own state and drive ticks.
   ├─ BMGame/            Runtime  — actors, player, transitions, gameplay glue.
   ├─ BMUI/              Runtime  — UMG widgets, view models.
   └─ BMEditor/          Editor   — validators, commandlets, golden-vector tooling.
```

| Module | Depends on | Contains | Must NOT contain |
|---|---|---|---|
| **BMCore** | `Core` only | All math and rules: economy, heat, evidence, pressure, loyalty, rival scoring, job resolution, hashing, state structs, **the save FORMAT** (§8) | Any `UObject`-derived gameplay type, any Actor, any rendering, **any file I/O** — `[V]` now enforced by `BM.Save.NoFileIoInBMCore`, and this row is what settled where the save codec lives |
| **BMSim** | `Core`, `CoreUObject`, `Engine`, `BMCore` | Subsystems, tick coordinator, save, data assets | Actors, widgets |
| **BMGame** | + `BMSim`, `EnhancedInput`, `LevelSequence` | Player pawn, cameras, city view, transition manager, interaction actors | Authoritative state, game rules |
| **BMUI** | + `UMG`, `BMSim` | Widgets, view models | Authoritative state, rules |
| **BMEditor** | + `UnrealEd`, `DataValidation` | Asset validators, golden-vector extractor/comparator | Anything shipped |

**Why BMCore has no Engine dependency `[P]`:** it is the concrete, compiler-enforced version of the
Godot lesson *"any unit-testable logic goes in a `class_name` helper, never inside an autoload"*
(`[V]` `tasks/lessons.md` — statics on an autoload script don't resolve via preload). If BMCore cannot
`#include "Engine.h"`, no one can accidentally reach for `GWorld` inside a formula. Golden-vector
tests link BMCore alone.

---

## 3. Subsystems and ownership

### 3.1 The lifetime decision, and why it is not cosmetic

`[V]` The Godot build draws a deliberate line: `GameState`, `TimeService`, `EconomyService`,
`JobDirector`, `SaveService`, `RivalDirector` are **autoloads**, while `NightCycle`,
`RelationshipService`, `NarrativeDirector`, `CinematicTransition` are **scene-wired nodes**.

The stated reason (`tasks/lessons.md`): *"NightCycle as an autoload would exist in EVERY unit-test
scene and silently advance phases under P05–P08 tests."* A driver that mutates shared state must not
run under other systems' tests.

`[P]` **Port that line directly:**

| Godot | Unreal | Lifetime | Rationale |
|---|---|---|---|
| Autoload | `UGameInstanceSubsystem` | Survives level transitions | Campaign state must survive city → warehouse → city (Locked #8 forbids Level Blueprint ownership) |
| Scene-wired node | `UActorComponent` on `ABMGameMode`, spawned explicitly | Per-world | Exists only where the game actually runs; test worlds opt in |

**`UWorldSubsystem` is used only where world lifetime genuinely owns the behavior** — which in this
design is **nothing in the simulation**. Campaign state that died with the level would break the
cinematic round-trip, which is the core requirement. It is therefore deliberately *not* used for sim.

### 3.2 The subsystem set

```cpp
// ---- BMSim: GameInstance subsystems (campaign-lifetime) ----
UBMCampaignSubsystem      // owns FBMCampaignState — the single authoritative container
UBMTimeSubsystem          // tick accumulator, speeds, pause; emits tick delegates
UBMSimulationCoordinator  // THE explicit tick order (§5). Nothing else may tick the sim.
UBMEconomySubsystem       // settle, racket pause, front pressure, operatives
UBMHeatSubsystem          // heat, evidence deposit/erode, inspection hysteresis
UBMPressureSubsystem      // central pressure + alert
UBMJobSubsystem           // job offers, cadence cap, lifecycle routing, follow-ups
UBMRivalSubsystem         // rival intent: telegraph → land, grudge decay
UBMRelationshipSubsystem  // betrayal telegraph → land → defuse, reassure
UBMSaveSubsystem          // save/load/checkpoint, version refusal
UBMContentRegistry        // resolves job/venue/character definitions by Id (Asset Manager)

// ---- BMGame: GameMode components (world-lifetime, explicit) ----
UBMNightCycleComponent    // phase machine
UBMNarrativeComponent     // authored beats + endings
UBMTransitionComponent    // city ⇄ embodied round-trip
```

`[P]` **Why `UBMCampaignSubsystem` owns state rather than each subsystem owning its slice:** the save
contract serializes one coherent snapshot, and the Godot build's determinism depends on a single
consistent read of the world per tick. Scattering state across nine subsystems would create ordering
hazards the current design does not have.

---

## 4. Data flow

```
                    ┌─────────────────────────────────────────┐
                    │        UBMCampaignSubsystem             │
                    │  FBMCampaignState  (AUTHORITATIVE)      │
                    │  districts · venues · factions ·        │
                    │  characters · jobs · narrative · clock  │
                    └───────────▲───────────────┬─────────────┘
                      mutations │               │ const reads
                       (verbs)  │               ▼
   ┌─────────────────────────────┴──┐   ┌───────────────────────────┐
   │   UBMSimulationCoordinator     │   │   View models (BMUI)      │
   │   drives, in declared order:   │   │   FBMCityViewModel        │
   │   Economy→Heat→Pressure→Jobs   │   │   FBMHudViewModel         │
   │   →NightCycle→Narrative        │   │   FBMRosterViewModel      │
   │   (rival ticks: Rel→Rival)     │   └───────────┬───────────────┘
   └────────────┬───────────────────┘               │ read-only
                │ calls pure functions              ▼
                ▼                          ┌──────────────────────┐
   ┌────────────────────────────┐          │ Widgets / Actors     │
   │  BMCore (no Engine dep)    │          │ (BMGame, BMUI)       │
   │  FBMEconomyMath            │          │ never write state    │
   │  FBMEvidence               │          └──────────┬───────────┘
   │  FBMPressureMath           │                     │ verb calls only
   │  FBMLoyaltyScoring         │◄────────────────────┘
   │  FBMRivalScoring           │
   │  FBMJobResolution          │
   │  FBMHash                   │
   └────────────────────────────┘
```

**One-way rule:** state flows *down* to presentation as immutable view models; intent flows *up* as
explicit verb calls. There is no other channel. `[V]` This mirrors the verified Godot invariant.

### 4.1 Verbs — the complete write surface

`[P]` Derived from the Godot build's actual write surface (`[V]` §01 audit §7.11). **If it is not on
this list, presentation cannot do it.**

```cpp
// UBMEconomySubsystem
bool SetRacketPaused(FBMVenueId, bool);
bool PressureFront(FBMVenueId, FBMFactionId);
int32 AssignOperatives(FBMVenueId, FBMFactionId, int32 N);
int32 RecallOperatives(FBMVenueId, FBMFactionId, int32 N);
// UBMJobSubsystem
bool BeginJob(FBMJobId);  bool ChoosePrep(FBMJobId, FName);
bool ChooseApproach(FBMJobId, FName);  bool ChooseCoverUp(FBMJobId, FName);
// UBMRelationshipSubsystem
bool Reassure(FBMCharacterId);
// UBMHeatSubsystem
bool RemoveEvidenceCase(FBMDistrictId, FBMCaseId);
// UBMTimeSubsystem
void SetSpeed(EBMSpeed);  void TogglePause();  void CycleSpeed();
// UBMTransitionComponent
void EnterConfrontation(FBMCharacterId);  void EnterCrimeScene(FBMDistrictId);
```

Each returns success/failure and **never** partially applies. `[V]` This matches the Godot verbs,
which refuse cleanly (e.g. `pressure_front` returns false on insufficient capital).

---

## 5. Tick ownership — the explicit order

`[V]` **The problem being fixed:** in Godot, execution order across systems listening to the same
`strategic_tick` is determined by autoload registration order in `project.godot` — implicit and
fragile. The source spec flags it as "a dependency to check before finalizing UE event ordering."

`[P]` **The fix:** exactly one object ticks the simulation, in a written-down order.

```cpp
void UBMSimulationCoordinator::AdvanceTick(int32 TickIndex)
{
    // Order is CONTRACT. Changing it changes the game. Asserted by BM.Time.TickOrderIsContract.
    Economy->Settle(TickIndex);        // 1. clear exposure → settle each faction (array order)
    Heat->UpdateDistricts(TickIndex);  // 2. consumes THIS tick's exposure
    Pressure->UpdateCentral(TickIndex);// 3. consumes THIS tick's district heat
    Jobs->TickJobs(TickIndex);         // 4. deadlines, follow-ups, resolution
    NightCycle->TickPhase(TickIndex);  // 5. phase budget
    Narrative->Evaluate(TickIndex);    // 6. beats + endings, after all state settles

    if (TickIndex % BMConst::RivalTickInterval == 0)  // 10
    {
        Rival->OnRivalTick(TickIndex);         // 7. telegraph → land, grudge decay
        Relationships->OnRivalTick(TickIndex); // 8. advance open intents, then score new
    }
}
```

> ⚠️ **As built (S2, 2026-09-18) steps 1–3 are ONE call, not three.** The sketch above is the
> *ordering* contract, not the call shape. `FBMSimulation::AdvanceTick` (in **BMCore**) runs
> steps 1–3 internally **and owns the `TickIndex` increment**, and that function is the unit the
> golden vectors and the probe measure. Splitting the three passes at the coordinator would move
> the increment somewhere else and create a **second definition of what a tick is** — two places
> that could disagree about whether a tick happened.
>
> So the coordinator calls `FBMSimulation::AdvanceTick(State)` and steps 4–8 hook in around it as
> their slices land. The per-pass entry points still exist on the subsystems for the probe, the HUD
> and later slices; they are simply not how the tick is driven.
>
> The deeper reason the passes live in BMCore at all: **the whole tick must run with no world, no
> engine tick and no `UObject`.** That is what makes the headless probe and the golden-vector tests
> possible. BMSim schedules; it does not contain rules.

`[V]` Steps 1→3 reproduce the verified intra-`EconomyService` order (settle all factions, then heat,
then central pressure).

`[V]` **Steps 7→8 are Rival BEFORE Relationships — corrected 2026-09-18.** An earlier revision of
this document had them reversed and claimed the reversed order "preserves the observed Godot
behavior." It does not. Measured at runtime by enumerating `TimeService.rival_tick.get_connections()`
in a headless probe:

```
0: RivalDirector
1: RelationshipService
```

`RivalDirector` is an autoload (`project.godot` `[autoload]`, registered at engine init);
`RelationshipService` is bootstrap-wired (`bootstrap.gd::_build_relationships` → `new()` in
`_ready`), so it always connects later and therefore always runs second.

**This is a decision order, not a formula** — and 08 §5.2 requires discrete decisions to match the
oracle *exactly*. `RivalDirector::_land` can flip a venue's owner (EXPAND) and add district heat
(FRAME); `RelationshipService` re-checks its betrayal gates against that state. Running Relationships
first means betrayal decisions cannot see the rival action that landed on the same tick — a
different, still-deterministic game. Port the measured order.

**Tick source `[P]`:** `UBMTimeSubsystem::Tick` (a `FTSTicker` or `UGameInstanceSubsystem` tick)
accumulates `DeltaSeconds × SpeedScale` and **drains in a while-loop**, exactly as Godot does:

```cpp
Accumulator += DeltaSeconds * BMConst::SpeedScale(Speed);
while (Accumulator >= BMConst::StrategicTickSeconds) {   // 1.0
    Accumulator -= BMConst::StrategicTickSeconds;
    Coordinator->AdvanceTick(++TickIndex);
}
```

`[V]` The drain loop is required: it is what makes tick counts identical across framerates and after
hitches, and it is how the Godot build behaves at FAST/FASTER.

**Never** use Actor `Tick` for simulation. Presentation actors may tick freely — they read only.

---

## 6. Event boundaries

`[P]` Simulation → presentation is **one-way, typed, and emitted after state is consistent.**

```cpp
DECLARE_MULTICAST_DELEGATE_TwoParams(FBMOnEconomySettled, FBMFactionId, const FBMSettleInfo&);
DECLARE_MULTICAST_DELEGATE_OneParam (FBMOnInspectionStarted, FBMDistrictId);
DECLARE_MULTICAST_DELEGATE_OneParam (FBMOnInspectionEnded,   FBMDistrictId);
DECLARE_MULTICAST_DELEGATE_OneParam (FBMOnCentralAlertChanged, bool);
DECLARE_MULTICAST_DELEGATE_ThreeParams(FBMOnRivalTelegraphed, FBMFactionId, FBMVenueId, EBMRivalAction);
DECLARE_MULTICAST_DELEGATE_ThreeParams(FBMOnRivalLanded,      FBMFactionId, FBMVenueId, EBMRivalAction);
DECLARE_MULTICAST_DELEGATE_OneParam (FBMOnBetrayalTelegraphed, FBMCharacterId);
DECLARE_MULTICAST_DELEGATE_OneParam (FBMOnBetrayalDefused,     FBMCharacterId);
DECLARE_MULTICAST_DELEGATE_ThreeParams(FBMOnBetrayalCommitted, FBMCharacterId, FBMVenueId, FBMFactionId);
DECLARE_MULTICAST_DELEGATE_OneParam (FBMOnJobOffered,      FBMJobId);
DECLARE_MULTICAST_DELEGATE_OneParam (FBMOnJobStageChanged, FBMJobId);
DECLARE_MULTICAST_DELEGATE_OneParam (FBMOnJobResolved,     FBMJobId);
DECLARE_MULTICAST_DELEGATE_TwoParams(FBMOnPhaseChanged, int32 /*Cycle*/, EBMPhase);
DECLARE_MULTICAST_DELEGATE_TwoParams(FBMOnBeatFired, FName /*Beat*/, FBMJobId);
DECLARE_MULTICAST_DELEGATE_OneParam (FBMOnEndingReached, FName);
```

**Rules `[P]`:**
- Events carry **Ids, not pointers** — a listener re-reads current state, so a stale pointer cannot
  outlive a load. `[V]` This directly encodes the Godot lesson: *"in any probe/test that calls
  load_game, resolve characters/districts via GameState lookups per iteration, never hold references
  across a load"* — that lesson cost a debugging session.
- Events are emitted **after** the mutation completes, never mid-update.
- Handlers **must not** mutate simulation state. A handler that needs a change calls a verb, which
  runs on the next tick boundary.
- `[V]` Godot needed `call_deferred` to work around autoload ordering; the explicit coordinator
  removes that need entirely. Do not port the deferred-wiring pattern.

### 6.1 Blueprint exposure

`[P]` Delegates are exposed to Blueprints via a thin `UBMEventRelay` (BMUI) with
`BlueprintAssignable` multicast properties. Blueprints **listen and render**; they never tick the sim
and never hold state (Locked #7, #8).

---

## 7. Cinematic / level-transition model

### 7.1 The provider seam

`[V]` The Godot build's `CinematicWorldProvider` returns `{center, floor_y, bounds_half}` and a single
`USE_SPLAT` flag swaps backends. The *pattern* is excellent and is preserved; the splat branch is CUT.

```cpp
USTRUCT() struct FBMCinematicBounds {
    FVector Center = FVector::ZeroVector;
    float   FloorZ = 0.f;
    float   BoundsHalf = 240.f;   // cm; Godot used 2.4 m
};

UINTERFACE() class UBMCinematicWorldProvider : public UInterface { GENERATED_BODY() };
class IBMCinematicWorldProvider {
    virtual FBMCinematicBounds GetBounds() const = 0;
    virtual TSoftObjectPtr<UWorld> GetLevel() const = 0;
};
```

`[P]` Implementations: `ABMAuthoredLevelProvider` (the slice's warehouse). A future splat provider
implements the same interface — D-07 decides whether that ever happens.

### 7.2 The round-trip

`[V]` Sequence preserved from `cinematic_transition.gd` + brief §14.2, with the checkpoint ordering
that the Month-4 gate verified:

```
EnterConfrontation(CharacterId):
  1. TimeSubsystem->SetSpeed(PAUSED)                    // sim stops first
  2. SaveSubsystem->SaveGame("checkpoint")              // BEFORE any mutation — crash-safe
  3. Guard: already inside? no world? → return (headless-safe no-op)
  4. Capture return context (camera, HUD visibility, strategic level state)
  5. Hide/unload strategic level; load embodied level (streaming or OpenLevel + persistent GI)
  6. Spawn actors from DataAsset; bind interaction points to sim Ids
  7. Play the entry Sequencer beat; hand control to the player pawn

  [player acts] → verbs call the SAME simulation functions the strategic layer uses
                  (Reassure / RemoveEvidenceCase). The scene owns no logic.

ResolveConfrontation(CharacterId, bOutcome):
  8.  Unload embodied level; restore strategic level + camera + HUD
  9.  Resume at PAUSED (deliberate — the player decides when to restart time)
  10. Broadcast the outcome event so the HUD can show the consequence
```

`[V]` Two behaviors that must survive the port because tests already pin them:
**headless safety** (with no world, enter/resolve only pause + checkpoint — this is how the Godot gate
tests drive the sim path), and **resume-at-paused** rather than resume-at-previous-speed.

### 7.3 Level strategy

`[P]` **Level Streaming, not World Partition.** Justification (Locked #10, brief §12.3): the slice has
one small district and one interior. World Partition exists for large streaming worlds; adopting it
here would add cell management, HLOD and data-layer complexity to a game that explicitly refuses to be
open-world — and its presence would quietly invite scope creep.

```
L_BM_Persistent          Always loaded. GameMode, subsystems bootstrap, persistent audio.
├─ L_GlassWharf_Strategic   Streamed: city proxy, strategic camera
├─ L_Warehouse_Embodied     Streamed: authored interior, characters, Sequencer
└─ L_Council_Embodied       Streamed: council/command location
```

**Invariant `[V]`:** *the city and an embodied level are never resident simultaneously* (brief §15).
Asserted by `Test_Transition_ExclusiveResidency`.

### 7.4 Sequencer boundary

`[P]` Sequencer owns **staging** — camera cuts, character performance, timed beats. It **never**
decides outcomes. A Level Sequence may play an animation of a lieutenant reacting; the *decision* that
he was reassured lives in `UBMRelationshipSubsystem`. Sequencer reads state to select which take to
play; it does not write.

---

## 8. Save model

> ⛔ **CORRECTED DURING S4 (`Docs/gates/S4.md`, Finding 1 / D-S4-1). The `USaveGame` sketch below
> CANNOT COMPILE and has been replaced.** It is kept, struck through, only because `05` §7 carried a
> *second, differently-shaped* version of the same mistake and the two need to be seen together.
>
> `UPROPERTY` requires reflection; reflection requires `CoreUObject`; **`BMCore` depends on `Core`
> alone, and that absence IS the determinism wall** (§2 below). `USTRUCT` appears **zero times** in the
> whole `Source/` tree. Making the state structs reflected to satisfy this sketch would breach the
> boundary S0 built to make rule 3 enforceable by the linker.
>
> ~~`[P]` `USaveGame` subclass with `UPROPERTY() TArray<FBMFactionSave> Factions;` etc.~~
> ~~(`04` used mirror types `FBMFactionSave`/`FBMDistrictSave`; `05` §7 used the live BMCore structs.~~
> ~~Neither compiles, and they were never two readings of one design.)~~

**What actually ships `[V]` — the original GOAL was right, only its wrapper was impossible.** The
struck-through sketch asked for *"serialized through `FArchive`, binary, float-exact — the requirement
Godot met with `var_to_str`"*, and that is met **exactly**, because **the whole `FArchive` family lives
in `Core`, not `CoreUObject`**: `Serialization/Archive.h` (already pulled in by `CoreMinimal.h`, so
`FArchive` was in scope in `BMCore` *before* S4 touched anything), `MemoryWriter.h`, `MemoryReader.h`,
`BufferArchive.h`, `Misc/FileHelper.h`, and the `TArray` / `TMap` / `FString` `operator<<` overloads.
Verified by compiling it: **no `BMCore.Build.cs` change was needed.**

```cpp
// BMCore — the FORMAT. A plain struct. No UCLASS, no USTRUCT, no UPROPERTY.
struct BMCORE_API FBMSaveCodec {
    static TArray<uint8>      Encode(const FBMCampaignState& State);
    static FBMSaveLoadReport  Decode(const TArray<uint8>& Bytes, FBMCampaignState& OutState,
                                     TArray<FBMJobSave>& OutJobs);
    static FBMSaveLoadReport  PeekHeader(const TArray<uint8>& Bytes);
    static FBMJobSave         EncodeJob(const FBMJob& Job);
    static void               ApplyJobState(FBMJob& Job, const FBMJobSave& Saved);
    // one Serialize* per shape, each writing its fields in ONE FIXED ORDER
};

// BMSim — the FILE and the REBUILD LOOP.
UCLASS() class BMSIM_API UBMSaveSubsystem : public UGameInstanceSubsystem { /* ... */ };
```

**The two-piece split is MANDATED by this very document, not a style choice `[V]`:** §2's table lists
*"any file I/O"* under BMCore's **Must NOT contain** while listing **"save"** under BMSim's *Contains*.
It is also exactly the oracle's own shape — a pure `SaveCodec` plus a `SaveService` autoload that does
the I/O. `BM.Save.NoFileIoInBMCore` and `BM.Save.SubsystemIsAThinFacade` enforce both directions.

**What is lost is only reflection-driven auto-serialization. What is GAINED is explicit field-order
control** — which a hard-version-refusal contract wants anyway, and which §8.1 below turns out to
depend on absolutely.

**Two additions to the contract the oracle has no equivalent for `[V]` (D-S4-3):**

1. **A 4-byte `BMSV` magic tag**, before the version. The oracle gets this free: `str_to_var` on a
   non-save file yields a non-Dictionary and `save_service.gd:55` rejects it. A binary format has no
   such natural guard — an arbitrary file's first four bytes are a plausible version int.
2. **`EBMLoadResult` instead of a bare bool.** Conflating a version refusal with a parse refusal lets a
   version bug hide behind a parse bug, and the tests must tell them apart.

**The three rules carried from the verified Godot contract `[V]`:**

1. **Source-of-truth vs rebuilt.** Jobs persist only `{Id, Stage, ChosenPrep[], ChosenApproach,
   ChosenCoverUp, TicksRemaining, Outcome}`. Authored content is re-resolved on load:
   `ContentRegistry->FindJobDefinition(Id)` → else `FBMJobGenerator::Rebuild(Id)` → else **drop with a
   warning**. A generated job's id encodes its own targeting, which is what makes this work.
2. **Hard version refusal, no migration.** Mismatch → refuse the entire load, leave state untouched.
   `[V]` Verified behavior; no partial application, ever.
3. **Additive tolerance within a version.** New fields default; `SaveVersion` gates container shape.
   ⛔ ~~Use `FCustomVersion` to formalize what Godot did with `.get(key, default)`.~~ **Corrected in
   S4 (D-S4-1): `FCustomVersion` does NOT apply here** — it is a mechanism for engine-versioned
   *reflected* serialization, and there is no reflection. A hand-rolled codec gets additive tolerance
   from **one explicit version int plus default member initializers**, which is simpler and is what
   `BM.Save.AdditiveFieldDefaults` actually measures against the oracle's nine measured defaults.

⚠️ **Rule 2's "hard version refusal" is right, and one detail of it is NOT what a porter would
write `[V]` (S4 Finding 2).** The oracle's check is `int(data.get("version", -1)) != SAVE_VERSION` — a
**coercion**, under which a *string* `"1"` and a *float* `1.0` both LOAD while `"abc"` refuses. A binary
format cannot express that ambiguity, so **the coercion is a recorded bounded divergence, not something
to imitate**; only the refusal semantics port. But the `!=` is load-bearing and must be copied
literally: a **future** version refuses exactly like a past one (measured: 0, −1 and 2 all refuse), and
a `<` here would load a version-2 file with version-1 code — a migration path by accident, which rule 2
forbids outright.

**Slots `[P]`:** `quick`, `checkpoint`, `auto`. Path `FPaths::ProjectSavedDir()/SaveGames/`.
`SaveGame(FString Slot)` is the shape §12's S17 checkpoint call needs, so it was fixed in S4.

**Load leaves the game paused** `[V]` — an asserted Godot behavior.
⚠️ **But it has NO automated coverage, and S4 measured that rather than assuming it.** Moving the pause
after the restore leaves the suite green at 56/56. Reaching `UBMTimeSubsystem` needs a live
`GameInstance`, and `NewObject`'ing a `UGameInstanceSubsystem` into the transient package trips the
CoreUObject ensure the automation framework promotes to a failure (S2). Every *other* load assertion
escaped that by moving to static `RestoreInto` / `RebuildJob`; a pause has nothing to assert on outside
a `GameInstance`. **The ordering is protected by review and a header comment only.** Closure is `08`
§7's `FT_Save_*` family, in the slice that first stands up a real world.

**Explicitly excluded from the save:** UI state. `[V]` The Godot build stores `ending_seen` in
`narrative_flags`; the port moves it to a separate UI-state save (`BM.Save.NoUIStateInCampaign`).

### 8.1 `[V]` Field order IS the format — and no round-trip test can see it change

**Discovered in S4 (Finding 3) and it has no counterpart in the Godot build, which is exactly why the
package missed it.**

The oracle's save round-trip test compares snapshots as `var_to_str(...)` strings — and **`var_to_str`
SORTS dictionary keys alphabetically.** Field order is simply not part of its format, and its runner
*literally could not* catch a reordered encode.

In a binary archive, field order **is** the format. And the failure is silent: the reader and the writer
are **the same function body** (`FArchive::operator<<` is bidirectional), so swapping two `Ar <<` lines
moves both halves together and every round-trip assertion follows them. Measured: swapping two
**same-type** fields inside `SerializeVenue` turns **exactly one test red and leaves 55 green** — and
because the types match, the byte *count* is unchanged, so even a size check misses it.

⛔ **Therefore: APPEND fields, never insert or reorder.** Every `Serialize*` function carries that
instruction in a comment.

**The only thing that can catch a violation is a committed binary from a PREVIOUS build**
(`Tests/Fixtures/Saves/v1.bmsav`, 782 B, deliberately **not** LFS-routed so it stays diffable).
`BM.Save.FixtureStillLoads` compares against it and localises the first differing byte.

⛔ **NEVER regenerate that fixture to make its test pass.** Regenerating it is precisely the act that
destroys its value, because the new bytes agree with the new field order by construction. If the format
changes deliberately: bump `BMSave::CurrentVersion` and add a **new** fixture *alongside* the old one.

### 8.2 `[V]` `Encode(Decode(x)) == x` is FALSE, by design

Cost one red gate in S4 to establish, so it is written down here. `Decode` hands jobs out **separately**
as `FBMJobSave` runtime state, because turning one back into an `FBMJob` requires the registry
(`ById` → `Rebuild`) and rebuilding is a BMSim concern — `UBMSaveSubsystem::RestoreInto` closes the
loop. A campaign straight out of `Decode` therefore has **empty `ActiveJobs`** and re-encodes short.

The property worth asserting is **stability, not equality**: once the jobs are put back, encoding is
idempotent.

---

## 9. Systems deliberately NOT adopted

`[P]` Each of these was considered and rejected **for a stated reason**, not overlooked:

| System | Verdict | Reason |
|---|---|---|
| **World Partition** | **No** | One district + one interior. Contradicts Locked #10; invites open-world creep |
| **Gameplay Ability System** | **No** | GAS models cooldowns, costs and effects on *actors in a world*. Jobs are a four-stage data-driven decision machine with no actor targeting. GAS would add attribute sets and prediction machinery for zero benefit |
| **Behavior Trees for rival AI** | **No** (Locked, and correct) | The rival is a **scored argmax over a fixed action list**, evaluated every 10 s with hash tie-breaking. A BT would obscure determinism and add no expressiveness. BTs are permitted **only** for embodied NPC idle/look-at behavior |
| **StateTree for the sim** | **No** | The phase machine is 4 states advancing on a tick budget; the job machine is 5 stages advancing on player input. Plain C++ enums are testable headless and serialize trivially. StateTree buys nothing and costs determinism clarity |
| **Replication / networking** | **No** | Single-player (brief §12.3). Do not mark state `Replicated` — it adds cost and invites multiplayer creep |
| **Niagara for the sim** | n/a | Presentation only (rain, steam) — fine |
| **Chaos physics** | **Minimal** | No drivable vehicles, no destruction. Character movement + simple collision only |
| **Common UI** | **Yes, justified** | Multiple input devices, focus management, and a modal stack (job panel over HUD over roster, plus the cinematic layer hiding all of them). `[V]` The Godot build hand-rolled an `hud_layers` array with manual visibility toggling — exactly the problem Common UI solves |
| **Enhanced Input** | **Yes, required** | Brief §19 Month-5 requires **rebinding**; `[V]` the uncommitted P20 `SettingsService` implements runtime rebinding manually. Enhanced Input + `UEnhancedInputUserSettings` does this natively, and cleanly separates strategic vs embodied contexts |
| **Asset Manager + soft refs** | **Yes, required** | Content is data-driven (Locked #5). Job/character/venue definitions load by Id; embodied levels load on demand. Hard refs would pull the entire content graph into memory at boot |
| **Data Tables vs Data Assets** | **Both, split** | `UPrimaryDataAsset` for jobs, characters, venues, districts, embodied scenes (rich nested structure, per-asset validation). **DataTable** for flat balance constants — one row per tunable, so balance changes need no recompile |
| **Level Sequence / Sequencer** | **Yes, core** | The reboot's justification (§7.4) |
| **Control Rig / Anim BP** | **Yes, core** | One hero character must perform |
| **Automation + Functional Tests** | **Yes, required** | §[08](08_TEST_STRATEGY.md) |

---

## 10. Error handling, logging, observability

### 10.1 Failure philosophy

`[V]` The Godot build's pattern, worth keeping: **refuse cleanly and say why.** `pressure_front`
returns false rather than going negative; `load_game` refuses a bad version rather than partially
applying; `rebuild` returns null rather than fabricating a job whose evidence case is gone.

`[P]` In C++:
- Verbs return `bool`/`int32` and never partially apply.
- Invariant violations use `check()` in Debug, `ensureMsgf()` in Development (log + continue),
  and are **compiled out** of Shipping.
- Content problems fail at **cook time** via the asset validator — never at runtime.

### 10.2 Logging

```cpp
DECLARE_LOG_CATEGORY_EXTERN(LogBMSim,        Log, All);  // tick, settle, phase
DECLARE_LOG_CATEGORY_EXTERN(LogBMDeterminism,Log, All);  // hash inputs, tie-breaks, ordering
DECLARE_LOG_CATEGORY_EXTERN(LogBMSave,       Log, All);  // version, slots, rebuild outcomes
DECLARE_LOG_CATEGORY_EXTERN(LogBMTransition, Log, All);  // enter/resolve, level residency
DECLARE_LOG_CATEGORY_EXTERN(LogBMContent,    Log, All);  // data asset resolution failures
```

`[P]` `LogBMDeterminism` is not ordinary logging — it is the debugging tool for the one class of bug
this project is most exposed to. At `Verbose` it records every hash input/output and every tie-break
decision, so a divergence can be bisected against the Godot golden vectors instead of guessed at.

### 10.3 Observability

`[P]` A `UBMDebugSubsystem` (Development builds only) providing: a tick-state HUD overlay
(cash, heat, combined pressure, phase, open intents), `BM.DumpState` / `BM.RunProbe N` /
`BM.CompareGolden <file>` console commands, and a **state-hash-per-tick** trace for divergence
bisection. `[V]` This is the Unreal equivalent of `tools/validation/*_probe.tscn`, which proved its
worth repeatedly in the Godot build — and whose *instrumentation* bugs were themselves a documented
lesson, so the probes must derive thresholds from the real constants, never from copied literals.

### 10.4 Crash recovery

`[V]` **Known gap being fixed:** the Godot build writes a `checkpoint` before cinematic entry but has
**no handler that ever restores it**. `[P]` The port adds: on boot, if a checkpoint exists and is
newer than the last clean save, offer to resume from it.

---

## 11. Determinism boundaries

Full specification in [08_TEST_STRATEGY.md](08_TEST_STRATEGY.md) §3–4. Architecturally:

**Must be deterministic (BMCore + BMSim):** every formula, every threshold comparison, all ordering
and tie-breaking, hash-derived variety, tick counts, save/load round-trips.

**Explicitly allowed to be non-deterministic (BMGame + BMUI):** animation blending, particles, audio
timing, camera interpolation, crowd/traffic visual phase, UI transitions, LOD selection.

**The enforcement `[P]`:** BMCore's lack of an Engine dependency means it cannot reach
`FMath::Rand`, `GWorld`, or frame-time. A static test (`Test_Determinism_NoRandomInSimModule`) scans
BMCore and BMSim for `FMath::Rand`, `RandRange`, `FRandomStream`, `FDateTime::Now`, and
`GetWorld()->GetTimeSeconds()`. `[V]` This mirrors the Godot suite, which source-scans for RNG.

---

## 12. Mapping table — Godot to Unreal

| Godot | Unreal | Note |
|---|---|---|
| `GameState` autoload | `UBMCampaignSubsystem` + `FBMCampaignState` | Single authoritative container |
| `TimeService` | `UBMTimeSubsystem` | Drain-loop accumulator preserved |
| `EconomyService` | `UBMEconomySubsystem` + `FBMEconomyMath` | State vs math split preserved |
| `EconomyMath`/`EvidenceMath`/`PressureMath`/`LoyaltyScoring`/`OperativeMath`/`RivalScoring`/`JobResolution` | BMCore static structs | 1:1; these are already pure |
| `JobDirector` | `UBMJobSubsystem` | |
| `RivalDirector` | `UBMRivalSubsystem` | |
| `SaveService` + `SaveCodec` | `UBMSaveSubsystem` + **`FBMSaveCodec`** | `[V]` S4. The two-piece split is preserved exactly: the codec is pure and lives in BMCore, the subsystem owns the file. **NOT `UBMSaveGame`** — see §8 |
| `NightCycle` (scene-wired) | `UBMNightCycleComponent` on GameMode | Lifetime distinction preserved |
| `RelationshipService` (scene-wired) | `UBMRelationshipSubsystem` | **Exception:** promoted to subsystem because betrayal intents must survive the cinematic round-trip |
| `NarrativeDirector` (scene-wired) | `UBMNarrativeComponent` | |
| `CinematicTransition` (scene-wired) | `UBMTransitionComponent` | |
| `CinematicWorldProvider` | `IBMCinematicWorldProvider` | Splat branch cut |
| `WorldSeed` (code) | `UBMWorldSeedDataAsset` | REDESIGN — data-driven |
| `JobTemplates`/`NarrativeJobs` (code) | `UBMJobDefinition` assets | REDESIGN — data-driven |
| `*Data` Resources | `USTRUCT` state + `UPrimaryDataAsset` definitions | Split authored vs mutable (see [05](05_DATA_MODEL.md)) |
| Signals | Typed multicast delegates carrying **Ids** | No pointers across loads |
| `hud_layers` visibility array | Common UI layer stack | |
| Code-built UI | UMG assets | |
| `tools/validation/*probe*` | `UBMDebugSubsystem` + Functional Tests | |
| `GLBValidator` | `UBMAssetValidator` (Data Validation) | |

---

**Next:** [05_DATA_MODEL.md](05_DATA_MODEL.md)
