# 05 — Data Model

The principal types, and — critically — the **separation** between authored, mutable, transient, saved
and derived data. All numeric values carry `[V]` where extracted verbatim from the Godot build.

Tags: `[V]` Verified from repository · `[I]` Inferred · `[P]` Proposed

---

## 1. The five data categories

`[P]` The Godot build blurred these: `DistrictData` is a `Resource` (authored-looking) that is
mutated every tick (runtime state), and `WorldSeed` builds it in code. The Unreal model separates them
explicitly, because the save contract and the content pipeline both depend on knowing which is which.

| Category | Lifetime | Mutable | Saved | Unreal form |
|---|---|---|---|---|
| **Authored immutable** | Ships with the build | ❌ | ❌ (referenced by Id) | `UPrimaryDataAsset`, `UDataTable` |
| **Mutable campaign state** | Campaign | ✅ | ✅ | `USTRUCT` in `FBMCampaignState` |
| **Transient presentation** | Frame / view | ✅ | ❌ | View-model structs, actors |
| **Saved state** | Disk | — | ✅ | `UBMSaveGame` mirrors |
| **Derived** | Computed on read | ❌ | ❌ | `static` functions in BMCore |

**Rule `[P]`:** if a value can be recomputed from authored data + campaign state, it is **derived** and
must not be stored or saved. `[V]` The Godot build already honours this for `district_demand()`,
`betrayal_pressure()` and `combined_pressure()` — all computed on read, never cached.

---

## 2. Identifiers

`[P]` Strong typing prevents the class of bug where a district id is passed where a venue id belongs.

```cpp
USTRUCT(BlueprintType)
struct FBMId
{
    GENERATED_BODY()
    UPROPERTY(EditAnywhere, BlueprintReadOnly) FName Value;

    bool IsValid() const { return !Value.IsNone(); }
    friend uint32 GetTypeHash(const FBMId& Id) { return GetTypeHash(Id.Value); }
    bool operator==(const FBMId& O) const { return Value == O.Value; }
};

// Distinct types via a tag template — cheap, header-only, catches argument swaps at compile time.
template<typename Tag> struct TBMId : FBMId {};
struct FDistrictTag; struct FVenueTag; struct FFactionTag;
struct FCharacterTag; struct FJobTag; struct FCaseTag;

using FBMDistrictId  = TBMId<FDistrictTag>;
using FBMVenueId     = TBMId<FVenueTag>;
using FBMFactionId   = TBMId<FFactionTag>;
using FBMCharacterId = TBMId<FCharacterTag>;
using FBMJobId       = TBMId<FJobTag>;
using FBMCaseId      = TBMId<FCaseTag>;
```

### 2.1 Structured ids — a load-bearing format

`[V]` Two id formats encode meaning and **must** be preserved exactly; the save/rebuild contract
parses them.

```
Evidence case:  case@<district>@<kind>@<tick>                          (4 segments)
Generated jobs: gen@retaliation@<venue>@<rival>@<tick>                 (5 parts)
                gen@contested@<venue>@<rival>@<tick>                   (5 parts)
                gen@followup@<venue>@<tick>                            (4 parts)
                gen@burycase@<district>@case@<d>@<kind>@<t>@<tick>     (8 parts)
```

`[V]` The `burycase` form embeds a whole case id, so the part count is 8 — the Godot parser depends on
this exact arity. `[P]` The port provides `FBMJobIdParser` with explicit arity checks and a round-trip
test (`Test_Job_IdRoundTrip`), rather than ad-hoc `Split` calls at four call sites.

---

## 3. Enums and constants

### 3.1 Enums `[V]` — integer ordering is **save-critical**; these are append-only

