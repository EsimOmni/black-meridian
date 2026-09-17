# 01 — Source Audit: the Godot repository as behavioral evidence

**Purpose:** establish what actually exists in `D:\black-meridian`, what is proven, what is stale, and
which parts must **not** shape the Unreal architecture. Every material claim carries a repository path.

**Audit date:** 2026-09-17/18 · **HEAD at audit:** `7aa0872` *feat(p19): slice endings + live city-state read (content-lite)*

Tags: `[Verified from repository]` · `[Inferred]` · `[Proposed]` · `[Unverified]`

---

## 1. Repository inventory

`[Verified from repository]`

| Area | Contents | Count |
|---|---|---|
| `src/` | Simulation, AI, jobs, narrative, save, presentation — GDScript | 40 files, **4,367 lines** |
| `scenes/` | bootstrap, city, cinematic, ui | 22 scripts |
| `tests/unit/` | Unit suites | 24 tests |
| `tests/integration/` | Runners (save round-trip, bootstrap smoke) | 2 |
| `tools/validation/` | Probes + GLB validator | 11 |
| `docs/prompts/` | Ordered build slices P01–P24 | 34 |
| `docs/prompts/notes/` | Gate notes + acceptance records | 24 |
| `assets/` | city, props, characters/portraits, splat, ui, audio | — |
| `.git` | Repository history | **155 MB**, 2,275 objects |

**Engine:** Godot 4.7 (`D:\Godot\Godot_v4.7-stable_win64.exe`); `project.godot` declares
`config/features=PackedStringArray("4.8", "Forward Plus")` — a **stale feature tag** vs the actual 4.7
binary in use (`[Verified]`, see §6.2).

### 1.1 Autoload / wiring topology — load-bearing for the port

`[Verified from repository]` `project.godot` `[autoload]`, in order:

```
GameState        → src/core/game_state.gd
TimeService      → src/simulation/time_service.gd
EconomyService   → src/simulation/economy_service.gd
JobDirector      → src/jobs/job_director.gd
SaveService      → src/save/save_service.gd
RivalDirector    → src/ai/rival_director.gd
SettingsService  → src/presentation/settings_service.gd     ← UNCOMMITTED
_mcp_game_helper → addons/godot_ai/runtime/game_helper.gd    ← dev tooling
```

**Scene-wired, deliberately NOT autoloads** (`scenes/bootstrap/bootstrap.gd`):
`NightCycle`, `RelationshipService`, `NarrativeDirector`, `CinematicTransition`.

This split is **intentional and load-bearing**, recorded in `tasks/lessons.md`: *"a driver whose
_ready/tick changes shared state belongs in the scene, not the autoload list, unless every test
genuinely wants it running."* NightCycle as an autoload would silently advance phases underneath every
other system's unit tests. **The Unreal port must preserve this distinction** — it maps to
`UGameInstanceSubsystem` (global) vs world/GameMode-owned actors (scoped). See
[04_UNREAL_ARCHITECTURE.md](04_UNREAL_ARCHITECTURE.md) §3.

---

## 2. Implemented systems

`[Verified from repository]` Every system below was read in full at source level.

