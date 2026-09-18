# S3 — Job System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the Godot job system — four-stage lifecycle, nine-dimension resolution, id-encoded generation, cadence cap — into Unreal `BMCore`/`BMSim`, with every behavior measured against golden vectors extracted from this repo's oracle.

**Architecture:** All job logic lives in `BMCore` as plain structs with static methods, exactly like S2's `FBMEconomyMath`/`FBMSimulation`. `FBMJobDirector` holds the per-campaign job state (active jobs, pending follow-ups, cadence cap) as a **plain struct**, *not* a subsystem — this is the decision that keeps every S3 test runnable without a live `GameInstance`. `UBMJobSubsystem` in `BMSim` is a scheduling/signal facade whose every method is a one-line forward, matching the S2 precedent. A single `FBMJobIdParser` is the only code in the port that splits a job id; all four call sites go through it.

**Tech Stack:** Unreal Engine 5.8.2 C++ (`BMCore` depends on `Core` alone — the determinism wall), Unreal Automation tests, Godot 4.7 headless (`-s` SceneTree script) for oracle extraction, JSON golden-vector fixtures.

**Oracle repo:** `D:\black-meridian` (this repo, read-only for S3) · **Port repo:** `D:\black-meridian-ue`

---

## Two traps recorded in `Docs/gates/S2.md`, both binding here

**Trap 1 — `UGameInstanceSubsystem` cannot be `NewObject`'d in a test.** It carries
`ClassWithin = UGameInstance`, so constructing one into the transient package trips a CoreUObject
ensure that the automation framework promotes to a **failure while every assertion in the test
passes** — it reads as a mystery. S2 dodged this by making its two verbs `static`. S3 cannot: it has
real per-campaign state. **Resolution (decided 2026-09-18): the state and all cap/trigger logic go
into `FBMJobDirector` in `BMCore`.** `UBMJobSubsystem` holds a single `FBMJobDirector` member and
forwards. No S3 test ever constructs a subsystem.

**Trap 2 — the job/case id parse contract.** Ids are positional `@`-splits with hardcoded segment
counts, and a `burycase` id **embeds a case id that itself contains three `@`**:

```
gen@retaliation@<venue>@<rival>@<tick>          -> 5 parts
gen@contested@<venue>@<rival>@<tick>            -> 5 parts
gen@followup@<venue>@<tick>                     -> 4 parts
gen@burycase@<district>@case@<district>@<kind>@<tick>@<tick>   -> 8 parts
                        └────── case id, parts[3..6] ──────┘
```

The case id is reassembled as `"@".join(parts.slice(3, 7))`. Consequences a careless port misses:

1. **The split is positional, not delimiter-safe.** An `@` inside any district/venue/rival/case id
   shifts every index. The Godot code does not defend against this; the port must reproduce the
   same behavior, not "fix" it.
2. **A wrong segment count returns null, it does not throw.** `parts.size() != N` → `return null` in
   every branch. `rebuild()` returning null is a legitimate, tested outcome.
3. **Four call sites parse the same string** — `JobGenerator.rebuild`, `JobDirector._district_of`,
   `_burn_target_of`, `_provocateur_of` — each with its own hardcoded count. In the port they all
   route through `FBMJobIdParser`. ⛔ Prohibited by `07` §S3: changing the id format at all.
4. **`int(parts[N])` on a non-numeric string yields 0 silently** in Godot. Reproduce that, do not
   substitute an error.

### A third constraint the enums carry

`BM.JobOrigin`'s two newest members are **appended, not sorted**, and `enums.gd` says why in a
comment: *"appended, so saved int values stay stable."*

```gdscript
enum JobStage  { INTAKE, PREPARATION, INTERVENTION, COVER_UP, RESOLVED }        # 0..4
enum JobOrigin { FAILED_RACKET, WITNESS, RIVAL_PROVOCATION, INTERNAL_DISPUTE,
                 INSTITUTIONAL_PRESSURE, EVIDENCE_CHAIN, TERRITORY_LOSS }        # 0..6
const JOB_MAX_PREP_ACTIONS := 3
```

`EVIDENCE_CHAIN = 5` and `TERRITORY_LOSS = 6` are the two origins S3's post-outcome branches key
off. **Do not reorder `EBMJobOrigin` into a "tidier" grouping in the port** — these integers are a
save-format contract that S4 consumes one slice later, and a reorder silently rewrites the meaning
of every saved job.

---

## File structure

### `D:\black-meridian` (oracle — read-only except the new extractor)

| File | Responsibility |
|---|---|
| `tools/export_job_vectors.gd` | **CREATE.** Read-only `-s` SceneTree extractor. Drives `JobResolution`, `JobLifecycle`, `JobGenerator`, `JobTemplates` and writes `job_vectors.json`. |

Every class it drives is `class_name … extends RefCounted` with static methods and **zero autoload
references** (verified by grep, 2026-09-18). That is why this is a `-s` script like
`export_sim_vectors.gd`, and not a `.tscn` like `export_trajectory.gd`. `JobDirector` is the only
autoload in the job layer, and its state is precisely what moves to `FBMJobDirector`.

### `D:\black-meridian-ue` (port)

| File | Responsibility |
|---|---|
| `Tests/Golden/job_vectors.json` | The fixture the extractor writes. |
| `Source/BMCore/Public/BMJobTypes.h` | `EBMJobStage`, `EBMJobOrigin`, `FBMJobChoice`, `FBMJob`, `FBMJobOutcome`, `FBMPendingFollowup`. |
| `Source/BMCore/Public/BMJobIdParser.h` + `.cpp` | **The single id parser.** Build + parse, positional semantics preserved. |
| `Source/BMCore/Public/BMJobResolution.h` + `.cpp` | Nine dimensions, accumulate, clamp **once at the end**. |
| `Source/BMCore/Public/BMJobLifecycle.h` + `.cpp` | Stage machine + `ApplyOutcome`. |
| `Source/BMCore/Public/BMJobTemplates.h` + `.cpp` | Authored content as C++ tables (moves to Data Assets in S14). |
| `Source/BMCore/Public/BMJobGenerator.h` + `.cpp` | Four builders + `Rebuild` + `VariantIndex`. |
| `Source/BMCore/Public/BMJobDirector.h` + `.cpp` | **State:** active jobs, pending follow-ups, cadence cap, triggers, origin branches. |
| `Source/BMSim/Public/BMJobSubsystem.h` + `.cpp` | Facade. One-line forwards. No logic, no state of its own. |
| `Source/BMCore/Private/BMJobTest.cpp` | Golden-vector tests `GV-JOB-01..04`. |
| `Source/BMCore/Private/BMJobBehaviorTest.cpp` | The seven named behavior tests from `07` §S3. |

Two test files, split by what fails: a fixture mismatch and a behavior regression are different
investigations. Same reason S1 and S2 kept `hash_vectors.json` and `sim_vectors.json` apart.

### Where the job pass slots into the tick

S2 left the seam marked and unambiguous in `Source/BMCore/Private/BMSimulation.cpp`:

```cpp
void FBMSimulation::AdvanceTick(FBMCampaignState& State)
{
	++State.TickIndex;

	// ORDER IS CONTRACT. See the header and 04 §5.
	Settle(State);                 // 1. clear exposure -> settle each faction (array order)
	UpdateDistrictHeat(State);     // 2. consumes THIS tick's exposure
	UpdateCentralPressure(State);  // 3. consumes THIS tick's district heat

	// 4-6 (jobs, night cycle, narrative) and the rival tick arrive in later slices.
}
```

**An open design question Task 11 must answer explicitly, not silently:** `AdvanceTick` takes only
`FBMCampaignState&`, but the job pass needs the director's state (active jobs, pending follow-ups)
as well. Two honest options:

| Option | Trade-off |
|---|---|
| Put `FBMJobDirector` **inside** `FBMCampaignState` as a member | `AdvanceTick`'s signature is unchanged, and jobs automatically participate in the interleaved-campaign determinism test S2 already ships (`TickIsReproducible` advances two campaigns and requires byte-identical state). Jobs become part of "what a campaign is" — which matches S4, where the save contract must serialize them anyway. |
| Add a second parameter, `AdvanceTick(State, JobDirector)` | Keeps the structs independent, but changes a signature the golden vectors and the probe are both defined against, and risks a second definition of what a tick is — the exact hazard S2's Correction 6 recorded. |

**Recommendation: the first.** S4 has to serialize job state with the campaign regardless, and the
interleaved-determinism test is free coverage. Whichever is chosen, record it in `Docs/gates/S3.md`
as a decision with its reason — do not let it be settled by whichever compiles first.

> ✅ **DECIDED — see C-6 below.** `FBMJobDirector` becomes a member of `FBMCampaignState`. This
> question is closed; the section is kept because the rejected option and its reason are worth
> having on the record.

---

## Task 1: Oracle extractor — `job_vectors.json`

Nothing in the port can be verified until the fixture exists. This task runs entirely in
`D:\black-meridian` and writes into the port repo's `Tests/Golden/`.

**Files:**
- Create: `D:\black-meridian\tools\export_job_vectors.gd`
- Writes: `D:\black-meridian-ue\Tests\Golden\job_vectors.json`

- [ ] **Step 1: Create the extractor skeleton**

Create `D:\black-meridian\tools\export_job_vectors.gd`:

```gdscript
extends SceneTree
## Job golden-vector extractor — the Unreal port's behavioral oracle (reboot S3).
##
## READ-ONLY. It drives the four autoload-free job classes (JobResolution, JobLifecycle,
## JobGenerator, JobTemplates) over hand-built data and writes one JSON document. It
## mutates no shipped resource and touches no autoload.
##
## Run:
##   D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . \
##       -s tools/export_job_vectors.gd -- --out=<abs path>.json
##
## Like S1/S2's extractors it writes the file itself rather than printing to stdout: the
## godot_ai game_helper autoload emits a banner AFTER the script finishes and that trailing
## text corrupts a redirected document.
##
## Autoloads do not exist in a `-s` SceneTree script. Verified 2026-09-18: JobResolution,
## JobLifecycle, JobGenerator, JobTemplates, NarrativeJobs and EvidenceMath contain ZERO
## autoload references (the only grep hits are comments), which is exactly why the job
## layer is extractable this way. JobDirector IS an autoload — it is deliberately not
## driven here; its state moves to FBMJobDirector in BMCore and is tested there.
##
## `[V]` Covers GV-JOB-01..04 (07_IMPLEMENTATION_ROADMAP.md -> S3).

const SCHEMA := 1
const DEFAULT_OUT := "D:/black-meridian-ue/Tests/Golden/job_vectors.json"

func _init() -> void:
	var out := {
		"schema": SCHEMA,
		"source": "godot-final",
		"godot_version": Engine.get_version_info().string,
		"note": "Job vectors for reboot S3. Floats are JSON numbers (state values compared at 1e-5 per 08 5.1). Discrete fields — stage, origin, variant index, id strings, parse results, booleans — are compared EXACTLY. The variant layer's hash and avalanche fields are DECIMAL STRINGS, not numbers: they are 64-bit and would round silently through a double (the S1 lesson).",
		"resolution": _resolution_vectors(),
		"lifecycle": _lifecycle_vectors(),
		"ids": _id_vectors(),
		"variant": _variant_vectors(),
	}

	var path := _out_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		quit(1)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()

	print("wrote %s — %d resolution, %d lifecycle, %d ids, %d variant rows" % [
		path,
		out["resolution"]["rows"].size(), out["lifecycle"]["rows"].size(),
		out["ids"]["rows"].size(), out["variant"]["rows"].size()])
	quit(0)

func _out_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			return arg.substr(6)
	return DEFAULT_OUT
```

Add four stub functions so the script parses while you build it up task by task. Each returns an
empty layer; the next steps replace them one at a time.

```gdscript
func _resolution_vectors() -> Dictionary:
	return {"rows": []}

func _lifecycle_vectors() -> Dictionary:
	return {"rows": []}

func _id_vectors() -> Dictionary:
	return {"rows": []}

func _variant_vectors() -> Dictionary:
	return {"rows": []}
```

- [ ] **Step 2: Run the skeleton to prove the harness works before adding data**

Run:
```sh
cd /d/black-meridian && D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . \
    -s tools/export_job_vectors.gd -- --out=D:/black-meridian-ue/Tests/Golden/job_vectors.json
```
Expected: exit 0, and the line `wrote D:/black-meridian-ue/Tests/Golden/job_vectors.json — 0 resolution, 0 lifecycle, 0 ids, 0 variant rows`.

If instead you see a parse error naming `GameState` or `TimeService`, a class you referenced drags
an autoload into compilation — remove that reference. This is the S1 failure, and catching it now
with an empty document is far cheaper than catching it with 2000 rows of data half-written.

- [ ] **Step 3: Replace `_resolution_vectors` (GV-JOB-01, GV-JOB-02)**

This pins the nine dimensions, the signed/unsigned split, and the clamp-once-at-the-end rule. The
`over_clamp` rows exist specifically to catch a port that clamps per-term: three prep actions each
contributing `+0.5` to `objective_achieved` must yield `1.0`, and `-0.6` followed by `+0.4` on a
signed axis must yield `-0.2` — not `-0.6`, clamped, then `+0.4`.

```gdscript
func _resolution_vectors() -> Dictionary:
	var rows: Array = []

	for case in _resolution_cases():
		var job := JobData.new()
		job.prep_actions = case["prep_pool"]
		job.approaches = case["approach_pool"]
		job.coverups = case["coverup_pool"]
		job.chosen_prep = case["chosen_prep"]
		job.chosen_approach = case["chosen_approach"]
		job.chosen_coverup = case["chosen_coverup"]
		rows.append({
			"kind": case["kind"],
			"chosen_prep": case["chosen_prep"].map(func(s): return String(s)),
			"chosen_approach": String(case["chosen_approach"]),
			"chosen_coverup": String(case["chosen_coverup"]),
			"outcome": _outcome_row(JobResolution.resolve(job)),
		})

	rows.append({
		"kind": "expired",
		"chosen_prep": [],
		"chosen_approach": "",
		"chosen_coverup": "",
		"outcome": _outcome_row(JobResolution.expired()),
	})
	rows.append({
		"kind": "blank",
		"chosen_prep": [],
		"chosen_approach": "",
		"chosen_coverup": "",
		"outcome": _outcome_row(JobResolution.blank()),
	})

	return {
		"dimensions": JobResolution.DIMENSIONS.map(func(d): return String(d)),
		"signed_dimensions": JobResolution.SIGNED_DIMENSIONS.map(func(d): return String(d)),
		"rows": rows,
	}

func _outcome_row(outcome: Dictionary) -> Dictionary:
	var row: Dictionary = {}
	for d in JobResolution.DIMENSIONS:
		row[String(d)] = outcome[d]
	return row

## Hand-built choice pools. Deliberately includes contributions that overshoot both ends of
## both clamp ranges, so a per-term clamp and an end clamp produce DIFFERENT vectors.
func _resolution_cases() -> Array:
	var prep := [
		JobChoiceData.make(&"p_big", "big", "", {&"objective_achieved": 0.5}),
		JobChoiceData.make(&"p_big2", "big2", "", {&"objective_achieved": 0.5}),
		JobChoiceData.make(&"p_big3", "big3", "", {&"objective_achieved": 0.5}),
		JobChoiceData.make(&"p_neg", "neg", "", {&"evidence_generated": -0.6}),
		JobChoiceData.make(&"p_mixed", "mixed", "",
			{&"evidence_generated": 0.4, &"operative_injury": -0.3, &"new_leverage": 0.2}),
	] as Array[JobChoiceData]
	var approaches := [
		JobChoiceData.make(&"a_loud", "loud", "",
			{&"objective_achieved": 0.7, &"evidence_generated": 0.35, &"public_fear": 0.2,
				&"rival_suspicion": 0.2}),
		JobChoiceData.make(&"a_over", "over", "",
			{&"evidence_generated": 0.9, &"collateral_damage": 1.2}),
	] as Array[JobChoiceData]
	var coverups := [
		JobChoiceData.make(&"c_deny", "deny", "", {&"evidence_generated": -0.3}),
		JobChoiceData.make(&"c_under", "under", "",
			{&"evidence_generated": -1.5, &"relationship_change": -1.4}),
		JobChoiceData.make(&"c_heavy", "heavy", "", {&"delayed_consequence": 0.5}),
	] as Array[JobChoiceData]

	return [
		{"kind": "single_approach_only", "prep_pool": prep, "approach_pool": approaches,
			"coverup_pool": coverups, "chosen_prep": [] as Array[StringName],
			"chosen_approach": &"a_loud", "chosen_coverup": &""},
		{"kind": "full_three_prep", "prep_pool": prep, "approach_pool": approaches,
			"coverup_pool": coverups,
			"chosen_prep": [&"p_big", &"p_big2", &"p_big3"] as Array[StringName],
			"chosen_approach": &"a_loud", "chosen_coverup": &"c_deny"},
		{"kind": "over_clamp_unsigned", "prep_pool": prep, "approach_pool": approaches,
			"coverup_pool": coverups,
			"chosen_prep": [&"p_big", &"p_big2", &"p_big3"] as Array[StringName],
			"chosen_approach": &"a_over", "chosen_coverup": &"c_heavy"},
		{"kind": "signed_negative_then_positive", "prep_pool": prep,
			"approach_pool": approaches, "coverup_pool": coverups,
			"chosen_prep": [&"p_neg"] as Array[StringName],
			"chosen_approach": &"a_loud", "chosen_coverup": &""},
		{"kind": "under_clamp_signed", "prep_pool": prep, "approach_pool": approaches,
			"coverup_pool": coverups, "chosen_prep": [&"p_neg"] as Array[StringName],
			"chosen_approach": &"a_loud", "chosen_coverup": &"c_under"},
		{"kind": "mixed_axes", "prep_pool": prep, "approach_pool": approaches,
			"coverup_pool": coverups,
			"chosen_prep": [&"p_mixed", &"p_neg"] as Array[StringName],
			"chosen_approach": &"a_loud", "chosen_coverup": &"c_deny"},
		{"kind": "unknown_choice_ids_ignored", "prep_pool": prep,
			"approach_pool": approaches, "coverup_pool": coverups,
			"chosen_prep": [&"p_big"] as Array[StringName],
			"chosen_approach": &"a_missing", "chosen_coverup": &"c_missing"},
	]
```

- [ ] **Step 4: Run and sanity-check the resolution layer**

Run the same command as Step 2.
Expected: `— 9 resolution, 0 lifecycle, 0 ids, 0 variant rows`.

Then verify two rows by hand, because a fixture nobody checked is not evidence:

```sh
cd /d/black-meridian-ue && python -c "import json;d=json.load(open('Tests/Golden/job_vectors.json'));r={x['kind']:x['outcome'] for x in d['resolution']['rows']};print('over_clamp obj =',r['over_clamp_unsigned']['objective_achieved']);print('over_clamp coll =',r['over_clamp_unsigned']['collateral_damage']);print('signed ev =',r['signed_negative_then_positive']['evidence_generated']);print('unknown obj =',r['unknown_choice_ids_ignored']['objective_achieved'])"
```

Expected exactly:
```
over_clamp obj = 1.0
over_clamp coll = 1.0
signed ev = -0.25
unknown obj = 0.5
```

`signed ev = -0.25` is the one that matters: `-0.6` (prep) `+0.35` (approach) `= -0.25`, inside the
range, never clamped. A per-term clamping port returns `-0.25` here too — but returns `0.6` instead
of `1.0` for `over_clamp obj` only if it clamps the *sum*; the three `+0.5` terms are what separate
the implementations. If `unknown obj` is anything but `0.5`, `_accumulate`'s null guard is not
being reproduced.

- [ ] **Step 5: Commit**

```bash
cd /d/black-meridian
git add tools/export_job_vectors.gd
git commit -m "feat(s3): job vector extractor — resolution layer

Covers GV-JOB-01 (nine dimensions, clamped once at the end) and GV-JOB-02
(the fixed expiry outcome). Read-only -s script: the whole job layer except
JobDirector is autoload-free, verified by grep.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Extractor — lifecycle layer

The stage machine's value is in what it **refuses**. Every transition guard returns `false` and
leaves state untouched; a port that lets a caller skip Preparation still passes a happy-path test.
So this layer records the illegal transitions as first-class rows.

**Files:**
- Modify: `D:\black-meridian\tools\export_job_vectors.gd` (replace the `_lifecycle_vectors` stub)

- [ ] **Step 1: Replace `_lifecycle_vectors`**

```gdscript
## Stage machine vectors. Each row drives one call against a job in a known stage and
## records the returned bool AND the resulting state — the guard's whole job is to return
## false WITHOUT mutating, and only recording the bool would miss a port that returns
## false after already having written the stage.
func _lifecycle_vectors() -> Dictionary:
	var rows: Array = []

	for case in _lifecycle_cases():
		var job := _lifecycle_job()
		job.stage = case["stage"]
		job.chosen_prep = case["chosen_prep"].duplicate()
		job.ticks_remaining = case["ticks_remaining"]
		var accepted: bool = case["call"].call(job)
		rows.append({
			"kind": case["kind"],
			"stage_before": case["stage"],
			"accepted": accepted,
			"stage_after": job.stage,
			"chosen_prep_after": job.chosen_prep.map(func(s): return String(s)),
			"chosen_approach_after": String(job.chosen_approach),
			"chosen_coverup_after": String(job.chosen_coverup),
			"ticks_remaining_after": job.ticks_remaining,
			"outcome_after": _outcome_row(job.outcome) if not job.outcome.is_empty() else {},
		})

	return {
		"max_prep_actions": BM.JOB_MAX_PREP_ACTIONS,
		"stage_intake": BM.JobStage.INTAKE,
		"stage_preparation": BM.JobStage.PREPARATION,
		"stage_intervention": BM.JobStage.INTERVENTION,
		"stage_coverup": BM.JobStage.COVER_UP,
		"stage_resolved": BM.JobStage.RESOLVED,
		"rows": rows,
	}

## A job with a known three-option pool in each stage, so prep-cap and toggle rows have
## something real to select from.
func _lifecycle_job() -> JobData:
	var job := JobData.new()
	job.id = &"lc_probe"
	job.deadline_ticks = 60
	job.prep_actions = [
		JobChoiceData.make(&"p1", "p1", "", {&"objective_achieved": 0.1}),
		JobChoiceData.make(&"p2", "p2", "", {&"objective_achieved": 0.1}),
		JobChoiceData.make(&"p3", "p3", "", {&"objective_achieved": 0.1}),
		JobChoiceData.make(&"p4", "p4", "", {&"objective_achieved": 0.1}),
	] as Array[JobChoiceData]
	job.approaches = [
		JobChoiceData.make(&"a1", "a1", "", {&"objective_achieved": 0.6}),
	] as Array[JobChoiceData]
	job.coverups = [
		JobChoiceData.make(&"c1", "c1", "", {&"evidence_generated": -0.3}),
	] as Array[JobChoiceData]
	return job

func _lifecycle_cases() -> Array:
	var none: Array[StringName] = []
	var three: Array[StringName] = [&"p1", &"p2", &"p3"]
	var one: Array[StringName] = [&"p1"]

	return [
		# --- begin: INTAKE -> PREPARATION, and refused from anywhere else ---
		{"kind": "begin_from_intake", "stage": BM.JobStage.INTAKE, "chosen_prep": none,
			"ticks_remaining": 60, "call": func(j): return JobLifecycle.begin(j)},
		{"kind": "begin_from_preparation_refused", "stage": BM.JobStage.PREPARATION,
			"chosen_prep": none, "ticks_remaining": 60,
			"call": func(j): return JobLifecycle.begin(j)},
		{"kind": "begin_from_resolved_refused", "stage": BM.JobStage.RESOLVED,
			"chosen_prep": none, "ticks_remaining": 60,
			"call": func(j): return JobLifecycle.begin(j)},

		# --- choose_prep: select, toggle off, cap, unknown id, wrong stage ---
		{"kind": "prep_select_first", "stage": BM.JobStage.PREPARATION, "chosen_prep": none,
			"ticks_remaining": 60, "call": func(j): return JobLifecycle.choose_prep(j, &"p1")},
		{"kind": "prep_toggle_off", "stage": BM.JobStage.PREPARATION, "chosen_prep": one,
			"ticks_remaining": 60, "call": func(j): return JobLifecycle.choose_prep(j, &"p1")},
		{"kind": "prep_at_cap_refused", "stage": BM.JobStage.PREPARATION, "chosen_prep": three,
			"ticks_remaining": 60, "call": func(j): return JobLifecycle.choose_prep(j, &"p4")},
		{"kind": "prep_at_cap_toggle_off_allowed", "stage": BM.JobStage.PREPARATION,
			"chosen_prep": three, "ticks_remaining": 60,
			"call": func(j): return JobLifecycle.choose_prep(j, &"p2")},
		{"kind": "prep_unknown_id_refused", "stage": BM.JobStage.PREPARATION, "chosen_prep": none,
			"ticks_remaining": 60, "call": func(j): return JobLifecycle.choose_prep(j, &"nope")},
		{"kind": "prep_wrong_stage_refused", "stage": BM.JobStage.INTERVENTION,
			"chosen_prep": none, "ticks_remaining": 60,
			"call": func(j): return JobLifecycle.choose_prep(j, &"p1")},

		# --- choose_approach: PREPARATION -> INTERVENTION only ---
		{"kind": "approach_from_preparation", "stage": BM.JobStage.PREPARATION,
			"chosen_prep": one, "ticks_remaining": 60,
			"call": func(j): return JobLifecycle.choose_approach(j, &"a1")},
		{"kind": "approach_from_intake_refused", "stage": BM.JobStage.INTAKE,
			"chosen_prep": none, "ticks_remaining": 60,
			"call": func(j): return JobLifecycle.choose_approach(j, &"a1")},
		{"kind": "approach_unknown_id_refused", "stage": BM.JobStage.PREPARATION,
			"chosen_prep": none, "ticks_remaining": 60,
			"call": func(j): return JobLifecycle.choose_approach(j, &"nope")},

		# --- choose_coverup: the ATOMIC one. INTERVENTION -> COVER_UP -> RESOLVED in a
		# single call, with the outcome resolved on the way through. A port that stops at
		# COVER_UP and waits for another call is a different game.
		{"kind": "coverup_atomic_to_resolved", "stage": BM.JobStage.INTERVENTION,
			"chosen_prep": one, "ticks_remaining": 60,
			"call": func(j):
				j.chosen_approach = &"a1"
				return JobLifecycle.choose_coverup(j, &"c1")},
		{"kind": "coverup_from_preparation_refused", "stage": BM.JobStage.PREPARATION,
			"chosen_prep": none, "ticks_remaining": 60,
			"call": func(j): return JobLifecycle.choose_coverup(j, &"c1")},
		{"kind": "coverup_unknown_id_refused", "stage": BM.JobStage.INTERVENTION,
			"chosen_prep": none, "ticks_remaining": 60,
			"call": func(j): return JobLifecycle.choose_coverup(j, &"nope")},

		# --- tick: the deadline. Fires exactly once, at the transition to <= 0. ---
		{"kind": "tick_above_deadline", "stage": BM.JobStage.PREPARATION, "chosen_prep": none,
			"ticks_remaining": 5, "call": func(j): return JobLifecycle.tick(j)},
		{"kind": "tick_expires_at_one", "stage": BM.JobStage.PREPARATION, "chosen_prep": none,
			"ticks_remaining": 1, "call": func(j): return JobLifecycle.tick(j)},
		{"kind": "tick_already_resolved_noop", "stage": BM.JobStage.RESOLVED,
			"chosen_prep": none, "ticks_remaining": 1,
			"call": func(j): return JobLifecycle.tick(j)},
		{"kind": "tick_from_intake_expires", "stage": BM.JobStage.INTAKE, "chosen_prep": none,
			"ticks_remaining": 1, "call": func(j): return JobLifecycle.tick(j)},
	]
```

- [ ] **Step 2: Run and check the three rows that carry the contract**

Run:
```sh
cd /d/black-meridian && D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . \
    -s tools/export_job_vectors.gd -- --out=D:/black-meridian-ue/Tests/Golden/job_vectors.json
```
Expected: `— 9 resolution, 19 lifecycle, 0 ids, 0 variant rows`.

```sh
cd /d/black-meridian-ue && python -c "import json;d=json.load(open('Tests/Golden/job_vectors.json'));r={x['kind']:x for x in d['lifecycle']['rows']};a=r['coverup_atomic_to_resolved'];print('atomic accepted/stage =',a['accepted'],a['stage_after'],'resolved_const =',d['lifecycle']['stage_resolved']);c=r['prep_at_cap_refused'];print('cap refused =',c['accepted'],'prep_after =',c['chosen_prep_after']);t=r['tick_already_resolved_noop'];print('resolved tick =',t['accepted'],'ticks_after =',t['ticks_remaining_after'])"
```

Expected exactly:
```
atomic accepted/stage = True 4 resolved_const = 4
cap refused = False ['p1', 'p2', 'p3']
resolved tick = False ticks_after = 1
```

Read those three: the cover-up lands on **RESOLVED**, not COVER_UP — one call, three states. The
cap refusal left `chosen_prep` **exactly as it was**, proving the guard ran before any mutation. And
a tick on a resolved job did **not** decrement `ticks_remaining` — that early return is why a
resolved job's counter stops moving, and a port that decrements first and checks after drifts.

- [ ] **Step 3: Commit**

```bash
cd /d/black-meridian
git add tools/export_job_vectors.gd
git commit -m "feat(s3): job vector extractor — lifecycle layer

19 rows covering every stage guard, the prep cap and its toggle-off
exemption, the atomic INTERVENTION -> COVER_UP -> RESOLVED cover-up call,
and the deadline tick. Refusal rows record post-state, not just the bool:
a guard that returns false after mutating would otherwise pass.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Extractor — id layer (Trap 2)

This is the layer the gate turns on: *"a generated job's id round-trips byte-identically through
rebuild."* It is also where the positional-parse contract lives.

**Files:**
- Modify: `D:\black-meridian\tools\export_job_vectors.gd` (replace the `_id_vectors` stub)

- [ ] **Step 1: Replace `_id_vectors`**

```gdscript
## Id build + rebuild vectors. Every row records the built id string, and — where the id is
## fed back through rebuild() — whether the rebuild succeeded and whether the rebuilt job's
## id matches the original BYTE FOR BYTE. That equality is the S3 gate condition.
##
## The malformed rows are the point of this layer. Godot's parser is POSITIONAL: it splits
## on "@" and indexes fixed slots, guarded only by parts.size(). An id with an extra or
## missing segment returns null; an id with an "@" INSIDE a district/venue/rival id shifts
## every slot and silently rebuilds something else or returns null. The port must reproduce
## that exactly — 07 S3 prohibits changing the id format, and "hardening" the parser IS
## changing it.
func _id_vectors() -> Dictionary:
	var districts := _id_world()
	var factions := _id_factions()
	var rows: Array = []

	var venue := _find_venue_in(districts, &"gw_contraband")
	var rival := factions[0]
	var district := districts[0]
	var evidence_case := district.evidence_cases[0]

	# --- Built ids, each round-tripped through rebuild ---
	for built in [
		{"kind": "retaliation", "job": JobGenerator.retaliation_job(venue, rival, 240)},
		{"kind": "retaliation_tick_zero", "job": JobGenerator.retaliation_job(venue, rival, 0)},
		{"kind": "contested", "job": JobGenerator.contested_ground_job(venue, rival, 240)},
		{"kind": "followup", "job": JobGenerator.followup_job(venue, 301)},
		{"kind": "burycase",
			"job": JobGenerator.bury_case_job(evidence_case, district, 240)},
	]:
		var job: JobData = built["job"]
		var rebuilt := JobGenerator.rebuild(job.id, districts, factions)
		rows.append({
			"kind": built["kind"],
			"id": String(job.id),
			"origin": job.origin,
			"title": job.title,
			"venue_id": String(job.venue_id),
			"deadline_ticks": job.deadline_ticks,
			"rebuilt": rebuilt != null,
			"rebuilt_id": String(rebuilt.id) if rebuilt != null else "",
			"id_round_trips": rebuilt != null and rebuilt.id == job.id,
			"rebuilt_title": rebuilt.title if rebuilt != null else "",
			"rebuilt_origin": rebuilt.origin if rebuilt != null else -1,
		})

	# --- Parse-contract rows: ids fed straight to rebuild, never built ---
	for probe in _id_probes(String(evidence_case.id)):
		var rebuilt := JobGenerator.rebuild(StringName(probe["id"]), districts, factions)
		rows.append({
			"kind": probe["kind"],
			"id": probe["id"],
			"segments": probe["id"].split("@").size(),
			"rebuilt": rebuilt != null,
			"rebuilt_id": String(rebuilt.id) if rebuilt != null else "",
			"id_round_trips": rebuilt != null and String(rebuilt.id) == probe["id"],
			"rebuilt_title": rebuilt.title if rebuilt != null else "",
		})

	return {
		"generated_prefix": JobGenerator.GENERATED_PREFIX,
		"followup_threshold": JobGenerator.FOLLOWUP_THRESHOLD,
		"followup_lead_ticks": JobGenerator.FOLLOWUP_LEAD_TICKS,
		"case_id_example": String(evidence_case.id),
		"rows": rows,
	}

## Ids handed directly to rebuild(). `case_id` is a real 4-segment case id from the world
## below, so the burycase rows exercise the nested-id reassembly.
func _id_probes(case_id: String) -> Array:
	return [
		{"kind": "not_generated_prefix", "id": "job_intercepted_shipment"},
		{"kind": "prefix_only", "id": "gen@"},
		{"kind": "unknown_template", "id": "gen@nosuchtemplate@gw_contraband@corvine@240"},
		{"kind": "retaliation_too_few_segments", "id": "gen@retaliation@gw_contraband@240"},
		{"kind": "retaliation_too_many_segments",
			"id": "gen@retaliation@gw_contraband@corvine@240@extra"},
		{"kind": "retaliation_unknown_venue", "id": "gen@retaliation@no_such_venue@corvine@240"},
		{"kind": "retaliation_unknown_rival",
			"id": "gen@retaliation@gw_contraband@no_such_rival@240"},
		{"kind": "retaliation_nonnumeric_tick",
			"id": "gen@retaliation@gw_contraband@corvine@notanumber"},
		{"kind": "retaliation_negative_tick", "id": "gen@retaliation@gw_contraband@corvine@-5"},
		{"kind": "followup_too_many_segments", "id": "gen@followup@gw_contraband@240@extra"},
		{"kind": "burycase_correct", "id": "gen@burycase@glasswharf@%s@240" % case_id},
		{"kind": "burycase_missing_case_segment",
			"id": "gen@burycase@glasswharf@case@glasswharf@0@240"},
		# A well-formed 8-segment id whose nested case id names a case that does not exist
		# (kind 3, tick 999 — the seeded case is kind 0, tick 120). EvidenceMath.find_case
		# returns null and rebuild refuses rather than inventing content. This is the
		# "honest null" 03 calls out for the save/load path.
		{"kind": "burycase_unknown_case",
			"id": "gen@burycase@glasswharf@case@glasswharf@3@999@240"},
		{"kind": "burycase_unknown_district",
			"id": "gen@burycase@no_such_district@%s@240" % case_id},
	]

## A minimal world: one district with one venue and one real evidence case, plus a rival.
## EvidenceMath.deposit builds the case so its id uses the SHIPPED format rather than a
## transcribed one — the S1/S2 discipline (never hand-write a value the source can produce).
func _id_world() -> Array[DistrictData]:
	var district := DistrictData.new()
	district.id = &"glasswharf"
	district.display_name = "Glass Wharf"

	var venue := VenueData.new()
	venue.id = &"gw_contraband"
	venue.display_name = "Cargo Terminal"
	venue.owner_faction = &"compact"
	district.venues = [venue] as Array[VenueData]

	EvidenceMath.deposit(district, 0.4, &"seed_job", 120)

	return [district] as Array[DistrictData]

func _id_factions() -> Array[FactionData]:
	var rival := FactionData.new()
	rival.id = &"corvine"
	rival.display_name = "Corvine Syndicate"
	return [rival] as Array[FactionData]

func _find_venue_in(districts: Array[DistrictData], venue_id: StringName) -> VenueData:
	for d in districts:
		for v in d.venues:
			if v.id == venue_id:
				return v
	return null
```