```cpp
UENUM(BlueprintType) enum class EBMControlState : uint8 {
    Unknown=0, Contested=1, Influenced=2, Controlled=3, Fortified=4, Compromised=5 };

UENUM(BlueprintType) enum class EBMVenueType : uint8 {
    Racket=0, Front=1, Safehouse=2, TransitNode=3,
    PoliticalOffice=4, IntelligenceNode=5, NeutralInstitution=6, StoryLocation=7 };

UENUM(BlueprintType) enum class EBMRacketKind : uint8 {
    ContrabandLogistics=0, Protection=1, IllegalClinic=2,
    IdentityFabrication=3, UndergroundGaming=4, InformationBrokerage=5 };

UENUM(BlueprintType) enum class EBMFrontKind : uint8 {
    Nightclub=0, FreightCompany=1, PrivateSecurity=2,
    LuxuryClinic=3, PropertyHolding=4, MediaEvent=5 };

UENUM(BlueprintType) enum class EBMRivalAction : uint8 {
    Expand=0, Probe=1, Sabotage=2, Recruit=3, Bribe=4, Retaliate=5,
    Negotiate=6, Frame=7, ReduceHeat=8, Defend=9, ExploitGrievance=10 };
    // Only Expand, Probe, Sabotage, Recruit, Frame are scored — see §03 matrix TD-01.

UENUM(BlueprintType) enum class EBMJobStage : uint8 {
    Intake=0, Preparation=1, Intervention=2, CoverUp=3, Resolved=4 };

UENUM(BlueprintType) enum class EBMJobOrigin : uint8 {   // APPEND-ONLY for save stability
    FailedRacket=0, Witness=1, RivalProvocation=2, InternalDispute=3,
    InstitutionalPressure=4, EvidenceChain=5, TerritoryLoss=6 };

UENUM(BlueprintType) enum class EBMEvidenceKind : uint8 {
    Manifest=0, Footage=1, Witness=2, Physical=3 };

UENUM(BlueprintType) enum class EBMPhase : uint8 {
    Council=0, Operations=1, Crisis=2, Reckoning=3 };

UENUM(BlueprintType) enum class EBMSpeed : uint8 {
    Paused=0, Normal=1, Fast=2, Faster=3 };
```

### 3.2 Constants `[V]` — the complete balance table

`[P]` These live in `BMCore/BMConstants.h` as `constexpr`, **and** are mirrored into a DataTable
(`DT_BMBalance`) so designers can retune without a recompile. The C++ values are the defaults and the
golden-vector baseline; a DataTable override is applied at load and logged.

```cpp
namespace BMConst
{
    // ---- Time ----
    constexpr float StrategicTickSeconds = 1.0f;
    constexpr int32 RivalTickInterval    = 10;
    // SpeedScale: Paused 0.0, Normal 1.0, Fast 2.0, Faster 4.0

    // ---- Economy ----
    constexpr int32 FrontPressureStep = 100;
    constexpr int32 FrontPressureCost = 400;    // clean capital
    constexpr int32 FrontCapacityMax  = 1500;
    constexpr float ExposureScalar    = 0.0001f;
    constexpr float HeatDisruptionGrace = 0.30f;
    constexpr float HeatDisruptionMax   = 0.60f;
    // ControlModifier: Fortified 1.2, Controlled 1.0, Influenced 0.6,
    //                  Compromised 0.4, Contested 0.3, Unknown 0.0

    // ---- Heat / inspection ----
    constexpr float HeatRiseScale            = 0.05f;
    constexpr float ExposureHeatFloor        = 0.008f;
    constexpr float HeatDecayPerTick         = 0.0006f;
    constexpr float HeatInspectionThreshold  = 0.45f;
    constexpr float HeatInspectionWarn       = 0.38f;   // HUD telegraph only
    constexpr float HeatInspectionRearm      = 0.30f;
    constexpr int32 InspectionDurationTicks  = 30;
    constexpr float InspectionDisruption     = 0.80f;

    // ---- Evidence ----
    constexpr int32 MaxCasesPerDistrict = 4;
    constexpr float CasePressureWeight  = 0.5f;

    // ---- Central pressure ----
    constexpr float CentralRiseFloor              = 0.35f;
    constexpr float CentralRiseScale              = 0.15f;
    constexpr float CentralDecayPerTick           = 0.01f;
    constexpr float CentralAlertThreshold         = 0.60f;
    constexpr float CentralAlertRearm             = 0.40f;
    constexpr int32 CentralAlertDurationTicks     = 20;
    constexpr float CentralAlertInspectionRelief  = 0.15f;

    // ---- Loyalty / betrayal ----
    constexpr float OpportunityThreshold       = 0.30f;
    constexpr int32 TelegraphLeadRivalTicks    = 6;     // ≈60 strategic ticks
    constexpr int32 MaxNewIntentsPerRivalTick  = 1;
    constexpr int32 ReassureCostClean          = 200;
    constexpr float ReassureTrustGain          = 0.15f;
    constexpr float ReassureSharedGain         = 0.15f;
    constexpr float OppInspection              = 0.35f;
    constexpr float OppSabotage                = 0.30f;
    constexpr float OppLeveragePressed         = 0.50f;  // × rival_leverage
    // MotiveTerms order (argmax ties → earliest):
    //   Ambition, Grievance, RivalLeverage, SurvivalPressure

    // ---- Rival ----
    constexpr float SabotageDisruption      = 0.35f;
    constexpr int32 SabotageDurationTicks   = 40;
    constexpr float ProbeDisruption         = 0.10f;
    constexpr int32 ProbeDurationTicks      = 20;
    constexpr float RecruitLeverage         = 0.15f;
    constexpr float FrameHeat               = 0.25f;
    constexpr float CommitThreshold         = 0.30f;
    constexpr int32 RivalTelegraphLeadTicks = 3;        // rival ticks
    constexpr float TieJitterEpsilon        = 0.01f;
    constexpr float GrudgeScoreBonus        = 0.35f;
    constexpr float GrudgeSabotageLean      = 0.15f;
    constexpr float GrudgeDecayPerTick      = 0.05f;

    // ---- Jobs ----
    constexpr int32 JobMaxPrepActions   = 3;
    constexpr int32 MaxConcurrentJobs   = 3;
    constexpr float FollowupThreshold   = 0.25f;
    constexpr int32 FollowupLeadTicks   = 20;

    // ---- Night cycle (Godot values; slice retunes — see 06 §2) ----
    constexpr int32 PhaseTicksCouncil    = 240;
    constexpr int32 PhaseTicksOperations = 1080;
    constexpr int32 PhaseTicksCrisis     = 360;
    constexpr int32 PhaseTicksReckoning  = 120;   // total 1800 = 30 min

    // ---- Narrative ----
    constexpr int32 BeatLeadTicks   = 30;
    constexpr int32 EndingLeadTicks = 120;

    // ---- World seed ----
    constexpr int32 OperativeFreeReserve = 2;
}
```