| System | File(s) | State |
|---|---|---|
| Shared enums + tick constants | `src/core/enums.gd` (`BM`) | Complete |
| World container + lookups | `src/core/game_state.gd` | Complete |
| Typed data resources | `src/core/{district,venue,faction,character,job,job_choice,evidence_case}_data.gd` | Complete |
| World seeding | `src/core/world_seed.gd` | Complete (code-built, not `/data`) |
| Time / pause / speeds | `src/simulation/time_service.gd` | Complete |
| Economy settle | `src/simulation/economy_service.gd` | Complete |
| Economy formulas | `src/simulation/economy_math.gd` | Complete, unit-tested |
| Evidence cases | `src/simulation/evidence_math.gd` | Complete |
| Central pressure | `src/simulation/pressure_math.gd` | Complete |
| Loyalty / betrayal | `src/simulation/loyalty_scoring.gd` + `relationship_service.gd` | Complete |
| Operative pool | `src/simulation/operative_math.gd` | Complete |
| Night Cycle phases | `src/simulation/night_cycle.gd` | Complete |
| Rival utility AI | `src/ai/rival_scoring.gd` + `rival_director.gd` | **Partial** — 5 of 10 actions scored |
| Job lifecycle | `src/jobs/job_lifecycle.gd` | Complete (4 stages) |
| Job resolution | `src/jobs/job_resolution.gd` | Complete (9 dimensions) |
| Authored jobs | `src/jobs/job_templates.gd` | Complete |
| Systemic generation | `src/jobs/job_generator.gd` | Complete (4 origins) |
| Job routing / cadence | `src/jobs/job_director.gd` | Complete (cap 3) |
| Narrative spine | `src/narrative/{narrative_director,narrative_beats,narrative_jobs}.gd` | Complete (3 beats + 3 endings) |
| Save / load | `src/save/{save_service,save_codec}.gd` | Complete (v1) |
| Cinematic transition | `src/presentation/cinematic_transition.gd` | Complete |
| World provider seam | `src/presentation/{cinematic_world_provider,mesh_world_provider,splat_world_provider}.gd` | Complete |
| City proxy + kit | `scenes/city/city_view.gd`, `src/presentation/kit_assembler.gd` | Complete |
| UI panels | `scenes/ui/*.gd` | Complete (3 uncommitted) |

### 2.1 Rival AI is only half-built — a real gap

`[Verified from repository]` `BM.RivalAction` declares **10** actions; `RivalScoring.score_action`
scores only **5** (EXPAND, PROBE, SABOTAGE, RECRUIT, FRAME). The other five — BRIBE, RETALIATE,
NEGOTIATE, REDUCE_HEAT, DEFEND — fall to the `default:` branch and return `-INF`, so they can never
be chosen. Brief §7.4 lists all ten plus "exploit a character grievance" as the intended set.

**Port implication:** the Unreal rival AI inherits a *proven scoring architecture* with a
*known-incomplete action set*. Do not mistake the five for the design. Tracked in
[03_BEHAVIORAL_PORT_MATRIX.md](03_BEHAVIORAL_PORT_MATRIX.md) as ADAPT.

---

## 3. Test coverage — run in this session

`[Verified from repository — executed 2026-09-17, results recorded verbatim]`

### 3.1 Import / parse

```sh
GODOT="D:/Godot/Godot_v4.7-stable_win64_console.exe"
"$GODOT" --headless --path . --import
```
**Result:** exit 0, zero `SCRIPT ERROR` / `Parse Error` lines.

### 3.2 Unit suite — 24/24 PASS

⚠️ **The suite is bimodal and this matters.** Tests declaring `extends SceneTree` run via `-s`;
tests declaring `extends Node` **must** run as their `.tscn` (running them with `-s` skips autoloads
and they fail with `Identifier not found: RivalDirector`). Running everything with `-s` produced a
misleading **20 false failures** in this audit's first pass. Correct invocation:

```sh
for t in tests/unit/*.gd; do
  base="${t%.gd}"
  if head -3 "$t" | grep -q "extends SceneTree"; then mode="-s $t"; else mode="res://$base.tscn"; fi
  "$GODOT" --headless --path . $mode
done
```

**Result: PASSED=24 FAILED=0 SKIPPED=0.**

| Mode | Tests |
|---|---|
| `-s` (SceneTree) | `test_economy`, `test_job_lifecycle`, `test_kit_assembler`, `test_territory_loss_p08b` |
| `.tscn` (Node + autoloads) | the other 20 |

Covered: economy, economy verbs, evidence, heat consequence, central pressure, job generation,
job lifecycle, job resolution, job variety, territory loss/cycle, loyalty (×2), night cycle,
operative pool, rival AI (×2), narrative, endings, cinematic checkpoint, reveal/crime-scene
persistence, kit assembler, GLB validator.

### 3.3 Integration runners — both PASS

```sh
"$GODOT" --headless --path . res://tests/integration/save_roundtrip_runner.tscn   # exit 0
"$GODOT" --headless --path . res://tests/integration/bootstrap_smoke_runner.tscn  # exit 0
```