- [ ] **Step 2: Run and check the round-trip plus the parse contract**

Run:
```sh
cd /d/black-meridian && D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . \
    -s tools/export_job_vectors.gd -- --out=D:/black-meridian-ue/Tests/Golden/job_vectors.json
```
Expected: `— 9 resolution, 19 lifecycle, 19 ids, 0 variant rows`.

```sh
cd /d/black-meridian-ue && python -c "import json;d=json.load(open('Tests/Golden/job_vectors.json'));i=d['ids'];r={x['kind']:x for x in i['rows']};print('case id  =',i['case_id_example']);print('burycase =',r['burycase']['id']);print('segments =',r['burycase']['id'].count('@')+1);print('round trip all builts =',all(r[k]['id_round_trips'] for k in ('retaliation','retaliation_tick_zero','contested','followup','burycase')));print('nulls =',[k for k,v in r.items() if not v['rebuilt']])"
```

Expected exactly:
```
case id  = case@glasswharf@0@120
burycase = gen@burycase@glasswharf@case@glasswharf@0@120@240
segments = 8
round trip all builts = True
nulls = ['not_generated_prefix', 'prefix_only', 'unknown_template', 'retaliation_too_few_segments', 'retaliation_too_many_segments', 'retaliation_unknown_venue', 'retaliation_unknown_rival', 'followup_too_many_segments', 'burycase_missing_case_segment', 'burycase_unknown_case', 'burycase_unknown_district']
```

> **These values were measured, not predicted.** They were produced on 2026-09-18 by driving the
> real `JobGenerator` against this exact world in a throwaway `-s` script (since deleted). If your
> run disagrees, the oracle changed — investigate before adjusting the numbers.

Two readings that decide the port:

- **`segments = 8`** with the case id visibly nested inside. This is Trap 2 made concrete — the
  `burycase` id contains a `@`-delimited id, and `parts.slice(3, 7)` is what puts it back together.