---

## 4. Authored immutable data

`[P]` Everything a designer authors. Never mutated at runtime; referenced by Id.

```cpp
UCLASS() class UBMVenueDefinition : public UPrimaryDataAsset {
    UPROPERTY(EditAnywhere) FBMVenueId    VenueId;
    UPROPERTY(EditAnywhere) FText         DisplayName;
    UPROPERTY(EditAnywhere) EBMVenueType  Type;
    UPROPERTY(EditAnywhere) EBMRacketKind RacketKind;
    UPROPERTY(EditAnywhere) EBMFrontKind  FrontKind;
    UPROPERTY(EditAnywhere) int32 BaseYield          = 0;
    UPROPERTY(EditAnywhere) int32 LaunderingCapacity = 0;
    UPROPERTY(EditAnywhere, meta=(ClampMin="0", ClampMax="1")) float FrontEfficiency = 0.7f;
    UPROPERTY(EditAnywhere, meta=(ClampMin="0", ClampMax="1")) float OperatingCost   = 0.15f;
    UPROPERTY(EditAnywhere, meta=(ClampMin="0", ClampMax="1")) float RacketRisk      = 0.3f;
    UPROPERTY(EditAnywhere) FVector2D MapPosition;        // presentation only
    UPROPERTY(EditAnywhere) TSoftObjectPtr<UStaticMesh> HeroMeshOverride;   // soft ref
};

UCLASS() class UBMDistrictDefinition : public UPrimaryDataAsset {
    UPROPERTY(EditAnywhere) FBMDistrictId DistrictId;
    UPROPERTY(EditAnywhere) FText DisplayName;
    // Starting values only — runtime values live in FBMDistrictState
    UPROPERTY(EditAnywhere) float StartInfluence=0.f, StartSecurity=0.f, StartProsperity=0.5f;
    UPROPERTY(EditAnywhere) float StartFear=0.f, StartVisibility=0.5f, StartInstitutionalPresence=0.3f;
    UPROPERTY(EditAnywhere) float StartLocalHeat = 0.f;
    UPROPERTY(EditAnywhere) TMap<FBMFactionId,float> StartFactionPressure;
    UPROPERTY(EditAnywhere) TArray<TSoftObjectPtr<UBMVenueDefinition>> Venues;  // ORDER IS CONTRACT
};

UCLASS() class UBMCharacterDefinition : public UPrimaryDataAsset {
    UPROPERTY(EditAnywhere) FBMCharacterId CharacterId;
    UPROPERTY(EditAnywhere) FText DisplayName;
    UPROPERTY(EditAnywhere) FBMFactionId FactionId;
    UPROPERTY(EditAnywhere) FText Role;
    UPROPERTY(EditAnywhere) bool bIsPlayer = false;
    // Starting motives
    UPROPERTY(EditAnywhere) float StartPublicTrust=0.5f, StartAmbition=0.3f, StartFear=0.2f;
    UPROPERTY(EditAnywhere) float StartGrievance=0.f, StartSharedSuccess=0.f;
    UPROPERTY(EditAnywhere) float BetrayalThreshold = 0.7f;
    UPROPERTY(EditAnywhere) TMap<FBMCharacterId,float> StartRelationships;   // −1..1
    // Presentation — soft refs, loaded on demand (see 11_CANONICAL_REFERENCE_INTAKE)
    UPROPERTY(EditAnywhere) TSoftObjectPtr<UTexture2D>   Portrait;
    UPROPERTY(EditAnywhere) TSoftClassPtr<ABMCharacter>  EmbodiedActorClass;
};

UCLASS() class UBMJobDefinition : public UPrimaryDataAsset {
    UPROPERTY(EditAnywhere) FBMJobId JobId;
    UPROPERTY(EditAnywhere) FText Title, ApparentProblem, VisibleStakes, HiddenStakes;
    UPROPERTY(EditAnywhere) EBMJobOrigin Origin;
    UPROPERTY(EditAnywhere) FBMVenueId VenueId;
    UPROPERTY(EditAnywhere) TArray<FBMCharacterId> InvolvedCharacters;
    UPROPERTY(EditAnywhere) int32 DeadlineTicks = 120;
    UPROPERTY(EditAnywhere) int32 RewardDirty   = 0;
    UPROPERTY(EditAnywhere) TArray<FText> KnownEvidence;
    UPROPERTY(EditAnywhere) TArray<FBMJobChoice> PrepActions;   // ORDER IS CONTRACT
    UPROPERTY(EditAnywhere) TArray<FBMJobChoice> Approaches;
    UPROPERTY(EditAnywhere) TArray<FBMJobChoice> CoverUps;
};

USTRUCT() struct FBMJobChoice {
    UPROPERTY(EditAnywhere) FName ChoiceId;
    UPROPERTY(EditAnywhere) FText Label, Description;
    UPROPERTY(EditAnywhere) FBMJobOutcome Effects;   // typed, not a loose map
};

UCLASS() class UBMWorldSeedDataAsset : public UPrimaryDataAsset {
    UPROPERTY(EditAnywhere) TArray<TSoftObjectPtr<UBMDistrictDefinition>>  Districts;
    UPROPERTY(EditAnywhere) TArray<TSoftObjectPtr<UBMFactionDefinition>>   Factions;   // ORDER IS CONTRACT
    UPROPERTY(EditAnywhere) TArray<TSoftObjectPtr<UBMCharacterDefinition>> Characters; // ORDER IS CONTRACT
    UPROPERTY(EditAnywhere) FBMFactionId PlayerFactionId;
};
```