`save_roundtrip_runner` → `[PASS] save/load deterministic round-trip`, asserting:
save succeeds · state diverged after save · load succeeds · **loaded state equals the saved snapshot
byte-for-byte** · **replay after load reproduces the same state** · version mismatch refused ·
refused load leaves state untouched.

`bootstrap_smoke_runner` → `[PASS] bootstrap smoke + in-scene save/load`, covering the full
four-stage job progression, reward application, quick-save/load mid-loop, cash+tick restoration,
paused-on-load, and HUD re-render.

### 3.4 Determinism proof — the key result

The 1800-tick full-cycle probe was run **twice** and the cleaned outputs compared:

```sh
"$GODOT" --headless --path . res://tools/validation/full_cycle_probe.tscn > probeA.log 2>&1
"$GODOT" --headless --path . res://tools/validation/full_cycle_probe.tscn > probeB.log 2>&1
diff probeA.clean probeB.clean    # → identical
```

**Result: byte-identical across runs.** Verdict line: `VERDICT: LOOP ALIVE`.
Summary: 40 jobs offered / 40 resolved · 4 phase transitions · cycle 2 reached · dirty $5,000 → $298,022 ·
clean capital $1,119,300 · central pressure peak 0.420 (bar 0.60, never fired) · 0/15 dead stretches.

This is the empirical basis for the golden-vector strategy in [08_TEST_STRATEGY.md](08_TEST_STRATEGY.md).

### 3.5 Known-clean noise baseline

`[Verified]` The bootstrap smoke run emits `Leaked instance dependency` warnings, `47 ObjectDB
instances were leaked at exit`, and `1 resources still in use at exit`. `tasks/lessons.md` records
these as **pre-existing since P14**, verified on a clean HEAD worktree with zero new code. They are
noise, not a regression — but they *are* an unfixed defect (§5, TD-04).

---

## 4. Verified milestones

`[Verified from repository]` `docs/prompts/notes/`:

| Milestone | Note | Verdict |
|---|---|---|
| Splat kill criterion | `P01-splat-benchmark.md` | **SPLAT_OK** — 542,246 splats, 483 avg / 420 1%-low fps @1080p, RTX 5060 Ti |
| Month 1 | `P04-month1-gate.md` | PASSED |
| Month 2 | `P08-month2-gate.md`, `P11-month2-gate.md` | PASSED — "fun, there's stress, very good" (short session) |
| Month 3 | `P14b-month3-gate.md` | PASSED, one item re-scoped |
| Month 4 | `P18-month4-gate.md` | PASSED on evidence; feel session pending |

**Caveat carried forward** `[Verified]`: the Month-2 verdict was a **~35-tick short session**, not a
played-through 25–30 minute Night Cycle. The note says so itself. The full-length feel confirmation
was deferred and, per `docs/NOW.md`, **Cem gate #1 (the cinematic feel session) was still pending** at
the time of this audit. So: *the loop is proven fun in the small and proven alive in the large
(probe), but a human has never sat through a full cycle start to finish.* The Unreal roadmap must not
inherit an unearned assumption here — see [07_IMPLEMENTATION_ROADMAP.md](07_IMPLEMENTATION_ROADMAP.md) Slice 4.

---

## 5. Technical debt

| ID | Debt | Evidence | Port impact |
|---|---|---|---|
| **TD-01** | Rival AI: 5 of 10 actions unscored | `src/ai/rival_scoring.gd` `default: -INF` | Design gap, not a port gap |
| **TD-02** | World is code-seeded, not data-driven | `src/core/world_seed.gd`; brief §13.3 wants `/data` | **Must fix in port** — Locked #5 requires data-driven content |
| **TD-03** | Jobs are code-as-data | `narrative_jobs.gd`, `job_templates.gd`; `docs/NOW.md` records the `.tres` migration was **CUT** ship-first | **Must fix in port** — DataAssets |
| **TD-04** | Resource leaks at exit | 47 ObjectDB instances; pre-existing since P14 | Does not transfer; don't reproduce |
| **TD-05** | `_avalanche` duplicated byte-for-byte in 2 files | `rival_scoring.gd` + `job_generator.gd`, deliberate, comment demands they stay identical | Port as **one** shared utility |
| **TD-06** | `glass_wharf` district id hardcoded | `night_cycle.gd::_reset_summary` | Generalize before multi-district |
| **TD-07** | Debug keys mutate sim state | `bootstrap.gd` `KEY_B` force-arms betrayal; `KEY_N` deposits evidence | Port behind a dev-only cheat manager |
| **TD-08** | Uncommitted P20 work in tree | 5 modified + 4 new scripts + `assets/audio/` | Decision D-08 |
| **TD-09** | Stale engine feature tag | `project.godot` says `"4.8"`, binary is 4.7 | Cosmetic; noted for accuracy |
| **TD-10** | One room serves both cinematic types | `mesh_world_provider.gd` | Reboot reverses this |

