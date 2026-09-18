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
| `Source/BMCore/Tests/BMJobTest.cpp` | Golden-vector tests `GV-JOB-01..04`. |
| `Source/BMCore/Tests/BMJobBehaviorTest.cpp` | The seven named behavior tests from `07` §S3. |

Two test files, split by what fails: a fixture mismatch and a behavior regression are different
investigations. Same reason S1 and S2 kept `hash_vectors.json` and `sim_vectors.json` apart.

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