### 4.1 "ORDER IS CONTRACT"

`[V]` Three array orders are **simulation-visible**, not cosmetic:

- **Faction order** → per-tick settle order in the economy.
- **District → venue order** → rival candidate generation order, which is the **tie-break** when two
  candidates score equally (strict `>` means first wins).
- **Character order** → betrayal candidate tie-break (ties resolve by *ascending authored index*).

`[P]` Reordering an array in a Data Asset therefore **changes the game**. The asset validator emits a
warning on reorder, and the golden-vector suite will catch it. This must be documented where designers
can see it — a tooltip on the property, not only here.

### 4.2 Typed outcome struct

`[V]` Godot uses a loose `Dictionary` keyed by nine StringNames, with an `assert` on unknown keys —
i.e. authoring errors surface at runtime. `[P]` The port makes it a struct, so they surface at compile
time:

```cpp
USTRUCT(BlueprintType) struct FBMJobOutcome {
    // Unsigned 0..1
    UPROPERTY(EditAnywhere) float ObjectiveAchieved = 0.f;
    UPROPERTY(EditAnywhere) float CollateralDamage  = 0.f;
    UPROPERTY(EditAnywhere) float RivalSuspicion    = 0.f;
    UPROPERTY(EditAnywhere) float PublicFear        = 0.f;
    UPROPERTY(EditAnywhere) float NewLeverage       = 0.f;
    UPROPERTY(EditAnywhere) float DelayedConsequence= 0.f;
    // Signed −1..1
    UPROPERTY(EditAnywhere) float EvidenceGenerated  = 0.f;
    UPROPERTY(EditAnywhere) float OperativeInjury    = 0.f;
    UPROPERTY(EditAnywhere) float RelationshipChange = 0.f;

    void Accumulate(const FBMJobOutcome& O);   // component-wise add
    void ClampAll();                           // signed → [−1,1], unsigned → [0,1]
};
```