---

## 6. Stale or conflicting documentation — read this before trusting any doc

### 6.1 `docs/astra-recovery/` is NOT documentation

`[Verified from repository]` **Finding:** the untracked directory `docs/astra-recovery/` contains seven
files with authoritative-sounding names — `01_REPOSITORY_REALITY.md`, `02_GAME_FLOW_V2.md`,
`03_GENERATIVE_CINEMA_ARCHITECTURE.md`, `04_IDENTITY_MIGRATION.md`, `05_RECOVERY_EXECUTION_PLAN.md`,
`06_DECISIONS_REQUIRED.md`, `README.md`.

**None of them contain their titular content.** Every one is a captured dump of Godot headless
stdout — engine banner, test PASS lines, a certificate-store error. `README.md` holds a full-cycle
probe log. They are redirected-output accidents that landed on planning filenames.

**Why it matters:** a future agent (or Cem) reading `06_DECISIONS_REQUIRED.md` expecting decisions
would find a test log — and this package deliberately creates a file of the *same name* in a different
directory. **They are unrelated.** This planning package lives **only** in `docs/unreal-reboot/`.

**Recommendation** `[Proposed]`: delete or rename `docs/astra-recovery/`. **Not done here** — the task
forbids deleting or moving anything. Raised as **D-09**.

### 6.2 Other conflicts

| # | Conflict | Authoritative source | Resolution |
|---|---|---|---|
| C-1 | Brief §13.1 mandates **Godot**, forbids engine switch unless the splat spike fails — and it **passed** | Prompt's locked decisions outrank the brief | **Superseded, not merged.** Recorded in [ADR-0001](ADR-0001-UNREAL-REBOOT.md) |
| C-2 | `README.md` says "Current milestone — Month 1" with unchecked boxes; the project finished Month 4 | `docs/NOW.md` (live state) | README is **stale**; NOW.md governs |
| C-3 | `CLAUDE.md` "Current status" says Month 2 COMPLETE; NOW.md says Month 4 passed | `docs/NOW.md`, self-declared as source of truth | CLAUDE.md lags by design |
| C-4 | Brief §12.1 slice = 45–60 min, 8 jobs, 4 characters | Prompt §Vertical slice = 20–30 min | Prompt wins; slice is **narrower**. See [06_VERTICAL_SLICE.md](06_VERTICAL_SLICE.md) §1 |
| C-5 | Brief §19 Month-3 gate requires "1 character animation"; the Godot build has no 3D cast | Ship-first decision, `docs/NOW.md` | Trimmed in Godot; **reboot reverses it** |
| C-6 | `project.godot` feature tag `"4.8"` vs 4.7 binary | Binary | Cosmetic (TD-09) |
| C-7 | Brief §7.7 wants splats for cinematics | Reboot: authored 3D | Superseded; D-07 asks if splats return |

### 6.3 Documentation that IS reliable

`docs/NOW.md` (live state) · `docs/prompts/notes/*` (gate evidence) · `tasks/lessons.md`
(hard-won, specific, repeatedly validated) · `assets/ATTRIBUTIONS.md` (license ledger) ·
the brief PDF **for design intent** (not for the engine decision).

---

## 7. Reusable behavioral specifications

These transfer as **specification**. Exact values are consolidated in
[05_DATA_MODEL.md](05_DATA_MODEL.md); the full table is [03_BEHAVIORAL_PORT_MATRIX.md](03_BEHAVIORAL_PORT_MATRIX.md).

