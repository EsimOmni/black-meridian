# 13 — Repository Bootstrap

Exact steps to create `../black-meridian-ue/`. **Do not execute these during planning** — they run in
S0, after Cem's approval.

Tags: `[V]` Verified in this environment · `[P]` Proposed · `[U]` Unverified

---

## 0. Verified environment

`[V]` Checked on this machine during the audit:

| Component | Value | Source |
|---|---|---|
| **Unreal Engine** | **5.8.2** (`++UE5+Release-5.8`, CL 56702186, promoted build) | `C:\Program Files\Epic Games\UE_5.8\Engine\Build\Build.version` |
| Editor binaries | `UnrealEditor.exe`, `UnrealEditor-Cmd.exe` present | `Engine\Binaries\Win64\` |
| Build scripts | `Build.bat`, `RunUAT.bat` present | `Engine\Build\BatchFiles\` |
| **C++ toolchain** | **VS Build Tools 2022 17.14.35** + **NetFx SDK 4.8** — ⚠️ the NetFx SDK is **mandatory even for S0** (see D-01 note below); IDE still absent | `vswhere` |
| MSVC | **14.44.35207**, `cl.exe` present (Hostx64/x64) | `VC\Tools\MSVC\` |
| Windows SDK | **10.0.26100.0** | `Windows Kits\10\Include\` |
| .NET | system **8.0.31** — ⚠️ **not sufficient on its own**; UE 5.8.2's UnrealBuildTool targets **.NET 10**. The engine ships its own at `Engine\Binaries\ThirdParty\DotNet\10.0\win-x64\`, which `Build.bat` uses automatically. No system install needed. (S0 finding 4.) | `dotnet --list-runtimes` |
| **Git LFS** | **3.7.0** | `git lfs version` |
| Disk (D:) | **1.2 TB free** of 1.9 TB | `df -h` |
| Disk (C:) | 187 GB free of 931 GB | `df -h` |
| GPU | RTX 5060 Ti 16 GB (128-bit) | User hardware record |

`[P]` **Place the repo on D:** — `D:\black-meridian-ue`, sibling to `D:\black-meridian`. C: has only
187 GB free and an Unreal project with DDC will consume a lot of it.

### 0.1 `[V]` Mandatory prerequisite — the .NET Framework SDK (D-01 correction)

> WARNING: **S0 cannot build without this.** An earlier revision assumed S0 could proceed on the
> standalone Build Tools and that D-01 (Visual Studio) was only needed before S1. **That was wrong.**
> `UnrealEd.Build.cs` lists **`SwarmInterface`** as an *unconditional* dependency, and SwarmInterface
> requires the **.NET Framework 4.6+ SDK**, which the standalone Build Tools install does not carry:
>
> ```
> Unable to instantiate module 'SwarmInterface': Could not find NetFxSDK install dir
> (referenced via BlackMeridianEditor -> ... -> UnrealEd.Build.cs)
> ```
>
> There is no NetFxSDK-free path to an editor build — the dependency is not optional or configurable.

Install it into the existing Build Tools (a full IDE is **not** required for S0):

```powershell
& "C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe" modify `
    --channelId VisualStudio.17.Release `
    --productId Microsoft.VisualStudio.Product.BuildTools `
    --add Microsoft.Net.Component.4.8.SDK `
    --add Microsoft.Net.Component.4.8.TargetingPack `
    --add Microsoft.Net.ComponentGroup.TargetingPacks.Common
```

`[V]` Installer command-line traps, each of which cost a failed run on installer 4.7.25:

| Trap | Reality |
|---|---|
| `--wait` | Does not exist on this installer version. Use `Start-Process -Wait`. |
| `--norestart` alone | Rejected — requires `--quiet` or `--passive` alongside it. |
| `--quiet` / `--passive` | Require the process to be **already elevated**, else exit **5007**. |
| `--installPath "C:\Program Files (x86)\..."` | Truncates at the first space; the 8.3 short path is rejected outright. Use `--channelId` + `--productId` and sidestep paths entirely. |
| Another installer window open | Exit **5007**. Close it first. |

**Verify** (both must exist before attempting §8):