`[V]` Clamping happens **once at the end** of accumulation, never per-term — intermediate overshoot is
intentional and must be reproduced.

---

## 5. Mutable campaign state

`[P]` One authoritative container. Everything here is saved.

> ⚠️ **As built in S2 (2026-09-18) these are PLAIN C++ structs, not `USTRUCT`, and ids are `FString`,
> not the typed wrappers.** Four deliberate divergences from the sketch below, all forced by one
> constraint:
>
> 1. **No `USTRUCT` / `UPROPERTY` / `UENUM`.** They require `CoreUObject`, and `BMCore` depends on
>    `Core` alone — *the absence of that dependency is the determinism wall* (04 §2). Reflection
>    markup here would quietly breach it. A Blueprint-facing mirror belongs in `BMSim` if one is ever
>    needed; nothing has needed one yet.
> 2. **Ids are `FString`, not `TBMId<Tag>`.** The typed wrappers are a good idea and remain worth
>    doing — but they are `USTRUCT`s in this sketch, so adopting them as written would breach (1).
>    Revisit as a `Core`-only value type when something actually confuses two id kinds.
> 3. **`FBMVenueState` carries the definition fields too** (`BaseYield`, `RacketRisk`,
>    `FrontEfficiency`, `OperatingCost`, `Type`). §4's split of authored-definition vs runtime-state
>    is right for the data layer, which does not exist yet (S14). Until then the sim needs those
>    numbers and there is nowhere else to read them from. **Re-split them when the Data Assets land**
>    — the port matrix's formulas already treat them as immutable.
> 4. **`FBMEvidenceCase` keeps `Label`.** The Godot resource carries it and the case's display
>    phrasing is chosen by `KindFor` at deposit time, so dropping it would move a decision into
>    presentation.
>
> Everything else below — field names, defaults, the index-0-is-oldest contract, the preserved venue
> order — is as built. Actual: `D:\black-meridian-ue\Source\BMCore\Public\BMTypes.h`.