### 7.1 Tick model
`STRATEGIC_TICK_SECONDS = 1.0` · `RIVAL_TICK_INTERVAL = 10` · speeds `PAUSED 0.0 / NORMAL 1.0 /
FAST 2.0 / FASTER 4.0`. TimeService accumulates `delta × scale` and **drains in a while-loop**, so
several ticks may fire in one frame after a hitch. Rival tick fires on the same tick when
`tick_index % 10 == 0`.

### 7.2 Economy (brief §7.2, verified in code)
```
DirtyIncome  = BaseYield × DistrictDemand × OperationalStaff × ControlModifier × (1 − disruption)
CleanCapital = LaunderingCapacity × FrontEfficiency × (1 − OperatingCost)
ExposureGain = UnlaunderedOverflow × RacketRisk × DistrictVisibility × 0.0001
DistrictDemand = 0.5 + prosperity
ControlModifier: FORTIFIED 1.2 · CONTROLLED 1.0 · INFLUENCED 0.6 · COMPROMISED 0.4 · CONTESTED 0.3 · UNKNOWN 0.0
disruption_from_heat: 0 below heat 0.3; else (heat−0.3)/0.7 × 0.6
```
**Per-tick order (load-bearing):** clear exposure → settle every faction (array order) → update
district heat → update central pressure.

### 7.3 Heat / inspection hysteresis
`HEAT_RISE_SCALE 0.05` · `EXPOSURE_HEAT_FLOOR 0.008` · `HEAT_DECAY_PER_TICK 0.0006` ·
`HEAT_INSPECTION_THRESHOLD 0.45` · `WARN 0.38` · `REARM 0.30` · `INSPECTION_DURATION_TICKS 30` ·
`INSPECTION_DISRUPTION 0.8`. Fires once per excursion; re-arms only below 0.30.
`combined_pressure = local_heat + 0.5 × Σ case weights`.

`tasks/lessons.md` carries a critical instrumentation lesson: a probe policy that unpaused at 0.35
made inspection *recurrence physically unreachable* because re-arm needs < 0.30 — read as a mechanic
failure, was an instrument error. **Derive test thresholds from the constants, never from literals.**

### 7.4 Central pressure
`CENTRAL_RISE_FLOOR 0.35` · `RISE_SCALE 0.15` · `DECAY 0.01` · `ALERT_THRESHOLD 0.6` ·
`REARM 0.4` · `DURATION 20` · `INSPECTION_RELIEF 0.15`. City signal is the **mean** across districts.

### 7.5 Betrayal (brief §7.6)
```
BetrayalPressure = ambition + grievance + rival_leverage + survival_pressure
                 − public_trust − shared_success − fear        (clamped 0..4)
Gate 1: pressure ≥ betrayal_threshold × 2.0
Gate 2: opportunity ≥ 0.3   (inspection +0.35, sabotage +0.3, leverage × 0.5)
```
`TELEGRAPH_LEAD_RIVAL_TICKS 6` (≈60 strategic ticks of defusal window) ·
`MAX_NEW_INTENTS_PER_RIVAL_TICK 1` · reassure costs 200 clean, +0.15 trust, +0.15 shared_success.
No new telegraphs during COUNCIL; open intents still advance. Gates are re-checked every rival tick —
**that is what makes betrayal preventable**.

`[Verified]` A subtle ordering note worth preserving deliberately: existing intents advance *before*
new candidates are scored in the same rival tick, so a just-defused character can in principle be
re-scored as a fresh candidate within that same tick.

### 7.6 Rival utility AI
`COMMIT_THRESHOLD 0.3` · `TELEGRAPH_LEAD_RIVAL_TICKS 3` · `TIE_JITTER_EPSILON 0.01` ·
`SABOTAGE_DISRUPTION 0.35`/40 ticks · `PROBE_DISRUPTION 0.10`/20 ticks · `RECRUIT_LEVERAGE 0.15` ·
`FRAME_HEAT 0.25` · `GRUDGE_SCORE_BONUS 0.35` · `GRUDGE_SABOTAGE_LEAN 0.15` · `GRUDGE_DECAY 0.05`.
Candidates generated in authored district→venue order; argmax with strict `>` so the **first**
candidate wins exact ties; jitter is a hash nudge in `[0, 0.01)` salted by `intents_committed`.