```sh
ls "/c/Program Files (x86)/Windows Kits/NETFXSDK/"                                   # -> 4.8
ls "/c/Program Files (x86)/Reference Assemblies/Microsoft/Framework/.NETFramework/"  # -> v4.8
```

The **IDE** half of D-01 (VS 2022 Community, for debugging) remains open and is unaffected by this —
S0 needs the SDK components, not the IDE.


---

## 1. Project creation settings

`[P]` Create via the Editor's project wizard (**not** by hand-writing `.uproject` — the wizard
generates correct module boilerplate).

| Setting | Value | Why |
|---|---|---|
| Template | **Blank** | No third-person character, no starter input — `[V]` the game has no combat/traversal template need |
| Project type | **C++** | Locked #5 |
| Target platform | **Desktop** | `[V]` Windows first, Steam (Locked #4) |
| Quality preset | **Maximum** | Small bounded scenes; the interior is the visual payload |
| Starter content | **No** | Avoids unlicensed/unwanted assets in the ledger |
| Raytracing | **No** | `[V]` brief §15: *"no ray tracing requirement"* |
| Project name | `BlackMeridian` | No spaces |
| Location | `D:\black-meridian-ue` | §0 |

### 1.1 Plugins

**Enable** (first-party only — R-16):

| Plugin | Justification |
|---|---|
| **Enhanced Input** | `[V]` Rebinding is a brief §19 Month-5 deliverable; P20 implements it manually today |
| **Common UI** | `[V]` Replaces the hand-rolled `hud_layers` visibility stack |
| **Level Sequence / Sequencer** | Core to the reboot's justification |
| **Control Rig** | Hero character facial/body adjustment |
| **Functional Testing Editor** | Test strategy |
| **Editor Scripting Utilities** | Asset validation + commandlets |
| **Data Validation** | `UBMAssetValidator` |
| ~~glTF Importer~~ | ⚠️ **`[V]` No such plugin in UE 5.8 — do NOT list it.** glTF *import* is provided by **Interchange** (built in, always enabled); `GLTFExporter` is export-only. Naming it fails the build outright: `Unable to find plugin 'GLTFImporter'`. Existing validated GLB assets import with no plugin entry. (S0 finding 3.) |

**Explicitly disable / do not enable:** World Partition (Locked #10), Chaos Vehicles (`[V]` brief
§12.3), Gameplay Ability System ([04](04_UNREAL_ARCHITECTURE.md) §9), Online Subsystem / networking
(single-player), Niagara Fluids, any marketplace plugin.

`[V]` **Do not write these into the `.uproject` as `"Enabled": false`.** They are off by default, so
an explicit entry buys nothing and creates a plugin *name* that can go stale and hard-fail the build
— which is exactly how `GLTFImporter` above broke S0. Absence is the enforcement; a list of names is
a liability. Verify a plugin's real name against the engine's own
`Engine\Plugins\**\*.uplugin` files before adding any entry.

---

## 2. Directory structure

```
D:\black-meridian-ue\
├─ BlackMeridian.uproject
├─ .gitignore
├─ .gitattributes                 ← LFS rules; commit BEFORE any asset
├─ README.md
├─ NOW.md                         ← live state, per the Godot practice
├─ Config/
│  ├─ DefaultEngine.ini
│  ├─ DefaultGame.ini
│  ├─ DefaultInput.ini
│  └─ DefaultEditor.ini
├─ Source/
│  ├─ BlackMeridian.Target.cs
│  ├─ BlackMeridianEditor.Target.cs
│  ├─ BMCore/        ← pure logic, NO Engine dependency
│  │  ├─ BMCore.Build.cs
│  │  ├─ Public/{BMTypes.h,BMConstants.h,BMHash.h,BMEconomyMath.h,BMEvidence.h,
│  │  │           BMPressureMath.h,BMLoyaltyScoring.h,BMRivalScoring.h,
│  │  │           BMJobLifecycle.h,BMJobResolution.h,BMJobGenerator.h,BMState.h}
│  │  └─ Private/…
│  ├─ BMSim/         ← subsystems owning state
│  ├─ BMGame/        ← actors, pawn, cameras, transition
│  ├─ BMUI/          ← widgets, view models
│  └─ BMEditor/      ← validators, commandlets, golden-vector tooling
├─ Content/BlackMeridian/         ← see 05_DATA_MODEL §10
├─ Tests/
│  ├─ Golden/                     ← JSON vectors extracted from Godot
│  └─ Fixtures/Saves/             ← one .bmsav per shipped save version; NEVER regenerate one
│                                   to make its test pass (08 §8)
├─ Docs/
│  ├─ gates/                      ← S<n>.md gate evidence notes
│  ├─ ATTRIBUTIONS.md             ← migrated, not restarted
│  └─ lessons.md                  ← continues the Godot practice
└─ Builds/                        ← gitignored
```

---

## 3. Module definitions

```csharp
// BMCore.Build.cs — deliberately minimal: the absence of "Engine" is the enforcement mechanism
public class BMCore : ModuleRules {
    public BMCore(ReadOnlyTargetRules Target) : base(Target) {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
        PublicDependencyModuleNames.AddRange(new string[] { "Core" });
        // NO "Engine", NO "CoreUObject" beyond what USTRUCT reflection requires.
        // See 04_UNREAL_ARCHITECTURE.md §2 — this is why determinism cannot leak.
    }
}

// BMSim.Build.cs
PublicDependencyModuleNames.AddRange(new[]{ "Core","CoreUObject","Engine","BMCore","GameplayTags" });

// BMGame.Build.cs
PublicDependencyModuleNames.AddRange(new[]{ "Core","CoreUObject","Engine","BMCore","BMSim",
    "EnhancedInput","LevelSequence","MovieScene","AIModule" });

// BMUI.Build.cs
PublicDependencyModuleNames.AddRange(new[]{ "Core","CoreUObject","Engine","UMG","Slate","SlateCore",
    "CommonUI","BMCore","BMSim" });

// BMEditor.Build.cs  (Type = Editor, LoadingPhase = PostEngineInit)
PublicDependencyModuleNames.AddRange(new[]{ "Core","CoreUObject","Engine","UnrealEd",
    "DataValidation","BMCore","BMSim","Json","JsonUtilities" });
```

### 3.1 `[V]` BMGame is the PRIMARY game module

```cpp
// Source/BMGame/Private/BMGame.cpp
IMPLEMENT_PRIMARY_GAME_MODULE(FBMGameModule, BMGame, "BlackMeridian")
```

Exactly one module must use `IMPLEMENT_PRIMARY_GAME_MODULE`; the other four take plain
`IMPLEMENT_MODULE`. It supplies `GInternalProjectName`, `GIsGameAgnosticExe`, `GForeignEngineDir` and
the `FMemory_*` engine-loop symbols.

> WARNING: **The editor target builds clean either way** — the editor carries its own launch module.
> The failure appears only in the monolithic Shipping link, as
> `LNK1120: 6 unresolved externals`. This is precisely why packaging (§10) is an S0 gate item and is
> not deferred: nothing else in the checklist surfaces it. (S0 finding.)

---

## 4. Source control

### 4.1 `.gitattributes` — commit this **first**, before any asset

`[P]` `[V]` R-07 is High probability; LFS retrofitting rewrites history.

```gitattributes
* text=auto

# ---- Unreal binary assets → LFS ----
*.uasset  filter=lfs diff=lfs merge=lfs -text
*.umap    filter=lfs diff=lfs merge=lfs -text
*.ubulk   filter=lfs diff=lfs merge=lfs -text
*.uexp    filter=lfs diff=lfs merge=lfs -text
*.upack   filter=lfs diff=lfs merge=lfs -text

# ---- Source art / media → LFS ----
*.fbx   filter=lfs diff=lfs merge=lfs -text
*.glb   filter=lfs diff=lfs merge=lfs -text
*.gltf  filter=lfs diff=lfs merge=lfs -text
*.blend filter=lfs diff=lfs merge=lfs -text
*.obj   filter=lfs diff=lfs merge=lfs -text
*.png   filter=lfs diff=lfs merge=lfs -text
*.jpg   filter=lfs diff=lfs merge=lfs -text
*.jpeg  filter=lfs diff=lfs merge=lfs -text
*.tga   filter=lfs diff=lfs merge=lfs -text
*.psd   filter=lfs diff=lfs merge=lfs -text
*.exr   filter=lfs diff=lfs merge=lfs -text
*.hdr   filter=lfs diff=lfs merge=lfs -text
*.dds   filter=lfs diff=lfs merge=lfs -text
*.tif   filter=lfs diff=lfs merge=lfs -text
*.wav   filter=lfs diff=lfs merge=lfs -text
*.mp3   filter=lfs diff=lfs merge=lfs -text
*.ogg   filter=lfs diff=lfs merge=lfs -text
*.flac  filter=lfs diff=lfs merge=lfs -text
*.mp4   filter=lfs diff=lfs merge=lfs -text
*.mov   filter=lfs diff=lfs merge=lfs -text
*.ttf   filter=lfs diff=lfs merge=lfs -text
*.otf   filter=lfs diff=lfs merge=lfs -text

# ---- Text stays text (LF, per the Godot lesson about CRLF churn) ----
*.h        text eol=lf
*.cpp      text eol=lf
*.cs       text eol=lf
*.ini      text eol=lf
*.json     text eol=lf
*.md       text eol=lf
*.txt      text eol=lf
*.uproject text eol=lf
```

`[V]` The LF pinning mirrors the Godot `.gitattributes`, which exists because `core.autocrlf` caused
every re-import to show phantom modifications.

> ⚠️ **`[V]` One pattern per line — this is not cosmetic.** An earlier revision of this section wrote
> the art rules as space-separated globs (`*.fbx *.glb *.gltf ... filter=lfs ...`). Git reads exactly
> **one pattern per line** and parses everything after it as attributes, so only `*.fbx` would have
> been tracked; `.glb`, `.png`, `.wav` and the rest would have entered the repository as raw blobs —
> precisely the R-07 failure this section exists to prevent, and invisible until a retroactive history
> rewrite. Corrected during S0 (`Docs/gates/S0.md`, finding 2). Verify with
> `git check-attr filter -- Content/X.uasset Content/Y.png Source/Z.cpp` before trusting the rules.

### 4.2 `.gitignore`

```gitignore
Binaries/
Build/
DerivedDataCache/
Intermediate/
Saved/
Builds/
*.VC.db
*.opensdf
*.sdf
*.sln
*.slnx
*.suo
*.xcodeproj
*.xcworkspace
.vs/
.idea/
# Source art lives OUTSIDE the repo (see 09 §; keep working files local)
Art_Source/
```

### 4.3 Initialize

```sh
cd /d/black-meridian-ue
git init
git lfs install
git add .gitattributes .gitignore
git commit -m "chore: LFS + ignore rules before any asset lands"
git add .
git commit -m "feat(s0): Unreal C++ project skeleton — BMCore/BMSim/BMGame/BMUI/BMEditor"
git lfs ls-files          # expect: empty now, populated after the first asset
git remote add origin <per D-05>
```

`[V]` Per the user's standing rule: **commit directly to the current branch; no branches, no PRs
unless asked.**

---

## 5. Naming conventions

`[P]` Unreal standard, with a `BM` prefix for project types.

| Kind | Convention | Example |
|---|---|---|
| C++ class (UObject) | `UBM<Name>` | `UBMEconomySubsystem` |
| C++ class (Actor) | `ABM<Name>` | `ABMStrategicCamera` |
| C++ struct | `FBM<Name>` | `FBMDistrictState` |
| C++ enum | `EBM<Name>` | `EBMControlState` |
| C++ interface | `IBM<Name>` / `UBM<Name>` | `IBMCinematicWorldProvider` |
| Data Asset | `DA_<Type>_<Name>` | `DA_Venue_GW_Contraband` |
| Data Table | `DT_<Name>` | `DT_BMBalance` |
| Blueprint | `BP_<Name>` | `BP_VenueMarker` |
| Widget BP | `WBP_<Name>` | `WBP_HUD` |
| Level | `L_<Name>` | `L_GlassWharf_Strategic` |
| Level Sequence | `LS_<Name>` | `LS_Warehouse_Entry` |
| Static Mesh | `SM_<Name>` | `SM_Kit_Ground_A` |
| Skeletal Mesh | `SK_<Name>` | `SK_BengalLt` |
| Material / Instance | `M_` / `MI_` | `M_WetConcrete` / `MI_WetConcrete_Worn` |
| Texture | `T_<Name>_<Type>` | `T_Concrete_N` |
| Anim BP / Control Rig | `ABP_` / `CR_` | `ABP_BengalLt` |
| Niagara | `NS_<Name>` | `NS_Rain` |
| Sound | `S_` / `SC_` | `S_Rain_Loop` |

**Enforced** by `UBMAssetValidator` ([09](09_ASSET_AND_CHARACTER_PIPELINE.md) §6).

---

## 6. Configuration

### `Config/DefaultEngine.ini` `[P]`
```ini
[/Script/EngineSettings.GameMapsSettings]
GameDefaultMap=/Game/BlackMeridian/Levels/L_BM_Persistent
EditorStartupMap=/Game/BlackMeridian/Levels/L_BM_Persistent
GlobalDefaultGameMode=/Script/BMGame.BMGameMode

[/Script/Engine.RendererSettings]
r.DefaultFeature.AutoExposure=False        ; noir look needs authored exposure
r.DynamicGlobalIlluminationMethod=1        ; Lumen — justified for the interior
r.ReflectionMethod=1                       ; Lumen reflections (wet surfaces)
r.Shadow.Virtual.Enable=1
r.RayTracing=False                         ; brief §15
r.DefaultFeature.MotionBlur=False          ; strategy readability

[/Script/WindowsTargetPlatform.WindowsTargetSettings]
DefaultGraphicsRHI=DefaultGraphicsRHI_DX12
```

### `Config/DefaultGame.ini` `[P]`
```ini
[/Script/EngineSettings.GeneralProjectSettings]
ProjectName=OMNI: BLACK MERIDIAN
ProjectVersion=0.1.0
CompanyName=OMNI
Description=Character-driven cinematic crime strategy.

[/Script/UnrealEd.ProjectPackagingSettings]
BuildConfiguration=PPBC_Shipping
UsePakFile=True
bUseIoStore=True
```

### Environment variables `[P]`
**None required.** `[V]` The Godot project used one (`OMNI_COMFY_URL` for the Hunyuan adapter) and
that stays with the asset tooling, outside the game project. Keep it that way — a game that needs an
env var to run is a packaging bug waiting to happen.

---

## 7. Build configurations

| Config | Use | Notes |
|---|---|---|
| **Debug Editor** | Deep debugging | Slow; for determinism bisection |
| **Development Editor** | Daily work | Default |
| **Development** | Packaged testing | Perf numbers with stats available |
| **Shipping** | Release | No cheats (`Test_Shipping_NoCheats`), no `ensure` |

---

## 8. First build

```sh
UE="C:/Program Files/Epic Games/UE_5.8"
PROJ="D:/black-meridian-ue/BlackMeridian.uproject"

# 1. Generate project files
#    NOT UnrealBuildTool.exe directly: it targets .NET 10 and dies with
#    "You must install or update .NET" against a system .NET 8. Use the engine's
#    bundled runtime against the .dll (S0 finding 4).
"$UE/Engine/Binaries/ThirdParty/DotNet/10.0/win-x64/dotnet.exe" \
    "$UE/Engine/Binaries/DotNET/UnrealBuildTool/UnrealBuildTool.dll" \
    -projectfiles -project="$PROJ" -game -rocket -progress

# 2. Build the editor target  (Build.bat picks the bundled runtime itself)
"$UE/Engine/Build/BatchFiles/Build.bat" BlackMeridianEditor Win64 Development \
    -Project="$PROJ" -WaitMutex -FromMsBuild
```

`[V]` **Close any running `UnrealEditor.exe` first** — Live Coding holds the module DLLs and the
build aborts with *"Unable to build while Live Coding is active."* Any open editor blocks it, even
one on an unrelated project.

**Expected:** `Build succeeded`, non-zero-size `Binaries/Win64/UnrealEditor-BM*.dll`.

---

## 9. First test

```sh
"$UE/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" "$PROJ" \
    -ExecCmds="Automation RunTests BM.; Quit" \
    -unattended -nopause -nullrhi -nosplash \
    -testexit="Automation Test Queue Empty" \
    -log -abslog="D:/black-meridian-ue/Saved/Logs/tests.log"
```

**Expected:** every `BM.*` test passes; exit code 0.
`[V]` **Read the log file, don't pipe through grep/head** — the Godot benchmark lesson (buffering hid
output for four minutes and looked like a hang). Also grep for `Error:` before trusting a green result.