```cpp
USTRUCT() struct FBMVenueState {
    FBMVenueId       VenueId;          // → definition
    FBMFactionId     OwnerFaction;
    EBMControlState  ControlState = EBMControlState::Unknown;
    int32 OperationalStaff   = 0;
    int32 LaunderingCapacity = 0;      // mutable: PressureFront raises it
    bool  bPaused            = false;
    float Disruption         = 0.f;
    float SabotageDisruption = 0.f;
    int32 SabotageTicks      = 0;
};

USTRUCT() struct FBMEvidenceCase {
    FBMCaseId       CaseId;            // "case@<district>@<kind>@<tick>"
    EBMEvidenceKind Kind;
    float           Weight = 0.f;      // 0..1
};

USTRUCT() struct FBMDistrictState {
    FBMDistrictId DistrictId;
    float Influence=0, Security=0, Prosperity=0.5f, Fear=0, Visibility=0.5f;
    float InstitutionalPresence=0.3f, LocalHeat=0.f;
    int32 InspectionTicks   = 0;
    bool  bInspectionArmed  = true;
    TArray<FBMEvidenceCase> EvidenceCases;   // index 0 == OLDEST — contract
    TMap<FBMFactionId,float> FactionPressure;
    TArray<FBMVenueState> Venues;            // authored order preserved
};

USTRUCT() struct FBMFactionState {
    FBMFactionId FactionId;
    bool  bIsPlayer = false;
    int32 DirtyCash = 0, CleanCapital = 0;
    float Aggression=0.5f, Caution=0.5f, Cunning=0.5f;   // personality, stable
    // Rival intent lives ON the faction (Godot lesson: telegraph state belongs to its subject)
    int32        IntentAction        = -1;   // EBMRivalAction or −1
    FName        IntentTargetId;             // venue id, or character id when Recruit
    int32        IntentTicksUntilLand= 0;
    int32        IntentsCommitted    = 0;    // hash salt — MUST persist
    float        Grudge              = 0.f;
    int32        OperativePool       = 0;
};

USTRUCT() struct FBMCharacterState {
    FBMCharacterId CharacterId;
    FBMFactionId   FactionId;
    float PublicTrust=0.5f, Ambition=0.3f, Fear=0.2f, Grievance=0.f, SharedSuccess=0.f;
    float RivalLeverage=0.f, SurvivalPressure=0.f;      // HIDDEN — never rendered
    float BetrayalThreshold = 0.7f;
    FBMFactionId RecruitedByFaction;
    TMap<FBMCharacterId,float> Relationships;
    int32 BetrayalTicksUntilLand = -1;                  // −1 = no open intent
    FName BetrayalDrivingMotive;
    bool  bMotiveRevealed = false;

    float  ComputeBetrayalPressure() const;             // DERIVED
    bool   PressureExceedsThreshold() const;            // DERIVED
};

USTRUCT() struct FBMJobState {
    FBMJobId  JobId;                    // encodes targeting when generated
    EBMJobStage Stage = EBMJobStage::Intake;
    TArray<FName> ChosenPrep;           // ≤3, selection order preserved
    FName ChosenApproach, ChosenCoverUp;
    int32 TicksRemaining = 0;
    FBMJobOutcome Outcome;
    bool bOutcomeValid = false;
};

USTRUCT() struct FBMNarrativeState {           // typed, replacing Godot's loose flag bag
    TSet<FName>        FiredBeats;             // "fired@<beat>"
    TMap<FBMJobId,int32> ResolvedTicks;        // "resolved@<job>" → tick
    bool  bLedgerSecured = false;
    FName AccordStance;                        // truce | leverage | war
    FName Ending;                              // latches once set
};

USTRUCT() struct FBMCampaignState {
    TArray<FBMDistrictState>  Districts;    // ORDER IS CONTRACT
    TArray<FBMFactionState>   Factions;     // ORDER IS CONTRACT (settle order)
    TArray<FBMCharacterState> Characters;   // ORDER IS CONTRACT (tie-break)
    TArray<FBMJobState>       Jobs;
    TArray<FBMPendingFollowup> PendingFollowups;
    FBMNarrativeState Narrative;
    FBMFactionId PlayerFactionId;
    int32 NightCycle = 1, PhaseTicks = 0, TickIndex = 0;
    EBMPhase Phase = EBMPhase::Council;
    float CentralPressure = 0.f;
    bool  bCentralAlert = false;
    int32 CentralAlertTicks = 0;
};
```

### 5.1 Lookups

`[P]` `TMap<FBMVenueId,int32>` index caches rebuilt on load and on structural change — for speed.
**But iteration for simulation always walks the `TArray` in order**, never the map. `[V]` Godot used
linear scans everywhere; at slice scale either is fine, but the ordering guarantee is not optional.

### 5.2 Hidden vs public motives

`[V]` `RivalLeverage` and `SurvivalPressure` are **hidden** — the roster renders public fields only,
and the rival's `recruit_susceptibility` is forbidden from reading them (the fairness rule).

`[P]` Enforce structurally: the roster view model is built by a function that *cannot see* hidden
fields (it takes a `FBMPublicCharacterView`, not the full state). `Test_UI_NoHiddenMotiveLeak` asserts
it. This converts a discipline problem into a type problem.

---

## 6. Transient presentation state

`[P]` Never saved, never authoritative, rebuilt freely.