- **`retaliation_nonnumeric_tick` and `retaliation_negative_tick` are NOT in the null list.** They
  rebuild successfully. The non-numeric tick becomes `0` (Godot's silent `int()` conversion) and the
  negative tick round-trips as `-5`. Both produce a job whose id **differs from the input string** —
  check `id_round_trips` is `False` for the non-numeric one. A port that rejects these has changed
  the contract; a port that throws on them has changed it more.

- [ ] **Step 3: Commit**

```bash
cd /d/black-meridian
git add tools/export_job_vectors.gd
git commit -m "feat(s3): job vector extractor — id layer, the parse contract

19 rows: five built ids round-tripped through rebuild, plus fourteen probes
that pin the POSITIONAL parse — wrong segment counts, unknown targets, a
nested 4-segment case id inside an 8-segment burycase id, and Godot's silent
int() coercion on a non-numeric tick.

07 S3 prohibits changing the id format. These rows are what makes that
prohibition testable rather than aspirational.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Extractor — variant layer (GV-JOB-04)

Variant selection is `avalanche(String.hash(id)) mod count`, non-negative. It reuses the hash S1
already ported, so this layer is small — but it is where S1's three lessons land again, and getting
it wrong produces text variety that is deterministic and **wrong**, with no crash and no symptom.

**Files:**
- Modify: `D:\black-meridian\tools\export_job_vectors.gd` (replace the `_variant_vectors` stub)

- [ ] **Step 1: Replace `_variant_vectors`**

```gdscript
## Variant-pick vectors. `hash` and `avalanche` are emitted as DECIMAL STRINGS because they
## are 64-bit: 1713 of S1's 1719 avalanche values exceeded the 53-bit double mantissa and
## silently rounded when written as JSON numbers, failing a CORRECT implementation. Same
## trap, same fix. The port's test must reject a numeric field here.
##
## NOTE the two different non-negative-modulo idioms in the shipped source, which are NOT
## interchangeable and must not be unified in the port:
##   JobGenerator._variant_index : ((m % count) + count) % count   over avalanche(String.hash())
##   EvidenceMath.kind_for       : posmod(hash(...), size)         over the GLOBAL hash(), no avalanche
## The second is already covered by S2's GV-EVID. Only the first is GV-JOB-04.
func _variant_vectors() -> Dictionary:
	var rows: Array = []

	for seed_str in _variant_seeds():
		var h := seed_str.hash()
		var av := _avalanche_ref(h)
		for count in [2, 3]:
			rows.append({
				"seed": seed_str,
				"hash": str(h),
				"avalanche": str(av),
				"count": count,
				"index": ((av % count) + count) % count,
			})

	return {
		"retaliation_variants": JobTemplates.RETALIATION_VARIANTS,
		"bury_case_variants": JobTemplates.BURY_CASE_VARIANTS,
		"contested_variants": JobTemplates.CONTESTED_VARIANTS,
		"rows": rows,
	}

## Byte-identical copy of JobGenerator._avalanche. Copied rather than called because that
## method is private; if the two ever disagree the extractor is lying, so keep them
## identical. The constants are MurmurHash3 fmix64 (0xFF51AFD7ED558CCD /
## 0xC4CEB9FE1A85EC53) despite the shipped comment naming splitmix64 — S1 lost a gate to
## that comment. The decimal literals below are authoritative; the name is not.
func _avalanche_ref(x: int) -> int:
	x = (x ^ (x >> 30)) * -49064778989728563
	x = (x ^ (x >> 27)) * -4265267296055464877
	return x ^ (x >> 31)

## Seeds that matter: real generated ids at consecutive ticks (the +1-tick sensitivity the
## avalanche exists for), plus edge shapes. A port with a broken avalanche typically
## freezes consecutive ticks to the same index — these rows catch exactly that.
func _variant_seeds() -> Array:
	return [
		"gen@retaliation@gw_contraband@corvine@240",
		"gen@retaliation@gw_contraband@corvine@241",
		"gen@retaliation@gw_contraband@corvine@242",
		"gen@retaliation@gw_contraband@corvine@243",
		"gen@retaliation@gw_contraband@corvine@0",
		"gen@contested@gw_contraband@corvine@240",
		"gen@contested@gw_contraband@corvine@241",
		"gen@burycase@glasswharf@case@glasswharf@0@120@240",
		"gen@burycase@glasswharf@case@glasswharf@0@120@241",
		"gen@followup@gw_contraband@301",
		"",
		"a",
	]
```

- [ ] **Step 2: Run and confirm the avalanche actually moves the bucket**

Run:
```sh
cd /d/black-meridian && D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . \
    -s tools/export_job_vectors.gd -- --out=D:/black-meridian-ue/Tests/Golden/job_vectors.json
```
Expected: `— 9 resolution, 19 lifecycle, 19 ids, 24 variant rows`.

```sh
cd /d/black-meridian-ue && python -c "
import json;d=json.load(open('Tests/Golden/job_vectors.json'))
rows=[r for r in d['variant']['rows'] if r['count']==2]
for r in rows[:5]: print(r['seed'][-4:], 'hash',r['hash'], 'idx',r['index'])
print('all strings =', all(isinstance(r['hash'],str) and isinstance(r['avalanche'],str) for r in d['variant']['rows']))
big=[r for r in d['variant']['rows'] if abs(int(r['avalanche']))>2**53]
print('values past 2^53 =', len(big), 'of', len(d['variant']['rows']))
"
```

The measured values (2026-09-18, driven against the real oracle):

```
240 hash 712505440 av 1734293227203430138 idx 0
241 hash 712505441 av 4559747155846262078 idx 0
242 hash 712505442 av 5857529748973741130 idx 0
243 hash 712505443 av 4066539097871136215 idx 1
all strings = True
values past 2^53 = 24 of 24
```

Confirm three things:

1. **`all strings = True`.** If the extractor ever emits these as numbers, a correct C++ port fails
   the gate. This is the single highest-cost trap S1 recorded.
2. **`values past 2^53` is 24 of 24 — every row.** That is *why* they are strings, and it is
   measured, not theoretical.
3. **The `hash` column moves by exactly 1 per tick while `av` jumps by ~10^18.** That contrast is
   the whole point of the avalanche: `String.hash()` is DJB2 (the empty string hashes to its seed,
   `5381`), so consecutive ticks land in adjacent buckets and, mod 2, would just alternate with the
   tick's parity. Note that `mod 2` the avalanche still yields `0,0,0,1` here — **do not assert an
   alternating pattern**; assert these exact indices. A port whose `idx` column reads `0,1,0,1` is
   applying DJB2 without the avalanche and has silently shipped different text variety.

- [ ] **Step 3: Run twice and require byte-identical output**

Every extractor in S1 and S2 had to be byte-identical across runs; this one is no different.

```sh
cd /d/black-meridian
D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . \
    -s tools/export_job_vectors.gd -- --out=/tmp/jv_a.json
D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . \
    -s tools/export_job_vectors.gd -- --out=/tmp/jv_b.json
cmp /tmp/jv_a.json /tmp/jv_b.json && echo "BYTE-IDENTICAL"
```
Expected: `BYTE-IDENTICAL`, no output from `cmp`.

If the files differ, something in the job layer is order-dependent or reads a clock. Stop — that is
a determinism bug in the *oracle*, and it invalidates the fixture rather than the port.

- [ ] **Step 4: Commit the extractor and the fixture**

```bash
cd /d/black-meridian
git add tools/export_job_vectors.gd
git commit -m "feat(s3): job vector extractor — variant layer, complete

24 rows over avalanche(String.hash(id)) mod count. 64-bit fields emitted as
decimal STRINGS: S1 proved that 1713/1719 such values round through a JSON
double and fail a correct port. Consecutive-tick seeds prove the avalanche
is applied — DJB2 alone would freeze them to one bucket.

Fixture: 9 resolution + 19 lifecycle + 19 ids + 24 variant rows,
byte-identical across two runs.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

```bash
cd /d/black-meridian-ue
git add Tests/Golden/job_vectors.json
git commit -m "feat(s3): job golden vectors from the Godot oracle

Extracted by black-meridian/tools/export_job_vectors.gd, byte-identical
across two runs. Covers GV-JOB-01..04.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

---

## Corrections to this plan, made before Tasks 5–12 were integrated

Drafting the port half surfaced six things the earlier sections got wrong or left open. All six were
checked against the source rather than reasoned about; each is fixed in place below and in the tasks
that follow.

### C-1 — Test files live in `Private/`, not `Tests/`

The File-structure table above said `Source/BMCore/Tests/`. **That directory does not exist.** Every
shipped BMCore test is in `Private/` (`BMHashTest.cpp`, `BMSimVectorTest.cpp`, `BMSimulationTest.cpp`,
`BMProbeTest.cpp`, `BMSmokeTest.cpp`) and `BMCore.Build.cs` registers no additional source directory.

**Corrected paths:** `Source/BMCore/Private/BMJobTest.cpp` and
`Source/BMCore/Private/BMJobBehaviorTest.cpp`. Follow the repo, not the table.

### C-2 — `FBMEvidence::Deposit` DOES populate `Label`

Checked at `Source/BMCore/Private/BMEvidence.cpp:98`:

```cpp
NewCase.Label = KindLabel(Kind);
```

`KindLabel` returns the same four strings as Godot's `EvidenceMath.KIND_LABELS`. So `bury_case_job`'s
`evidence_case.label` argument maps to **`Case.Label`** directly — do not re-derive it by calling
`KindLabel` at the job-generation site, which would create a second path to the same string.

### C-3 — Generated job TEXT is out of scope for S3. Do not build a name table.

Godot's builders interpolate `venue.display_name`, `rival.display_name` and `district.display_name`
into `title` / `apparent_problem`. **BMCore has none of these**, and that is deliberate —
`BMTypes.h:138` states presentation data is absent from BMCore by design. It is the same determinism
wall that keeps `Engine` out of `BMCore.Build.cs`.

A tempting fix is a presentation-side name table in BMSim that the generator consults. **Reject it.**
Two reasons:

1. **The S3 gate does not measure text.** `07` §S3 reads: *"A generated job's id round-trips
   byte-identically through rebuild. All four origins fire."* Ids, origins, variant indices, choice
   ids and effect values — all of which BMCore has — are what the gate turns on.
2. **S14 moves job content to Data Assets.** A name table built in S3 is machinery S14 deletes, and
   until then it is a second source of truth for names sitting next to the one the Data Assets will
   own. `07` §S3 already says content is in C++ tables *temporarily*.

**The resolution:** `FBMJobGenerator`'s builders take display names as **parameters**. `Rebuild`
passes the parsed **ids** through in their place, because ids are all it can recover from an id
string. A rebuilt job therefore has identical id / origin / variant / deadline / choice ids / effect
values, and *different interpolated prose*, until S14 gives it a real content source.

This is safe precisely because **the variant pick keys on the id string, not the text** — so text
divergence cannot move the variant index and cannot desync the gate.

⚠️ **Record this in `Docs/gates/S3.md` as a known, bounded divergence with its closure date (S14).**
It is the kind of thing that reads as a bug to the next porter unless it is written down. The test
compares `rebuilt_title` against the fixture only for **authored** templates (which have no
interpolation); for generated jobs it compares id, origin and variant index.

### C-4 — Character effects are deferred, and the fixture does not cover them

`job_lifecycle.gd::apply_outcome` writes `public_trust` and `grievance` onto an
`Array[CharacterData]`. **`BMTypes.h` has no `FBMCharacterState` and `FBMCampaignState` has no
character array** — loyalty/relationships are S6 work per `03` §6.

`FBMJobLifecycle::ApplyOutcome` therefore ports the faction, district, evidence and heat/fear arms
and **omits the character arm**. Do not invent `FBMCharacterState` to fill the hole; S6 defines it.

The extractor's `lifecycle` layer does not emit character fields either, so **nothing goes vacuous** —
there is no assertion silently passing over missing data. Record the omission in `Docs/gates/S3.md`.

### C-5 — `NarrativeJobs.by_id` is out of scope

`JobTemplates.by_id` falls through to `NarrativeJobs.by_id` (the P16 authored chain, 192 lines of
narrative content). S3 ports the **registry contract**, not the P16 roster: `FBMJobTemplates::ById`
returns `false` for an unknown authored id. That is the honest answer for the slice, and it is what
`Test_Save_JobRebuildByteIdentical` in S4 will exercise.

### C-6 — The `AdvanceTick` question is now decided

The File-structure section above posed it as open. **Decided: `FBMJobDirector` becomes a member of
`FBMCampaignState`**, and the job pass slots in as step 4 of `FBMSimulation::AdvanceTick`.

Reasons, in the order they matter:
1. One save snapshot. S4 must serialize job state with the campaign anyway.
2. One definition of what a tick is — S2's Correction 6 recorded that splitting the passes at the
   coordinator would create a second one.
3. Free coverage: `BM.Determinism.TickIsReproducible` already advances **two interleaved campaigns**
   for 400 ticks and requires byte-identical state. Putting jobs inside campaign state means any
   accidental global or shared static in the job layer fails that existing test immediately.

⚠️ **Before and after wiring the job pass into `AdvanceTick`, run
`BM.Equivalence.TrajectoryMatchesOracle` and confirm ticks 0–240 are still bit-identical.** S2's
trajectory comparison passes over exactly that window; a job pass that perturbs the economy would
show up there and nowhere else.

---
## Task 5: `BMJobTypes.h` — the job structs and enums

Nothing in the port compiles until the shapes exist. This task adds **no behavior at all** — it is
declarations plus one test that pins the enumerator integers, because those integers are a
save-format contract (`enums.gd`: *"appended, so saved int values stay stable"*) and S4 consumes
them one slice later.

`FBMJobOutcome` is a **fixed nine-field struct**, not a `TMap<FString, float>`. The Godot original
is a `Dictionary` because GDScript has nothing better; the dimension set is closed (`DIMENSIONS` is
a `const` array) and `_accumulate` asserts on an unknown key. A struct reproduces that assert at
compile time and makes the clamp pass an explicit nine-line list instead of an iteration whose order
could drift.

**Files:**
- Create: `D:\black-meridian-ue\Source\BMCore\Public\BMJobTypes.h`
- Test: `D:\black-meridian-ue\Source\BMCore\Private\BMJobTest.cpp`

> **Note on test file location.** The plan's file table says `Source/BMCore/Tests/BMJobTest.cpp`.
> Every existing BMCore test actually lives in `Source/BMCore/Private/` (`BMHashTest.cpp`,
> `BMSimVectorTest.cpp`, `BMSimulationTest.cpp`, `BMProbeTest.cpp`, `BMSmokeTest.cpp`) and
> `BMCore.Build.cs` has no extra source directory registered. **Follow the repo, not the table:**
> put both test files in `Private/`. Changing the module's source layout is not S3 work.

- [ ] **Step 1: Write the failing test**

Create `D:\black-meridian-ue\Source\BMCore\Private\BMJobTest.cpp`:

```cpp
#include "BMJobTypes.h"

#include "CoreMinimal.h"
#include "Dom/JsonObject.h"
#include "Misc/AutomationTest.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"

/**
 * S3 gate. Measures the ported job system against the vectors extracted from the Godot
 * oracle (Tests/Golden/job_vectors.json, produced by
 * D:\black-meridian\tools\export_job_vectors.gd).
 *
 * Tolerances follow plan 08 §5.1: floats at 1e-5, DISCRETE outcomes exactly. Stage, origin,
 * variant index, id strings, parse success and booleans are compared with ==; only the nine
 * resolution dimensions get an epsilon.
 *
 * Every constant used below is read from the FIXTURE's own header fields or from BMConst,
 * never re-typed as a literal (`[V]` the P06d instrument-error lesson, carried from S2).
 */

namespace
{
	/** 08 §5.1 — float tolerance for state values. */
	constexpr float JobTolerance = 1e-5f;

	/** A systematic break should emit a handful of lines, not hundreds. */
	constexpr int32 MaxReportedMismatches = 5;

	FString JobVectorPath()
	{
		return FPaths::Combine(FPaths::ProjectDir(), TEXT("Tests"), TEXT("Golden"),
			TEXT("job_vectors.json"));
	}

	bool LoadJobVectors(TSharedPtr<FJsonObject>& OutRoot, FString& OutError)
	{
		const FString Path = JobVectorPath();

		FString Raw;
		if (!FFileHelper::LoadFileToString(Raw, *Path))
		{
			OutError = FString::Printf(TEXT("cannot read job vectors at %s"), *Path);
			return false;
		}

		const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(Raw);
		if (!FJsonSerializer::Deserialize(Reader, OutRoot) || !OutRoot.IsValid())
		{
			OutError = FString::Printf(TEXT("malformed JSON in %s"), *Path);
			return false;
		}

		return true;
	}

	/** One layer object, e.g. "resolution". */
	const TSharedPtr<FJsonObject>* LayerObject(const TSharedPtr<FJsonObject>& Root,
		const TCHAR* Layer)
	{
		const TSharedPtr<FJsonObject>* Out = nullptr;
		Root->TryGetObjectField(Layer, Out);
		return Out;
	}

	/** Rows of one layer. */
	const TArray<TSharedPtr<FJsonValue>>* LayerRows(const TSharedPtr<FJsonObject>& Root,
		const TCHAR* Layer)
	{
		const TSharedPtr<FJsonObject>* Layer_ = LayerObject(Root, Layer);
		if (!Layer_)
		{
			return nullptr;
		}

		const TArray<TSharedPtr<FJsonValue>>* Rows = nullptr;
		if (!(*Layer_)->TryGetArrayField(TEXT("rows"), Rows))
		{
			return nullptr;
		}

		return Rows;
	}

	float RowFloat(const TSharedPtr<FJsonObject>& Row, const TCHAR* Field)
	{
		return static_cast<float>(Row->GetNumberField(Field));
	}

	TArray<FString> StringArray(const TSharedPtr<FJsonObject>& Row, const TCHAR* Field)
	{
		TArray<FString> Out;
		const TArray<TSharedPtr<FJsonValue>>* Values = nullptr;
		if (Row->TryGetArrayField(Field, Values) && Values)
		{
			for (const TSharedPtr<FJsonValue>& Value : *Values)
			{
				Out.Add(Value->AsString());
			}
		}
		return Out;
	}
}

// ---------------------------------------------------------------------------
// BM.Jobs.EnumValuesAreSaveContract
// ---------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FBMJobEnumValuesTest,
	"BM.Jobs.EnumValuesAreSaveContract",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FBMJobEnumValuesTest::RunTest(const FString&)
{
	// `[V]` These integers are written to saves. enums.gd says so in a comment on JobOrigin:
	// "appended, so saved int values stay stable." A reorder into a tidier grouping silently
	// rewrites the meaning of every saved job — and EVIDENCE_CHAIN (5) / TERRITORY_LOSS (6)
	// are exactly the two the director's post-outcome branches key off.
	TestEqual(TEXT("JobStage::Intake"),       static_cast<int32>(EBMJobStage::Intake), 0);
	TestEqual(TEXT("JobStage::Preparation"),  static_cast<int32>(EBMJobStage::Preparation), 1);
	TestEqual(TEXT("JobStage::Intervention"), static_cast<int32>(EBMJobStage::Intervention), 2);
	TestEqual(TEXT("JobStage::CoverUp"),      static_cast<int32>(EBMJobStage::CoverUp), 3);
	TestEqual(TEXT("JobStage::Resolved"),     static_cast<int32>(EBMJobStage::Resolved), 4);

	TestEqual(TEXT("JobOrigin::FailedRacket"),          static_cast<int32>(EBMJobOrigin::FailedRacket), 0);
	TestEqual(TEXT("JobOrigin::Witness"),               static_cast<int32>(EBMJobOrigin::Witness), 1);
	TestEqual(TEXT("JobOrigin::RivalProvocation"),      static_cast<int32>(EBMJobOrigin::RivalProvocation), 2);
	TestEqual(TEXT("JobOrigin::InternalDispute"),       static_cast<int32>(EBMJobOrigin::InternalDispute), 3);
	TestEqual(TEXT("JobOrigin::InstitutionalPressure"), static_cast<int32>(EBMJobOrigin::InstitutionalPressure), 4);
	TestEqual(TEXT("JobOrigin::EvidenceChain"),         static_cast<int32>(EBMJobOrigin::EvidenceChain), 5);
	TestEqual(TEXT("JobOrigin::TerritoryLoss"),         static_cast<int32>(EBMJobOrigin::TerritoryLoss), 6);

	// And the fixture's own stage constants must agree with the port's, or every lifecycle
	// row below compares against a different machine.
	TSharedPtr<FJsonObject> Root;
	FString Error;
	if (!LoadJobVectors(Root, Error))
	{
		AddError(Error);
		return false;
	}

	const TSharedPtr<FJsonObject>* Lifecycle = LayerObject(Root, TEXT("lifecycle"));
	if (!Lifecycle)
	{
		AddError(TEXT("fixture has no 'lifecycle' layer"));
		return false;
	}

	struct FStageCheck { const TCHAR* Field; EBMJobStage Expected; };
	const FStageCheck Checks[] = {
		{ TEXT("stage_intake"),       EBMJobStage::Intake },
		{ TEXT("stage_preparation"),  EBMJobStage::Preparation },
		{ TEXT("stage_intervention"), EBMJobStage::Intervention },
		{ TEXT("stage_coverup"),      EBMJobStage::CoverUp },
		{ TEXT("stage_resolved"),     EBMJobStage::Resolved },
	};
	for (const FStageCheck& Check : Checks)
	{
		const int32 FixtureValue = (*Lifecycle)->GetIntegerField(Check.Field);
		if (FixtureValue != static_cast<int32>(Check.Expected))
		{
			AddError(FString::Printf(
				TEXT("enum drift: fixture %s = %d, port = %d — the oracle and the port disagree on the stage machine's integers"),
				Check.Field, FixtureValue, static_cast<int32>(Check.Expected)));
		}
	}

	if ((*Lifecycle)->GetIntegerField(TEXT("max_prep_actions")) != BMConst::JobMaxPrepActions)
	{
		AddError(TEXT("balance drift: fixture max_prep_actions != BMConst::JobMaxPrepActions"));
	}

	// The outcome struct carries exactly the oracle's nine dimensions, in its order.
	const TSharedPtr<FJsonObject>* Resolution = LayerObject(Root, TEXT("resolution"));
	if (!Resolution)
	{
		AddError(TEXT("fixture has no 'resolution' layer"));
		return false;
	}

	TArray<FString> Dimensions;
	{
		const TArray<TSharedPtr<FJsonValue>>* Values = nullptr;
		if ((*Resolution)->TryGetArrayField(TEXT("dimensions"), Values) && Values)
		{
			for (const TSharedPtr<FJsonValue>& Value : *Values)
			{
				Dimensions.Add(Value->AsString());
			}
		}
	}

	const TArray<FString> PortDimensions = FBMJobOutcome::DimensionNames();
	if (Dimensions != PortDimensions)
	{
		AddError(FString::Printf(
			TEXT("dimension set drift: fixture has %d names, port has %d, and they must match IN ORDER"),
			Dimensions.Num(), PortDimensions.Num()));
	}

	TArray<FString> SignedDimensions;
	{
		const TArray<TSharedPtr<FJsonValue>>* Values = nullptr;
		if ((*Resolution)->TryGetArrayField(TEXT("signed_dimensions"), Values) && Values)
		{
			for (const TSharedPtr<FJsonValue>& Value : *Values)
			{
				SignedDimensions.Add(Value->AsString());
			}
		}
	}

	for (const FString& Name : SignedDimensions)
	{
		if (!FBMJobOutcome::IsSignedDimension(Name))
		{
			AddError(FString::Printf(
				TEXT("'%s' is signed (-1..1) in the oracle but unsigned in the port — a negative contribution would be clamped away"),
				*Name));
		}
	}
	if (SignedDimensions.Num() != 3)
	{
		AddError(FString::Printf(
			TEXT("the oracle has 3 signed dimensions, the fixture reports %d"),
			SignedDimensions.Num()));
	}

	return true;
}
```

- [ ] **Step 2: Run it to verify it fails**

Run:
```sh
"C:/Program Files/Epic Games/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" \
    D:/black-meridian-ue/BlackMeridian.uproject \
    -ExecCmds="Automation RunTests BM.Jobs; Quit" -unattended -nopause -nullrhi -nosplash -NoLiveCoding \
    -testexit="Automation Test Queue Empty"
```
Expected: the **build fails before any test runs**, with
`fatal error C1083: Cannot open include file: 'BMJobTypes.h': No such file or directory`.
That is the intended red: there is no header yet.

- [ ] **Step 3: Implement**

Create `D:\black-meridian-ue\Source\BMCore\Public\BMJobTypes.h`:

```cpp
#pragma once

#include "CoreMinimal.h"

/**
 * The job system's shapes (brief §7.5), ported from src/core/job_data.gd,
 * src/core/job_choice_data.gd and the JobStage/JobOrigin enums in src/core/enums.gd.
 *
 * `[V]` Both enumerator ORDERS below are transcribed from enums.gd and are load-bearing:
 * the values are written to saves as ints, and enums.gd's own comment on JobOrigin says
 * why the two newest members are APPENDED rather than sorted — "so saved int values stay
 * stable." EvidenceChain (5) and TerritoryLoss (6) are the two the director's post-outcome
 * branches key off. Appending is safe; reordering is a save-format break.
 *
 * Plain C++ enums, not UENUM: BMCore has no CoreUObject dependency, and the absence of that
 * dependency is the determinism wall (04_UNREAL_ARCHITECTURE.md §2). Same rule as BMTypes.h.
 */

/** `[V]` The core verb's four stages plus a terminal. Resolution is multi-dimensional,
 *  never binary. COVER_UP is a real stage the machine passes THROUGH, not one it rests in —
 *  see FBMJobLifecycle::ChooseCoverup, which is atomic. */
enum class EBMJobStage : uint8
{
	Intake = 0,
	Preparation = 1,
	Intervention = 2,
	CoverUp = 3,
	Resolved = 4,
	Count
};

/** `[V]` Where a job came from. The last two were appended, not sorted — see the file note. */
enum class EBMJobOrigin : uint8
{
	FailedRacket = 0,
	Witness = 1,
	RivalProvocation = 2,
	InternalDispute = 3,
	InstitutionalPressure = 4,
	EvidenceChain = 5,
	TerritoryLoss = 6,
	Count
};

/**
 * The nine resolution dimensions (brief §7.5), as a fixed struct rather than a map.
 *
 * `[V]` The Godot original is a Dictionary keyed by StringName only because GDScript has
 * nothing better; the dimension set is CLOSED (JobResolution.DIMENSIONS is a const array)
 * and `_accumulate` asserts on an unknown key. A struct reproduces that assert at compile
 * time and makes the clamp an explicit nine-line list whose order cannot drift.
 *
 * `[V]` Three axes are SIGNED (-1..1): authored data feeds them negative on purpose
 * ("I left no trace", "I protected my people"). The other six clamp 0..1. Getting the split
 * wrong silently erases every suppression the player bought.
 */
struct BMCORE_API FBMJobOutcome
{
	/** 0..1 — did the apparent problem get solved. */
	float ObjectiveAchieved = 0.0f;
	/** -1..1 — SIGNED net trace; negative = suppressed. The evidence pass consumes it. */
	float EvidenceGenerated = 0.0f;
	/** 0..1 — bystander/asset harm. */
	float CollateralDamage = 0.0f;
	/** -1..1 — SIGNED net harm to your people; negative = protected. */
	float OperativeInjury = 0.0f;
	/** 0..1 — rival attention drawn. The grudge branch consumes it. */
	float RivalSuspicion = 0.0f;
	/** 0..1 — district fear shift. */
	float PublicFear = 0.0f;
	/** -1..1 — SIGNED net shift on involved characters. */
	float RelationshipChange = 0.0f;
	/** 0..1 — leverage gained. */
	float NewLeverage = 0.0f;
	/** 0..1 — deferred fallout weight. The follow-up scheduler consumes it. */
	float DelayedConsequence = 0.0f;

	/**
	 * `[V]` Distinguishes "never resolved" from "resolved to all zeros". The Godot code
	 * tests `out.is_empty()` on the Dictionary, and apply_outcome returns early on an empty
	 * one — a job that legitimately resolved to zeros is NOT empty and DOES apply. A port
	 * that tested "all fields zero" instead would skip the reward gate on such a job.
	 */
	bool bResolved = false;

	/** The oracle's dimension names, IN ORDER. Used only by tests and the fixture reader. */
	static TArray<FString> DimensionNames()
	{
		return {
			TEXT("objective_achieved"),
			TEXT("evidence_generated"),
			TEXT("collateral_damage"),
			TEXT("operative_injury"),
			TEXT("rival_suspicion"),
			TEXT("public_fear"),
			TEXT("relationship_change"),
			TEXT("new_leverage"),
			TEXT("delayed_consequence"),
		};
	}

	/** `[V]` The three net axes. Everything else clamps 0..1. */
	static bool IsSignedDimension(const FString& Name)
	{
		return Name == TEXT("evidence_generated")
			|| Name == TEXT("operative_injury")
			|| Name == TEXT("relationship_change");
	}

	/** Field access by oracle dimension name — for the fixture comparison and for
	 *  FBMJobChoice's effect accumulation, which is authored by name. */
	float* FindByName(const FString& Name)
	{
		if (Name == TEXT("objective_achieved"))   { return &ObjectiveAchieved; }
		if (Name == TEXT("evidence_generated"))   { return &EvidenceGenerated; }
		if (Name == TEXT("collateral_damage"))    { return &CollateralDamage; }
		if (Name == TEXT("operative_injury"))     { return &OperativeInjury; }
		if (Name == TEXT("rival_suspicion"))      { return &RivalSuspicion; }
		if (Name == TEXT("public_fear"))          { return &PublicFear; }
		if (Name == TEXT("relationship_change"))  { return &RelationshipChange; }
		if (Name == TEXT("new_leverage"))         { return &NewLeverage; }
		if (Name == TEXT("delayed_consequence"))  { return &DelayedConsequence; }
		return nullptr;
	}

	const float* FindByName(const FString& Name) const
	{
		return const_cast<FBMJobOutcome*>(this)->FindByName(Name);
	}
};

/**
 * One contribution an authored choice makes to one dimension.
 *
 * `[V]` Authored as a name/value pair rather than a nine-field struct because the GDScript
 * `effects` dictionaries are SPARSE — a choice names only the axes it touches, and
 * `_accumulate` iterates exactly those keys. A dense struct would work numerically but
 * would lose the "unknown dimension asserts" behavior the oracle has.
 */
struct BMCORE_API FBMJobEffect
{
	FString Dimension;
	float Value = 0.0f;

	FBMJobEffect() = default;
	FBMJobEffect(const FString& InDimension, float InValue)
		: Dimension(InDimension), Value(InValue) {}
};

/** One selectable option inside a job — a prep action, an approach, or a cover-up story.
 *  Data-only; FBMJobResolution sums the effects of every chosen option. */
struct BMCORE_API FBMJobChoice
{
	FString Id;
	FString Label;
	FString Description;
	TArray<FBMJobEffect> Effects;

	FBMJobChoice() = default;
	FBMJobChoice(const FString& InId, const FString& InLabel, const FString& InDescription,
		TArray<FBMJobEffect> InEffects)
		: Id(InId), Label(InLabel), Description(InDescription), Effects(MoveTemp(InEffects)) {}
};

/**
 * A fixer job. Authored fields describe the *apparent* situation; HiddenStakes is
 * deliberately not shown at intake (brief §7.5: some information is missing on purpose).
 *
 * Lifecycle state lives here too, exactly as in job_data.gd, so a save can serialize an
 * in-flight job.
 */
struct BMCORE_API FBMJob
{
	// ---- Authored ----
	FString Id;
	FString Title;
	EBMJobOrigin Origin = EBMJobOrigin::FailedRacket;
	FString ApparentProblem;
	TArray<FString> InvolvedCharacterIds;
	FString VenueId;
	int32 DeadlineTicks = 120;
	TArray<FString> KnownEvidence;
	FString VisibleStakes;
	/** `[V]` Intentionally NOT shown to the player at intake. */
	FString HiddenStakes;
	/** Dirty-cash reward, granted when the resolved ObjectiveAchieved is >= 0.5. */
	int32 RewardDirty = 0;

	TArray<FBMJobChoice> PrepActions;
	TArray<FBMJobChoice> Approaches;
	TArray<FBMJobChoice> Coverups;

	// ---- Lifecycle state (mutated by FBMJobLifecycle) ----
	EBMJobStage Stage = EBMJobStage::Intake;
	TArray<FString> ChosenPrep;
	FString ChosenApproach;
	FString ChosenCoverup;
	int32 TicksRemaining = 0;
	FBMJobOutcome Outcome;

	/** Index of a choice by id within one pool, or INDEX_NONE. Mirrors JobData.find_choice. */
	static int32 FindChoice(const TArray<FBMJobChoice>& Pool, const FString& ChoiceId)
	{
		for (int32 i = 0; i < Pool.Num(); ++i)
		{
			if (Pool[i].Id == ChoiceId)
			{
				return i;
			}
		}
		return INDEX_NONE;
	}
};

/**
 * A scheduled delayed-consequence follow-up.
 *
 * `[V]` The Godot original is `{"ticks_left": int, "venue_id": StringName}` — a Dictionary
 * inside an Array, persisted through the save's meta so a quicksave inside the window does
 * not lose the problem. Note it stores the venue id ALONE: the follow-up job is rebuilt
 * from the venue at fire time, not carried as a job.
 */
struct BMCORE_API FBMPendingFollowup
{
	int32 TicksLeft = 0;
	FString VenueId;

	FBMPendingFollowup() = default;
	FBMPendingFollowup(int32 InTicksLeft, const FString& InVenueId)
		: TicksLeft(InTicksLeft), VenueId(InVenueId) {}
};
```

Then add the `BMConstants.h` include to the test's include block — `BMConst::JobMaxPrepActions`
already exists (`BMConstants.h` line 86) and the test reads it:

```cpp
#include "BMConstants.h"
#include "BMJobTypes.h"
```

- [ ] **Step 4: Run to verify it passes**

Run:
```sh
"C:/Program Files/Epic Games/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" \
    D:/black-meridian-ue/BlackMeridian.uproject \
    -ExecCmds="Automation RunTests BM.Jobs.EnumValuesAreSaveContract; Quit" \
    -unattended -nopause -nullrhi -nosplash -NoLiveCoding \
    -testexit="Automation Test Queue Empty"
```
Expected:
```
BM.Jobs.EnumValuesAreSaveContract                  Result={Success}
**** TEST COMPLETE. EXIT CODE: 0 ****              1/1 · 0 fail · 0 errors
```

- [ ] **Step 5: Commit**

```bash
cd /d/black-meridian-ue
git add Source/BMCore/Public/BMJobTypes.h Source/BMCore/Private/BMJobTest.cpp
git commit -m "feat(s3): BMJobTypes — job shapes, with the enum integers pinned

EBMJobStage and EBMJobOrigin transcribed from enums.gd in declaration order:
these are written to saves as ints and enums.gd says so. EvidenceChain=5 and
TerritoryLoss=6 are what the director's post-outcome branches key off; a
reorder rewrites the meaning of every saved job.

FBMJobOutcome is a fixed nine-field struct, not a map. The dimension set is
closed in the oracle and _accumulate asserts on an unknown key — a struct
moves that assert to compile time and fixes the clamp order.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: `BMJobIdParser` — the single parser

Four call sites in Godot split the same string with four hardcoded segment counts
(`JobGenerator.rebuild`, `JobDirector._district_of`, `_burn_target_of`, `_provocateur_of`).
**In the port they all route through one type.** Same reasoning as TD-05's single-avalanche rule:
a second parser that drifts produces a deterministic, wrong, symptomless game.

The hard part is that the parse must stay **faithfully fragile**. `07` §S3 prohibits changing the id
format, and hardening the parser *is* changing it:

- positional indexing, guarded only by `parts.Num() != N`
- a wrong count returns "no parse", never an exception
- a non-numeric tick becomes `0` (Godot's silent `int()` coercion), not an error
- a negative tick parses and round-trips fine
- `burycase` reassembles the nested case id as `parts[3..6]` joined with `@`

**Files:**
- Create: `D:\black-meridian-ue\Source\BMCore\Public\BMJobIdParser.h`
- Create: `D:\black-meridian-ue\Source\BMCore\Private\BMJobIdParser.cpp`
- Test: `D:\black-meridian-ue\Source\BMCore\Private\BMJobTest.cpp` (append)

- [ ] **Step 1: Write the failing test**

Append to `D:\black-meridian-ue\Source\BMCore\Private\BMJobTest.cpp` (and add
`#include "BMJobIdParser.h"` to its include block):

```cpp
// ---------------------------------------------------------------------------
// BM.Jobs.IdParseContract — GV-JOB-03, the parse half
// ---------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FBMJobIdParseContractTest,
	"BM.Jobs.IdParseContract",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FBMJobIdParseContractTest::RunTest(const FString&)
{
	TSharedPtr<FJsonObject> Root;
	FString Error;
	if (!LoadJobVectors(Root, Error))
	{
		AddError(Error);
		return false;
	}

	const TSharedPtr<FJsonObject>* Ids = LayerObject(Root, TEXT("ids"));
	const TArray<TSharedPtr<FJsonValue>>* Rows = LayerRows(Root, TEXT("ids"));
	if (!Ids || !Rows)
	{
		AddError(TEXT("fixture has no usable 'ids' layer"));
		return false;
	}

	// The prefix is a parse contract, read from the fixture rather than re-typed.
	const FString Prefix = (*Ids)->GetStringField(TEXT("generated_prefix"));
	if (Prefix != FBMJobIdParser::GeneratedPrefix)
	{
		AddError(FString::Printf(
			TEXT("prefix drift: fixture \"%s\", port \"%s\""),
			*Prefix, FBMJobIdParser::GeneratedPrefix));
	}

	int32 Mismatches = 0;
	int32 ParsedRows = 0;

	for (const TSharedPtr<FJsonValue>& Value : *Rows)
	{
		const TSharedPtr<FJsonObject> Row = Value->AsObject();
		const FString Kind = Row->GetStringField(TEXT("kind"));
		const FString Id = Row->GetStringField(TEXT("id"));

		FBMParsedJobId Parsed;
		const bool bParsed = FBMJobIdParser::Parse(Id, Parsed);
		++ParsedRows;

		// The parse itself is a DECISION — exact. The fixture's `rebuilt` flag folds in
		// target lookup (an unknown venue also yields null), so the parse-level expectation
		// is derived here from the row kind, and the lookup half is Task 10's business.
		const bool bExpectParse = !(
			   Kind == TEXT("not_generated_prefix")
			|| Kind == TEXT("prefix_only")
			|| Kind == TEXT("unknown_template")
			|| Kind == TEXT("retaliation_too_few_segments")
			|| Kind == TEXT("retaliation_too_many_segments")
			|| Kind == TEXT("followup_too_many_segments")
			|| Kind == TEXT("burycase_missing_case_segment"));

		if (bParsed != bExpectParse && ++Mismatches <= MaxReportedMismatches)
		{
			AddError(FString::Printf(
				TEXT("Parse(\"%s\") [%s]: expected %s, got %s — the guard is a segment COUNT, and a wrong count is a refusal, never an error"),
				*Id, *Kind, bExpectParse ? TEXT("parse") : TEXT("no parse"),
				bParsed ? TEXT("parse") : TEXT("no parse")));
		}

		if (!bParsed)
		{
			continue;
		}

		// Segment count, where the fixture recorded it.
		int32 ExpectedSegments = 0;
		if (Row->TryGetNumberField(TEXT("segments"), ExpectedSegments))
		{
			TArray<FString> Parts;
			Id.ParseIntoArray(Parts, TEXT("@"), false);
			if (Parts.Num() != ExpectedSegments && ++Mismatches <= MaxReportedMismatches)
			{
				AddError(FString::Printf(
					TEXT("\"%s\": fixture says %d segments, the port's split yields %d — ParseIntoArray must NOT cull empties"),
					*Id, ExpectedSegments, Parts.Num()));
			}
		}

		// Rebuilding the id from the parse must be byte-identical for every well-formed
		// numeric-tick row. This is the gate condition, tested here at the parser level
		// before any template content is involved.
		const bool bNonNumericTick = Kind == TEXT("retaliation_nonnumeric_tick");
		if (!bNonNumericTick)
		{
			const FString Rebuilt = FBMJobIdParser::Build(Parsed);
			if (Rebuilt != Id && ++Mismatches <= MaxReportedMismatches)
			{
				AddError(FString::Printf(
					TEXT("Build(Parse(\"%s\")) = \"%s\" — the id must round-trip BYTE-identically"),
					*Id, *Rebuilt));
			}
		}
		else
		{
			// `[V]` Godot's int("notanumber") is 0, silently. The port reproduces the
			// coercion, so this id parses, yields tick 0, and DOES NOT round-trip.
			if (Parsed.Tick != 0 && ++Mismatches <= MaxReportedMismatches)
			{
				AddError(FString::Printf(
					TEXT("\"%s\": a non-numeric tick must coerce to 0 (Godot's silent int()), got %d"),
					*Id, Parsed.Tick));
			}
			const FString Rebuilt = FBMJobIdParser::Build(Parsed);
			if (Rebuilt == Id && ++Mismatches <= MaxReportedMismatches)
			{
				AddError(TEXT("a non-numeric tick must NOT round-trip — the coercion is lossy by design"));
			}
		}

		if (Kind == TEXT("retaliation_negative_tick"))
		{
			// A negative tick is well-formed and round-trips. Do not "validate" it away.
			if (Parsed.Tick != -5 && ++Mismatches <= MaxReportedMismatches)
			{
				AddError(FString::Printf(
					TEXT("\"%s\": expected tick -5, got %d"), *Id, Parsed.Tick));
			}
		}

		// The nested case id — the whole reason this parser exists as a single type.
		if (Kind == TEXT("burycase") || Kind == TEXT("burycase_correct"))
		{
			const FString ExpectedCaseId = (*Ids)->GetStringField(TEXT("case_id_example"));
			if (Parsed.CaseId != ExpectedCaseId && ++Mismatches <= MaxReportedMismatches)
			{
				AddError(FString::Printf(
					TEXT("\"%s\": case id expected \"%s\", got \"%s\" — it is parts[3..6] rejoined with '@', not parts[3]"),
					*Id, *ExpectedCaseId, *Parsed.CaseId));
			}
			if (Parsed.Template != EBMJobIdTemplate::BuryCase
				&& ++Mismatches <= MaxReportedMismatches)
			{
				AddError(FString::Printf(TEXT("\"%s\": template misread"), *Id));
			}
		}
	}

	AddInfo(FString::Printf(TEXT("ids: %d rows through the parser"), ParsedRows));

	if (Mismatches > 0)
	{
		AddError(FString::Printf(
			TEXT("S3 GATE FAILED — %d id-parse mismatch(es). See Docs/gates/S3.md."),
			Mismatches));
		return false;
	}

	return true;
}

// ---------------------------------------------------------------------------
// BM.Jobs.IdParserIsSingleImplementation — the TD-05 rule, applied to the parser
// ---------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FBMJobIdParserSingleImplementationTest,
	"BM.Jobs.IdParserIsSingleImplementation",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FBMJobIdParserSingleImplementationTest::RunTest(const FString&)
{
	// Godot split this string at four call sites with four hardcoded counts. The port keeps
	// exactly one. This scans BMCore and BMSim for a second splitter — the signature of
	// someone re-deriving the segments locally instead of calling the parser.
	const TArray<FString> GuardedModules = { TEXT("BMCore"), TEXT("BMSim") };
	const FString CanonicalImplementation = TEXT("BMJobIdParser.cpp");

	TArray<FString> Offenders;

	for (const FString& Module : GuardedModules)
	{
		const FString ModuleRoot = FPaths::Combine(FPaths::ProjectDir(), TEXT("Source"), Module);

		TArray<FString> Files;
		IFileManager::Get().FindFilesRecursive(Files, *ModuleRoot, TEXT("*.cpp"), true, false, false);
		IFileManager::Get().FindFilesRecursive(Files, *ModuleRoot, TEXT("*.h"), true, false, true);

		for (const FString& File : Files)
		{
			const FString Filename = FPaths::GetCleanFilename(File);
			if (Filename == CanonicalImplementation || Filename.EndsWith(TEXT("Test.cpp")))
			{
				continue;
			}

			FString Contents;
			if (!FFileHelper::LoadFileToString(Contents, *File))
			{
				continue;
			}

			if (Contents.Contains(TEXT("ParseIntoArray")) && Contents.Contains(TEXT("\"@\"")))
			{
				Offenders.AddUnique(FString::Printf(
					TEXT("%s/%s splits on '@' itself"), *Module, *Filename));
			}
		}
	}

	for (const FString& Offender : Offenders)
	{
		AddError(FString::Printf(
			TEXT("the job-id split must exist only in BMJobIdParser.cpp — %s"), *Offender));
	}

	return Offenders.Num() == 0;
}
```

- [ ] **Step 2: Run it to verify it fails**

Run:
```sh
"C:/Program Files/Epic Games/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" \
    D:/black-meridian-ue/BlackMeridian.uproject \
    -ExecCmds="Automation RunTests BM.Jobs; Quit" -unattended -nopause -nullrhi -nosplash -NoLiveCoding \
    -testexit="Automation Test Queue Empty"
```
Expected: build failure, `Cannot open include file: 'BMJobIdParser.h'`.

- [ ] **Step 3: Implement**

Create `D:\black-meridian-ue\Source\BMCore\Public\BMJobIdParser.h`:

```cpp
#pragma once

#include "CoreMinimal.h"

/**
 * THE single job-id parser. Every split of a generated job id in the port goes through here.
 *
 * `[V]` Godot splits the same string at FOUR call sites with four hardcoded segment counts
 * (JobGenerator.rebuild, JobDirector._district_of, _burn_target_of, _provocateur_of). They
 * collapse into this one type, and BM.Jobs.IdParserIsSingleImplementation guards the
 * collapse — the same rule, and the same reasoning, as TD-05's single avalanche.
 *
 * The id formats, all measured against the running oracle on 2026-09-18:
 *
 *   gen@retaliation@<venue>@<rival>@<tick>     5 segments
 *   gen@contested@<venue>@<rival>@<tick>       5
 *   gen@followup@<venue>@<tick>                4
 *   gen@burycase@<district>@<case id>@<tick>   8, because the case id is ITSELF
 *                                              case@<district>@<kind>@<tick> (4 segments)
 *
 * A real one: gen@burycase@glasswharf@case@glasswharf@0@120@240
 *
 * ⚠️ The parse is POSITIONAL and deliberately FRAGILE. 07 §S3 prohibits changing the id
 * format, and hardening this parser IS changing it. Four behaviors are contract:
 *   1. the only guard is the segment COUNT; an '@' inside any id shifts every slot
 *   2. a wrong count is a refusal (false), never an exception
 *   3. a non-numeric tick becomes 0 — Godot's silent int() coercion, reproduced exactly
 *   4. a negative tick parses and round-trips fine
 */

/** Which builder an id names. `Unknown` is a refusal, not an error. */
enum class EBMJobIdTemplate : uint8
{
	Unknown = 0,
	Retaliation,
	Contested,
	Followup,
	BuryCase,
};

/** What a generated id decomposes into. Unused fields stay empty — `followup` has no rival,
 *  `burycase` has no venue (it targets a CASE; the district is in the id instead). */
struct BMCORE_API FBMParsedJobId
{
	EBMJobIdTemplate Template = EBMJobIdTemplate::Unknown;

	FString VenueId;     // retaliation, contested, followup
	FString RivalId;     // retaliation, contested
	FString DistrictId;  // burycase
	FString CaseId;      // burycase — the nested 4-segment id, rejoined
	int32 Tick = 0;
};

struct BMCORE_API FBMJobIdParser
{
	/** `[V]` "gen@". A generated id starts with it; an authored id does not and is refused. */
	static const TCHAR* const GeneratedPrefix;

	/** Template name as it appears in segment 1. */
	static const TCHAR* TemplateToken(EBMJobIdTemplate Template);

	/**
	 * Splits a generated id into its parts. Returns false — never throws — for an id with
	 * the wrong prefix, an unknown template token, or the wrong segment count.
	 *
	 * `[V]` A false return is a LEGITIMATE, tested outcome: JobGenerator.rebuild returns
	 * null for exactly these ids and SaveService treats that as "this job cannot be rebuilt
	 * honestly", which is the intended behavior.
	 */
	static bool Parse(const FString& JobId, FBMParsedJobId& OutParsed);

	/**
	 * Rebuilds the id string from a parse. `[V]` Byte-identical round-trip for every
	 * well-formed id is the S3 gate condition — with one deliberate exception: an id whose
	 * tick was non-numeric coerced to 0 on the way in and cannot round-trip. The coercion
	 * is lossy by design, reproduced from Godot rather than repaired.
	 */
	static FString Build(const FBMParsedJobId& Parsed);

	/** `[V]` Godot's int() on a non-numeric string is 0, silently. Reproduced, not fixed.
	 *  A leading '-' is honored; anything else unparseable yields 0. */
	static int32 CoerceTick(const FString& Segment);
};
```

Create `D:\black-meridian-ue\Source\BMCore\Private\BMJobIdParser.cpp`:

```cpp
#include "BMJobIdParser.h"

const TCHAR* const FBMJobIdParser::GeneratedPrefix = TEXT("gen@");

const TCHAR* FBMJobIdParser::TemplateToken(EBMJobIdTemplate Template)
{
	switch (Template)
	{
	case EBMJobIdTemplate::Retaliation: return TEXT("retaliation");
	case EBMJobIdTemplate::Contested:   return TEXT("contested");
	case EBMJobIdTemplate::Followup:    return TEXT("followup");
	case EBMJobIdTemplate::BuryCase:    return TEXT("burycase");
	default:                            return TEXT("");
	}
}

int32 FBMJobIdParser::CoerceTick(const FString& Segment)
{
	// `[V]` Godot's int("notanumber") == 0. Reproduce the coercion exactly: no error, no
	// sentinel, no rejection. A port that validates here rejects ids the oracle accepts.
	if (Segment.IsNumeric())
	{
		return FCString::Atoi(*Segment);
	}

	// IsNumeric() is false for a leading '-', which the oracle DOES accept ("-5" -> -5).
	if (Segment.Len() > 1 && Segment[0] == TEXT('-') && Segment.RightChop(1).IsNumeric())
	{
		return FCString::Atoi(*Segment);
	}

	return 0;
}

bool FBMJobIdParser::Parse(const FString& JobId, FBMParsedJobId& OutParsed)
{
	OutParsed = FBMParsedJobId();

	if (!JobId.StartsWith(GeneratedPrefix, ESearchCase::CaseSensitive))
	{
		return false;
	}

	// `[V]` bCullEmpty MUST be false. "gen@" splits to {"gen", ""} — two parts — and the
	// count guard is the only thing standing between that and an out-of-range index.
	TArray<FString> Parts;
	JobId.ParseIntoArray(Parts, TEXT("@"), /*InCullEmpty=*/false);

	if (Parts.Num() < 2)
	{
		return false;
	}

	const FString& Token = Parts[1];

	if (Token == TEXT("retaliation") || Token == TEXT("contested"))
	{
		// gen@<template>@<venue>@<rival>@<tick>
		if (Parts.Num() != 5)
		{
			return false;
		}
		OutParsed.Template = Token == TEXT("retaliation")
			? EBMJobIdTemplate::Retaliation : EBMJobIdTemplate::Contested;
		OutParsed.VenueId = Parts[2];
		OutParsed.RivalId = Parts[3];
		OutParsed.Tick = CoerceTick(Parts[4]);
		return true;
	}

	if (Token == TEXT("followup"))
	{
		// gen@followup@<venue>@<tick>
		if (Parts.Num() != 4)
		{
			return false;
		}
		OutParsed.Template = EBMJobIdTemplate::Followup;
		OutParsed.VenueId = Parts[2];
		OutParsed.Tick = CoerceTick(Parts[3]);
		return true;
	}

	if (Token == TEXT("burycase"))
	{
		// gen@burycase@<district>@<case id>@<tick>, where the case id is itself four
		// "@"-segments (case@<district>@<kind>@<tick>) -> 8 parts total.
		// `[V]` The case id is parts[3..6] rejoined — Godot's "@".join(parts.slice(3, 7)).
		if (Parts.Num() != 8)
		{
			return false;
		}
		OutParsed.Template = EBMJobIdTemplate::BuryCase;
		OutParsed.DistrictId = Parts[2];
		OutParsed.CaseId = FString::Join(
			TArrayView<const FString>(Parts.GetData() + 3, 4), TEXT("@"));
		OutParsed.Tick = CoerceTick(Parts[7]);
		return true;
	}

	return false;
}

FString FBMJobIdParser::Build(const FBMParsedJobId& Parsed)
{
	switch (Parsed.Template)
	{
	case EBMJobIdTemplate::Retaliation:
	case EBMJobIdTemplate::Contested:
		return FString::Printf(TEXT("gen@%s@%s@%s@%d"),
			TemplateToken(Parsed.Template), *Parsed.VenueId, *Parsed.RivalId, Parsed.Tick);

	case EBMJobIdTemplate::Followup:
		return FString::Printf(TEXT("gen@followup@%s@%d"), *Parsed.VenueId, Parsed.Tick);

	case EBMJobIdTemplate::BuryCase:
		return FString::Printf(TEXT("gen@burycase@%s@%s@%d"),
			*Parsed.DistrictId, *Parsed.CaseId, Parsed.Tick);

	default:
		return FString();
	}
}
```

- [ ] **Step 4: Run to verify it passes**

Run:
```sh
"C:/Program Files/Epic Games/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" \
    D:/black-meridian-ue/BlackMeridian.uproject \
    -ExecCmds="Automation RunTests BM.Jobs; Quit" -unattended -nopause -nullrhi -nosplash -NoLiveCoding \
    -testexit="Automation Test Queue Empty"
```
Expected:
```
BM.Jobs.EnumValuesAreSaveContract                  Result={Success}
BM.Jobs.IdParseContract                            Result={Success}   19 rows through the parser
BM.Jobs.IdParserIsSingleImplementation             Result={Success}
**** TEST COMPLETE. EXIT CODE: 0 ****              3/3 · 0 fail · 0 errors
```

- [ ] **Step 5: Commit**

```bash
cd /d/black-meridian-ue
git add Source/BMCore/Public/BMJobIdParser.h Source/BMCore/Private/BMJobIdParser.cpp \
        Source/BMCore/Private/BMJobTest.cpp
git commit -m "feat(s3): BMJobIdParser — the single job-id parser

Godot splits this string at four call sites with four hardcoded segment
counts. The port keeps one, guarded by a source scan the same way TD-05
guards the avalanche.

Faithfully fragile, because 07 S3 prohibits changing the id format and
hardening the parser IS changing it: positional indexing guarded only by the
segment count, a wrong count refuses instead of throwing, a non-numeric tick
coerces to 0 (Godot's silent int()), a negative tick round-trips, and the
burycase case id is parts[3..6] rejoined.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: `BMJobResolution` — nine dimensions, clamped once

The whole of resolution is: start from zeros, add every chosen option's sparse contributions, clamp
**once at the end**. The mistake worth naming is clamping per term — it produces identical results
on every ordinary job and diverges only when contributions overshoot, which is precisely what the
`over_clamp_unsigned` fixture row is built from.

**Files:**
- Create: `D:\black-meridian-ue\Source\BMCore\Public\BMJobResolution.h`
- Create: `D:\black-meridian-ue\Source\BMCore\Private\BMJobResolution.cpp`
- Test: `D:\black-meridian-ue\Source\BMCore\Private\BMJobTest.cpp` (append)

- [ ] **Step 1: Write the failing test**

Append to `D:\black-meridian-ue\Source\BMCore\Private\BMJobTest.cpp` (add
`#include "BMJobResolution.h"`):

```cpp
// ---------------------------------------------------------------------------
// BM.Jobs.ResolutionMatchesGodotVectors — GV-JOB-01, GV-JOB-02
// ---------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FBMJobResolutionMatchesGodotVectorsTest,
	"BM.Jobs.ResolutionMatchesGodotVectors",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

namespace
{
	/** The hand-built choice pools the extractor used, transcribed field for field from
	 *  export_job_vectors.gd's _resolution_cases(). They deliberately overshoot BOTH ends of
	 *  BOTH clamp ranges, so a per-term clamp and an end clamp produce DIFFERENT vectors. */
	TArray<FBMJobChoice> ResolutionPrepPool()
	{
		return {
			FBMJobChoice(TEXT("p_big"),  TEXT("big"),  TEXT(""),
				{ FBMJobEffect(TEXT("objective_achieved"), 0.5f) }),
			FBMJobChoice(TEXT("p_big2"), TEXT("big2"), TEXT(""),
				{ FBMJobEffect(TEXT("objective_achieved"), 0.5f) }),
			FBMJobChoice(TEXT("p_big3"), TEXT("big3"), TEXT(""),
				{ FBMJobEffect(TEXT("objective_achieved"), 0.5f) }),
			FBMJobChoice(TEXT("p_neg"),  TEXT("neg"),  TEXT(""),
				{ FBMJobEffect(TEXT("evidence_generated"), -0.6f) }),
			FBMJobChoice(TEXT("p_mixed"), TEXT("mixed"), TEXT(""),
				{ FBMJobEffect(TEXT("evidence_generated"), 0.4f),
				  FBMJobEffect(TEXT("operative_injury"), -0.3f),
				  FBMJobEffect(TEXT("new_leverage"), 0.2f) }),
		};
	}

	TArray<FBMJobChoice> ResolutionApproachPool()
	{
		return {
			FBMJobChoice(TEXT("a_loud"), TEXT("loud"), TEXT(""),
				{ FBMJobEffect(TEXT("objective_achieved"), 0.7f),
				  FBMJobEffect(TEXT("evidence_generated"), 0.35f),
				  FBMJobEffect(TEXT("public_fear"), 0.2f),
				  FBMJobEffect(TEXT("rival_suspicion"), 0.2f) }),
			FBMJobChoice(TEXT("a_over"), TEXT("over"), TEXT(""),
				{ FBMJobEffect(TEXT("evidence_generated"), 0.9f),
				  FBMJobEffect(TEXT("collateral_damage"), 1.2f) }),
		};
	}

	TArray<FBMJobChoice> ResolutionCoverupPool()
	{
		return {
			FBMJobChoice(TEXT("c_deny"),  TEXT("deny"),  TEXT(""),
				{ FBMJobEffect(TEXT("evidence_generated"), -0.3f) }),
			FBMJobChoice(TEXT("c_under"), TEXT("under"), TEXT(""),
				{ FBMJobEffect(TEXT("evidence_generated"), -1.5f),
				  FBMJobEffect(TEXT("relationship_change"), -1.4f) }),
			FBMJobChoice(TEXT("c_heavy"), TEXT("heavy"), TEXT(""),
				{ FBMJobEffect(TEXT("delayed_consequence"), 0.5f) }),
		};
	}
}

bool FBMJobResolutionMatchesGodotVectorsTest::RunTest(const FString&)
{
	TSharedPtr<FJsonObject> Root;
	FString Error;
	if (!LoadJobVectors(Root, Error))
	{
		AddError(Error);
		return false;
	}

	const TArray<TSharedPtr<FJsonValue>>* Rows = LayerRows(Root, TEXT("resolution"));
	if (!Rows)
	{
		AddError(TEXT("fixture has no usable 'resolution' layer"));
		return false;
	}

	const TArray<FString> Dimensions = FBMJobOutcome::DimensionNames();

	int32 Mismatches = 0;
	int32 ResolvedRows = 0;

	for (const TSharedPtr<FJsonValue>& Value : *Rows)
	{
		const TSharedPtr<FJsonObject> Row = Value->AsObject();
		const FString Kind = Row->GetStringField(TEXT("kind"));
		const TSharedPtr<FJsonObject> Expected = Row->GetObjectField(TEXT("outcome"));

		FBMJobOutcome Actual;

		if (Kind == TEXT("expired"))
		{
			Actual = FBMJobResolution::Expired();
		}
		else if (Kind == TEXT("blank"))
		{
			Actual = FBMJobResolution::Blank();
		}
		else
		{
			++ResolvedRows;

			FBMJob Job;
			Job.PrepActions = ResolutionPrepPool();
			Job.Approaches = ResolutionApproachPool();
			Job.Coverups = ResolutionCoverupPool();
			Job.ChosenPrep = StringArray(Row, TEXT("chosen_prep"));
			Job.ChosenApproach = Row->GetStringField(TEXT("chosen_approach"));
			Job.ChosenCoverup = Row->GetStringField(TEXT("chosen_coverup"));

			Actual = FBMJobResolution::Resolve(Job);
		}

		for (const FString& Dimension : Dimensions)
		{
			const float ExpectedValue = static_cast<float>(Expected->GetNumberField(Dimension));
			const float* ActualValue = Actual.FindByName(Dimension);

			if (ActualValue == nullptr)
			{
				AddError(FString::Printf(
					TEXT("the port has no dimension '%s' — FBMJobOutcome and the oracle disagree"),
					*Dimension));
				++Mismatches;
				continue;
			}

			if (!FMath::IsNearlyEqual(*ActualValue, ExpectedValue, JobTolerance)
				&& ++Mismatches <= MaxReportedMismatches)
			{
				AddError(FString::Printf(
					TEXT("Resolve[%s].%s: expected %g, got %g"),
					*Kind, *Dimension, ExpectedValue, *ActualValue));
			}
		}

		// `[V]` Every row here produced an outcome, so bResolved must be set. The flag is
		// what distinguishes "never resolved" from "resolved to all zeros" — the `blank`
		// row is all zeros AND resolved, and apply_outcome must still run on it.
		if (!Actual.bResolved && ++Mismatches <= MaxReportedMismatches)
		{
			AddError(FString::Printf(
				TEXT("Resolve[%s]: bResolved is false — an all-zero outcome is still a RESOLVED outcome"),
				*Kind));
		}
	}

	AddInfo(FString::Printf(TEXT("resolution: %d resolve rows + expired + blank"), ResolvedRows));

	if (Mismatches > 0)
	{
		AddError(FString::Printf(
			TEXT("S3 GATE FAILED — %d resolution mismatch(es). See Docs/gates/S3.md."),
			Mismatches));
		return false;
	}

	return true;
}
```

> **Mutation note — read this before implementing.** Change the clamp to run per accumulated
> term (clamp inside `Accumulate` instead of once at the end) and re-run. The
> **`over_clamp_unsigned`** row must FAIL: its three `+0.5` prep contributions to
> `objective_achieved` clamp to `1.0` in the oracle, but a per-term clamp caps the running sum at
> `1.0` after the second term and then keeps it there — same answer for `objective_achieved`, but
> `collateral_damage` (a single `+1.2`) and `evidence_generated` (`+0.9` against a signed axis)
> expose the difference, and `signed_negative_then_positive` (`-0.6` then `+0.35` = `-0.25`) goes
> wrong the moment the intermediate `-0.6` is clamped by an unsigned rule. If the mutation passes,
> the fixture is not measuring the clamp and the gate is decorative. Revert after confirming.

- [ ] **Step 2: Run it to verify it fails**

Run:
```sh
"C:/Program Files/Epic Games/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" \
    D:/black-meridian-ue/BlackMeridian.uproject \
    -ExecCmds="Automation RunTests BM.Jobs; Quit" -unattended -nopause -nullrhi -nosplash -NoLiveCoding \
    -testexit="Automation Test Queue Empty"
```
Expected: build failure, `Cannot open include file: 'BMJobResolution.h'`.

- [ ] **Step 3: Implement**

Create `D:\black-meridian-ue\Source\BMCore\Public\BMJobResolution.h`:

```cpp
#pragma once

#include "BMJobTypes.h"
#include "CoreMinimal.h"

/**
 * Pure resolution math for fixer jobs (brief §7.5), ported from src/jobs/job_resolution.gd.
 *
 * Resolution is multi-dimensional, never binary, and fully deterministic — the pillar is
 * that outcomes are telegraphed, with no hidden rolls. Kept static and state-free for the
 * same reason the Godot original was split out of the JobDirector autoload: so it can be
 * measured headless.
 *
 * Measured against Tests/Golden/job_vectors.json (`resolution`) — GV-JOB-01, GV-JOB-02.
 */
struct BMCORE_API FBMJobResolution
{
	/**
	 * GV-JOB-01. Sums every chosen option's sparse contributions into a full outcome:
	 * each chosen prep action in CHOSEN order, then the approach, then the cover-up.
	 *
	 * `[V]` Clamped ONCE, at the end — never per term. Three prep actions each contributing
	 * +0.5 to an unsigned axis yield 1.0; a signed axis going -0.6 then +0.35 yields -0.25,
	 * having never been clamped on the way through. A per-term clamp agrees on ordinary jobs
	 * and diverges exactly where the authored data overshoots, which is where it matters.
	 *
	 * `[V]` A choice id that names nothing is SKIPPED, not an error — GDScript's
	 * `_accumulate` returns early on a null choice. An unknown DIMENSION is a different
	 * matter: the oracle asserts, and the port cannot even express one (FBMJobOutcome is a
	 * fixed struct), so a misspelled dimension in an authored table is caught at the table.
	 */
	static FBMJobOutcome Resolve(const FBMJob& Job);

	/**
	 * GV-JOB-02. The outcome when the deadline expires before the player resolves the job:
	 * the problem festers. `[V]` A FIXED triple — evidence +0.3, public fear +0.1, delayed
	 * consequence +0.5 — not a computation over the job. Note the delayed consequence
	 * (0.5) is comfortably over the follow-up threshold, so an expired job ALWAYS schedules
	 * a follow-up. That is the loop staying alive, not an accident.
	 */
	static FBMJobOutcome Expired();

	/** All nine dimensions at zero, marked resolved. `[V]` Distinct from a default-
	 *  constructed FBMJobOutcome, whose bResolved is false — "resolved to nothing" and
	 *  "never resolved" are different states and ApplyOutcome treats them differently. */
	static FBMJobOutcome Blank();

private:
	/** Adds one choice's sparse effects. `[V]` No clamping here — see Resolve. */
	static void Accumulate(FBMJobOutcome& Out, const FBMJobChoice* Choice);

	/** `[V]` The three signed axes clamp -1..1, the other six 0..1. Applied once. */
	static void Clamp(FBMJobOutcome& Out);
};
```

Create `D:\black-meridian-ue\Source\BMCore\Private\BMJobResolution.cpp`:

```cpp
#include "BMJobResolution.h"

FBMJobOutcome FBMJobResolution::Blank()
{
	FBMJobOutcome Out;
	Out.bResolved = true;
	return Out;
}

void FBMJobResolution::Accumulate(FBMJobOutcome& Out, const FBMJobChoice* Choice)
{
	// `[V]` A null choice is a silent skip — job_resolution.gd's `if choice == null: return`.
	// An id naming nothing contributes nothing; it is not an error.
	if (Choice == nullptr)
	{
		return;
	}

	for (const FBMJobEffect& Effect : Choice->Effects)
	{
		float* Field = Out.FindByName(Effect.Dimension);

		// The oracle asserts here on an unknown dimension. The port cannot express one at
		// runtime — FBMJobOutcome is a fixed struct — so this arm only fires on a typo in an
		// authored table, and it must be loud rather than silently dropped.
		checkf(Field != nullptr, TEXT("Unknown resolution dimension: %s"), *Effect.Dimension);

		*Field += Effect.Value;
	}
}

void FBMJobResolution::Clamp(FBMJobOutcome& Out)
{
	// `[V]` Signed axes: production MINUS suppression. Authored data feeds these negative
	// on purpose ("I left no trace", "I protected my people").
	Out.EvidenceGenerated  = FMath::Clamp(Out.EvidenceGenerated,  -1.0f, 1.0f);
	Out.OperativeInjury    = FMath::Clamp(Out.OperativeInjury,    -1.0f, 1.0f);
	Out.RelationshipChange = FMath::Clamp(Out.RelationshipChange, -1.0f, 1.0f);

	Out.ObjectiveAchieved  = FMath::Clamp(Out.ObjectiveAchieved,  0.0f, 1.0f);
	Out.CollateralDamage   = FMath::Clamp(Out.CollateralDamage,   0.0f, 1.0f);
	Out.RivalSuspicion     = FMath::Clamp(Out.RivalSuspicion,     0.0f, 1.0f);
	Out.PublicFear         = FMath::Clamp(Out.PublicFear,         0.0f, 1.0f);
	Out.NewLeverage        = FMath::Clamp(Out.NewLeverage,        0.0f, 1.0f);
	Out.DelayedConsequence = FMath::Clamp(Out.DelayedConsequence, 0.0f, 1.0f);
}

FBMJobOutcome FBMJobResolution::Resolve(const FBMJob& Job)
{
	FBMJobOutcome Out = Blank();

	// Prep actions in CHOSEN order, then the approach, then the cover-up. Addition is
	// commutative so order does not change the sum — but it does decide which contribution
	// an assert would name, and the order is free to preserve.
	for (const FString& PrepId : Job.ChosenPrep)
	{
		const int32 Index = FBMJob::FindChoice(Job.PrepActions, PrepId);
		Accumulate(Out, Index != INDEX_NONE ? &Job.PrepActions[Index] : nullptr);
	}

	{
		const int32 Index = FBMJob::FindChoice(Job.Approaches, Job.ChosenApproach);
		Accumulate(Out, Index != INDEX_NONE ? &Job.Approaches[Index] : nullptr);
	}

	{
		const int32 Index = FBMJob::FindChoice(Job.Coverups, Job.ChosenCoverup);
		Accumulate(Out, Index != INDEX_NONE ? &Job.Coverups[Index] : nullptr);
	}

	// ONCE, at the end. Never per term.
	Clamp(Out);
	return Out;
}

FBMJobOutcome FBMJobResolution::Expired()
{
	// `[V]` A fixed triple, not a computation. The problem festers: nothing achieved,
	// evidence piles up, fallout deferred — and 0.5 is over the follow-up threshold, so an
	// expired job always spawns its successor.
	FBMJobOutcome Out = Blank();
	Out.EvidenceGenerated = 0.3f;
	Out.PublicFear = 0.1f;
	Out.DelayedConsequence = 0.5f;
	return Out;
}
```

- [ ] **Step 4: Run to verify it passes**

Run:
```sh
"C:/Program Files/Epic Games/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" \
    D:/black-meridian-ue/BlackMeridian.uproject \
    -ExecCmds="Automation RunTests BM.Jobs; Quit" -unattended -nopause -nullrhi -nosplash -NoLiveCoding \
    -testexit="Automation Test Queue Empty"
```
Expected:
```
BM.Jobs.EnumValuesAreSaveContract                  Result={Success}
BM.Jobs.IdParseContract                            Result={Success}   19 rows through the parser
BM.Jobs.IdParserIsSingleImplementation             Result={Success}
BM.Jobs.ResolutionMatchesGodotVectors              Result={Success}   7 resolve rows + expired + blank
**** TEST COMPLETE. EXIT CODE: 0 ****              4/4 · 0 fail · 0 errors
```

- [ ] **Step 5: Commit**

```bash
cd /d/black-meridian-ue
git add Source/BMCore/Public/BMJobResolution.h Source/BMCore/Private/BMJobResolution.cpp \
        Source/BMCore/Private/BMJobTest.cpp
git commit -m "feat(s3): BMJobResolution — nine dimensions, clamped once at the end

Accumulate every chosen option's sparse contributions, then clamp ONCE: the
three signed axes to -1..1, the other six to 0..1. A per-term clamp agrees on
ordinary jobs and diverges exactly where authored data overshoots — verified
by mutation against the over_clamp_unsigned row.

Expired() is a fixed triple, and its 0.5 delayed_consequence is over the
follow-up threshold by design: an expired job always spawns its successor.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: `BMJobLifecycle` — the stage machine and `ApplyOutcome`

The stage machine's value is in what it **refuses**. Every transition guard returns `false` and
leaves state untouched; a port that lets a caller skip Preparation still passes every happy-path
test. The fixture records post-state on refusal rows for exactly that reason, and so must the port.

Three behaviors are contract and easy to lose:

1. **The cover-up call is ATOMIC.** `INTERVENTION → COVER_UP → RESOLVED` happens inside one call,
   with the outcome resolved on the way through. A port that stops at `CoverUp` and waits for a
   second call is a different game with a stage the player can sit in.
2. **`Tick` returns early on a resolved job, before decrementing.** A resolved job's counter stops
   moving. A port that decrements first and checks after drifts every counter in the save.
3. **The prep cap exempts toggle-off.** At three chosen actions, selecting a fourth is refused —
   but *deselecting* one of the three is allowed, because the erase branch sits above the cap check.

**Files:**
- Create: `D:\black-meridian-ue\Source\BMCore\Public\BMJobLifecycle.h`
- Create: `D:\black-meridian-ue\Source\BMCore\Private\BMJobLifecycle.cpp`
- Test: `D:\black-meridian-ue\Source\BMCore\Private\BMJobTest.cpp` (append)

- [ ] **Step 1: Write the failing test**

Append to `D:\black-meridian-ue\Source\BMCore\Private\BMJobTest.cpp` (add
`#include "BMJobLifecycle.h"`):

```cpp
// ---------------------------------------------------------------------------
// BM.Jobs.LifecycleMatchesGodotVectors — GV-JOB-03, the stage-machine half
// ---------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FBMJobLifecycleMatchesGodotVectorsTest,
	"BM.Jobs.LifecycleMatchesGodotVectors",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

namespace
{
	/** The extractor's `_lifecycle_job()`, transcribed: four prep options (one more than the
	 *  cap, so the cap row has something to be refused), one approach, one cover-up. */
	FBMJob LifecycleProbeJob()
	{
		FBMJob Job;
		Job.Id = TEXT("lc_probe");
		Job.DeadlineTicks = 60;
		Job.PrepActions = {
			FBMJobChoice(TEXT("p1"), TEXT("p1"), TEXT(""),
				{ FBMJobEffect(TEXT("objective_achieved"), 0.1f) }),
			FBMJobChoice(TEXT("p2"), TEXT("p2"), TEXT(""),
				{ FBMJobEffect(TEXT("objective_achieved"), 0.1f) }),
			FBMJobChoice(TEXT("p3"), TEXT("p3"), TEXT(""),
				{ FBMJobEffect(TEXT("objective_achieved"), 0.1f) }),
			FBMJobChoice(TEXT("p4"), TEXT("p4"), TEXT(""),
				{ FBMJobEffect(TEXT("objective_achieved"), 0.1f) }),
		};
		Job.Approaches = {
			FBMJobChoice(TEXT("a1"), TEXT("a1"), TEXT(""),
				{ FBMJobEffect(TEXT("objective_achieved"), 0.6f) }),
		};
		Job.Coverups = {
			FBMJobChoice(TEXT("c1"), TEXT("c1"), TEXT(""),
				{ FBMJobEffect(TEXT("evidence_generated"), -0.3f) }),
		};
		return Job;
	}

	/** Dispatches one fixture row's call against a prepared job. The row kinds are the
	 *  extractor's `_lifecycle_cases()` kinds, one for one. */
	bool RunLifecycleCall(const FString& Kind, FBMJob& Job)
	{
		if (Kind.StartsWith(TEXT("begin_")))
		{
			return FBMJobLifecycle::Begin(Job);
		}
		if (Kind == TEXT("prep_select_first") || Kind == TEXT("prep_toggle_off")
			|| Kind == TEXT("prep_wrong_stage_refused"))
		{
			return FBMJobLifecycle::ChoosePrep(Job, TEXT("p1"));
		}
		if (Kind == TEXT("prep_at_cap_refused"))
		{
			return FBMJobLifecycle::ChoosePrep(Job, TEXT("p4"));
		}
		if (Kind == TEXT("prep_at_cap_toggle_off_allowed"))
		{
			return FBMJobLifecycle::ChoosePrep(Job, TEXT("p2"));
		}
		if (Kind == TEXT("prep_unknown_id_refused"))
		{
			return FBMJobLifecycle::ChoosePrep(Job, TEXT("nope"));
		}
		if (Kind == TEXT("approach_unknown_id_refused"))
		{
			return FBMJobLifecycle::ChooseApproach(Job, TEXT("nope"));
		}
		if (Kind.StartsWith(TEXT("approach_")))
		{
			return FBMJobLifecycle::ChooseApproach(Job, TEXT("a1"));
		}
		if (Kind == TEXT("coverup_atomic_to_resolved"))
		{
			// The extractor sets the approach inside the call lambda; mirror that here.
			Job.ChosenApproach = TEXT("a1");
			return FBMJobLifecycle::ChooseCoverup(Job, TEXT("c1"));
		}
		if (Kind == TEXT("coverup_unknown_id_refused"))
		{
			return FBMJobLifecycle::ChooseCoverup(Job, TEXT("nope"));
		}
		if (Kind.StartsWith(TEXT("coverup_")))
		{
			return FBMJobLifecycle::ChooseCoverup(Job, TEXT("c1"));
		}
		if (Kind.StartsWith(TEXT("tick_")))
		{
			return FBMJobLifecycle::Tick(Job);
		}

		return false;
	}
}

bool FBMJobLifecycleMatchesGodotVectorsTest::RunTest(const FString&)
{
	TSharedPtr<FJsonObject> Root;
	FString Error;
	if (!LoadJobVectors(Root, Error))
	{
		AddError(Error);
		return false;
	}

	const TArray<TSharedPtr<FJsonValue>>* Rows = LayerRows(Root, TEXT("lifecycle"));
	if (!Rows)
	{
		AddError(TEXT("fixture has no usable 'lifecycle' layer"));
		return false;
	}

	int32 Mismatches = 0;
	int32 AcceptedRows = 0;
	int32 RefusedRows = 0;

	for (const TSharedPtr<FJsonValue>& Value : *Rows)
	{
		const TSharedPtr<FJsonObject> Row = Value->AsObject();
		const FString Kind = Row->GetStringField(TEXT("kind"));

		FBMJob Job = LifecycleProbeJob();
		Job.Stage = static_cast<EBMJobStage>(Row->GetIntegerField(TEXT("stage_before")));

		// The fixture records post-state; the PRE-state is reconstructed from the case
		// table's three shapes, which the kind names unambiguously.
		if (Kind == TEXT("prep_toggle_off") || Kind == TEXT("approach_from_preparation")
			|| Kind == TEXT("coverup_atomic_to_resolved"))
		{
			Job.ChosenPrep = { TEXT("p1") };
		}
		else if (Kind == TEXT("prep_at_cap_refused")
			|| Kind == TEXT("prep_at_cap_toggle_off_allowed"))
		{
			Job.ChosenPrep = { TEXT("p1"), TEXT("p2"), TEXT("p3") };
		}

		// Only the tick rows move ticks_remaining, and only when they are not refused.
		{
			const int32 After = Row->GetIntegerField(TEXT("ticks_remaining_after"));
			const bool bDecrements = Kind.StartsWith(TEXT("tick_"))
				&& Kind != TEXT("tick_already_resolved_noop");
			Job.TicksRemaining = bDecrements ? After + 1 : After;
		}

		const bool bExpectedAccepted = Row->GetBoolField(TEXT("accepted"));
		const bool bAccepted = RunLifecycleCall(Kind, Job);

		bExpectedAccepted ? ++AcceptedRows : ++RefusedRows;

		// Acceptance is a DECISION — exact.
		if (bAccepted != bExpectedAccepted && ++Mismatches <= MaxReportedMismatches)
		{
			AddError(FString::Printf(
				TEXT("%s: accepted expected %d, got %d"),
				*Kind, bExpectedAccepted ? 1 : 0, bAccepted ? 1 : 0));
		}

		// THE point of the refusal rows: a guard that returns false AFTER mutating would
		// pass on the bool alone. The post-state is what catches it.
		const int32 ExpectedStage = Row->GetIntegerField(TEXT("stage_after"));
		if (static_cast<int32>(Job.Stage) != ExpectedStage
			&& ++Mismatches <= MaxReportedMismatches)
		{
			AddError(FString::Printf(
				TEXT("%s: stage_after expected %d, got %d — a refusal must not move the stage, and the cover-up must land on RESOLVED, not COVER_UP"),
				*Kind, ExpectedStage, static_cast<int32>(Job.Stage)));
		}

		const TArray<FString> ExpectedPrep = StringArray(Row, TEXT("chosen_prep_after"));
		if (Job.ChosenPrep != ExpectedPrep && ++Mismatches <= MaxReportedMismatches)
		{
			AddError(FString::Printf(
				TEXT("%s: chosen_prep_after expected [%s], got [%s]"),
				*Kind, *FString::Join(ExpectedPrep, TEXT(",")),
				*FString::Join(Job.ChosenPrep, TEXT(","))));
		}

		const FString ExpectedApproach = Row->GetStringField(TEXT("chosen_approach_after"));
		if (Job.ChosenApproach != ExpectedApproach && ++Mismatches <= MaxReportedMismatches)
		{
			AddError(FString::Printf(
				TEXT("%s: chosen_approach_after expected \"%s\", got \"%s\""),
				*Kind, *ExpectedApproach, *Job.ChosenApproach));
		}

		const FString ExpectedCoverup = Row->GetStringField(TEXT("chosen_coverup_after"));
		if (Job.ChosenCoverup != ExpectedCoverup && ++Mismatches <= MaxReportedMismatches)
		{
			AddError(FString::Printf(
				TEXT("%s: chosen_coverup_after expected \"%s\", got \"%s\""),
				*Kind, *ExpectedCoverup, *Job.ChosenCoverup));
		}

		const int32 ExpectedTicks = Row->GetIntegerField(TEXT("ticks_remaining_after"));
		if (Job.TicksRemaining != ExpectedTicks && ++Mismatches <= MaxReportedMismatches)
		{
			AddError(FString::Printf(
				TEXT("%s: ticks_remaining_after expected %d, got %d — a resolved job's counter must STOP, not keep decrementing"),
				*Kind, ExpectedTicks, Job.TicksRemaining));
		}

		// Where the row carries an outcome, compare all nine dimensions.
		const TSharedPtr<FJsonObject>* ExpectedOutcome = nullptr;
		if (Row->TryGetObjectField(TEXT("outcome_after"), ExpectedOutcome)
			&& ExpectedOutcome && (*ExpectedOutcome)->Values.Num() > 0)
		{
			for (const FString& Dimension : FBMJobOutcome::DimensionNames())
			{
				const float ExpectedValue =
					static_cast<float>((*ExpectedOutcome)->GetNumberField(Dimension));
				const float* ActualValue = Job.Outcome.FindByName(Dimension);
				if (ActualValue && !FMath::IsNearlyEqual(*ActualValue, ExpectedValue, JobTolerance)
					&& ++Mismatches <= MaxReportedMismatches)
				{
					AddError(FString::Printf(
						TEXT("%s: outcome.%s expected %g, got %g"),
						*Kind, *Dimension, ExpectedValue, *ActualValue));
				}
			}

			if (!Job.Outcome.bResolved && ++Mismatches <= MaxReportedMismatches)
			{
				AddError(FString::Printf(
					TEXT("%s: the row carries an outcome but bResolved is false"), *Kind));
			}
		}
	}

	AddInfo(FString::Printf(TEXT("lifecycle: %d accepted, %d refused rows"),
		AcceptedRows, RefusedRows));

	if (Mismatches > 0)
	{
		AddError(FString::Printf(
			TEXT("S3 GATE FAILED — %d lifecycle mismatch(es). See Docs/gates/S3.md."),
			Mismatches));
		return false;
	}

	return true;
}
```

> **On the pre-state reconstruction above.** The fixture records `chosen_prep_after` and
> `ticks_remaining_after` but not the "before" values, so the test re-derives them from the row
> kind, exactly as the extractor's case table set them. **If you extend the extractor's
> `_lifecycle_cases()`, extend `RunLifecycleCall` and this block in the same commit** — a new row
> the dispatcher does not recognize falls through to `return false` and compares a job nothing
> touched, which reads as a pass. If that coupling proves fragile in practice, the honest fix is to
> add explicit `chosen_prep_before` / `ticks_remaining_before` fields to the extractor, not to
> loosen this test.

- [ ] **Step 2: Run it to verify it fails**

Run:
```sh
"C:/Program Files/Epic Games/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" \
    D:/black-meridian-ue/BlackMeridian.uproject \
    -ExecCmds="Automation RunTests BM.Jobs; Quit" -unattended -nopause -nullrhi -nosplash -NoLiveCoding \
    -testexit="Automation Test Queue Empty"
```
Expected: build failure, `fatal error C1083: Cannot open include file: 'BMJobLifecycle.h'`.

- [ ] **Step 3: Implement**

Create `D:\black-meridian-ue\Source\BMCore\Public\BMJobLifecycle.h`:

```cpp
#pragma once

#include "BMJobTypes.h"
#include "BMTypes.h"
#include "CoreMinimal.h"

/**
 * The pure stage machine plus outcome application for fixer jobs (brief §7.5), ported from
 * src/jobs/job_lifecycle.gd.
 *
 *   Intake -> Preparation (<= JobMaxPrepActions) -> Intervention (one approach)
 *          -> Cover-up (one story) -> Resolved
 *
 * Static and state-free, with no campaign reference: FBMJobDirector wires this to the world.
 * Every transition is GUARDED, every guard returns false, and every guard runs BEFORE any
 * mutation — a port that returns false after writing the stage passes a bool-only test and
 * fails the fixture's post-state.
 *
 * Measured against Tests/Golden/job_vectors.json (`lifecycle`) — GV-JOB-03.
 */
struct BMCORE_API FBMJobLifecycle
{
	/** INTAKE -> PREPARATION. The player has reviewed the situation and taken the job.
	 *  `[V]` Refused from any other stage, including RESOLVED. */
	static bool Begin(FBMJob& Job);

	/**
	 * Toggle-select a preparation action while in PREPARATION.
	 *
	 * `[V]` The ORDER of the gates is behavior: wrong stage -> false; unknown id -> false;
	 * ALREADY CHOSEN -> erase and return true; at the cap -> false; else append. Because the
	 * erase branch sits ABOVE the cap check, deselecting while at three is allowed while
	 * selecting a fourth is refused. Swapping those two silently locks the player out of
	 * changing their mind.
	 */
	static bool ChoosePrep(FBMJob& Job, const FString& ChoiceId);

	/** PREPARATION -> INTERVENTION. Locks one approach. `[V]` One-way: there is no
	 *  un-choosing an approach, unlike a prep action. */
	static bool ChooseApproach(FBMJob& Job, const FString& ChoiceId);

	/**
	 * INTERVENTION -> COVER_UP -> RESOLVED, in ONE call.
	 *
	 * `[V]` ATOMIC, deliberately. The job passes THROUGH CoverUp — the stage is written, the
	 * outcome resolved, then the stage written again to Resolved before returning. A port
	 * that stops at CoverUp and waits for a second call has invented a stage the player can
	 * sit in, and any save taken there restores into a state the oracle never produces.
	 *
	 * Effects are applied by the CALLER (FBMJobDirector), which is what keeps this function
	 * free of any world reference.
	 */
	static bool ChooseCoverup(FBMJob& Job, const FString& ChoiceId);

	/**
	 * Deadline tick. Returns true on the tick the job JUST expired.
	 *
	 * `[V]` The resolved check comes FIRST, before the decrement — a resolved job's counter
	 * stops moving entirely. The expiry test is `TicksRemaining > 0` AFTER the decrement, so
	 * a job at 1 expires on this tick and a job at 5 does not. Decrementing before the
	 * resolved check drifts every counter in the save by one per tick.
	 */
	static bool Tick(FBMJob& Job);

	/**
	 * Apply a resolved job's outcome to strategic state (brief §7.5: consequences flow back
	 * into cash, heat, fear, relationships).
	 *
	 * `[V]` Returns early on an UNRESOLVED outcome — the `out.is_empty()` guard. An all-zero
	 * RESOLVED outcome is NOT unresolved and DOES apply; it simply fails the reward gate.
	 *
	 * `[V]` The reward gate is `ObjectiveAchieved >= 0.5`, inclusive. Exactly 0.5 pays.
	 *
	 * `[V]` EvidenceGenerated is a single SIGNED net axis (the P06 decision, recorded in
	 * job_lifecycle.gd): net trace left is exactly what police attention responds to, so a
	 * suppressed job LOWERS heat and erodes a case, while an exposed one raises heat and
	 * deposits one. Do not split it into production and suppression.
	 *
	 * RivalSuspicion / NewLeverage / DelayedConsequence stay recorded on the outcome for the
	 * director's branches; this function does not consume them.
	 *
	 * @param Tick stamps the id of any evidence case the outcome deposits.
	 */
	static void ApplyOutcome(const FBMJob& Job, FBMFactionState& Faction,
		FBMDistrictState* District, int32 Tick);
};
```

Create `D:\black-meridian-ue\Source\BMCore\Private\BMJobLifecycle.cpp`:

```cpp
#include "BMJobLifecycle.h"

#include "BMConstants.h"
#include "BMEvidence.h"
#include "BMJobResolution.h"

bool FBMJobLifecycle::Begin(FBMJob& Job)
{
	if (Job.Stage != EBMJobStage::Intake)
	{
		return false;
	}
	Job.Stage = EBMJobStage::Preparation;
	return true;
}

bool FBMJobLifecycle::ChoosePrep(FBMJob& Job, const FString& ChoiceId)
{
	if (Job.Stage != EBMJobStage::Preparation)
	{
		return false;
	}
	if (FBMJob::FindChoice(Job.PrepActions, ChoiceId) == INDEX_NONE)
	{
		return false;
	}

	// `[V]` The toggle-off branch sits ABOVE the cap check, so deselecting at the cap is
	// allowed while selecting a fourth is refused. Swapping these locks the player in.
	if (Job.ChosenPrep.Contains(ChoiceId))
	{
		Job.ChosenPrep.Remove(ChoiceId);
		return true;
	}

	if (Job.ChosenPrep.Num() >= BMConst::JobMaxPrepActions)
	{
		return false;
	}

	Job.ChosenPrep.Add(ChoiceId);
	return true;
}

bool FBMJobLifecycle::ChooseApproach(FBMJob& Job, const FString& ChoiceId)
{
	if (Job.Stage != EBMJobStage::Preparation)
	{
		return false;
	}
	if (FBMJob::FindChoice(Job.Approaches, ChoiceId) == INDEX_NONE)
	{
		return false;
	}

	Job.ChosenApproach = ChoiceId;
	Job.Stage = EBMJobStage::Intervention;
	return true;
}

bool FBMJobLifecycle::ChooseCoverup(FBMJob& Job, const FString& ChoiceId)
{
	if (Job.Stage != EBMJobStage::Intervention)
	{
		return false;
	}
	if (FBMJob::FindChoice(Job.Coverups, ChoiceId) == INDEX_NONE)
	{
		return false;
	}

	// `[V]` ATOMIC. The job passes THROUGH CoverUp; it never rests there. Resolve happens
	// between the two stage writes, exactly as job_lifecycle.gd does it.
	Job.ChosenCoverup = ChoiceId;
	Job.Stage = EBMJobStage::CoverUp;
	Job.Outcome = FBMJobResolution::Resolve(Job);
	Job.Stage = EBMJobStage::Resolved;
	return true;
}

bool FBMJobLifecycle::Tick(FBMJob& Job)
{
	// `[V]` The resolved check comes FIRST — a resolved job's counter stops moving.
	if (Job.Stage == EBMJobStage::Resolved)
	{
		return false;
	}

	--Job.TicksRemaining;
	if (Job.TicksRemaining > 0)
	{
		return false;
	}

	Job.Outcome = FBMJobResolution::Expired();
	Job.Stage = EBMJobStage::Resolved;
	return true;
}

void FBMJobLifecycle::ApplyOutcome(const FBMJob& Job, FBMFactionState& Faction,
	FBMDistrictState* District, int32 Tick)
{
	const FBMJobOutcome& Out = Job.Outcome;

	// `[V]` `out.is_empty()` — never resolved, nothing to apply. An all-zero RESOLVED
	// outcome is a different thing and falls through to the gates below.
	if (!Out.bResolved)
	{
		return;
	}

	// `[V]` Inclusive: exactly 0.5 pays.
	if (Out.ObjectiveAchieved >= 0.5f)
	{
		Faction.DirtyCash += Job.RewardDirty;
	}

	if (District != nullptr)
	{
		// `[V]` The signed evidence axis drives heat directly — a suppressed job (negative)
		// legitimately LOWERS heat. The P06 decision: net trace IS the model, no split.
		District->LocalHeat = FMath::Clamp(
			District->LocalHeat + 0.08f * Out.EvidenceGenerated + 0.04f * Out.PublicFear,
			0.0f, 1.0f);
		District->Fear = FMath::Clamp(District->Fear + 0.1f * Out.PublicFear, 0.0f, 1.0f);

		// `[V]` P06b: the SAME signed axis also acts on DISCRETE state, additively to the
		// heat line above — never as a replacement. Net trace deposits a persistent case;
		// net suppression erodes the strongest one. Exactly 0.0 does neither.
		if (Out.EvidenceGenerated > 0.0f)
		{
			FBMEvidence::Deposit(*District, Out.EvidenceGenerated, Job.Id, Tick);
		}
		else if (Out.EvidenceGenerated < 0.0f)
		{
			FBMEvidence::ErodeStrongest(*District, -Out.EvidenceGenerated);
		}
	}

	// The involved-character arm of job_lifecycle.gd (public_trust, grievance) has no
	// counterpart in the port yet: BMTypes.h carries districts, venues, factions and
	// evidence cases only — there is no FBMCharacterState. It arrives with the relationship
	// layer, and this signature takes no character list until it does. Recorded here rather
	// than stubbed, so nobody mistakes an omission for a decision.
}
```

> **Explicitly not determinable from the sources read:** the port has **no character state type**.
> `job_lifecycle.gd::apply_outcome` also walks `involved: Array[CharacterData]` and writes
> `public_trust` and `grievance`. `BMTypes.h` has no `FBMCharacterState` and `FBMCampaignState` has
> no character array, so that arm cannot be ported in S3 without inventing a type the plan has not
> specified. **Decision for the executing engineer: leave it out, record it in `Docs/gates/S3.md`
> as deferred to the slice that introduces characters, and do NOT invent the struct here.** The
> fixture's lifecycle layer does not cover it either — the extractor drives `JobLifecycle` without
> characters — so nothing in the gate goes vacuous as a result.

- [ ] **Step 4: Run to verify it passes**

Run:
```sh
"C:/Program Files/Epic Games/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" \
    D:/black-meridian-ue/BlackMeridian.uproject \
    -ExecCmds="Automation RunTests BM.Jobs; Quit" -unattended -nopause -nullrhi -nosplash -NoLiveCoding \
    -testexit="Automation Test Queue Empty"
```
Expected:
```
BM.Jobs.EnumValuesAreSaveContract                  Result={Success}
BM.Jobs.IdParseContract                            Result={Success}   19 rows through the parser
BM.Jobs.IdParserIsSingleImplementation             Result={Success}
BM.Jobs.LifecycleMatchesGodotVectors               Result={Success}   8 accepted, 11 refused rows
BM.Jobs.ResolutionMatchesGodotVectors              Result={Success}   7 resolve rows + expired + blank
**** TEST COMPLETE. EXIT CODE: 0 ****              5/5 · 0 fail · 0 errors
```

- [ ] **Step 5: Commit**

```bash
cd /d/black-meridian-ue
git add Source/BMCore/Public/BMJobLifecycle.h Source/BMCore/Private/BMJobLifecycle.cpp Source/BMCore/Private/BMJobTest.cpp
git commit -m "feat(s3): BMJobLifecycle — the stage machine, guards and all

Three behaviors the fixture pins because a happy-path test misses all three:
the cover-up call is ATOMIC (INTERVENTION -> COVER_UP -> RESOLVED in one
call, outcome resolved on the way through), Tick returns before decrementing
on a resolved job, and the prep cap exempts toggle-off because the erase
branch sits above the cap check.

Every guard runs before any mutation, and the refusal rows compare post-state
rather than the bool alone.

ApplyOutcome's involved-character arm is deferred: the port has no character
state type yet. Recorded in the source, not stubbed.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: `BMJobTemplates` — authored content as C++ tables

Six authored builders, three of them with two variants each. This is the most transcription-heavy
task in S3: a faithful copy of `job_templates.gd`'s text, choice ids and effect numbers into C++
tables.

Two rules make it safe:

- **The effect numbers are mechanics, not flavour.** The oracle's `test_evidence` reads exact
  per-choice values (the P06d balance envelope: the loudest full lifecycle nets `>= +0.25` evidence,
  the quietest `<= -0.3`), and the two `bury_case` variants are **byte-identical in effects** on
  purpose — variant 1 differs in reading experience only. A "tidied" number is a balance change
  wearing a refactor's clothes.
- **The choice-id SET is shared across variants of an origin**, so a saved `ChosenPrep` /
  `ChosenApproach` / `ChosenCoverup` stays valid whichever variant the hash lands on.

**This layer moves to Data Assets in S14** (`07` → S14: authored content becomes `UDataAsset` /
`DataTable` so designers can retune without a recompile). Writing it as C++ tables now is
deliberate: S3's job is behavioral equivalence, and a data-asset pipeline would add an authoring
surface the gate cannot measure. Keep the tables mechanical so the S14 conversion stays a
transcription rather than a redesign.

**Files:**
- Create: `D:\black-meridian-ue\Source\BMCore\Public\BMJobTemplates.h`
- Create: `D:\black-meridian-ue\Source\BMCore\Private\BMJobTemplates.cpp`
- Test: `D:\black-meridian-ue\Source\BMCore\Private\BMJobBehaviorTest.cpp`

- [ ] **Step 1: Write the failing test**

Create `D:\black-meridian-ue\Source\BMCore\Private\BMJobBehaviorTest.cpp`:

```cpp
#include "BMConstants.h"
#include "BMJobResolution.h"
#include "BMJobTemplates.h"
#include "BMJobTypes.h"

#include "CoreMinimal.h"
#include "Misc/AutomationTest.h"

/**
 * S3 behavior tests — the invariants that are NOT golden-vector comparisons.
 *
 * Split from BMJobTest.cpp deliberately: a fixture mismatch and a behavior regression are
 * different investigations. Same reasoning that kept hash_vectors.json and sim_vectors.json
 * apart in S1/S2.
 */

namespace
{
	/** One choice's contribution to one dimension, for envelope checks. 0 if absent. */
	float PoolEffect(const TArray<FBMJobChoice>& Pool, const FString& ChoiceId,
		const FString& Dimension)
	{
		const int32 Index = FBMJob::FindChoice(Pool, ChoiceId);
		if (Index == INDEX_NONE)
		{
			return 0.0f;
		}
		for (const FBMJobEffect& Effect : Pool[Index].Effects)
		{
			if (Effect.Dimension == Dimension)
			{
				return Effect.Value;
			}
		}
		return 0.0f;
	}

	/** The ids present in one pool, sorted — variants of an origin must agree on this set. */
	TArray<FString> ChoiceIds(const TArray<FBMJobChoice>& Pool)
	{
		TArray<FString> Ids;
		for (const FBMJobChoice& Choice : Pool)
		{
			Ids.Add(Choice.Id);
		}
		Ids.Sort();
		return Ids;
	}
}

// ---------------------------------------------------------------------------
// BM.Jobs.VariantsShareChoiceIds
// ---------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FBMJobVariantsShareChoiceIdsTest,
	"BM.Jobs.VariantsShareChoiceIds",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FBMJobVariantsShareChoiceIdsTest::RunTest(const FString&)
{
	// `[V]` The variant contract from job_templates.gd: both variants of an origin share one
	// choice-id set, so a saved chosen_prep / chosen_approach / chosen_coverup stays valid
	// whichever variant the hash lands on. Break this and a load silently drops the player's
	// choices — no crash, no message, a different outcome.
	{
		const FBMJob V0 = FBMJobTemplates::Retaliation(TEXT("Cargo Terminal"), TEXT("Corvine"), 0);
		const FBMJob V1 = FBMJobTemplates::Retaliation(TEXT("Cargo Terminal"), TEXT("Corvine"), 1);

		TestEqual(TEXT("retaliation prep ids match across variants"),
			ChoiceIds(V0.PrepActions), ChoiceIds(V1.PrepActions));
		TestEqual(TEXT("retaliation approach ids match across variants"),
			ChoiceIds(V0.Approaches), ChoiceIds(V1.Approaches));
		TestEqual(TEXT("retaliation coverup ids match across variants"),
			ChoiceIds(V0.Coverups), ChoiceIds(V1.Coverups));

		// Different reading experience, same spine.
		TestNotEqual(TEXT("the two retaliation variants are actually different jobs"),
			V0.Title, V1.Title);
		TestEqual(TEXT("retaliation v0 carries RivalProvocation"),
			static_cast<int32>(V0.Origin), static_cast<int32>(EBMJobOrigin::RivalProvocation));
		TestEqual(TEXT("retaliation v1 carries RivalProvocation"),
			static_cast<int32>(V1.Origin), static_cast<int32>(EBMJobOrigin::RivalProvocation));
	}

	{
		const FBMJob V0 = FBMJobTemplates::ContestedGround(TEXT("Cargo Terminal"), TEXT("Corvine"), 0);
		const FBMJob V1 = FBMJobTemplates::ContestedGround(TEXT("Cargo Terminal"), TEXT("Corvine"), 1);

		TestEqual(TEXT("contested prep ids match across variants"),
			ChoiceIds(V0.PrepActions), ChoiceIds(V1.PrepActions));
		TestEqual(TEXT("contested approach ids match across variants"),
			ChoiceIds(V0.Approaches), ChoiceIds(V1.Approaches));
		TestEqual(TEXT("contested coverup ids match across variants"),
			ChoiceIds(V0.Coverups), ChoiceIds(V1.Coverups));
		TestEqual(TEXT("contested variants carry TerritoryLoss"),
			static_cast<int32>(V0.Origin), static_cast<int32>(EBMJobOrigin::TerritoryLoss));
	}

	{
		const FBMJob V0 = FBMJobTemplates::BuryCase(TEXT("Unfiled manifest"), TEXT("Glass Wharf"), 0);
		const FBMJob V1 = FBMJobTemplates::BuryCase(TEXT("Unfiled manifest"), TEXT("Glass Wharf"), 1);

		TestEqual(TEXT("bury_case prep ids match across variants"),
			ChoiceIds(V0.PrepActions), ChoiceIds(V1.PrepActions));
		TestEqual(TEXT("bury_case variants carry EvidenceChain"),
			static_cast<int32>(V0.Origin), static_cast<int32>(EBMJobOrigin::EvidenceChain));

		// `[V]` bury_case is the STRICTER contract: its two variants have BYTE-IDENTICAL
		// effects, because the burn/botch math reads exact per-choice numbers. Only the text
		// differs. The other two origins may differ in magnitude; this one may not.
		const TCHAR* Approaches[] = { TEXT("appr_torch"), TEXT("appr_custodian"), TEXT("appr_snatch") };
		for (const TCHAR* ChoiceId : Approaches)
		{
			TestEqual(FString::Printf(TEXT("bury_case %s objective identical across variants"), ChoiceId),
				PoolEffect(V0.Approaches, ChoiceId, TEXT("objective_achieved")),
				PoolEffect(V1.Approaches, ChoiceId, TEXT("objective_achieved")));
			TestEqual(FString::Printf(TEXT("bury_case %s evidence identical across variants"), ChoiceId),
				PoolEffect(V0.Approaches, ChoiceId, TEXT("evidence_generated")),
				PoolEffect(V1.Approaches, ChoiceId, TEXT("evidence_generated")));
		}
	}

	// `[V]` An out-of-range variant index falls back to variant 0, mirroring the GDScript's
	// `if variant == 1: ... return <variant 0>`. Not defensiveness — the generator's modulo
	// makes it unreachable today, and the fallback is what the oracle does.
	TestEqual(TEXT("variant 7 falls back to variant 0"),
		FBMJobTemplates::Retaliation(TEXT("V"), TEXT("R"), 7).Title,
		FBMJobTemplates::Retaliation(TEXT("V"), TEXT("R"), 0).Title);

	return true;
}

// ---------------------------------------------------------------------------
// BM.Jobs.TemplatesHonorBalanceEnvelope
// ---------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FBMJobTemplatesBalanceEnvelopeTest,
	"BM.Jobs.TemplatesHonorBalanceEnvelope",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FBMJobTemplatesBalanceEnvelopeTest::RunTest(const FString&)
{
	// `[V]` The P06d envelope, guarded in the oracle by test_evidence and stated in the
	// variant-contract comments in job_templates.gd: for retaliation and contested, the
	// LOUDEST full lifecycle must net >= +0.25 evidence (a visible reprisal leaves a trail,
	// which is what feeds the police line) and the QUIETEST must net <= -0.3 (a careful
	// answer keeps you clean). Without this, a retuned number can quietly sever the feud
	// from the heat system and nothing else would notice.
	struct FEnvelopeCase
	{
		const TCHAR* Name;
		FBMJob Job;
		const TCHAR* LoudApproach;
		const TCHAR* LoudCoverup;
		const TCHAR* QuietPrep;
		const TCHAR* QuietApproach;
		const TCHAR* QuietCoverup;
	};

	TArray<FEnvelopeCase> Cases = {
		{ TEXT("retaliation v0"),
		  FBMJobTemplates::Retaliation(TEXT("Cargo Terminal"), TEXT("Corvine"), 0),
		  TEXT("appr_mirror"), TEXT("cover_flaunt"),
		  TEXT("prep_stage_alibis"), TEXT("appr_absorb"), TEXT("cover_deny") },
		{ TEXT("retaliation v1"),
		  FBMJobTemplates::Retaliation(TEXT("Cargo Terminal"), TEXT("Corvine"), 1),
		  TEXT("appr_mirror"), TEXT("cover_flaunt"),
		  TEXT("prep_stage_alibis"), TEXT("appr_absorb"), TEXT("cover_deny") },
		{ TEXT("contested v0"),
		  FBMJobTemplates::ContestedGround(TEXT("Cargo Terminal"), TEXT("Corvine"), 0),
		  TEXT("appr_evict"), TEXT("cover_flaunt"),
		  TEXT("prep_stage"), TEXT("appr_rot"), TEXT("cover_deny") },
		{ TEXT("contested v1"),
		  FBMJobTemplates::ContestedGround(TEXT("Cargo Terminal"), TEXT("Corvine"), 1),
		  TEXT("appr_evict"), TEXT("cover_flaunt"),
		  TEXT("prep_stage"), TEXT("appr_rot"), TEXT("cover_deny") },
	};

	for (FEnvelopeCase& Case : Cases)
	{
		{
			FBMJob Loud = Case.Job;
			Loud.ChosenApproach = Case.LoudApproach;
			Loud.ChosenCoverup = Case.LoudCoverup;
			const FBMJobOutcome Out = FBMJobResolution::Resolve(Loud);
			if (Out.EvidenceGenerated < 0.25f)
			{
				AddError(FString::Printf(
					TEXT("%s: the loudest lifecycle nets %g evidence, below the +0.25 floor — a visible reprisal must leave a trail"),
					Case.Name, Out.EvidenceGenerated));
			}
		}

		{
			FBMJob Quiet = Case.Job;
			Quiet.ChosenPrep = { Case.QuietPrep };
			Quiet.ChosenApproach = Case.QuietApproach;
			Quiet.ChosenCoverup = Case.QuietCoverup;
			const FBMJobOutcome Out = FBMJobResolution::Resolve(Quiet);
			if (Out.EvidenceGenerated > -0.3f)
			{
				AddError(FString::Printf(
					TEXT("%s: the quietest lifecycle nets %g evidence, above the -0.3 ceiling — a careful answer must keep you clean"),
					Case.Name, Out.EvidenceGenerated));
			}
		}
	}

	// `[V]` The bury_case burn: a clean resolution nets strongly NEGATIVE evidence (the
	// targeted case burns — the director removes it), while the clumsy route nets POSITIVE
	// on every cover-up (a botched burn leaves more trace than it removes, and the case
	// stands). That sign flip IS the mechanic; the EvidenceChain branch keys on it.
	for (int32 Variant = 0; Variant < 2; ++Variant)
	{
		FBMJob Clean = FBMJobTemplates::BuryCase(TEXT("Unfiled manifest"), TEXT("Glass Wharf"), Variant);
		Clean.ChosenApproach = TEXT("appr_torch");
		Clean.ChosenCoverup = TEXT("cover_never_was");
		const FBMJobOutcome CleanOut = FBMJobResolution::Resolve(Clean);
		if (CleanOut.EvidenceGenerated >= 0.0f)
		{
			AddError(FString::Printf(
				TEXT("bury_case v%d: the clean burn nets %g — it must be negative or the targeted case never burns"),
				Variant, CleanOut.EvidenceGenerated));
		}

		FBMJob Botched = FBMJobTemplates::BuryCase(TEXT("Unfiled manifest"), TEXT("Glass Wharf"), Variant);
		Botched.ChosenApproach = TEXT("appr_snatch");
		Botched.ChosenCoverup = TEXT("cover_walk");
		const FBMJobOutcome BotchedOut = FBMJobResolution::Resolve(Botched);
		if (BotchedOut.EvidenceGenerated <= 0.0f)
		{
			AddError(FString::Printf(
				TEXT("bury_case v%d: the botched burn nets %g — it must be positive, so the case stands and fresh trace is deposited"),
				Variant, BotchedOut.EvidenceGenerated));
		}
	}

	return true;
}
```

- [ ] **Step 2: Run it to verify it fails**

Run:
```sh
"C:/Program Files/Epic Games/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" \
    D:/black-meridian-ue/BlackMeridian.uproject \
    -ExecCmds="Automation RunTests BM.Jobs; Quit" -unattended -nopause -nullrhi -nosplash -NoLiveCoding \
    -testexit="Automation Test Queue Empty"
```
Expected: build failure, `fatal error C1083: Cannot open include file: 'BMJobTemplates.h'`.

- [ ] **Step 3: Implement**

Create `D:\black-meridian-ue\Source\BMCore\Public\BMJobTemplates.h`:

```cpp
#pragma once

#include "BMJobTypes.h"
#include "CoreMinimal.h"

/**
 * The authored job-template layer (brief §7.5), ported from src/jobs/job_templates.gd.
 *
 * Each builder supplies the AUTHORED fields — text, choices, reward, deadline — and leaves
 * runtime state default. A generated job is a template plus sim-derived targeting stamped on
 * by FBMJobGenerator; it never invents content the template did not author.
 *
 * ⚠️ The effect NUMBERS below are mechanics, not flavour. The oracle's test_evidence reads
 * exact per-choice values (the P06d envelope: the loudest full lifecycle nets >= +0.25
 * evidence, the quietest <= -0.3), and the two bury_case variants are byte-identical in
 * effects on purpose. Retuning a value here is a balance change wearing a refactor's
 * clothes; BM.Jobs.TemplatesHonorBalanceEnvelope is what notices.
 *
 * ⚠️ Both variants of an origin share ONE choice-id set, so a saved ChosenPrep /
 * ChosenApproach / ChosenCoverup stays valid whichever variant the hash lands on.
 * BM.Jobs.VariantsShareChoiceIds guards it.
 *
 * `[S14]` This layer moves to Data Assets — `07` → S14 converts authored content to
 * UDataAsset/DataTable so designers can edit without a recompile. It is C++ here on purpose:
 * S3's job is behavioral equivalence, and an authoring pipeline adds a surface the gate
 * cannot measure. Keep these tables mechanical so that conversion stays a transcription.
 */
struct BMCORE_API FBMJobTemplates
{
	// `[V]` Variant counts per origin. FBMJobGenerator picks the index deterministically
	// (avalanche of the id string, mod count) — never stored, always recomputed.
	static constexpr int32 RetaliationVariants = 2;
	static constexpr int32 BuryCaseVariants    = 2;
	static constexpr int32 ContestedVariants   = 2;

	/** Rebuild an AUTHORED job by id (saves store runtime state only). Returns false for an
	 *  id this registry does not know — generated ids go to FBMJobGenerator::Rebuild. */
	static bool ById(const FString& JobId, FBMJob& OutJob);

	/** The one hand-authored job in the slice. Tied to gw_contraband in the world seed. */
	static FBMJob InterceptedShipment();

	/** Rival SABOTAGE landed on a player venue. `[V]` Variant 0 = "Answer in Kind" (the
	 *  street expects symmetry), 1 = "The Message" (a colder, surgical demonstration).
	 *  Anything else falls back to 0, mirroring the GDScript. */
	static FBMJob Retaliation(const FString& VenueName, const FString& RivalName, int32 Variant);

	/** An inspection landed while a named case pins the district. `[V]` Variant 0 = "Bury the
	 *  Case" (attack the paper), 1 = "Break the Chain" (attack the people who vouch for it).
	 *  The two are byte-identical in EFFECTS — the burn math is the shared spine. */
	static FBMJob BuryCase(const FString& CaseLabel, const FString& DistrictName, int32 Variant);

	/** The rival took ground. `[V]` Variant 0 = "Reclaim the Wharf", 1 = "Starve Them Out". */
	static FBMJob ContestedGround(const FString& VenueName, const FString& RivalName, int32 Variant);

	/** A resolved job's debris surfacing later. `[V]` No variants — one authored job. */
	static FBMJob Followup(const FString& VenueName);
};
```

Create `D:\black-meridian-ue\Source\BMCore\Private\BMJobTemplates.cpp`. Transcribe every builder
from `D:\black-meridian\src\jobs\job_templates.gd`, field for field. The two shown here are the
full pattern — `Retaliation`'s two variants — and the remaining builders follow it exactly:

```cpp
#include "BMJobTemplates.h"

namespace
{
	/** Terse constructors so a table reads like the GDScript it came from. */
	FBMJobChoice Choice(const TCHAR* Id, const TCHAR* Label, const TCHAR* Description,
		TArray<FBMJobEffect> Effects)
	{
		return FBMJobChoice(Id, Label, Description, MoveTemp(Effects));
	}

	FBMJobEffect E(const TCHAR* Dimension, float Value)
	{
		return FBMJobEffect(Dimension, Value);
	}
}

// --- Retaliation, variant 0: "Answer in Kind" -------------------------------
// The hit was public; the street expects symmetry. job_templates.gd:102-150.

static FBMJob RetaliationAnswerInKind(const FString& VenueName, const FString& RivalName)
{
	FBMJob Job;
	Job.Title = TEXT("Answer in Kind");
	Job.Origin = EBMJobOrigin::RivalProvocation;
	Job.ApparentProblem = FString::Printf(
		TEXT("%s crews hit the %s — machinery fouled, a shift boss beaten in front of his people. The street is watching how the Compact answers."),
		*RivalName, *VenueName);
	Job.DeadlineTicks = 60;
	Job.KnownEvidence = {
		TEXT("A wrecker's pry-bar, no serial"),
		TEXT("The shift boss saw the crew's colors"),
	};
	Job.VisibleStakes = TEXT("Answer too soft and every rival reads the Wharf as open. Answer too loud and the city answers back.");
	Job.HiddenStakes = TEXT("The crew was paid through a cutout — the trail doesn't end where it seems to.");
	Job.RewardDirty = 250;

	Job.PrepActions = {
		Choice(TEXT("prep_trace_crew"), TEXT("Trace the crew"),
			TEXT("Follow the pry-bar back through the pawnshops to whoever handed it out."),
			{ E(TEXT("new_leverage"), 0.15f), E(TEXT("evidence_generated"), -0.1f) }),
		Choice(TEXT("prep_stage_alibis"), TEXT("Stage alibis"),
			TEXT("Every name of ours has a paid witness for tonight, whatever happens."),
			{ E(TEXT("evidence_generated"), -0.2f) }),
		Choice(TEXT("prep_answer_tonight"), TEXT("Answer tonight"),
			TEXT("Before the story sets. No time to check whose story it is."),
			{ E(TEXT("delayed_consequence"), 0.2f), E(TEXT("objective_achieved"), 0.1f) }),
	};

	Job.Approaches = {
		Choice(TEXT("appr_mirror"), TEXT("Mirror the damage"),
			TEXT("Their nearest operation loses exactly what yours did. Symmetry is the message."),
			{ E(TEXT("objective_achieved"), 0.7f), E(TEXT("public_fear"), 0.2f),
			  E(TEXT("evidence_generated"), 0.35f), E(TEXT("rival_suspicion"), 0.2f) }),
		Choice(TEXT("appr_feed_inspectors"), TEXT("Feed them to the inspectors"),
			TEXT("A tidy dossier on the crew lands on an honest desk. The law does your hitting."),
			{ E(TEXT("objective_achieved"), 0.6f), E(TEXT("new_leverage"), 0.2f),
			  E(TEXT("evidence_generated"), 0.1f), E(TEXT("rival_suspicion"), 0.1f) }),
		Choice(TEXT("appr_absorb"), TEXT("Absorb the hit"),
			TEXT("Rebuild fast, pay the shift boss triple, and let the calm read as strength."),
			{ E(TEXT("objective_achieved"), 0.4f), E(TEXT("relationship_change"), 0.3f),
			  E(TEXT("new_leverage"), 0.2f) }),
	};

	Job.Coverups = {
		Choice(TEXT("cover_deny"), TEXT("Deny everything"),
			TEXT("The Compact heard about the unpleasantness and hopes the district stays safe."),
			{ E(TEXT("evidence_generated"), -0.3f) }),
		Choice(TEXT("cover_flaunt"), TEXT("Let the street know"),
			TEXT("No names, no proof — but everyone hears who answered and how fast."),
			{ E(TEXT("evidence_generated"), -0.05f), E(TEXT("public_fear"), 0.3f),
			  E(TEXT("delayed_consequence"), 0.2f) }),
		Choice(TEXT("cover_broker"), TEXT("Whisper a truce price"),
			TEXT("A back-channel note: this is what the next one costs. Signed by no one."),
			{ E(TEXT("evidence_generated"), -0.2f), E(TEXT("relationship_change"), 0.2f),
			  E(TEXT("rival_suspicion"), 0.1f) }),
	};

	return Job;
}

// --- Retaliation, variant 1: "The Message" ----------------------------------
// No symmetry, no heat of the moment: one precise demonstration aimed at whoever gave the
// order. Same choice-id set and axis shape as variant 0; magnitudes differ but stay inside
// the P06d envelope. job_templates.gd:156-205.

static FBMJob RetaliationTheMessage(const FString& VenueName, const FString& RivalName)
{
	FBMJob Job;
	Job.Title = TEXT("The Message");
	Job.Origin = EBMJobOrigin::RivalProvocation;
	Job.ApparentProblem = FString::Printf(
		TEXT("%s put a wrecking crew through the %s and made sure it was watched. Symmetry is what they expect. The Resolver's answer should be read twice: once by the street, once by the man who signed the order."),
		*RivalName, *VenueName);
	Job.DeadlineTicks = 60;
	Job.KnownEvidence = {
		TEXT("A payout envelope, wrong district's paper"),
		TEXT("The crew drank two blocks east before the hit"),
	};
	Job.VisibleStakes = TEXT("An answer aimed at the crew punishes the gloves, not the hand. Miss the hand and this happens again, cheaper.");
	Job.HiddenStakes = TEXT("The order was signed by someone auditioning for a bigger chair — the reprisal is their references.");
	Job.RewardDirty = 250;

	Job.PrepActions = {
		Choice(TEXT("prep_trace_crew"), TEXT("Name the paymaster"),
			TEXT("Follow the envelope, not the pry-bar — find who paid, not who swung."),
			{ E(TEXT("new_leverage"), 0.2f), E(TEXT("evidence_generated"), -0.05f) }),
		Choice(TEXT("prep_stage_alibis"), TEXT("Clear the calendar"),
			TEXT("By tonight every name of ours is verifiably, boringly elsewhere."),
			{ E(TEXT("evidence_generated"), -0.2f) }),
		Choice(TEXT("prep_answer_tonight"), TEXT("Send it before dawn"),
			TEXT("A message loses its meaning if it arrives late. Skip the homework."),
			{ E(TEXT("delayed_consequence"), 0.2f), E(TEXT("objective_achieved"), 0.1f) }),
	};

	Job.Approaches = {
		Choice(TEXT("appr_mirror"), TEXT("Make an example"),
			TEXT("Their captain's car burns at noon, in front of his crew. Nobody touched; everybody schooled."),
			{ E(TEXT("objective_achieved"), 0.7f), E(TEXT("public_fear"), 0.3f),
			  E(TEXT("evidence_generated"), 0.35f), E(TEXT("rival_suspicion"), 0.15f) }),
		Choice(TEXT("appr_feed_inspectors"), TEXT("Post the ledger"),
			TEXT("The paymaster's private accounts, photographed page by page, reach an honest desk."),
			{ E(TEXT("objective_achieved"), 0.6f), E(TEXT("new_leverage"), 0.2f),
			  E(TEXT("evidence_generated"), 0.1f), E(TEXT("rival_suspicion"), 0.1f) }),
		Choice(TEXT("appr_absorb"), TEXT("The open window"),
			TEXT("The man who signed the order wakes to an open bedroom window and nothing taken. Nothing needs to be."),
			{ E(TEXT("objective_achieved"), 0.45f), E(TEXT("new_leverage"), 0.25f),
			  E(TEXT("relationship_change"), 0.1f), E(TEXT("evidence_generated"), -0.05f) }),
	};

	Job.Coverups = {
		Choice(TEXT("cover_deny"), TEXT("We were never there"),
			TEXT("Every hand involved is out of the district by morning; the Compact expresses concern."),
			{ E(TEXT("evidence_generated"), -0.3f) }),
		Choice(TEXT("cover_flaunt"), TEXT("Sign the work"),
			TEXT("No proof, no names — but the craftsmanship is unmistakably yours, and meant to be."),
			{ E(TEXT("evidence_generated"), -0.05f), E(TEXT("public_fear"), 0.3f),
			  E(TEXT("delayed_consequence"), 0.2f) }),
		Choice(TEXT("cover_broker"), TEXT("Send the invoice"),
			TEXT("A courier delivers an itemized bill for the damage, payable in territory. No signature."),
			{ E(TEXT("evidence_generated"), -0.2f), E(TEXT("relationship_change"), 0.2f),
			  E(TEXT("rival_suspicion"), 0.1f) }),
	};

	return Job;
}

FBMJob FBMJobTemplates::Retaliation(const FString& VenueName, const FString& RivalName,
	int32 Variant)
{
	// `[V]` `if variant == 1 ... else variant 0` — an out-of-range index falls back to 0.
	// The generator's modulo makes that unreachable today; it is the oracle's shape, kept.
	if (Variant == 1)
	{
		return RetaliationTheMessage(VenueName, RivalName);
	}
	return RetaliationAnswerInKind(VenueName, RivalName);
}

bool FBMJobTemplates::ById(const FString& JobId, FBMJob& OutJob)
{
	if (JobId == TEXT("job_intercepted_shipment"))
	{
		OutJob = InterceptedShipment();
		return true;
	}

	// The oracle falls through to NarrativeJobs.by_id here — the P16 authored chain, which
	// has no port yet and is out of S3 scope. A false return is the honest answer: the
	// registry contract is "try authored, then generated", and an unknown authored id is a
	// legitimate miss, not an error.
	return false;
}
```

**Remaining builders — transcribe with the same pattern, from these exact source ranges:**

| Builder | `job_templates.gd` lines | What is behavior, not style |
|---|---|---|
| `InterceptedShipment` | 28–83 | Origin `FailedRacket`, `VenueId = "gw_contraband"`, `DeadlineTicks = 90`, `RewardDirty = 400`, `InvolvedCharacterIds = {"bengal_lt"}`. **Four** prep actions, not three. |
| `BuryCase` v0 "Bury the Case" | 223–271 | `ApparentProblem` lowercases the case label (`case_label.to_lower()` → `CaseLabel.ToLower()`). `cover_walk` has an **empty** effects list — a real authored choice contributing nothing. |
| `BuryCase` v1 "Break the Chain" | 276–324 | Effects **byte-identical to v0**; only the text differs. |
| `ContestedGround` v0 "Reclaim the Wharf" | 336–385 | `KnownEvidence[0]` interpolates the rival name. Prep ids are `prep_scout / prep_stage / prep_move_now` — **not** retaliation's set. |
| `ContestedGround` v1 "Starve Them Out" | 389–438 | Same ids as v0; `appr_evict` differs from v0 only in `rival_suspicion` (0.15 vs 0.2). |
| `Followup` | 442–489 | Origin `FailedRacket` — **not** a TerritoryLoss or EvidenceChain origin; a follow-up is a fresh failed-racket problem. `DeadlineTicks = 75`, `RewardDirty = 300`, ids `prep_ears / prep_move_stash / prep_hush_fund`, `appr_buy_silence / appr_burn_trail / appr_smaller_truth`, `cover_ledger / cover_rumor / cover_walk_away`. |

Each `BuryCase` / `ContestedGround` builder follows `Retaliation`'s dispatch shape exactly:
`if (Variant == 1) { return <v1>(...); } return <v0>(...);`.

> **Explicitly not determinable from the sources read:** `NarrativeJobs.by_id` — the P16 authored
> chain that `JobTemplates.by_id` falls through to — was not read for this plan and is outside S3's
> scope per the roadmap. Do **not** port it here. If a later slice needs it, it extends `ById`; the
> registry contract is already in place.

- [ ] **Step 4: Run to verify it passes**

Run:
```sh
"C:/Program Files/Epic Games/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" \
    D:/black-meridian-ue/BlackMeridian.uproject \
    -ExecCmds="Automation RunTests BM.Jobs; Quit" -unattended -nopause -nullrhi -nosplash -NoLiveCoding \
    -testexit="Automation Test Queue Empty"
```
Expected:
```
BM.Jobs.EnumValuesAreSaveContract                  Result={Success}
BM.Jobs.IdParseContract                            Result={Success}
BM.Jobs.IdParserIsSingleImplementation             Result={Success}
BM.Jobs.LifecycleMatchesGodotVectors               Result={Success}
BM.Jobs.ResolutionMatchesGodotVectors              Result={Success}
BM.Jobs.TemplatesHonorBalanceEnvelope              Result={Success}
BM.Jobs.VariantsShareChoiceIds                     Result={Success}
**** TEST COMPLETE. EXIT CODE: 0 ****              7/7 · 0 fail · 0 errors
```

- [ ] **Step 5: Commit**

```bash
cd /d/black-meridian-ue
git add Source/BMCore/Public/BMJobTemplates.h Source/BMCore/Private/BMJobTemplates.cpp Source/BMCore/Private/BMJobBehaviorTest.cpp
git commit -m "feat(s3): BMJobTemplates — authored content as C++ tables

Six builders, three with two variants. Transcribed field for field from
job_templates.gd: the effect numbers are mechanics, not flavour, and the
oracle's test_evidence reads exact per-choice values.

Two contracts now guarded by tests rather than comments: both variants of an
origin share one choice-id set (so a saved choice survives whichever variant
the hash picks), and bury_case's two variants are byte-identical in effects
because the burn/botch sign flip IS the mechanic.

This layer moves to Data Assets in S14. C++ here on purpose — S3 measures
behavior, and an authoring pipeline is a surface the gate cannot see.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: `BMJobGenerator` — four builders, `Rebuild`, and the variant pick

This is where the S3 gate condition lives: **a generated job's id round-trips byte-identically
through `Rebuild`**. A generated job is an authored template plus sim-derived targeting, and the id
encodes everything needed to rebuild the content — which is what lets saves store runtime state
only. `Rebuild` re-runs the same builder with the parsed inputs and must return the identical job.

The variant pick reuses `BMHash::VariantIndex` from S1. **Do not write a second avalanche.**
`BM.Determinism.Hash_SingleImplementation` scans for the constants and will fail the build's test
suite if one appears; that guard exists because Godot carried two byte-identical copies with a
comment asking future authors to keep them in sync by hand.

Measured, on 2026-09-18, against the real oracle:

| seed | `String.hash` | avalanche | index (count 2) |
|---|---|---|---|
| `gen@retaliation@gw_contraband@corvine@240` | 712505440 | 1734293227203430138 | 0 |
| `…@241` | 712505441 | 4559747155846262078 | 0 |
| `…@242` | 712505442 | 5857529748973741130 | 0 |
| `…@243` | 712505443 | 4066539097871136215 | **1** |

Note the hash moves by exactly 1 per tick while the avalanche jumps by ~10^18. That contrast is the
whole reason the avalanche exists — and note also that the indices are `0,0,0,1`, **not** an
alternating pattern. A port whose indices read `0,1,0,1` is applying DJB2 without the avalanche and
has silently shipped different text variety.

**Files:**
- Create: `D:\black-meridian-ue\Source\BMCore\Public\BMJobGenerator.h`
- Create: `D:\black-meridian-ue\Source\BMCore\Private\BMJobGenerator.cpp`
- Test: `D:\black-meridian-ue\Source\BMCore\Private\BMJobTest.cpp` (append)

- [ ] **Step 1: Write the failing test**

Append to `D:\black-meridian-ue\Source\BMCore\Private\BMJobTest.cpp` (add
`#include "BMEvidence.h"`, `#include "BMHash.h"`, `#include "BMJobGenerator.h"`,
`#include "BMJobTemplates.h"`):

```cpp
// ---------------------------------------------------------------------------
// BM.Jobs.VariantIndexMatchesGodotVectors — GV-JOB-04
// ---------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FBMJobVariantIndexMatchesGodotVectorsTest,
	"BM.Jobs.VariantIndexMatchesGodotVectors",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

namespace
{
	/**
	 * 64-bit fields are carried as DECIMAL STRINGS in the fixture and must be parsed as
	 * integers. JSON numbers are doubles: every avalanche row here exceeds the 53-bit
	 * mantissa (24 of 24, measured), so reading one as a number rounds it silently and would
	 * fail a CORRECT implementation. A numeric field is therefore a FIXTURE ERROR, not
	 * something to quietly accept — a lost digit must not look like a hash bug. (The S1
	 * lesson, carried forward verbatim.)
	 */
	bool ReadUint64Field(const TSharedPtr<FJsonObject>& Row, const TCHAR* Field, uint64& OutValue)
	{
		const TSharedPtr<FJsonValue> Value = Row->TryGetField(Field);
		if (!Value.IsValid())
		{
			return false;
		}

		FString AsString;
		if (!Value->TryGetString(AsString))
		{
			return false;
		}

		return LexTryParseString(OutValue, *AsString);
	}
}

bool FBMJobVariantIndexMatchesGodotVectorsTest::RunTest(const FString&)
{
	TSharedPtr<FJsonObject> Root;
	FString Error;
	if (!LoadJobVectors(Root, Error))
	{
		AddError(Error);
		return false;
	}

	const TSharedPtr<FJsonObject>* Variant = LayerObject(Root, TEXT("variant"));
	const TArray<TSharedPtr<FJsonValue>>* Rows = LayerRows(Root, TEXT("variant"));
	if (!Variant || !Rows)
	{
		AddError(TEXT("fixture has no usable 'variant' layer"));
		return false;
	}

	// The variant counts are a port contract: the modulus decides which text the player
	// reads, and a mismatched count reads a different variant for the same id forever.
	struct FCountCheck { const TCHAR* Field; int32 Expected; };
	const FCountCheck CountChecks[] = {
		{ TEXT("retaliation_variants"), FBMJobTemplates::RetaliationVariants },
		{ TEXT("bury_case_variants"),   FBMJobTemplates::BuryCaseVariants },
		{ TEXT("contested_variants"),   FBMJobTemplates::ContestedVariants },
	};
	for (const FCountCheck& Check : CountChecks)
	{
		const int32 FixtureValue = (*Variant)->GetIntegerField(Check.Field);
		if (FixtureValue != Check.Expected)
		{
			AddError(FString::Printf(
				TEXT("variant-count drift: fixture %s = %d, port = %d"),
				Check.Field, FixtureValue, Check.Expected));
		}
	}

	int32 Mismatches = 0;
	int32 BigValues = 0;

	for (const TSharedPtr<FJsonValue>& Value : *Rows)
	{
		const TSharedPtr<FJsonObject> Row = Value->AsObject();
		const FString Seed = Row->GetStringField(TEXT("seed"));
		const int32 Count = Row->GetIntegerField(TEXT("count"));
		const int32 ExpectedIndex = Row->GetIntegerField(TEXT("index"));

		// REJECT a numeric field here rather than reading it — see ReadUint64Field.
		uint64 ExpectedHash = 0;
		if (!ReadUint64Field(Row, TEXT("hash"), ExpectedHash))
		{
			AddError(FString::Printf(
				TEXT("row \"%s\": 'hash' must be a decimal STRING — a numeric field would round through a double and fail a correct port"),
				*Seed));
			return false;
		}

		uint64 ExpectedAvalanche = 0;
		if (!ReadUint64Field(Row, TEXT("avalanche"), ExpectedAvalanche))
		{
			AddError(FString::Printf(
				TEXT("row \"%s\": 'avalanche' must be a decimal STRING"), *Seed));
			return false;
		}

		if (ExpectedAvalanche > (1ull << 53))
		{
			++BigValues;
		}

		const uint32 ActualHash = BMHash::StringHash(Seed);
		if (static_cast<uint64>(ActualHash) != ExpectedHash
			&& ++Mismatches <= MaxReportedMismatches)
		{
			AddError(FString::Printf(
				TEXT("StringHash(\"%s\") = %u, expected %llu"), *Seed, ActualHash, ExpectedHash));
			continue;
		}

		const uint64 ActualAvalanche = BMHash::Avalanche(ActualHash);
		if (ActualAvalanche != ExpectedAvalanche && ++Mismatches <= MaxReportedMismatches)
		{
			AddError(FString::Printf(
				TEXT("Avalanche(\"%s\") = %llu, expected %llu"),
				*Seed, ActualAvalanche, ExpectedAvalanche));
		}

		// The index is a DECISION — exact. And it must come out of the SAME entry point the
		// rest of the sim uses; a local reimplementation is what TD-05 forbids.
		const int32 ActualIndex = FBMJobGenerator::VariantIndex(Seed, Count);
		if (ActualIndex != ExpectedIndex && ++Mismatches <= MaxReportedMismatches)
		{
			AddError(FString::Printf(
				TEXT("VariantIndex(\"%s\", %d) = %d, expected %d"),
				*Seed, Count, ActualIndex, ExpectedIndex));
		}
	}

	AddInfo(FString::Printf(
		TEXT("variant: %d rows, %d avalanche values past 2^53 (which is why they are strings)"),
		Rows->Num(), BigValues));

	if (BigValues == 0)
	{
		AddError(TEXT("no avalanche value exceeded 2^53 — the fixture is not exercising the trap it exists for"));
	}

	if (Mismatches > 0)
	{
		AddError(FString::Printf(
			TEXT("S3 GATE FAILED — %d variant mismatch(es). See Docs/gates/S3.md."),
			Mismatches));
		return false;
	}

	return true;
}

// ---------------------------------------------------------------------------
// BM.Jobs.GeneratedIdRoundTrips — the S3 gate condition
// ---------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FBMJobGeneratedIdRoundTripsTest,
	"BM.Jobs.GeneratedIdRoundTrips",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

namespace
{
	/**
	 * The extractor's `_id_world()`, transcribed: one district, one venue, one REAL evidence
	 * case built by the shipped deposit path rather than a hand-written id. Never hand-write
	 * a value the source can produce (the S1/S2 discipline) — the case id format is a parse
	 * contract and transcribing it is exactly how S1 lost a gate.
	 */
	TArray<FBMDistrictState> IdWorld()
	{
		FBMDistrictState District;
		District.Id = TEXT("glasswharf");

		FBMVenueState Venue;
		Venue.Id = TEXT("gw_contraband");
		Venue.Type = EBMVenueType::Racket;
		Venue.OwnerFaction = TEXT("compact");
		District.Venues.Add(MoveTemp(Venue));

		FBMEvidence::Deposit(District, 0.4f, TEXT("seed_job"), 120);

		return TArray<FBMDistrictState>{ MoveTemp(District) };
	}

	TArray<FBMFactionState> IdFactions()
	{
		FBMFactionState Rival;
		Rival.Id = TEXT("corvine");
		return TArray<FBMFactionState>{ MoveTemp(Rival) };
	}
}

bool FBMJobGeneratedIdRoundTripsTest::RunTest(const FString&)
{
	TSharedPtr<FJsonObject> Root;
	FString Error;
	if (!LoadJobVectors(Root, Error))
	{
		AddError(Error);
		return false;
	}

	const TSharedPtr<FJsonObject>* Ids = LayerObject(Root, TEXT("ids"));
	const TArray<TSharedPtr<FJsonValue>>* Rows = LayerRows(Root, TEXT("ids"));
	if (!Ids || !Rows)
	{
		AddError(TEXT("fixture has no usable 'ids' layer"));
		return false;
	}

	TArray<FBMDistrictState> Districts = IdWorld();
	const TArray<FBMFactionState> Factions = IdFactions();

	// The world must produce the SAME case id the oracle's did, or every burycase row below
	// is comparing against a different string.
	const FString ExpectedCaseId = (*Ids)->GetStringField(TEXT("case_id_example"));
	if (Districts[0].EvidenceCases.Num() != 1
		|| Districts[0].EvidenceCases[0].Id != ExpectedCaseId)
	{
		AddError(FString::Printf(
			TEXT("the test world's case id is \"%s\", the oracle's was \"%s\" — FBMEvidence::MakeCaseId and the fixture disagree"),
			Districts[0].EvidenceCases.Num() > 0 ? *Districts[0].EvidenceCases[0].Id : TEXT("<none>"),
			*ExpectedCaseId));
		return false;
	}

	// The follow-up constants are read from the fixture, never re-typed.
	if (!FMath::IsNearlyEqual(
			static_cast<float>((*Ids)->GetNumberField(TEXT("followup_threshold"))),
			BMConst::FollowupThreshold, JobTolerance))
	{
		AddError(TEXT("balance drift: fixture followup_threshold != BMConst::FollowupThreshold"));
	}
	if ((*Ids)->GetIntegerField(TEXT("followup_lead_ticks")) != BMConst::FollowupLeadTicks)
	{
		AddError(TEXT("balance drift: fixture followup_lead_ticks != BMConst::FollowupLeadTicks"));
	}

	int32 Mismatches = 0;
	int32 BuiltRows = 0;
	int32 ProbeRows = 0;

	for (const TSharedPtr<FJsonValue>& Value : *Rows)
	{
		const TSharedPtr<FJsonObject> Row = Value->AsObject();
		const FString Kind = Row->GetStringField(TEXT("kind"));
		const FString ExpectedId = Row->GetStringField(TEXT("id"));

		// --- The five BUILT rows: build with the port, compare the id byte for byte. ---
		FBMJob Built;
		bool bWasBuilt = true;

		if (Kind == TEXT("retaliation"))
		{
			Built = FBMJobGenerator::RetaliationJob(
				Districts[0].Venues[0], TEXT("Cargo Terminal"), Factions[0], TEXT("Corvine"), 240);
		}
		else if (Kind == TEXT("retaliation_tick_zero"))
		{
			Built = FBMJobGenerator::RetaliationJob(
				Districts[0].Venues[0], TEXT("Cargo Terminal"), Factions[0], TEXT("Corvine"), 0);
		}
		else if (Kind == TEXT("contested"))
		{
			Built = FBMJobGenerator::ContestedGroundJob(
				Districts[0].Venues[0], TEXT("Cargo Terminal"), Factions[0], TEXT("Corvine"), 240);
		}
		else if (Kind == TEXT("followup"))
		{
			Built = FBMJobGenerator::FollowupJob(
				Districts[0].Venues[0], TEXT("Cargo Terminal"), 301);
		}
		else if (Kind == TEXT("burycase"))
		{
			Built = FBMJobGenerator::BuryCaseJob(
				Districts[0].EvidenceCases[0], Districts[0], TEXT("Glass Wharf"), 240);
		}
		else
		{
			bWasBuilt = false;
		}

		if (bWasBuilt)
		{
			++BuiltRows;

			// THE GATE CONDITION, first half: the builder produces the oracle's id exactly.
			if (Built.Id != ExpectedId && ++Mismatches <= MaxReportedMismatches)
			{
				AddError(FString::Printf(
					TEXT("%s: built id \"%s\", oracle's \"%s\" — the format is a parse contract, not cosmetics"),
					*Kind, *Built.Id, *ExpectedId));
			}

			const int32 ExpectedOrigin = Row->GetIntegerField(TEXT("origin"));
			if (static_cast<int32>(Built.Origin) != ExpectedOrigin
				&& ++Mismatches <= MaxReportedMismatches)
			{
				AddError(FString::Printf(
					TEXT("%s: origin expected %d, got %d"),
					*Kind, ExpectedOrigin, static_cast<int32>(Built.Origin)));
			}

			const FString ExpectedVenueId = Row->GetStringField(TEXT("venue_id"));
			if (Built.VenueId != ExpectedVenueId && ++Mismatches <= MaxReportedMismatches)
			{
				AddError(FString::Printf(
					TEXT("%s: venue_id expected \"%s\", got \"%s\" — burycase leaves it EMPTY; it targets a case, not a venue"),
					*Kind, *ExpectedVenueId, *Built.VenueId));
			}

			const int32 ExpectedDeadline = Row->GetIntegerField(TEXT("deadline_ticks"));
			if (Built.DeadlineTicks != ExpectedDeadline
				&& ++Mismatches <= MaxReportedMismatches)
			{
				AddError(FString::Printf(
					TEXT("%s: deadline_ticks expected %d, got %d"),
					*Kind, ExpectedDeadline, Built.DeadlineTicks));
			}

			// The variant the hash landed on decides the title — which is how a wrong
			// avalanche shows up as a user-visible difference rather than a silent one.
			const FString ExpectedTitle = Row->GetStringField(TEXT("title"));
			if (Built.Title != ExpectedTitle && ++Mismatches <= MaxReportedMismatches)
			{
				AddError(FString::Printf(
					TEXT("%s: title expected \"%s\", got \"%s\" — the hash picked a different variant"),
					*Kind, *ExpectedTitle, *Built.Title));
			}
		}
		else
		{
			++ProbeRows;
		}

		// --- Rebuild, for EVERY row: built ids and raw parse probes alike. ---
		FBMJob Rebuilt;
		const bool bRebuilt = FBMJobGenerator::Rebuild(ExpectedId, Districts, Factions, Rebuilt);

		const bool bExpectedRebuilt = Row->GetBoolField(TEXT("rebuilt"));
		if (bRebuilt != bExpectedRebuilt && ++Mismatches <= MaxReportedMismatches)
		{
			AddError(FString::Printf(
				TEXT("Rebuild(\"%s\") [%s]: expected %s, got %s — a rebuild refusal is a legitimate outcome, never an error"),
				*ExpectedId, *Kind,
				bExpectedRebuilt ? TEXT("success") : TEXT("refusal"),
				bRebuilt ? TEXT("success") : TEXT("refusal")));
		}

		if (bRebuilt)
		{
			const FString ExpectedRebuiltId = Row->GetStringField(TEXT("rebuilt_id"));
			if (Rebuilt.Id != ExpectedRebuiltId && ++Mismatches <= MaxReportedMismatches)
			{
				AddError(FString::Printf(
					TEXT("Rebuild(\"%s\"): rebuilt id \"%s\", expected \"%s\""),
					*ExpectedId, *Rebuilt.Id, *ExpectedRebuiltId));
			}

			// THE GATE CONDITION, second half: the round trip is byte-identical.
			const bool bExpectedRoundTrip = Row->GetBoolField(TEXT("id_round_trips"));
			const bool bRoundTrips = Rebuilt.Id == ExpectedId;
			if (bRoundTrips != bExpectedRoundTrip && ++Mismatches <= MaxReportedMismatches)
			{
				AddError(FString::Printf(
					TEXT("Rebuild(\"%s\"): id_round_trips expected %d, got %d"),
					*ExpectedId, bExpectedRoundTrip ? 1 : 0, bRoundTrips ? 1 : 0));
			}

			const FString ExpectedRebuiltTitle = Row->GetStringField(TEXT("rebuilt_title"));
			if (Rebuilt.Title != ExpectedRebuiltTitle && ++Mismatches <= MaxReportedMismatches)
			{
				AddError(FString::Printf(
					TEXT("Rebuild(\"%s\"): title \"%s\", expected \"%s\" — rebuild must re-run the SAME builder and land on the SAME variant"),
					*ExpectedId, *Rebuilt.Title, *ExpectedRebuiltTitle));
			}
		}

		// And for the built rows: rebuild must reproduce the built job's content, not just
		// its id. This is what makes "saves store runtime state only" true.
		if (bWasBuilt && bRebuilt)
		{
			if (Rebuilt.Title != Built.Title && ++Mismatches <= MaxReportedMismatches)
			{
				AddError(FString::Printf(
					TEXT("%s: rebuild produced \"%s\" but the builder produced \"%s\""),
					*Kind, *Rebuilt.Title, *Built.Title));
			}
			if (Rebuilt.Approaches.Num() != Built.Approaches.Num()
				&& ++Mismatches <= MaxReportedMismatches)
			{
				AddError(FString::Printf(
					TEXT("%s: rebuild produced %d approaches, the builder %d"),
					*Kind, Rebuilt.Approaches.Num(), Built.Approaches.Num()));
			}
		}
	}

	AddInfo(FString::Printf(TEXT("ids: %d built rows, %d parse probes"), BuiltRows, ProbeRows));

	if (BuiltRows != 5)
	{
		AddError(FString::Printf(
			TEXT("expected 5 built rows in the fixture, saw %d — the round-trip gate is measuring less than it should"),
			BuiltRows));
	}

	if (Mismatches > 0)
	{
		AddError(FString::Printf(
			TEXT("S3 GATE FAILED — %d generator mismatch(es). See Docs/gates/S3.md."),
			Mismatches));
		return false;
	}

	return true;
}
```

- [ ] **Step 2: Run it to verify it fails**

Run:
```sh
"C:/Program Files/Epic Games/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" \
    D:/black-meridian-ue/BlackMeridian.uproject \
    -ExecCmds="Automation RunTests BM.Jobs; Quit" -unattended -nopause -nullrhi -nosplash -NoLiveCoding \
    -testexit="Automation Test Queue Empty"
```
Expected: build failure, `fatal error C1083: Cannot open include file: 'BMJobGenerator.h'`.

- [ ] **Step 3: Implement**

Create `D:\black-meridian-ue\Source\BMCore\Public\BMJobGenerator.h`:

```cpp
#pragma once

#include "BMJobTypes.h"
#include "BMTypes.h"
#include "CoreMinimal.h"

/**
 * Pure sim-trigger -> job mapping (brief §7.5), ported from src/jobs/job_generator.gd.
 *
 * PURELY DETERMINISTIC: the same trigger on the same sim state produces the identical job.
 * No RNG, no seeded jitter — template variety within an origin is a deterministic hash of
 * the id-encoded targeting, which is still not randomness.
 * (BM.Determinism.NoRandomInSimModule enforces the first half of that statement.)
 *
 * A generated job = an authored FBMJobTemplates builder + sim-derived targeting. The id
 * encodes everything needed to rebuild the content, so saves keep storing runtime state
 * ONLY: Rebuild re-runs the same builder with the parsed inputs and returns the identical
 * job. That round trip is the S3 gate condition.
 *
 * `[V]` This layer READS sim objects handed to it. It never recomputes economy/heat/rival
 * state and never writes any.
 *
 * `[V]` DISPLAY NAMES are passed in rather than read off the state structs: BMTypes.h
 * carries no display name (presentation data is deliberately absent from BMCore — see the
 * FBMVenueState comment), while the Godot VenueData/FactionData/DistrictData resources do.
 * The caller supplies them; the ids, which are what the format encodes, come off the state.
 */
struct BMCORE_API FBMJobGenerator
{
	/** Trigger 1 — a rival SABOTAGE landed on a player venue.
	 *  `[V]` The variant is a hash of the id string ITSELF, so Rebuild — which re-enters
	 *  this function with the parsed inputs — recomputes the identical index. Never stored,
	 *  never a counter. */
	static FBMJob RetaliationJob(const FBMVenueState& Venue, const FString& VenueName,
		const FBMFactionState& Rival, const FString& RivalName, int32 Tick);

	/** Trigger 2 — a resolved job's DelayedConsequence crossed the threshold, FollowupLeadTicks
	 *  ago. `[V]` The director holds the window; this only builds the job. No variants. */
	static FBMJob FollowupJob(const FBMVenueState& Venue, const FString& VenueName, int32 Tick);

	/** Trigger 3 — an inspection landed while evidence cases pin the district.
	 *  `[V]` VenueId stays EMPTY: the job targets a CASE, and the district is encoded in the
	 *  id instead. The director parses it back out. */
	static FBMJob BuryCaseJob(const FBMEvidenceCase& Case, const FBMDistrictState& District,
		const FString& DistrictName, int32 Tick);

	/** Trigger 4 — the rival took ground: a landed EXPAND onto a neutral venue, or a betrayal
	 *  handing a venue over. Both arms produce this same job. */
	static FBMJob ContestedGroundJob(const FBMVenueState& Venue, const FString& VenueName,
		const FBMFactionState& Rival, const FString& RivalName, int32 Tick);

	/**
	 * Rebuild a generated job's authored content from its id — the save-load path, and the
	 * generated-id counterpart of FBMJobTemplates::ById.
	 *
	 * `[V]` Returns false for a non-generated id, an unparseable one, or one whose targets
	 * no longer exist. All three are LEGITIMATE outcomes, not errors: if the case a burycase
	 * job targets is gone, the job cannot be rebuilt honestly and the oracle returns null.
	 *
	 * `[V]` Display names are re-derived by the caller's world in the oracle; here they are
	 * looked up from the id and passed through as the ids themselves, because BMCore has no
	 * display names. See the note in Step 3 — this is the one place the port cannot be a
	 * literal transcription, and it is recorded rather than hidden.
	 */
	static bool Rebuild(const FString& JobId, const TArray<FBMDistrictState>& Districts,
		const TArray<FBMFactionState>& Factions, FBMJob& OutJob);

	/**
	 * `[V]` The deterministic variant pick: avalanche of the id-encoded string, non-negative
	 * modulo the count. A pure function of the id, so save -> load -> rebuild lands on the
	 * same variant forever.
	 *
	 * ⚠️ Forwards to BMHash::VariantIndex. DO NOT write a second avalanche here — Godot
	 * carried two byte-identical copies with a comment asking future authors to keep them in
	 * sync by hand, and TD-05 collapsed them. BM.Determinism.Hash_SingleImplementation scans
	 * for the constants and fails if one reappears.
	 */
	static int32 VariantIndex(const FString& SeedString, int32 Count);

	/** Index of a venue across all districts, or INDEX_NONE. */
	static int32 FindVenue(const TArray<FBMDistrictState>& Districts, const FString& VenueId,
		int32& OutDistrictIndex);

	/** Index of a district by id, or INDEX_NONE. */
	static int32 FindDistrict(const TArray<FBMDistrictState>& Districts, const FString& DistrictId);

	/** Index of a faction by id, or INDEX_NONE. */
	static int32 FindFaction(const TArray<FBMFactionState>& Factions, const FString& FactionId);
};
```

Create `D:\black-meridian-ue\Source\BMCore\Private\BMJobGenerator.cpp`:

```cpp
#include "BMJobGenerator.h"

#include "BMEvidence.h"
#include "BMHash.h"
#include "BMJobIdParser.h"
#include "BMJobTemplates.h"

int32 FBMJobGenerator::VariantIndex(const FString& SeedString, int32 Count)
{
	// `[V]` One entry point for the whole simulation. TD-05.
	return BMHash::VariantIndex(SeedString, Count);
}

int32 FBMJobGenerator::FindVenue(const TArray<FBMDistrictState>& Districts,
	const FString& VenueId, int32& OutDistrictIndex)
{
	for (int32 d = 0; d < Districts.Num(); ++d)
	{
		for (int32 v = 0; v < Districts[d].Venues.Num(); ++v)
		{
			if (Districts[d].Venues[v].Id == VenueId)
			{
				OutDistrictIndex = d;
				return v;
			}
		}
	}
	OutDistrictIndex = INDEX_NONE;
	return INDEX_NONE;
}

int32 FBMJobGenerator::FindDistrict(const TArray<FBMDistrictState>& Districts,
	const FString& DistrictId)
{
	for (int32 i = 0; i < Districts.Num(); ++i)
	{
		if (Districts[i].Id == DistrictId)
		{
			return i;
		}
	}
	return INDEX_NONE;
}

int32 FBMJobGenerator::FindFaction(const TArray<FBMFactionState>& Factions,
	const FString& FactionId)
{
	for (int32 i = 0; i < Factions.Num(); ++i)
	{
		if (Factions[i].Id == FactionId)
		{
			return i;
		}
	}
	return INDEX_NONE;
}

FBMJob FBMJobGenerator::RetaliationJob(const FBMVenueState& Venue, const FString& VenueName,
	const FBMFactionState& Rival, const FString& RivalName, int32 Tick)
{
	FBMParsedJobId Parsed;
	Parsed.Template = EBMJobIdTemplate::Retaliation;
	Parsed.VenueId = Venue.Id;
	Parsed.RivalId = Rival.Id;
	Parsed.Tick = Tick;

	const FString IdString = FBMJobIdParser::Build(Parsed);

	FBMJob Job = FBMJobTemplates::Retaliation(VenueName, RivalName,
		VariantIndex(IdString, FBMJobTemplates::RetaliationVariants));
	Job.Id = IdString;
	Job.VenueId = Venue.Id;
	return Job;
}

FBMJob FBMJobGenerator::FollowupJob(const FBMVenueState& Venue, const FString& VenueName,
	int32 Tick)
{
	FBMParsedJobId Parsed;
	Parsed.Template = EBMJobIdTemplate::Followup;
	Parsed.VenueId = Venue.Id;
	Parsed.Tick = Tick;

	// `[V]` No variant pick: the follow-up has exactly one authored template.
	FBMJob Job = FBMJobTemplates::Followup(VenueName);
	Job.Id = FBMJobIdParser::Build(Parsed);
	Job.VenueId = Venue.Id;
	return Job;
}

FBMJob FBMJobGenerator::BuryCaseJob(const FBMEvidenceCase& Case,
	const FBMDistrictState& District, const FString& DistrictName, int32 Tick)
{
	FBMParsedJobId Parsed;
	Parsed.Template = EBMJobIdTemplate::BuryCase;
	Parsed.DistrictId = District.Id;
	Parsed.CaseId = Case.Id;
	Parsed.Tick = Tick;

	const FString IdString = FBMJobIdParser::Build(Parsed);

	FBMJob Job = FBMJobTemplates::BuryCase(FBMEvidence::KindLabel(Case.Kind), DistrictName,
		VariantIndex(IdString, FBMJobTemplates::BuryCaseVariants));
	Job.Id = IdString;
	// `[V]` VenueId stays EMPTY. The job targets a case; the district is in the id.
	return Job;
}

FBMJob FBMJobGenerator::ContestedGroundJob(const FBMVenueState& Venue, const FString& VenueName,
	const FBMFactionState& Rival, const FString& RivalName, int32 Tick)
{
	FBMParsedJobId Parsed;
	Parsed.Template = EBMJobIdTemplate::Contested;
	Parsed.VenueId = Venue.Id;
	Parsed.RivalId = Rival.Id;
	Parsed.Tick = Tick;

	const FString IdString = FBMJobIdParser::Build(Parsed);

	FBMJob Job = FBMJobTemplates::ContestedGround(VenueName, RivalName,
		VariantIndex(IdString, FBMJobTemplates::ContestedVariants));
	Job.Id = IdString;
	Job.VenueId = Venue.Id;
	return Job;
}

bool FBMJobGenerator::Rebuild(const FString& JobId, const TArray<FBMDistrictState>& Districts,
	const TArray<FBMFactionState>& Factions, FBMJob& OutJob)
{
	FBMParsedJobId Parsed;
	if (!FBMJobIdParser::Parse(JobId, Parsed))
	{
		return false;
	}

	switch (Parsed.Template)
	{
	case EBMJobIdTemplate::Retaliation:
	case EBMJobIdTemplate::Contested:
	{
		int32 DistrictIndex = INDEX_NONE;
		const int32 VenueIndex = FindVenue(Districts, Parsed.VenueId, DistrictIndex);
		const int32 FactionIndex = FindFaction(Factions, Parsed.RivalId);
		if (VenueIndex == INDEX_NONE || FactionIndex == INDEX_NONE)
		{
			// `[V]` The target is gone — the job cannot be rebuilt honestly. A refusal.
			return false;
		}

		const FBMVenueState& Venue = Districts[DistrictIndex].Venues[VenueIndex];
		const FBMFactionState& Rival = Factions[FactionIndex];

		OutJob = Parsed.Template == EBMJobIdTemplate::Retaliation
			? RetaliationJob(Venue, Venue.Id, Rival, Rival.Id, Parsed.Tick)
			: ContestedGroundJob(Venue, Venue.Id, Rival, Rival.Id, Parsed.Tick);
		return true;
	}

	case EBMJobIdTemplate::Followup:
	{
		int32 DistrictIndex = INDEX_NONE;
		const int32 VenueIndex = FindVenue(Districts, Parsed.VenueId, DistrictIndex);
		if (VenueIndex == INDEX_NONE)
		{
			return false;
		}

		const FBMVenueState& Venue = Districts[DistrictIndex].Venues[VenueIndex];
		OutJob = FollowupJob(Venue, Venue.Id, Parsed.Tick);
		return true;
	}

	case EBMJobIdTemplate::BuryCase:
	{
		const int32 DistrictIndex = FindDistrict(Districts, Parsed.DistrictId);
		if (DistrictIndex == INDEX_NONE)
		{
			return false;
		}

		const FBMDistrictState& District = Districts[DistrictIndex];
		const int32 CaseIndex = FBMEvidence::FindCase(District, Parsed.CaseId);
		if (CaseIndex == INDEX_NONE)
		{
			// `[V]` The case is gone — the job can't be rebuilt honestly.
			return false;
		}

		OutJob = BuryCaseJob(District.EvidenceCases[CaseIndex], District, District.Id,
			Parsed.Tick);
		return true;
	}

	default:
		return false;
	}
}
```

> **A real divergence, and the one place this port cannot be a literal transcription.** The Godot
> builders read `venue.display_name`, `rival.display_name`, `district.display_name` and
> `evidence_case.label` to interpolate into the job text. **BMCore's state structs carry no display
> names** — `BMTypes.h` says so explicitly ("presentation data (map position, display name) is
> deliberately absent from BMCore"), and adding them would put presentation data behind the
> determinism wall. The port therefore takes display names as parameters at the trigger sites, and
> `Rebuild` — which has only the ids — passes the **ids** through as the names.
>
> **Consequence: a rebuilt job's TEXT differs from a freshly generated one, while its id, origin,
> variant, choices and every effect number are identical.** That is acceptable because the variant
> pick is a function of the **id**, not of the text, so the mechanics round-trip exactly; only the
> interpolated proper nouns differ until a display-name source exists.
>
> **This is a decision, not an oversight. Record it in `Docs/gates/S3.md`,** and note the two honest
> ways to close it later: (a) a presentation-side name table BMSim injects before the job reaches
> the UI — the option that preserves the determinism wall, and the recommended one; or (b) a
> `TMap<FString, FString>` name lookup passed into `Rebuild`. **Do not** add display names to
> `FBMVenueState`. The test above compares `rebuilt_title` (the template's own title, which does not
> interpolate) rather than `ApparentProblem` (which does), so the gate measures the mechanics and
> does not go vacuous on this difference.
>
> **Also verify at implementation time:** the oracle's `bury_case_job` passes
> `evidence_case.label`, and `FBMEvidenceCase` **does** carry a `Label` field — but
> `FBMEvidence::Deposit` was not read closely enough here to confirm whether it populates `Label` or
> leaves it empty. The code above uses `FBMEvidence::KindLabel(Case.Kind)` as the substitute.
> **Read `BMEvidence.cpp::Deposit` first:** if it sets `Label`, use `Case.Label` instead and delete
> the `KindLabel` call. If it does not, keep `KindLabel` and record that too.

- [ ] **Step 4: Run to verify it passes**

Run:
```sh
"C:/Program Files/Epic Games/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" \
    D:/black-meridian-ue/BlackMeridian.uproject \
    -ExecCmds="Automation RunTests BM.Jobs; Quit" -unattended -nopause -nullrhi -nosplash -NoLiveCoding \
    -testexit="Automation Test Queue Empty"
```
Expected:
```
BM.Jobs.EnumValuesAreSaveContract                  Result={Success}
BM.Jobs.GeneratedIdRoundTrips                      Result={Success}   5 built rows, 14 parse probes
BM.Jobs.IdParseContract                            Result={Success}
BM.Jobs.IdParserIsSingleImplementation             Result={Success}
BM.Jobs.LifecycleMatchesGodotVectors               Result={Success}
BM.Jobs.ResolutionMatchesGodotVectors              Result={Success}
BM.Jobs.TemplatesHonorBalanceEnvelope              Result={Success}
BM.Jobs.VariantIndexMatchesGodotVectors            Result={Success}   24 rows, 24 avalanche values past 2^53
BM.Jobs.VariantsShareChoiceIds                     Result={Success}
**** TEST COMPLETE. EXIT CODE: 0 ****              9/9 · 0 fail · 0 errors
```

- [ ] **Step 5: Commit**

```bash
cd /d/black-meridian-ue
git add Source/BMCore/Public/BMJobGenerator.h Source/BMCore/Private/BMJobGenerator.cpp Source/BMCore/Private/BMJobTest.cpp
git commit -m "feat(s3): BMJobGenerator — four builders, rebuild, variant pick

The S3 gate condition lands here: a generated job's id round-trips
byte-identically through Rebuild, so saves keep storing runtime state only.

The variant pick forwards to BMHash::VariantIndex — no second avalanche.
Measured indices for consecutive ticks are 0,0,0,1, not alternating: a port
applying DJB2 without the avalanche reads 0,1,0,1 and ships different text
variety with no other symptom.

Recorded divergence: BMCore has no display names (presentation data is
deliberately absent), so builders take them as parameters and Rebuild passes
ids through. A rebuilt job's interpolated text differs; its id, origin,
variant, choices and every effect number do not. See Docs/gates/S3.md.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: `FBMJobDirector` — state, cadence, triggers, origin branches

The architectural decision this task exists to implement, **already made, not up for revisiting**:
job state lives in `FBMJobDirector`, a **plain struct in BMCore**, not in a subsystem. A
`UGameInstanceSubsystem` carries `ClassWithin = UGameInstance` and cannot be `NewObject`'d in an
automation test — it trips a CoreUObject ensure the framework promotes to a failure while every
assertion in the test passes, which reads as a mystery. S2 dodged it by making its two verbs
`static`; S3 has real per-campaign state and cannot. So the state and all cap/trigger logic live
here, and **no S3 test constructs a subsystem or stands up a GameInstance.**

Six behaviors are the substance:

1. **The cadence cap.** At most `MaxConcurrentJobs` (3) UNRESOLVED jobs. A trigger firing at the cap
   is **DROPPED**, never queued — the simpler deterministic choice, recorded as the P08 decision.
   A queue would change pacing *and* introduce an ordering the save must serialize.
2. **Dedupe before the cap.** The same id twice is dropped as a duplicate, and that check runs
   *before* the capacity check — so a duplicate at the cap is reported as a duplicate.
3. **Four generation triggers**, each a mapping from a sim event to one builder.
4. **Three post-outcome origin branches**, each an origin-gated single write:
   `EvidenceChain` burns the TARGETED case (distinct from `ApplyOutcome`'s passive strongest-first
   erosion — two mechanisms, deliberately), `RivalProvocation` raises the provocateur's grudge, and
   `TerritoryLoss` reclaims the venue to **Contested**, not to full control.
5. **Follow-up scheduling** at `DelayedConsequence >= FollowupThreshold` (0.25) with a
   `FollowupLeadTicks` (20) lead.
6. **The tick order inside the pass:** every active job's deadline tick first, then the follow-up
   countdown. Both in array order.

**Files:**
- Create: `D:\black-meridian-ue\Source\BMCore\Public\BMJobDirector.h`
- Create: `D:\black-meridian-ue\Source\BMCore\Private\BMJobDirector.cpp`
- Test: `D:\black-meridian-ue\Source\BMCore\Private\BMJobBehaviorTest.cpp` (append)

### The open design question, answered

`FBMSimulation::AdvanceTick` takes only `FBMCampaignState&`, but the job pass needs the director's
state. **Decision: put `FBMJobDirector` INSIDE `FBMCampaignState` as a member.** Reasons, in order
of weight:

- S4's save contract has to serialize job state with the campaign anyway — they are one snapshot.
- `AdvanceTick`'s signature stays unchanged, so the golden vectors and `FBMProbe` keep measuring the
  same unit. S2's Correction 6 recorded exactly this hazard: splitting the tick's inputs creates a
  *second definition of what a tick is*.
- Jobs join `BM.Determinism.TickIsReproducible` for free — it already advances two campaigns
  interleaved and requires byte-identical state, which would fail on any shared global.

**Record this in `Docs/gates/S3.md` as a decision with its reason.** Do not let it be settled by
whichever version compiles first.

- [ ] **Step 1: Write the failing test**

Append to `D:\black-meridian-ue\Source\BMCore\Private\BMJobBehaviorTest.cpp` (add
`#include "BMEvidence.h"`, `#include "BMJobDirector.h"`, `#include "BMJobGenerator.h"`,
`#include "BMJobLifecycle.h"`, `#include "BMTypes.h"`):

```cpp
// ---------------------------------------------------------------------------
// Shared world for the director tests
// ---------------------------------------------------------------------------

namespace
{
	/**
	 * One district, three player venues, one rival. Enough to exceed the cadence cap and to
	 * exercise every origin branch.
	 *
	 * `[V]` No GameInstance, no subsystem, no UObject anywhere in this file. That is the
	 * whole point of FBMJobDirector being a plain struct — see the task's opening note.
	 */
	FBMCampaignState DirectorWorld()
	{
		FBMCampaignState State;
		State.PlayerFactionId = TEXT("compact");

		FBMDistrictState District;
		District.Id = TEXT("glasswharf");
		District.LocalHeat = 0.5f;

		for (int32 i = 0; i < 3; ++i)
		{
			FBMVenueState Venue;
			Venue.Id = FString::Printf(TEXT("gw_venue_%d"), i);
			Venue.Type = EBMVenueType::Racket;
			Venue.OwnerFaction = TEXT("compact");
			Venue.ControlState = EBMControlState::Controlled;
			District.Venues.Add(MoveTemp(Venue));
		}

		State.Districts.Add(MoveTemp(District));

		FBMFactionState Player;
		Player.Id = TEXT("compact");
		Player.bIsPlayer = true;
		Player.DirtyCash = 5000;
		State.Factions.Add(MoveTemp(Player));

		FBMFactionState Rival;
		Rival.Id = TEXT("corvine");
		State.Factions.Add(MoveTemp(Rival));

		return State;
	}

	/** Drives a job from Intake to Resolved with a chosen approach and cover-up. */
	void ResolveJobWith(FBMJob& Job, const TCHAR* Approach, const TCHAR* Coverup)
	{
		FBMJobLifecycle::Begin(Job);
		FBMJobLifecycle::ChooseApproach(Job, Approach);
		FBMJobLifecycle::ChooseCoverup(Job, Coverup);
	}
}

// ---------------------------------------------------------------------------
// BM.Jobs.CadenceCapDropsAtCapacity
// ---------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FBMJobCadenceCapTest,
	"BM.Jobs.CadenceCapDropsAtCapacity",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FBMJobCadenceCapTest::RunTest(const FString&)
{
	FBMCampaignState State = DirectorWorld();
	FBMJobDirector& Director = State.Jobs;

	// Fill to the cap, one venue each so the ids differ.
	for (int32 i = 0; i < BMConst::MaxConcurrentJobs; ++i)
	{
		const FBMJob Job = FBMJobGenerator::RetaliationJob(
			State.Districts[0].Venues[i], State.Districts[0].Venues[i].Id,
			State.Factions[1], State.Factions[1].Id, 100 + i);
		TestTrue(FString::Printf(TEXT("offer %d accepted below the cap"), i),
			Director.TryOffer(Job));
	}

	TestEqual(TEXT("at the cap"), Director.UnresolvedCount(), BMConst::MaxConcurrentJobs);

	// `[V]` A trigger at the cap is DROPPED, never queued. The P08 decision: the simpler
	// deterministic choice. A queue would change pacing AND add an ordering the save has to
	// serialize — so "dropped" must be observable as "the job is not there at all".
	{
		const FBMJob Overflow = FBMJobGenerator::FollowupJob(
			State.Districts[0].Venues[0], State.Districts[0].Venues[0].Id, 500);
		TestFalse(TEXT("an offer at the cap is refused"), Director.TryOffer(Overflow));
		TestEqual(TEXT("the dropped job is not in active_jobs"),
			Director.ActiveJobs.Num(), BMConst::MaxConcurrentJobs);
		TestEqual(TEXT("the dropped job is NOT queued anywhere"),
			Director.FindJob(Overflow.Id), INDEX_NONE);
	}

	// Resolving one frees a slot — the cap counts UNRESOLVED, not total.
	ResolveJobWith(Director.ActiveJobs[0], TEXT("appr_absorb"), TEXT("cover_deny"));
	TestEqual(TEXT("a resolved job stops counting against the cap"),
		Director.UnresolvedCount(), BMConst::MaxConcurrentJobs - 1);
	TestEqual(TEXT("but it stays in active_jobs"),
		Director.ActiveJobs.Num(), BMConst::MaxConcurrentJobs);

	{
		const FBMJob Fresh = FBMJobGenerator::FollowupJob(
			State.Districts[0].Venues[0], State.Districts[0].Venues[0].Id, 600);
		TestTrue(TEXT("a new offer is accepted once a slot frees"), Director.TryOffer(Fresh));
	}

	return true;
}

// ---------------------------------------------------------------------------
// BM.Jobs.DuplicateIdDroppedBeforeCapCheck
// ---------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FBMJobDuplicateIdTest,
	"BM.Jobs.DuplicateIdDroppedBeforeCapCheck",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FBMJobDuplicateIdTest::RunTest(const FString&)
{
	FBMCampaignState State = DirectorWorld();
	FBMJobDirector& Director = State.Jobs;

	const FBMJob Job = FBMJobGenerator::RetaliationJob(
		State.Districts[0].Venues[0], State.Districts[0].Venues[0].Id,
		State.Factions[1], State.Factions[1].Id, 240);

	TestTrue(TEXT("the first offer is accepted"), Director.TryOffer(Job));
	TestFalse(TEXT("the same id offered again is dropped"), Director.TryOffer(Job));
	TestEqual(TEXT("and nothing was appended"), Director.ActiveJobs.Num(), 1);

	// `[V]` Dedupe runs BEFORE the capacity check. Two triggers landing on the same venue at
	// the same tick build the SAME id by construction — that is the collision this exists
	// for, and it must not consume a slot on the way to being refused.
	//
	// Fill the remaining slots with jobs on DISTINCT venues (DirectorWorld seeds three:
	// gw_venue_0..2, and MaxConcurrentJobs is 3), so the director sits exactly at capacity
	// with no duplicates involved.
	for (int32 i = 1; i < BMConst::MaxConcurrentJobs; ++i)
	{
		const FBMJob Filler = FBMJobGenerator::RetaliationJob(
			State.Districts[0].Venues[i], State.Districts[0].Venues[i].Id,
			State.Factions[1], State.Factions[1].Id, 240);
		TestTrue(TEXT("a distinct-venue job fills the next slot"), Director.TryOffer(Filler));
	}

	TestEqual(TEXT("the director is now at capacity"),
		Director.UnresolvedCount(), BMConst::MaxConcurrentJobs);

	// At capacity AND a duplicate: dedupe must answer first. The distinction is invisible in
	// the return value — both paths return false — so assert on the LOG-FREE consequence:
	// the array length. Either way nothing is appended, but a port that checked capacity
	// first would ALSO refuse a genuinely new id here, which the next assertion catches.
	TestFalse(TEXT("the duplicate is still refused at capacity"), Director.TryOffer(Job));
	TestEqual(TEXT("and still nothing was appended"),
		Director.ActiveJobs.Num(), BMConst::MaxConcurrentJobs);

	// Resolve one slot, then re-offer the duplicate. It must STILL be refused — proving the
	// earlier refusal was dedupe, not capacity. This is the assertion that separates the two
	// orderings; without it the test passes under either.
	Director.ActiveJobs[0].Stage = EBMJobStage::Resolved;
	TestEqual(TEXT("one slot freed"),
		Director.UnresolvedCount(), BMConst::MaxConcurrentJobs - 1);
	TestFalse(TEXT("the duplicate is refused on identity, not capacity"),
		Director.TryOffer(Job));

	return true;
}

// ---------------------------------------------------------------------------
// BM.Jobs.PostOutcomeOriginBranches
// ---------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FBMJobPostOutcomeBranchesTest,
	"BM.Jobs.PostOutcomeOriginBranches",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FBMJobPostOutcomeBranchesTest::RunTest(const FString&)
{
	// --- EvidenceChain: a burn that suppressed trace removes its TARGETED case. ---
	{
		FBMCampaignState State = DirectorWorld();
		FBMJobDirector& Director = State.Jobs;

		// Two cases, the targeted one deliberately NOT the strongest — that is what
		// separates the aimed removal from ApplyOutcome's passive strongest-first erosion.
		FBMEvidence::Deposit(State.Districts[0], 0.9f, TEXT("other_job"), 10);
		FBMEvidence::Deposit(State.Districts[0], 0.3f, TEXT("target_job"), 20);
		const FString TargetCaseId = State.Districts[0].EvidenceCases[1].Id;
		const FString StrongCaseId = State.Districts[0].EvidenceCases[0].Id;

		FBMJob Job = FBMJobGenerator::BuryCaseJob(
			State.Districts[0].EvidenceCases[1], State.Districts[0],
			State.Districts[0].Id, 240);
		TestTrue(TEXT("the bury-case job is offered"), Director.TryOffer(Job));

		FBMJob& Live = Director.ActiveJobs[Director.FindJob(Job.Id)];
		ResolveJobWith(Live, TEXT("appr_torch"), TEXT("cover_never_was"));
		TestTrue(TEXT("the clean burn nets negative evidence"),
			Live.Outcome.EvidenceGenerated < 0.0f);

		Director.ApplyAndFinalize(State, Live, 300);

		TestEqual(TEXT("the TARGETED case is removed, even though it was not the strongest"),
			FBMEvidence::FindCase(State.Districts[0], TargetCaseId), INDEX_NONE);
		TestNotEqual(TEXT("the strongest case survives the aimed strike (it was eroded, not removed)"),
			FBMEvidence::FindCase(State.Districts[0], StrongCaseId), INDEX_NONE);
	}

	// --- EvidenceChain, botched: net POSITIVE evidence leaves the case standing. ---
	{
		FBMCampaignState State = DirectorWorld();
		FBMJobDirector& Director = State.Jobs;

		FBMEvidence::Deposit(State.Districts[0], 0.3f, TEXT("target_job"), 20);
		const FString TargetCaseId = State.Districts[0].EvidenceCases[0].Id;

		FBMJob Job = FBMJobGenerator::BuryCaseJob(
			State.Districts[0].EvidenceCases[0], State.Districts[0],
			State.Districts[0].Id, 240);
		Director.TryOffer(Job);

		FBMJob& Live = Director.ActiveJobs[Director.FindJob(Job.Id)];
		ResolveJobWith(Live, TEXT("appr_snatch"), TEXT("cover_walk"));
		TestTrue(TEXT("the botched burn nets positive evidence"),
			Live.Outcome.EvidenceGenerated > 0.0f);

		Director.ApplyAndFinalize(State, Live, 300);

		TestNotEqual(TEXT("a botched burn leaves the targeted case standing"),
			FBMEvidence::FindCase(State.Districts[0], TargetCaseId), INDEX_NONE);
	}

	// --- RivalProvocation: the provocateur's grudge rises by rival_suspicion. ---
	{
		FBMCampaignState State = DirectorWorld();
		FBMJobDirector& Director = State.Jobs;
		State.Factions[1].Grudge = 0.1f;

		FBMJob Job = FBMJobGenerator::RetaliationJob(
			State.Districts[0].Venues[0], State.Districts[0].Venues[0].Id,
			State.Factions[1], State.Factions[1].Id, 240);
		Director.TryOffer(Job);

		FBMJob& Live = Director.ActiveJobs[Director.FindJob(Job.Id)];
		ResolveJobWith(Live, TEXT("appr_mirror"), TEXT("cover_deny"));
		const float Suspicion = Live.Outcome.RivalSuspicion;
		TestTrue(TEXT("the loud answer draws rival suspicion"), Suspicion > 0.0f);

		Director.ApplyAndFinalize(State, Live, 300);

		// `[V]` The provocateur is identified from the ID, not from a stored reference:
		// gen@retaliation@<venue>@<rival>@<tick>. This branch is the single writer of grudge
		// UPWARD; the rival director decays it.
		TestEqual(TEXT("the provocateur's grudge rose by exactly rival_suspicion"),
			State.Factions[1].Grudge, FMath::Clamp(0.1f + Suspicion, 0.0f, 1.0f));
	}

	// --- TerritoryLoss: a real objective reclaims the venue, but only to CONTESTED. ---
	{
		FBMCampaignState State = DirectorWorld();
		FBMJobDirector& Director = State.Jobs;

		// The rival holds it going in.
		State.Districts[0].Venues[0].OwnerFaction = TEXT("corvine");
		State.Districts[0].Venues[0].ControlState = EBMControlState::Influenced;

		FBMJob Job = FBMJobGenerator::ContestedGroundJob(
			State.Districts[0].Venues[0], State.Districts[0].Venues[0].Id,
			State.Factions[1], State.Factions[1].Id, 240);
		Director.TryOffer(Job);

		FBMJob& Live = Director.ActiveJobs[Director.FindJob(Job.Id)];
		ResolveJobWith(Live, TEXT("appr_evict"), TEXT("cover_deny"));
		TestTrue(TEXT("the eviction achieves the objective"),
			Live.Outcome.ObjectiveAchieved >= 0.5f);

		Director.ApplyAndFinalize(State, Live, 300);

		TestEqual(TEXT("the venue returns to the player"),
			State.Districts[0].Venues[0].OwnerFaction, State.PlayerFactionId);
		// `[V]` CONTESTED, not Controlled. Disputed ground keeps the loop alive — a full
		// reclaim would close the thread the job opened.
		TestEqual(TEXT("reclaimed to CONTESTED, never fully controlled"),
			static_cast<int32>(State.Districts[0].Venues[0].ControlState),
			static_cast<int32>(EBMControlState::Contested));
	}

	// --- TerritoryLoss, failed: no objective, no reclaim. ---
	{
		FBMCampaignState State = DirectorWorld();
		FBMJobDirector& Director = State.Jobs;

		State.Districts[0].Venues[0].OwnerFaction = TEXT("corvine");
		State.Districts[0].Venues[0].ControlState = EBMControlState::Influenced;

		FBMJob Job = FBMJobGenerator::ContestedGroundJob(
			State.Districts[0].Venues[0], State.Districts[0].Venues[0].Id,
			State.Factions[1], State.Factions[1].Id, 241);
		Director.TryOffer(Job);

		FBMJob& Live = Director.ActiveJobs[Director.FindJob(Job.Id)];
		// Expire it instead of resolving: the expired outcome has ObjectiveAchieved 0.
		Live.TicksRemaining = 1;
		FBMJobLifecycle::Tick(Live);
		Director.ApplyAndFinalize(State, Live, 300);

		TestEqual(TEXT("a failed reclaim leaves the venue with the rival"),
			State.Districts[0].Venues[0].OwnerFaction, FString(TEXT("corvine")));
	}

	return true;
}

// ---------------------------------------------------------------------------
// BM.Jobs.FollowupSchedulesAndFires
// ---------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FBMJobFollowupTest,
	"BM.Jobs.FollowupSchedulesAndFires",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FBMJobFollowupTest::RunTest(const FString&)
{
	FBMCampaignState State = DirectorWorld();
	FBMJobDirector& Director = State.Jobs;

	FBMJob Job = FBMJobGenerator::RetaliationJob(
		State.Districts[0].Venues[0], State.Districts[0].Venues[0].Id,
		State.Factions[1], State.Factions[1].Id, 240);
	Director.TryOffer(Job);

	// Expire it: the expired outcome carries DelayedConsequence 0.5, comfortably over the
	// threshold. `[V]` That is why the loop never simply empties — brief §5.1, "a new problem
	// is created rather than every problem disappearing."
	{
		FBMJob& Live = Director.ActiveJobs[Director.FindJob(Job.Id)];
		Live.TicksRemaining = 1;
		TestTrue(TEXT("the job expires"), FBMJobLifecycle::Tick(Live));
		TestTrue(TEXT("the expired outcome crosses the follow-up threshold"),
			Live.Outcome.DelayedConsequence >= BMConst::FollowupThreshold);
		Director.ApplyAndFinalize(State, Live, 300);
	}

	TestEqual(TEXT("exactly one follow-up is scheduled"), Director.PendingFollowups.Num(), 1);
	TestEqual(TEXT("scheduled with the full lead"),
		Director.PendingFollowups[0].TicksLeft, BMConst::FollowupLeadTicks);
	TestEqual(TEXT("and it remembers the venue, not the job"),
		Director.PendingFollowups[0].VenueId, State.Districts[0].Venues[0].Id);

	// Count down. It must fire on the tick TicksLeft reaches 0, not before.
	const int32 UnresolvedBefore = Director.UnresolvedCount();
	for (int32 i = 0; i < BMConst::FollowupLeadTicks - 1; ++i)
	{
		Director.AdvanceTick(State, 300 + i);
		TestEqual(FString::Printf(TEXT("no follow-up yet at lead-%d"), BMConst::FollowupLeadTicks - 1 - i),
			Director.UnresolvedCount(), UnresolvedBefore);
	}

	Director.AdvanceTick(State, 300 + BMConst::FollowupLeadTicks);

	TestEqual(TEXT("the pending entry is consumed"), Director.PendingFollowups.Num(), 0);
	TestEqual(TEXT("and a follow-up job surfaced"),
		Director.UnresolvedCount(), UnresolvedBefore + 1);

	// `[V]` A light resolution does NOT schedule anything: rushing alone (+0.2) stays under
	// the 0.25 threshold. The threshold is the whole reason debris sometimes fades quietly.
	{
		FBMCampaignState Light = DirectorWorld();
		FBMJobDirector& LightDirector = Light.Jobs;

		FBMJob Quiet = FBMJobGenerator::RetaliationJob(
			Light.Districts[0].Venues[0], Light.Districts[0].Venues[0].Id,
			Light.Factions[1], Light.Factions[1].Id, 240);
		LightDirector.TryOffer(Quiet);

		FBMJob& Live = LightDirector.ActiveJobs[LightDirector.FindJob(Quiet.Id)];
		ResolveJobWith(Live, TEXT("appr_absorb"), TEXT("cover_deny"));
		TestTrue(TEXT("the quiet resolution stays under the threshold"),
			Live.Outcome.DelayedConsequence < BMConst::FollowupThreshold);

		LightDirector.ApplyAndFinalize(Light, Live, 300);
		TestEqual(TEXT("nothing is scheduled below the threshold"),
			LightDirector.PendingFollowups.Num(), 0);
	}

	return true;
}

// ---------------------------------------------------------------------------
// BM.Jobs.DirectorNeedsNoGameInstance
// ---------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FBMJobDirectorNoGameInstanceTest,
	"BM.Jobs.DirectorNeedsNoGameInstance",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FBMJobDirectorNoGameInstanceTest::RunTest(const FString&)
{
	// The decision this whole task rests on, asserted rather than assumed: two campaigns
	// advance independently, interleaved, with jobs in both — which would be impossible if
	// director state lived in a subsystem or a static.
	FBMCampaignState A = DirectorWorld();
	FBMCampaignState B = DirectorWorld();

	A.Jobs.TryOffer(FBMJobGenerator::RetaliationJob(
		A.Districts[0].Venues[0], A.Districts[0].Venues[0].Id,
		A.Factions[1], A.Factions[1].Id, 240));

	for (int32 i = 0; i < 10; ++i)
	{
		A.Jobs.AdvanceTick(A, 300 + i);
		B.Jobs.AdvanceTick(B, 300 + i);
	}

	TestEqual(TEXT("campaign A carries its job"), A.Jobs.ActiveJobs.Num(), 1);
	TestEqual(TEXT("campaign B carries none — no shared state"), B.Jobs.ActiveJobs.Num(), 0);

	// And BMCore must stay free of the subsystem header. A director that reaches for
	// UGameInstance has moved the state back where it cannot be tested.
	const FString DirectorSource = FPaths::Combine(FPaths::ProjectDir(),
		TEXT("Source"), TEXT("BMCore"), TEXT("Private"), TEXT("BMJobDirector.cpp"));
	FString Contents;
	if (FFileHelper::LoadFileToString(Contents, *DirectorSource))
	{
		TestFalse(TEXT("BMJobDirector.cpp does not mention UGameInstance"),
			Contents.Contains(TEXT("GameInstance")));
		TestFalse(TEXT("BMJobDirector.cpp does not mention Subsystem"),
			Contents.Contains(TEXT("Subsystem")));
	}
	else
	{
		AddError(TEXT("cannot read BMJobDirector.cpp to scan it"));
	}

	return true;
}
```

> **Why `DuplicateIdDroppedBeforeCapCheck` ends the way it does.** Both a duplicate and a
> capacity refusal return `false`, so asserting on the return value alone cannot tell the two
> orderings apart — a port that checked capacity first would pass a naive version of this test.
> That is why the test resolves one slot and re-offers the duplicate: with a slot free, only a
> dedupe-first implementation still refuses. Keep that final assertion; it is the entire point of
> the test.

This test file also needs `#include "Misc/FileHelper.h"` and `#include "Misc/Paths.h"` for the
source scan at the end.

- [ ] **Step 2: Run it to verify it fails**

Run:
```sh
"C:/Program Files/Epic Games/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" \
    D:/black-meridian-ue/BlackMeridian.uproject \
    -ExecCmds="Automation RunTests BM.Jobs; Quit" -unattended -nopause -nullrhi -nosplash -NoLiveCoding \
    -testexit="Automation Test Queue Empty"
```
Expected: build failure, `fatal error C1083: Cannot open include file: 'BMJobDirector.h'` — and,
once that header exists, `error C2039: 'Jobs': is not a member of 'FBMCampaignState'` until the
member is added.

- [ ] **Step 3: Implement**

Create `D:\black-meridian-ue\Source\BMCore\Public\BMJobDirector.h`:

```cpp
#pragma once

#include "BMJobTypes.h"
#include "CoreMinimal.h"

struct FBMCampaignState;
struct FBMDistrictState;
struct FBMVenueState;

/**
 * The job system's per-campaign state and its trigger logic — ported from the JobDirector
 * autoload (src/jobs/job_director.gd), minus the signals.
 *
 * `[V]` A PLAIN STRUCT in BMCore, not a subsystem. A UGameInstanceSubsystem carries
 * ClassWithin = UGameInstance and cannot be NewObject'd into the transient package: doing so
 * trips a CoreUObject ensure that the automation framework promotes to a failure WHILE EVERY
 * ASSERTION IN THE TEST PASSES, which reads as a mystery (measured in S2, recorded in
 * Docs/gates/S2.md). S2 dodged it by making its two verbs static; S3 has real per-campaign
 * state and cannot. So the state lives here, UBMJobSubsystem holds one of these and forwards,
 * and no S3 test ever constructs a subsystem.
 *
 * `[V]` It lives INSIDE FBMCampaignState as a member. The save contract has to serialize job
 * state with the campaign anyway; AdvanceTick's signature stays unchanged so the golden
 * vectors and the probe keep measuring one unit (S2's Correction 6 — splitting the tick's
 * inputs creates a second definition of what a tick is); and jobs join
 * BM.Determinism.TickIsReproducible for free.
 *
 * The Godot original emitted job_offered / job_stage_changed / job_resolved. Those are the
 * presentation boundary and belong on the subsystem, not here — BMCore has no delegates
 * because it has no CoreUObject.
 */
struct BMCORE_API FBMJobDirector
{
	/** Every job this campaign has offered, resolved ones included. `[V]` A resolved job is
	 *  NOT removed — it stops counting against the cap but stays for the UI and the save. */
	TArray<FBMJob> ActiveJobs;

	/** `[V]` Scheduled delayed-consequence follow-ups. Persisted with the campaign so a
	 *  quicksave inside the window does not lose the problem. */
	TArray<FBMPendingFollowup> PendingFollowups;

	/** Index of a job by id, or INDEX_NONE. */
	int32 FindJob(const FString& JobId) const;

	/** `[V]` How many jobs are NOT resolved. This, not ActiveJobs.Num(), is what the cap
	 *  measures — resolving a job frees a slot without removing it. */
	int32 UnresolvedCount() const;

	/**
	 * The cadence gate (brief §5.2: "run four to six" across a phase, not all at once).
	 *
	 * `[V]` Dedupe by id FIRST, then cap. A trigger firing at the cap is DROPPED, never
	 * queued — the P08 decision, chosen as the simpler deterministic option. A queue would
	 * change pacing and add an ordering the save would have to serialize.
	 *
	 * @return true if the job was offered; false for a duplicate or a drop at capacity.
	 */
	bool TryOffer(const FBMJob& Job);

	/** Appends unconditionally, stamping Intake and the deadline. `[V]` TryOffer is the
	 *  gated entry point; this is what it calls once the gates pass. */
	void Offer(const FBMJob& Job);

	/** Replace state from a loaded save. `[V]` Does NOT reset stage or deadline — the save's
	 *  runtime state is already applied. */
	void RestoreJobs(TArray<FBMJob>&& Jobs, TArray<FBMPendingFollowup>&& Pending);

	// ---- The four generation triggers ----

	/** `[V]` A rival SABOTAGE on a PLAYER venue provokes retaliation; a PROBE is pressure,
	 *  not a provocation, and produces nothing. An EXPAND onto any venue (it is the rival's
	 *  now) produces Contested Ground. Ownership is checked for sabotage ONLY. */
	void OnRivalSabotage(FBMCampaignState& State, const FBMVenueState& Venue,
		const FString& RivalId, int32 Tick);
	void OnRivalExpand(FBMCampaignState& State, const FBMVenueState& Venue,
		const FString& RivalId, int32 Tick);

	/** `[V]` A sweep landing while evidence cases pin the district offers the aimed strike
	 *  against the STRONGEST case. No cases, no job — that sweep was pure heat, and pausing
	 *  rackets already answers it. */
	void OnInspectionStarted(FBMCampaignState& State, const FString& DistrictId, int32 Tick);

	/** `[V]` A betrayal handed a venue to the rival — the same job as an EXPAND loss. */
	void OnBetrayalCommitted(FBMCampaignState& State, const FBMVenueState& Venue,
		const FString& RivalId, int32 Tick);

	// ---- The tick pass ----

	/**
	 * One strategic tick of the job pass: every active job's deadline tick in ARRAY ORDER,
	 * applying the outcome of any that just expired, then the follow-up countdown.
	 *
	 * `[V]` The order matters — a job expiring this tick can schedule a follow-up, and that
	 * follow-up must get its FULL lead rather than being decremented on the same tick it was
	 * created. Ticking the follow-ups first would shorten every one of them by one.
	 */
	void AdvanceTick(FBMCampaignState& State, int32 Tick);

	/**
	 * Applies a resolved job's outcome and runs the three origin branches.
	 *
	 * `[V]` The branch ORDER is the oracle's: ApplyOutcome (which may erode passively), then
	 * EvidenceChain's aimed removal, then RivalProvocation's grudge, then TerritoryLoss's
	 * reclaim, then the follow-up schedule. Each is an ORIGIN-GATED SINGLE WRITE.
	 */
	void ApplyAndFinalize(FBMCampaignState& State, FBMJob& Job, int32 Tick);

private:
	/** `[V]` The district a job's consequences land in: by venue for venue-bound jobs, or
	 *  parsed out of the generated id for case-bound burycase jobs, which have no venue. */
	static FBMDistrictState* DistrictOf(FBMCampaignState& State, const FBMJob& Job);
};
```

Add the member to `FBMCampaignState` in
`D:\black-meridian-ue\Source\BMCore\Public\BMCampaignState.h` (include `BMJobDirector.h` at the
top, alongside `BMTypes.h`):

```cpp
	/**
	 * `[V]` Job state lives ON the campaign, decided in S3. The save contract has to
	 * serialize it with everything else, AdvanceTick's signature stays one parameter so the
	 * golden vectors and the probe keep measuring one unit (S2 Correction 6), and jobs join
	 * BM.Determinism.TickIsReproducible's interleaved two-campaign run for free.
	 */
	FBMJobDirector Jobs;
```

Create `D:\black-meridian-ue\Source\BMCore\Private\BMJobDirector.cpp`:

```cpp
#include "BMJobDirector.h"

#include "BMCampaignState.h"
#include "BMConstants.h"
#include "BMEvidence.h"
#include "BMJobGenerator.h"
#include "BMJobIdParser.h"
#include "BMJobLifecycle.h"
#include "BMTypes.h"

int32 FBMJobDirector::FindJob(const FString& JobId) const
{
	for (int32 i = 0; i < ActiveJobs.Num(); ++i)
	{
		if (ActiveJobs[i].Id == JobId)
		{
			return i;
		}
	}
	return INDEX_NONE;
}

int32 FBMJobDirector::UnresolvedCount() const
{
	int32 Count = 0;
	for (const FBMJob& Job : ActiveJobs)
	{
		if (Job.Stage != EBMJobStage::Resolved)
		{
			++Count;
		}
	}
	return Count;
}

void FBMJobDirector::Offer(const FBMJob& Job)
{
	FBMJob Offered = Job;
	Offered.Stage = EBMJobStage::Intake;
	Offered.TicksRemaining = Offered.DeadlineTicks;
	ActiveJobs.Add(MoveTemp(Offered));
}

bool FBMJobDirector::TryOffer(const FBMJob& Job)
{
	// `[V]` Dedupe FIRST. Two triggers on the same venue at the same tick build the SAME id
	// by construction — that collision is what this check exists for, and it must not consume
	// a slot on its way to being refused.
	if (FindJob(Job.Id) != INDEX_NONE)
	{
		return false;
	}

	// `[V]` At the cap the trigger is DROPPED, not queued. The P08 decision.
	if (UnresolvedCount() >= BMConst::MaxConcurrentJobs)
	{
		return false;
	}

	Offer(Job);
	return true;
}

void FBMJobDirector::RestoreJobs(TArray<FBMJob>&& Jobs, TArray<FBMPendingFollowup>&& Pending)
{
	// `[V]` No stage or deadline reset — the save's runtime state is already applied.
	ActiveJobs = MoveTemp(Jobs);
	PendingFollowups = MoveTemp(Pending);
}

void FBMJobDirector::OnRivalSabotage(FBMCampaignState& State, const FBMVenueState& Venue,
	const FString& RivalId, int32 Tick)
{
	// `[V]` Only on a PLAYER venue. A sabotage on someone else's business is not the
	// Resolver's problem.
	if (Venue.OwnerFaction != State.PlayerFactionId)
	{
		return;
	}

	const FBMFactionState* Rival = State.FindFaction(RivalId);
	if (Rival == nullptr)
	{
		return;
	}

	TryOffer(FBMJobGenerator::RetaliationJob(Venue, Venue.Id, *Rival, Rival->Id, Tick));
}

void FBMJobDirector::OnRivalExpand(FBMCampaignState& State, const FBMVenueState& Venue,
	const FString& RivalId, int32 Tick)
{
	// `[V]` No ownership check here — the venue is the RIVAL's now, which is the problem.
	const FBMFactionState* Rival = State.FindFaction(RivalId);
	if (Rival == nullptr)
	{
		return;
	}

	TryOffer(FBMJobGenerator::ContestedGroundJob(Venue, Venue.Id, *Rival, Rival->Id, Tick));
}

void FBMJobDirector::OnInspectionStarted(FBMCampaignState& State, const FString& DistrictId,
	int32 Tick)
{
	FBMDistrictState* District = State.FindDistrict(DistrictId);
	if (District == nullptr)
	{
		return;
	}

	// `[V]` No cases, no job. The sweep was pure heat.
	const int32 Strongest = FBMEvidence::StrongestCase(*District);
	if (Strongest == INDEX_NONE)
	{
		return;
	}

	TryOffer(FBMJobGenerator::BuryCaseJob(
		District->EvidenceCases[Strongest], *District, District->Id, Tick));
}

void FBMJobDirector::OnBetrayalCommitted(FBMCampaignState& State, const FBMVenueState& Venue,
	const FString& RivalId, int32 Tick)
{
	// `[V]` Same job as an EXPAND loss — reclaim it.
	OnRivalExpand(State, Venue, RivalId, Tick);
}

FBMDistrictState* FBMJobDirector::DistrictOf(FBMCampaignState& State, const FBMJob& Job)
{
	for (FBMDistrictState& District : State.Districts)
	{
		for (const FBMVenueState& Venue : District.Venues)
		{
			if (Venue.Id == Job.VenueId)
			{
				return &District;
			}
		}
	}

	// `[V]` A burycase job has no venue; its district is encoded in the id.
	FBMParsedJobId Parsed;
	if (FBMJobIdParser::Parse(Job.Id, Parsed)
		&& Parsed.Template == EBMJobIdTemplate::BuryCase)
	{
		return State.FindDistrict(Parsed.DistrictId);
	}

	return nullptr;
}

void FBMJobDirector::ApplyAndFinalize(FBMCampaignState& State, FBMJob& Job, int32 Tick)
{
	FBMDistrictState* District = DistrictOf(State, Job);
	FBMFactionState* Player = State.PlayerFaction();
	if (Player == nullptr)
	{
		return;
	}

	FBMJobLifecycle::ApplyOutcome(Job, *Player, District, Tick);

	// --- Branch 1: EvidenceChain. The AIMED strike. --------------------------------------
	// `[V]` A burn that actually suppressed trace (net negative) removes its TARGETED case —
	// distinct from ApplyOutcome's passive strongest-first erosion. Two mechanisms,
	// deliberately. A botched burn (net positive) leaves the case standing and has already
	// deposited fresh trace above.
	if (Job.Origin == EBMJobOrigin::EvidenceChain && District != nullptr
		&& Job.Outcome.EvidenceGenerated < 0.0f)
	{
		FBMParsedJobId Parsed;
		if (FBMJobIdParser::Parse(Job.Id, Parsed)
			&& Parsed.Template == EBMJobIdTemplate::BuryCase
			&& !Parsed.CaseId.IsEmpty())
		{
			FBMEvidence::RemoveCase(*District, Parsed.CaseId);
		}
	}

	// --- Branch 2: RivalProvocation. The feud closes. ------------------------------------
	// `[V]` When the player resolves the retaliation a rival provoked, that rival remembers:
	// its grudge rises by the job's rival_suspicion. This is the SINGLE WRITER of grudge
	// upward; the rival director decays it. The provocateur is identified from the id, never
	// from a stored reference.
	if (Job.Origin == EBMJobOrigin::RivalProvocation && Job.Outcome.RivalSuspicion > 0.0f)
	{
		FBMParsedJobId Parsed;
		if (FBMJobIdParser::Parse(Job.Id, Parsed)
			&& Parsed.Template == EBMJobIdTemplate::Retaliation)
		{
			if (FBMFactionState* Rival = State.FindFaction(Parsed.RivalId))
			{
				Rival->Grudge = FMath::Clamp(
					Rival->Grudge + Job.Outcome.RivalSuspicion, 0.0f, 1.0f);
			}
		}
	}

	// --- Branch 3: TerritoryLoss. The reclaim. -------------------------------------------
	// `[V]` A real objective takes the venue back — but to CONTESTED, not full control.
	// Disputed ground keeps the loop alive; a full reclaim would close the thread the job
	// opened. Same >= 0.5 gate as the cash reward.
	if (Job.Origin == EBMJobOrigin::TerritoryLoss && Job.Outcome.ObjectiveAchieved >= 0.5f)
	{
		int32 DistrictIndex = INDEX_NONE;
		const int32 VenueIndex = FBMJobGenerator::FindVenue(State.Districts, Job.VenueId,
			DistrictIndex);
		if (VenueIndex != INDEX_NONE)
		{
			FBMVenueState& Venue = State.Districts[DistrictIndex].Venues[VenueIndex];
			Venue.OwnerFaction = State.PlayerFactionId;
			Venue.ControlState = EBMControlState::Contested;
		}
	}

	// --- The follow-up schedule ----------------------------------------------------------
	// `[V]` A heavy delayed consequence spawns the problem ApplyOutcome had been holding.
	// The loop never simply empties (brief §5.1). Note it stores the VENUE id, not a job —
	// the follow-up is built from the venue at fire time.
	if (Job.Outcome.DelayedConsequence >= BMConst::FollowupThreshold)
	{
		PendingFollowups.Add(FBMPendingFollowup(BMConst::FollowupLeadTicks, Job.VenueId));
	}
}

void FBMJobDirector::AdvanceTick(FBMCampaignState& State, int32 Tick)
{
	// `[V]` Deadlines first, in ARRAY ORDER. Indexed rather than ranged-for because
	// ApplyAndFinalize can append to PendingFollowups — it does not touch ActiveJobs, but an
	// index keeps that true if it ever does.
	for (int32 i = 0; i < ActiveJobs.Num(); ++i)
	{
		if (FBMJobLifecycle::Tick(ActiveJobs[i]))
		{
			ApplyAndFinalize(State, ActiveJobs[i], Tick);
		}
	}

	// `[V]` Follow-ups SECOND. A job expiring this tick schedules a follow-up with the full
	// lead; counting down first would shave one tick off every one of them.
	TArray<FBMPendingFollowup> Still;
	TArray<FString> Due;

	for (FBMPendingFollowup& Entry : PendingFollowups)
	{
		--Entry.TicksLeft;
		if (Entry.TicksLeft <= 0)
		{
			Due.Add(Entry.VenueId);
		}
		else
		{
			Still.Add(Entry);
		}
	}
	PendingFollowups = MoveTemp(Still);

	for (const FString& VenueId : Due)
	{
		int32 DistrictIndex = INDEX_NONE;
		const int32 VenueIndex = FBMJobGenerator::FindVenue(State.Districts, VenueId,
			DistrictIndex);
		if (VenueIndex != INDEX_NONE)
		{
			const FBMVenueState& Venue = State.Districts[DistrictIndex].Venues[VenueIndex];
			TryOffer(FBMJobGenerator::FollowupJob(Venue, Venue.Id, Tick));
		}
	}
}
```

Finally, wire the pass into the tick in
`D:\black-meridian-ue\Source\BMCore\Private\BMSimulation.cpp`, at the seam S2 left marked:

```cpp
void FBMSimulation::AdvanceTick(FBMCampaignState& State)
{
	++State.TickIndex;

	// ORDER IS CONTRACT. See the header and 04 §5.
	Settle(State);                 // 1. clear exposure -> settle each faction (array order)
	UpdateDistrictHeat(State);     // 2. consumes THIS tick's exposure
	UpdateCentralPressure(State);  // 3. consumes THIS tick's district heat
	State.Jobs.AdvanceTick(State, State.TickIndex);  // 4. deadlines, then follow-ups

	// 5-6 (night cycle, narrative) and the rival tick arrive in later slices.
}
```

> **A note the executing engineer must not skip.** Adding step 4 changes what an 1800-tick probe
> run produces, which means `BM.Equivalence.TrajectoryMatchesOracle` may move. It should **not**
> move for a seeded world with no job triggers firing — nothing offers a job unless a rival action,
> an inspection or a betrayal calls in. **Run the equivalence test before and after this edit and
> confirm the ticks-0–240 window is unchanged.** If it moves, the job pass is doing something on an
> empty director, and that is a bug in this task, not a re-baseline.

- [ ] **Step 4: Run to verify it passes**

Run:
```sh
"C:/Program Files/Epic Games/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" \
    D:/black-meridian-ue/BlackMeridian.uproject \
    -ExecCmds="Automation RunTests BM; Quit" -unattended -nopause -nullrhi -nosplash -NoLiveCoding \
    -testexit="Automation Test Queue Empty"
```
Expected — the full suite, S2's 23 plus S3's, all green:
```
BM.Jobs.CadenceCapDropsAtCapacity                  Result={Success}
BM.Jobs.DirectorNeedsNoGameInstance                Result={Success}
BM.Jobs.DuplicateIdDroppedBeforeCapCheck           Result={Success}
BM.Jobs.FollowupSchedulesAndFires                  Result={Success}
BM.Jobs.PostOutcomeOriginBranches                  Result={Success}
...
BM.Equivalence.TrajectoryMatchesOracle             Result={Success}   ticks 0-240, unchanged
**** TEST COMPLETE. EXIT CODE: 0 ****              0 fail · 0 errors
```

- [ ] **Step 5: Commit**

```bash
cd /d/black-meridian-ue
git add Source/BMCore/Public/BMJobDirector.h Source/BMCore/Private/BMJobDirector.cpp \
        Source/BMCore/Public/BMCampaignState.h Source/BMCore/Private/BMSimulation.cpp \
        Source/BMCore/Private/BMJobBehaviorTest.cpp
git commit -m "feat(s3): FBMJobDirector — state, cadence cap, triggers, origin branches

A plain struct in BMCore, and a member of FBMCampaignState. A
UGameInstanceSubsystem cannot be NewObject'd in a test (S2 measured this: a
CoreUObject ensure the framework promotes to a failure while every assertion
passes), and S3 has real per-campaign state, so no S3 test constructs one.
State on the campaign keeps AdvanceTick one parameter and one definition of a
tick, and jobs join the interleaved two-campaign determinism run for free.

Cadence cap: at most 3 unresolved, dedupe before capacity, and a trigger at
the cap is DROPPED, never queued. Three origin-gated post-outcome branches:
EvidenceChain burns the TARGETED case (distinct from the passive
strongest-first erosion), RivalProvocation raises the provocateur's grudge
from the id, TerritoryLoss reclaims to CONTESTED so the loop stays alive.

The job pass slots in as step 4 of AdvanceTick. Deadlines before follow-ups,
so a follow-up scheduled this tick gets its full lead.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: `UBMJobSubsystem` — the facade

Every method is a one-line forward to the `FBMJobDirector` this subsystem holds. It exists for the
same reason `UBMEconomySubsystem` does: scheduling and the presentation boundary live in BMSim, the
rules live in BMCore. S2's gate evidence says it plainly — *"every facade is a one-line forward."*

The test at the end is unusual and deliberate: it asserts the subsystem **contains no logic**, by
scanning its own source for the control flow that would indicate a rule leaked across the module
boundary. A rule that drifts into BMSim is a rule the golden vectors cannot reach.

**Files:**
- Create: `D:\black-meridian-ue\Source\BMSim\Public\BMJobSubsystem.h`
- Create: `D:\black-meridian-ue\Source\BMSim\Private\BMJobSubsystem.cpp`
- Test: `D:\black-meridian-ue\Source\BMSim\Private\BMJobSubsystemTest.cpp`

- [ ] **Step 1: Write the failing test**

Create `D:\black-meridian-ue\Source\BMSim\Private\BMJobSubsystemTest.cpp`:

```cpp
#include "BMJobDirector.h"
#include "BMJobSubsystem.h"
#include "BMJobTypes.h"

#include "CoreMinimal.h"
#include "HAL/FileManager.h"
#include "Misc/AutomationTest.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"

/**
 * S3 subsystem test. There is nothing here to measure numerically — the subsystem computes
 * nothing — so what is asserted instead is that it STAYS that way.
 *
 * `[V]` No instance is constructed. A UGameInstanceSubsystem carries
 * ClassWithin = UGameInstance and NewObject into the transient package trips a CoreUObject
 * ensure the framework promotes to a failure (S2, measured). Every forward here needs a live
 * campaign anyway, so the honest test is a structural one.
 */

// ---------------------------------------------------------------------------
// BM.Jobs.SubsystemIsAThinFacade
// ---------------------------------------------------------------------------

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
	FBMJobSubsystemIsAThinFacadeTest,
	"BM.Jobs.SubsystemIsAThinFacade",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FBMJobSubsystemIsAThinFacadeTest::RunTest(const FString&)
{
	const FString SubsystemSource = FPaths::Combine(FPaths::ProjectDir(),
		TEXT("Source"), TEXT("BMSim"), TEXT("Private"), TEXT("BMJobSubsystem.cpp"));

	FString Contents;
	if (!FFileHelper::LoadFileToString(Contents, *SubsystemSource))
	{
		AddError(FString::Printf(TEXT("cannot read %s"), *SubsystemSource));
		return false;
	}

	// Strip comments before scanning: the file EXPLAINS the rules it must not implement, and
	// the words appear in prose. Only code is scanned.
	TArray<FString> Lines;
	Contents.ParseIntoArrayLines(Lines, /*InCullEmpty=*/false);

	TArray<FString> Offenders;
	int32 CodeLines = 0;

	for (int32 i = 0; i < Lines.Num(); ++i)
	{
		FString Line = Lines[i].TrimStartAndEnd();
		if (Line.IsEmpty() || Line.StartsWith(TEXT("//")) || Line.StartsWith(TEXT("*"))
			|| Line.StartsWith(TEXT("/*")))
		{
			continue;
		}
		++CodeLines;

		// The signature of a rule: a loop, or arithmetic on simulation values. A guard
		// (`if (Director == nullptr) return;`) is scheduling, not a rule, and is allowed —
		// so `if` is not in this list, but the things a RULE needs are.
		struct FSignature { const TCHAR* Token; const TCHAR* Why; };
		const FSignature Signatures[] = {
			{ TEXT("for ("),        TEXT("iteration — the director owns every loop over jobs") },
			{ TEXT("while ("),      TEXT("iteration") },
			{ TEXT("FMath::Clamp"), TEXT("a clamp is a rule; BMCore owns every clamp") },
			{ TEXT("BMConst::"),    TEXT("a threshold read here means a decision is made here") },
			{ TEXT("EBMJobStage::"),TEXT("stage comparison — the stage machine lives in BMCore") },
		};

		for (const FSignature& Signature : Signatures)
		{
			if (Line.Contains(Signature.Token))
			{
				Offenders.Add(FString::Printf(TEXT("line %d: %s (%s)"),
					i + 1, *Line, Signature.Why));
			}
		}
	}

	for (const FString& Offender : Offenders)
	{
		AddError(FString::Printf(
			TEXT("BMJobSubsystem.cpp must be one-line forwards only — %s"), *Offender));
	}

	AddInfo(FString::Printf(TEXT("BMJobSubsystem.cpp: %d code lines"), CodeLines));

	// Every public method on the header must have a counterpart on FBMJobDirector. This is
	// the half that catches a forward gaining a second behavior rather than a new rule.
	const FString SubsystemHeader = FPaths::Combine(FPaths::ProjectDir(),
		TEXT("Source"), TEXT("BMSim"), TEXT("Public"), TEXT("BMJobSubsystem.h"));
	const FString DirectorHeader = FPaths::Combine(FPaths::ProjectDir(),
		TEXT("Source"), TEXT("BMCore"), TEXT("Public"), TEXT("BMJobDirector.h"));

	FString SubsystemText;
	FString DirectorText;
	if (FFileHelper::LoadFileToString(SubsystemText, *SubsystemHeader)
		&& FFileHelper::LoadFileToString(DirectorText, *DirectorHeader))
	{
		const TCHAR* ForwardedNames[] = {
			TEXT("TryOffer"), TEXT("UnresolvedCount"), TEXT("FindJob"),
			TEXT("RestoreJobs"), TEXT("AdvanceTick"),
		};
		for (const TCHAR* Name : ForwardedNames)
		{
			if (SubsystemText.Contains(Name) && !DirectorText.Contains(Name))
			{
				AddError(FString::Printf(
					TEXT("UBMJobSubsystem exposes '%s' with no FBMJobDirector counterpart — it is not a forward, it is new behavior"),
					Name));
			}
		}
	}
	else
	{
		AddError(TEXT("cannot read the subsystem and director headers to compare them"));
	}

	return Offenders.Num() == 0;
}
```

- [ ] **Step 2: Run it to verify it fails**

Run:
```sh
"C:/Program Files/Epic Games/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" \
    D:/black-meridian-ue/BlackMeridian.uproject \
    -ExecCmds="Automation RunTests BM.Jobs.SubsystemIsAThinFacade; Quit" \
    -unattended -nopause -nullrhi -nosplash -NoLiveCoding \
    -testexit="Automation Test Queue Empty"
```
Expected: build failure, `fatal error C1083: Cannot open include file: 'BMJobSubsystem.h'`.

- [ ] **Step 3: Implement**

Create `D:\black-meridian-ue\Source\BMSim\Public\BMJobSubsystem.h`:

```cpp
#pragma once

#include "BMJobTypes.h"
#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"

#include "BMJobSubsystem.generated.h"

struct FBMCampaignState;
struct FBMJobDirector;
struct FBMVenueState;

/**
 * A facade over the BMCore job system, plus the player verbs from brief §7.5.
 *
 * `[V]` Every method here is ONE LINE — it resolves the campaign and forwards. The rules
 * live in FBMJobDirector, FBMJobLifecycle and FBMJobResolution, which is what the golden
 * vectors measure. A rule that drifts into this file is a rule the fixture cannot reach, so
 * BM.Jobs.SubsystemIsAThinFacade scans the .cpp for the signature of one.
 *
 * `[V]` Unlike UBMEconomySubsystem's verbs, these are NOT static: the job state is a member
 * of the campaign and every call needs to reach it. That is exactly why FBMJobDirector is a
 * plain struct rather than this class — see its header for the CoreUObject ensure that makes
 * a subsystem untestable.
 *
 * The Godot autoload also emitted job_offered / job_stage_changed / job_resolved. Those are
 * the presentation boundary and belong here rather than in BMCore, which has no delegates.
 * They arrive with the UI slice; the forwards below are the surface they will fire from.
 */
UCLASS()
class BMSIM_API UBMJobSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	/** Offer a job through the cadence gate. Returns false for a duplicate or a drop at the
	 *  cap — see FBMJobDirector::TryOffer, which owns both decisions. */
	bool TryOffer(const FBMJob& Job);

	/** How many jobs are not yet resolved. The cap measures this, not the total. */
	int32 UnresolvedCount() const;

	/** Index of a job by id in the campaign's ActiveJobs, or INDEX_NONE. */
	int32 FindJob(const FString& JobId) const;

	// ---- Player verbs (brief §7.5) ----
	// Each resolves the job by id and forwards to the pure stage machine.

	bool Begin(const FString& JobId);
	bool ChoosePrep(const FString& JobId, const FString& ChoiceId);
	bool ChooseApproach(const FString& JobId, const FString& ChoiceId);

	/** `[V]` Atomic: INTERVENTION -> COVER_UP -> RESOLVED, then the director's post-outcome
	 *  branches. The two calls are one player action and must not be split at this boundary. */
	bool ChooseCoverup(const FString& JobId, const FString& ChoiceId);

	/** Replace job state from a loaded save. */
	void RestoreJobs(TArray<FBMJob>&& Jobs, TArray<FBMPendingFollowup>&& Pending);

	/** The job pass. `[V]` FBMSimulation::AdvanceTick already runs this as step 4; this
	 *  exists for the probe, the UI and any slice that needs the pass alone — the same
	 *  reason UBMEconomySubsystem::Settle exists. */
	void AdvanceTick(int32 Tick);

private:
	/** Null only before a GameInstance exists (a raw CDO). Every caller checks. */
	FBMCampaignState* State() const;

	/** The one director, which lives on the campaign. Null with the campaign. */
	FBMJobDirector* Director() const;
};
```

Create `D:\black-meridian-ue\Source\BMSim\Private\BMJobSubsystem.cpp`:

```cpp
#include "BMJobSubsystem.h"

#include "BMCampaignState.h"
#include "BMCampaignSubsystem.h"
#include "BMJobDirector.h"
#include "BMJobLifecycle.h"

FBMCampaignState* UBMJobSubsystem::State() const
{
	UGameInstance* GI = GetGameInstance();
	if (GI == nullptr)
	{
		return nullptr;
	}

	UBMCampaignSubsystem* Campaign = GI->GetSubsystem<UBMCampaignSubsystem>();
	return Campaign != nullptr ? &Campaign->GetMutableState() : nullptr;
}

FBMJobDirector* UBMJobSubsystem::Director() const
{
	FBMCampaignState* Campaign = State();
	return Campaign != nullptr ? &Campaign->Jobs : nullptr;
}

bool UBMJobSubsystem::TryOffer(const FBMJob& Job)
{
	FBMJobDirector* D = Director();
	return D != nullptr ? D->TryOffer(Job) : false;
}

int32 UBMJobSubsystem::UnresolvedCount() const
{
	FBMJobDirector* D = Director();
	return D != nullptr ? D->UnresolvedCount() : 0;
}

int32 UBMJobSubsystem::FindJob(const FString& JobId) const
{
	FBMJobDirector* D = Director();
	return D != nullptr ? D->FindJob(JobId) : INDEX_NONE;
}

bool UBMJobSubsystem::Begin(const FString& JobId)
{
	FBMJobDirector* D = Director();
	const int32 Index = D != nullptr ? D->FindJob(JobId) : INDEX_NONE;
	return Index != INDEX_NONE ? FBMJobLifecycle::Begin(D->ActiveJobs[Index]) : false;
}

bool UBMJobSubsystem::ChoosePrep(const FString& JobId, const FString& ChoiceId)
{
	FBMJobDirector* D = Director();
	const int32 Index = D != nullptr ? D->FindJob(JobId) : INDEX_NONE;
	return Index != INDEX_NONE
		? FBMJobLifecycle::ChoosePrep(D->ActiveJobs[Index], ChoiceId) : false;
}

bool UBMJobSubsystem::ChooseApproach(const FString& JobId, const FString& ChoiceId)
{
	FBMJobDirector* D = Director();
	const int32 Index = D != nullptr ? D->FindJob(JobId) : INDEX_NONE;
	return Index != INDEX_NONE
		? FBMJobLifecycle::ChooseApproach(D->ActiveJobs[Index], ChoiceId) : false;
}

bool UBMJobSubsystem::ChooseCoverup(const FString& JobId, const FString& ChoiceId)
{
	FBMCampaignState* Campaign = State();
	const int32 Index = Campaign != nullptr ? Campaign->Jobs.FindJob(JobId) : INDEX_NONE;
	if (Index == INDEX_NONE
		|| !FBMJobLifecycle::ChooseCoverup(Campaign->Jobs.ActiveJobs[Index], ChoiceId))
	{
		return false;
	}

	// `[V]` The resolution and its consequences are ONE player action. Splitting them here
	// would let a caller resolve a job and skip its branches.
	Campaign->Jobs.ApplyAndFinalize(*Campaign, Campaign->Jobs.ActiveJobs[Index],
		Campaign->TickIndex);
	return true;
}

void UBMJobSubsystem::RestoreJobs(TArray<FBMJob>&& Jobs, TArray<FBMPendingFollowup>&& Pending)
{
	FBMJobDirector* D = Director();
	if (D != nullptr)
	{
		D->RestoreJobs(MoveTemp(Jobs), MoveTemp(Pending));
	}
}

void UBMJobSubsystem::AdvanceTick(int32 Tick)
{
	FBMCampaignState* Campaign = State();
	if (Campaign != nullptr)
	{
		Campaign->Jobs.AdvanceTick(*Campaign, Tick);
	}
}
```

> **A note for the implementer.** `ChooseCoverup`'s body touches three lines, not one, because the resolve and the
> post-outcome branches are one player action. That is the single justified exception to the
> one-line rule, and the facade test's signature list is written so it passes — no loop, no clamp,
> no threshold, no stage comparison. **If you find yourself adding a fourth line with a condition in
> it, the logic belongs in `FBMJobDirector`, not here.**

- [ ] **Step 4: Run to verify it passes**

Run:
```sh
"C:/Program Files/Epic Games/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" \
    D:/black-meridian-ue/BlackMeridian.uproject \
    -ExecCmds="Automation RunTests BM; Quit" -unattended -nopause -nullrhi -nosplash -NoLiveCoding \
    -testexit="Automation Test Queue Empty"
```
Expected:
```
BM.Jobs.SubsystemIsAThinFacade                     Result={Success}   BMJobSubsystem.cpp: ~70 code lines
...
**** TEST COMPLETE. EXIT CODE: 0 ****              0 fail · 0 errors
```

- [ ] **Step 5: Commit**

```bash
cd /d/black-meridian-ue
git add Source/BMSim/Public/BMJobSubsystem.h Source/BMSim/Private/BMJobSubsystem.cpp \
        Source/BMSim/Private/BMJobSubsystemTest.cpp
git commit -m "feat(s3): UBMJobSubsystem — the facade, and a test that keeps it thin

One-line forwards to the FBMJobDirector on the campaign. The rules stay in
BMCore where the golden vectors reach them.

The test is structural rather than numeric, because the subsystem computes
nothing: it scans the .cpp for the signature of a rule that leaked across the
module boundary — a loop, a clamp, a BMConst threshold, a stage comparison —
and checks every exposed method has a director counterpart.

ChooseCoverup is the one justified multi-line forward: resolve and the
post-outcome branches are a single player action and must not be splittable
at this boundary.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

# Gate verification

## The command

Identical in shape to S2's, which is recorded in `Docs/gates/S2.md`:

```sh
UnrealEditor-Cmd.exe D:\black-meridian-ue\BlackMeridian.uproject \
    -ExecCmds="Automation RunTests BM; Quit" -unattended -nopause -nullrhi -nosplash -NoLiveCoding \
    -testexit="Automation Test Queue Empty"
```

Run the **whole `BM` suite**, not just `BM.Jobs`. S3 edits `FBMCampaignState` and
`FBMSimulation::AdvanceTick`, both of which S2's tests measure; a green `BM.Jobs` over a red
`BM.Equivalence` is not a passed gate.

**The editor build must also succeed with 0 warnings.** That was S0's bar and S2 held it.

## Expected test names

S3's additions — 14 tests across three files:

| Test | File | What fails if it is wrong |
|---|---|---|
| `BM.Jobs.EnumValuesAreSaveContract` | `BMJobTest.cpp` | Every saved job's origin and stage means something else |
| `BM.Jobs.IdParseContract` | `BMJobTest.cpp` | The positional parse; a wrong count throwing instead of refusing |
| `BM.Jobs.IdParserIsSingleImplementation` | `BMJobTest.cpp` | A second `@`-splitter drifting from the first |
| `BM.Jobs.ResolutionMatchesGodotVectors` | `BMJobTest.cpp` | The clamp-once rule and the signed/unsigned split |
| `BM.Jobs.LifecycleMatchesGodotVectors` | `BMJobTest.cpp` | Any stage guard, the atomic cover-up, the deadline tick |
| `BM.Jobs.VariantIndexMatchesGodotVectors` | `BMJobTest.cpp` | Which text the player reads, forever |
| `BM.Jobs.GeneratedIdRoundTrips` | `BMJobTest.cpp` | **The gate condition** — saves that cannot rebuild their jobs |
| `BM.Jobs.VariantsShareChoiceIds` | `BMJobBehaviorTest.cpp` | A load silently dropping the player's choices |
| `BM.Jobs.TemplatesHonorBalanceEnvelope` | `BMJobBehaviorTest.cpp` | The feud quietly severed from the heat system |
| `BM.Jobs.CadenceCapDropsAtCapacity` | `BMJobBehaviorTest.cpp` | Problems arriving as a flood instead of beats |
| `BM.Jobs.DuplicateIdDroppedBeforeCapCheck` | `BMJobBehaviorTest.cpp` | A same-tick collision consuming a slot |
| `BM.Jobs.PostOutcomeOriginBranches` | `BMJobBehaviorTest.cpp` | The three consequence branches, each silently |
| `BM.Jobs.FollowupSchedulesAndFires` | `BMJobBehaviorTest.cpp` | The loop emptying instead of regenerating |
| `BM.Jobs.DirectorNeedsNoGameInstance` | `BMJobBehaviorTest.cpp` | The architectural decision quietly reversed |
| `BM.Jobs.SubsystemIsAThinFacade` | `BMJobSubsystemTest.cpp` | A rule drifting where the vectors cannot reach it |

Plus S2's 23, all of which must stay green:

```
BM.Determinism.Hash_MatchesGodotVectors            BM.Economy.SettleOrder
BM.Determinism.Hash_SingleImplementation           BM.Equivalence.SeedMatchesOracle
BM.Determinism.NoRandomInSimModule                 BM.Equivalence.TrajectoryMatchesOracle
BM.Determinism.TickIsReproducible                  BM.Evidence.MatchesGodotVectors
BM.Determinism.ProbeIsReproducible                 BM.Heat.InspectionHysteresis
BM.Economy.MatchesGodotVectors                     BM.Heat.InspectionLatchReadsCombinedPressure
BM.Economy.OperativesConservation                  BM.Heat.MatchesGodotVectors
BM.Economy.PausedRacketZeroYield                   BM.Pressure.AlertLifecycle
BM.Economy.PressureFrontCapAndCost                 BM.Pressure.AlertRelievesInspectionThreshold
                                                   BM.Pressure.MatchesGodotVectors
BM.Time.DrainLoopCatchUp                           BM.Time.TickOrderIsContract
BM.Smoke
```

**Target: 38/38, exit code 0, zero errors.**

Two of S2's deserve a specific look after this slice, because S3 touches what they measure:

- **`BM.Determinism.TickIsReproducible`** now advances two campaigns that each carry a
  `FBMJobDirector`. It should still pass untouched — and if it does not, job state is leaking
  between campaigns, which is precisely the failure the plain-struct-on-the-campaign decision was
  made to prevent.
- **`BM.Equivalence.TrajectoryMatchesOracle`** covers ticks 0–240 and must be **bit-identical to its
  pre-S3 result**. Nothing offers a job unless a rival action, an inspection or a betrayal calls in,
  and the seeded world triggers none of those in that window. **Record the before and after values
  in `Docs/gates/S3.md`.** A moved trajectory here is a bug in Task 11, not a re-baseline.

## Mutation testing

S2 established this discipline after first-run green turned out to be weak evidence — **three real
test gaps were found this way**, and two of them would each have shipped a compiling, deterministic,
wrong game with no symptom. The failure class in S3 is the same: *silently different but still
deterministic*.

So: introduce each mutation below, run the gate, confirm it goes **red**, then revert. A mutation
the gate does not catch is a **fixture or test gap to close before claiming the gate**, exactly as
S2 closed its three.

| # | Mutation | Where | Must be caught by | If it passes |
|---|---|---|---|---|
| 1 | **Clamp per term** — move `Clamp(Out)` from the end of `Resolve` into `Accumulate`, after each `+=` | `BMJobResolution.cpp` | `BM.Jobs.ResolutionMatchesGodotVectors`, on the `over_clamp_unsigned` and `signed_negative_then_positive` rows | The fixture's overshoot rows are not overshooting enough. Add a case with two same-sign contributions that individually exceed 1.0 AND a signed axis that dips below -1.0 mid-accumulation before returning in range. |
| 2 | **Decrement before the resolved check** — in `FBMJobLifecycle::Tick`, move `--Job.TicksRemaining` above the `Stage == Resolved` early return | `BMJobLifecycle.cpp` | `BM.Jobs.LifecycleMatchesGodotVectors`, on `tick_already_resolved_noop` (its `ticks_remaining_after` is 1, unchanged) | The test is reconstructing the pre-state wrong. This is the row the extractor added specifically for this mutation — check the `tick_` branch of the pre-state derivation. |
| 3 | **Swap the prep cap and toggle-off** — in `ChoosePrep`, move the `ChosenPrep.Num() >= Max` check above the `Contains` branch | `BMJobLifecycle.cpp` | `BM.Jobs.LifecycleMatchesGodotVectors`, on `prep_at_cap_toggle_off_allowed` | The dispatcher is not reaching that row. Verify `RunLifecycleCall` maps it to `ChoosePrep(Job, "p2")` and not to the `p1` branch. |
| 4 | **Queue instead of drop** — in `TryOffer`, when at capacity, append to a pending list instead of returning false | `BMJobDirector.cpp` | `BM.Jobs.CadenceCapDropsAtCapacity`, on the "NOT queued anywhere" assertion | The test only checked `ActiveJobs.Num()`. The `FindJob(Overflow.Id) == INDEX_NONE` assertion is what makes the difference visible — keep it. |
| 5 | **Reclaim to Controlled** — in `ApplyAndFinalize`'s TerritoryLoss branch, set `EBMControlState::Controlled` instead of `Contested` | `BMJobDirector.cpp` | `BM.Jobs.PostOutcomeOriginBranches`, on the "reclaimed to CONTESTED" assertion | The assertion is comparing against a computed value instead of the literal enum. It must name `Contested` explicitly. |
| 6 | **Follow-ups before deadlines** — in `AdvanceTick`, run the follow-up countdown loop before the job-deadline loop | `BMJobDirector.cpp` | `BM.Jobs.FollowupSchedulesAndFires`, on the lead-tick countdown | The test fires the follow-up in a separate phase from the expiry. It must schedule and count down **across the same `AdvanceTick` calls**, so a same-tick decrement shortens the observed lead by one. |

Mutation 1 is the one most likely to pass silently, and it is the reason the extractor's
`over_clamp_unsigned` row exists at all. Mutations 2, 3 and 6 are the S3 analogues of S2's
`else if` → `if` gap: off-by-one errors on a path that ordinary play exercises constantly and that a
happy-path test never distinguishes.

**Record the mutation table's results in `Docs/gates/S3.md`,** caught or not, with what was changed
to close any gap. A gate that cannot fail is not evidence — that sentence is in S2's evidence
document and it earns its place again here.

## What to write into `Docs/gates/S3.md`

Beyond the test log and the mutation table, four items from this plan need recording as decisions
rather than left implicit in the code:

1. **`FBMJobDirector` lives on `FBMCampaignState`** — with the reason (one save snapshot, one
   definition of a tick, free interleaved-determinism coverage), and the rejected alternative.
2. **Display names are not in BMCore**, so `Rebuild` passes ids through and a rebuilt job's
   interpolated text differs from a freshly generated one while every mechanic is identical. Name
   the two ways to close it and the recommendation (a presentation-side name table in BMSim).
3. **`ApplyOutcome`'s involved-character arm is deferred** — the port has no character state type,
   and inventing one was out of scope.
4. **The trajectory comparison's before/after values**, proving the job pass changed nothing on an
   empty director.