---

## 10. First packaged build

```sh
"$UE/Engine/Build/BatchFiles/RunUAT.bat" BuildCookRun \
  -project="$PROJ" -noP4 -platform=Win64 -clientconfig=Shipping \
  -cook -allmaps -build -stage -pak -archive \
  -archivedirectory="D:/black-meridian-ue/Builds"
```

**Expected:** `BUILD SUCCESSFUL`; `Builds/Windows/BlackMeridian.exe` launches on a machine without the
editor `[V]` (brief §18 Technical acceptance).

---

## 11. S0 validation checklist

| # | Check | Command | Expected |
|---|---|---|---|
| 1 | Engine version | `cat "$UE/Engine/Build/Build.version"` | 5.8.2, CL 56702186 |
| 2 | Toolchain | `vswhere -requires …VC.Tools.x86.x64 -property installationPath` | non-empty |
| 2b | **NetFx SDK (§0.1)** | `ls "/c/Program Files (x86)/Windows Kits/NETFXSDK/"` | **4.8** — blocks the editor build if missing |
| 3 | LFS | `git lfs version` | 3.7.0+ |
| 4 | Project files | §8 step 1 | `.sln` generated |
| 5 | Editor build | §8 step 2 | `Build succeeded` |
| 6 | Modules load | launch editor, check log | no missing-module errors |
| 7 | Smoke test | §9 | pass, exit 0 |
| 8 | Packaging | §10 | `BUILD SUCCESSFUL` |
| 9 | Clean tree | `git status --short` | empty |
| 10 | LFS coverage | `git lfs ls-files` | all binaries tracked |
| 11 | Godot repo untouched | `cd /d/black-meridian && git status --short` | **unchanged from the audit snapshot** |