```cpp
USTRUCT() struct FBMVenueViewModel {
    FBMVenueId VenueId; FText DisplayName;
    EBMControlState ControlState; FLinearColor OwnerAccent;
    int32 Floors;  bool bPaused, bDisrupted, bSabotaged;   // derived visuals
};
USTRUCT() struct FBMHudViewModel {
    int32 DirtyCash, CleanCapital, LaunderingCapacity, UnlaunderedOverflow;
    float LocalHeat, CombinedPressure, CentralPressure;
    EBMPhase Phase; int32 PhaseTicksRemaining; EBMSpeed Speed;
    bool bInspectionActive, bInspectionWarning, bCentralAlert;
};
USTRUCT() struct FBMPublicCharacterView {        // hidden motives structurally absent
    FBMCharacterId CharacterId; FText DisplayName; TSoftObjectPtr<UTexture2D> Portrait;
    float PublicTrust, Ambition, Fear, Grievance, SharedSuccess;
    bool bBetrayalTelegraphed; FName RevealedMotive;   // only if bMotiveRevealed
};
```

**UI-only state** (`bEndingSeen`, last-selected venue, panel open/closed) lives in a separate
`UBMUserSettings` / UI save — `[V]` fixing the Godot build's `ending_seen` leak into campaign flags.

---

## 7. Saved state and versioning

```cpp
namespace BMSave { constexpr int32 CurrentVersion = 1; }   // [V] matches Godot SAVE_VERSION = 1

UCLASS() class UBMSaveGame : public USaveGame {
    UPROPERTY() int32 SaveVersion = BMSave::CurrentVersion;
    UPROPERTY() FBMSaveMeta Meta;                     // tick, phase, cycle, pressure, narrative, timestamp
    UPROPERTY() TArray<FBMFactionState>   Factions;
    UPROPERTY() TArray<FBMDistrictState>  Districts;  // venues + cases embedded
    UPROPERTY() TArray<FBMCharacterState> Characters;
    UPROPERTY() TArray<FBMJobSave>        Jobs;       // RUNTIME ONLY
    UPROPERTY() TArray<FBMPendingFollowup> PendingFollowups;
};

USTRUCT() struct FBMJobSave {     // [V] exactly the Godot encode_job shape
    FBMJobId JobId; EBMJobStage Stage;
    TArray<FName> ChosenPrep; FName ChosenApproach, ChosenCoverUp;
    int32 TicksRemaining; FBMJobOutcome Outcome; bool bOutcomeValid;
};
```

**Versioning policy `[V]`, carried verbatim from the verified build:**

| Change | Version bump? | Handling |
|---|---|---|
| New field with a safe default | **No** | Defaulted `UPROPERTY`; old saves load |
| New enum value **appended** | **No** | Append-only rule on `EBMJobOrigin` etc. |
| Field removed / renamed / retyped | **Yes** | Old saves **refused** |
| Enum values reordered | **Yes** | Would silently corrupt meaning |
| Container shape changed | **Yes** | |

**On mismatch: hard refusal.** Refuse the whole load, leave campaign state untouched, log at
`LogBMSave` Warning. No migration, no partial application. `[V]` This is verified behavior
(`"ok: version mismatch is refused"`, `"ok: refused load leaves state untouched"`).

### 7.1 What is deliberately NOT saved

`[V]` Night-cycle summary accumulators (dirty/clean earned, cycle-start heat) are **not** persisted in
Godot — they are framing, recomputed per cycle. Also not saved: view models, UI state, transient
visuals, and any derived value.

---

## 8. Derived values — computed, never stored

| Value | Formula | `[V]` Source |
|---|---|---|
| `DistrictDemand` | `0.5 + Prosperity` | `district_data.gd` |
| `DirtyIncome` | `BaseYield × Demand × Staff × ControlMod × (1−Disruption)`, rounded | `economy_math.gd` |
| `FrontClean` | `LaunderingCapacity × FrontEfficiency × (1−OperatingCost)`, rounded | `economy_math.gd` |
| `ExposureGain` | `Overflow × RacketRisk × Visibility × 0.0001` | `economy_math.gd` |
| `DisruptionFromHeat` | `0` if `h ≤ 0.3`, else `(h−0.3)/0.7 × 0.6` | `economy_math.gd` |
| `CasePressure` | `clamp(Σ weights, 0, 1)` | `evidence_math.gd` |
| `CombinedPressure` | `LocalHeat + 0.5 × CasePressure` | `evidence_math.gd` |
| `CityPressure` | **mean** of districts' combined pressure | `pressure_math.gd` |
| `BetrayalPressure` | `Amb+Grv+Lev+Surv − Trust − Shared − Fear`, clamp 0..4 | `character_data.gd` |
| `BetrayalOpportunity` | inspection +0.35, sabotage +0.3, leverage ×0.5; clamp 0..1 | `loyalty_scoring.gd` |
| `RecruitSusceptibility` | `(1−Trust)×0.4 + Grievance×0.4 + Ambition×0.2` | `rival_scoring.gd` |
| `TargetWeakness` | `Disruption×0.5` + state bonus + 0.3 if inspected | `rival_scoring.gd` |
| `FreeOperatives` | `max(0, Pool − Σ assigned)` | `operative_math.gd` |
| `BuildingFloors` | `2 + clamp(Influence,0,1) × 4` | `kit_assembler.gd` |