### 7.7 Jobs
Stages `INTAKE → PREPARATION → INTERVENTION → COVER_UP → RESOLVED`; `COVER_UP` is transient and
resolves inside the same call (a save can never observe it split). Max **3** prep actions
(`JOB_MAX_PREP_ACTIONS`), exactly one approach, one cover-up. `MAX_CONCURRENT_JOBS = 3`.
Nine outcome dimensions, three of them signed:
```
objective_achieved, evidence_generated*, collateral_damage, operative_injury*,
rival_suspicion, public_fear, relationship_change*, new_leverage, delayed_consequence
                                                            (* signed −1..1, others 0..1)
```
Resolution = sum of chosen prep + approach + cover-up effect dicts, clamped once at the end.
Expiry = fixed `{evidence 0.3, public_fear 0.1, delayed_consequence 0.5}`.
Follow-up scheduled when `delayed_consequence ≥ 0.25`, lead 20 ticks.

### 7.8 Generated job ids — the rebuild contract
```
gen@retaliation@<venue>@<rival>@<tick>          (5 parts)
gen@followup@<venue>@<tick>                     (4 parts)
gen@contested@<venue>@<rival>@<tick>            (5 parts)
gen@burycase@<district>@case@<d>@<kind>@<t>@<tick>  (8 parts — case id is itself 4 segments)
```
Content is a pure function of (template, targeting ids, tick, variant index), and the variant index is
`avalanche(id.hash()) mod count`. So **only runtime state is saved**; the whole authored payload is
rebuilt from the id. `burycase` returns null if the case is gone — "the job can't be rebuilt honestly."

### 7.9 Narrative spine
Chain: `job_intercepted_shipment` → *(+30 ticks)* → `beat_ledger` → `job_inspectors_ledger` →
`beat_debt` → `job_lieutenants_debt` → `beat_accord` → `job_meridian_accord` → *(+120 ticks)* → ending.
Strictly sequential. Flags live in `GameState.narrative_flags`: `fired@<beat>`, `resolved@<job_id>`,
`ledger_secured`, `accord_stance`, `ending`. Endings: `truce → ending_accord`,
`leverage → ending_armed_peace`, `war → ending_war` (default).

**Critical cadence rule:** if the job cap is full, the beat retries every tick *without* marking itself
fired — "never let an authored beat die to the cadence cap."

### 7.10 Save contract
`SAVE_VERSION = 1` · `user://saves/<slot>.bmsave` · `var_to_str` (chosen over JSON **specifically**
because JSON truncates floats and breaks replay determinism). Top level:
`{version, meta, factions, districts (venues + evidence embedded), characters, jobs}`.
Jobs persist **runtime state only**. Version mismatch = **hard refusal**, no migration, no partial apply.
Additive fields tolerated within a version via `.get(key, default)`.
Cinematic entry writes `checkpoint` slot **before** any mutation.

### 7.11 The authority invariant — verified, zero violations
Every presentation/UI script either renders state or calls an existing service verb
(`EconomyService.set_racket_paused` / `assign_operatives` / `pressure_front`,
`RelationshipService.reassure`, `EvidenceMath.remove_case`). **No UI or scene script writes a
`DistrictData`/`VenueData`/`CharacterData`/`FactionData` field directly.** The cinematic scenes
declare themselves "PRESENTATION ONLY — this scene owns no simulation state" and funnel their single
decision through thin delegates.

One nuance `[Verified]`: `ending_panel.gd` writes `GameState.narrative_flags["ending_seen"] = true`.
That is UI-presentation bookkeeping living in the narrative flag bag, not simulation state — but in
the Unreal port it belongs in a **separate UI-state struct**, not in campaign state.

---

## 8. Godot-specific code that must NOT shape the Unreal architecture