---

## 12. Migration boundaries

**What crosses from the Godot repository:**

| Item | How | Why |
|---|---|---|
| Behavioral specs (constants, formulas, state machines) | Transcribed into C++ | The whole point |
| Golden vectors | **Extracted by running the Godot build** | The oracle |
| `assets/ATTRIBUTIONS.md` | Copied and continued | `[V]` Legal obligation carries over |
| Validated GLB kit/props | Re-imported through the Unreal validator | `[V]` Already cleaned and licence-logged |
| `tasks/lessons.md` | Copied and continued | Hard-won, still applicable |
| Gate-note practice | Continued in `Docs/gates/` | What made this audit possible |
| Concept art / masters | Copied | Art direction |

**What does NOT cross:** any `.gd` file · `.tscn`/`.tres` · the GDGS plugin and its patch · the
godot-ai rail · Godot `.import` metadata · `project.godot` · the Godot test harness · `var_to_str` saves.

**The Godot repository is archived, read-only, and never deleted** (Locked #1). `[P]` Keep it runnable:
Gate B requires playing its cinematic scene side-by-side with the Unreal one.

---

## 13. What S0 must NOT do

- ⛔ Import any art asset (Gate A first — Locked #15).
- ⛔ Create Blueprints.
- ⛔ Enable World Partition or any plugin outside §1.1.
- ⛔ Write game logic (that is S1+).
- ⛔ Modify `D:\black-meridian` in any way.

---

**Next:** [ADR-0001-UNREAL-REBOOT.md](ADR-0001-UNREAL-REBOOT.md) · [MASTER_PLAN.md](MASTER_PLAN.md)