---

## 9. The hash utility — one implementation

`[V]` Currently duplicated byte-for-byte across `rival_scoring.gd` and `job_generator.gd` (TD-05),
with a comment demanding they stay identical. `[P]` One implementation, explicit unsigned arithmetic:

```cpp
namespace FBMHash
{
    // Godot String.hash() — DJB2 over UTF-8 bytes. MUST match exactly. See 08 §4.
    uint32 StringHash(const FString& S);

    // splitmix64 finalizer. Godot ints wrap mod 2^64; uint64 makes that explicit and defined.
    inline uint64 Avalanche(uint64 X)
    {
        X = (X ^ (X >> 30)) * 0xBF58476D1CE4E5B9ULL;
        X = (X ^ (X >> 27)) * 0x94D049BB133111EBULL;
        return X ^ (X >> 31);
    }

    float TieJitter(FName RivalId, FName TargetId, EBMRivalAction Action, int32 Salt);
    int32 VariantIndex(const FString& SeedString, int32 Count);
}
```

`[V]` The Godot literals are the *signed* renderings of these constants: `-49064778989728563` is
`0xBF58476D1CE4E5B9`, `-4265267296055464877` is `0x94D049BB133111EB`. Confirming that correspondence
numerically — and confirming Godot's `String.hash()` — is **mandatory before any golden vector is
trusted**; see [08_TEST_STRATEGY.md](08_TEST_STRATEGY.md) §4. This is the highest-risk detail in the
entire port.

---

## 10. Content authoring layout

```
Content/BlackMeridian/
├─ Data/
│  ├─ Districts/   DA_District_GlassWharf
│  ├─ Venues/      DA_Venue_GW_Contraband, _Nightclub, _Protection, _Gaming,
│  │               _Freight, _Clinic, _Saltworks
│  ├─ Factions/    DA_Faction_Compact, DA_Faction_Corvine
│  ├─ Characters/  DA_Char_Aiko, _Regent, _BengalLt, _RavenBoss
│  ├─ Jobs/
│  │  ├─ Authored/  DA_Job_InterceptedShipment, _InspectorsLedger,
│  │  │             _LieutenantsDebt, _MeridianAccord
│  │  └─ Templates/ DA_JobTpl_Retaliation_V0/V1, _BuryCase_V0/V1,
│  │                _Contested_V0/V1, _Followup
│  ├─ Balance/     DT_BMBalance
│  └─ World/       DA_WorldSeed_Slice
├─ Levels/         L_BM_Persistent, L_GlassWharf_Strategic,
│                  L_Warehouse_Embodied, L_Council_Embodied
├─ UI/             WBP_HUD, WBP_JobPanel, WBP_Roster, WBP_Ending, WBP_Settings
├─ Characters/     SK_*, ABP_*, CR_*
├─ Environments/   Wharf kit, props
└─ Cinematics/     LS_Warehouse_Entry, LS_Confrontation_*
```

`[V]` The seven Glass Wharf venues and their exact seed values (yields 220/140/180/160/90, capacities
600/450, efficiencies 0.75/0.7, operating costs 0.18/0.2, `racket_risk` 0.3 throughout) are recorded in
[01_SOURCE_AUDIT.md](01_SOURCE_AUDIT.md) and reproduced in [06_VERTICAL_SLICE.md](06_VERTICAL_SLICE.md) §3.

---

**Next:** [06_VERTICAL_SLICE.md](06_VERTICAL_SLICE.md)