| Pattern | Why it doesn't transfer | Unreal approach |
|---|---|---|
| **Autoload singletons** | Godot-specific lifetime | `UGameInstanceSubsystem` — but keep the autoload/scene-wired split |
| **`var_to_str` serialization** | Godot type printer | `FArchive` binary — preserves float precision natively |
| **`extends SceneTree` test harness** | Godot-only entry | Automation Test framework |
| **`preload()` / `class_name`** | GDScript resolution | `UCLASS`/`USTRUCT` + Asset Manager soft refs |
| **Signals + `call_deferred` wiring** | Works around autoload ordering | Explicit subsystem init order + typed delegates |
| **`hash()` (DJB2) + splitmix64 wraparound** | GDScript ints wrap mod 2⁶⁴ | **Must be re-specified exactly** — see [08_TEST_STRATEGY.md](08_TEST_STRATEGY.md) §4. Highest-risk detail in the port |
| **Code-built scenes** (`mesh_world_provider`, all UI) | Pragmatic Godot shortcut | Authored Levels + UMG assets |
| **GDGS + 4.7 push-constant patch** | Godot renderer internals | CUT |
| **`user://` paths** | Godot VFS | `FPaths::ProjectSavedDir()/SaveGames/` |
| **`.tres` Resources** | Godot format | `UPrimaryDataAsset` / DataTable |
| **Linear-scan lookups** (`get_faction` etc.) | Fine at slice scale | `TMap` — *but preserve authored array order where it is a tie-break* |

### 8.1 The one that will bite — read it twice

`[Verified from repository]` Determinism depends on `_avalanche()`, a splitmix64 finalizer over
Godot's string `hash()`:

```gdscript
x = (x ^ (x >> 30)) * -49064778989728563
x = (x ^ (x >> 27)) * -4265267296055464877
return x ^ (x >> 31)
```

It relies on **signed 64-bit wraparound** and **Godot's specific `String.hash()`**. It drives rival
tie-breaking *and* job-variant selection — i.e. which job text the player sees and which venue the
rival hits. Naïvely re-implemented in C++ (different hash, different shift semantics on signed ints,
UB on signed overflow) it will silently produce a *different but still deterministic* game.

**Mandated approach:** re-specify as explicit `uint64` arithmetic with a documented, ported string
hash, and validate against extracted golden vectors. Detail: [08_TEST_STRATEGY.md](08_TEST_STRATEGY.md) §4.

---

## 9. Asset + licensing state

`[Verified from repository]` `assets/ATTRIBUTIONS.md` is a genuine, maintained license ledger:
8 Sketchfab models under **CC BY 4.0** (with required credit lines written out verbatim), 1 PolyHaven
HDRI under **CC0**. The policy is stated correctly: commercial Steam release ⇒ **CC0 and CC-BY only**;
CC-BY-NC and CC-BY-SA forbidden.

4 character portraits exist (`assets/characters/portraits/`) — explicitly **swappable placeholders
pending the world-bible identity lock** (brief §20 #5).

`assets/audio/` (5 WAVs) is **untracked**.

**Port note:** every reused CC-BY asset carries its attribution obligation into the Unreal build. The
ledger must be migrated, not restarted — [09_ASSET_AND_CHARACTER_PIPELINE.md](09_ASSET_AND_CHARACTER_PIPELINE.md) §10.

---

## 10. Working-tree state at audit time

`[Verified from repository]` `git status --short` at audit start — **left untouched by this task**:

```
 M project.godot
 M scenes/bootstrap/bootstrap.gd
 M scenes/city/city_view.gd
 M scenes/ui/hud.gd
 M scenes/ui/roster_panel.gd
?? assets/audio/
?? docs/astra-recovery/
?? scenes/ui/audio_cues.gd(+.uid)
?? scenes/ui/onboarding_nudges.gd(+.uid)
?? scenes/ui/settings_panel.gd(+.uid)
?? src/presentation/settings_service.gd(+.uid)
```

This is the **P20 slice** (settings / onboarding / audio / rebinding), functionally complete on
reading but uncommitted. It is *not* reflected in `docs/NOW.md`, which still shows "Cem gate #1".
Its disposition is **D-08**.

---

**Next:** [02_PRODUCT_CONTRACT.md](02_PRODUCT_CONTRACT.md) · **Matrix:** [03_BEHAVIORAL_PORT_MATRIX.md](03_BEHAVIORAL_PORT_MATRIX.md)
