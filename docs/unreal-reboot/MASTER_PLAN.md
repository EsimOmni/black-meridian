# MASTER PLAN — OMNI: BLACK MERIDIAN Unreal Reboot

**The control document.** Everything else hangs off this. Read this first; read the rest as needed.

**Status:** Planning complete — **awaiting Cem's approval.** No code written, no project created.
**Date:** 2026-09-18 · **Godot HEAD at audit:** `7aa0872`

---

## 1. Current state

### The Godot build is working software

`[Verified from repository — commands run and recorded in this session]`

| Evidence | Result |
|---|---|
| Headless import | exit 0, zero parse errors |
| Unit suite (24 tests) | **24/24 PASS** |
| `save_roundtrip_runner` | **PASS** — byte-identical restore, deterministic replay, version refusal |
| `bootstrap_smoke_runner` | **PASS** — full job lifecycle + save/load mid-loop |
| Full-cycle probe ×2 | **Byte-identical output.** `VERDICT: LOOP ALIVE` |
| Milestone gates | Months 1–4 **all PASSED** with written evidence notes |
| Splat kill criterion | **SPLAT_OK** — 542k splats @ 483 fps |

⚠️ One correction worth carrying: running the unit suite with `-s` for every test produces **20 false
failures**. The suite is bimodal — `extends SceneTree` tests run via `-s`; `extends Node` tests must
run as `.tscn` or autoloads don't load. See [01_SOURCE_AUDIT.md](01_SOURCE_AUDIT.md) §3.2.

### What the Godot build could not become

`[Verified]` The fourth design pillar — *"Walk through the consequence"* — ships as an 8×6 m box room
with capsule actors, a 2D-portrait-only cast, one room serving both scene types, and a missing
"plant" verb. **That gap is the reboot's entire justification.**

### Working tree

`[Verified]` Uncommitted P20 work (settings / onboarding / audio) is present and was **left exactly as
found**. See **D-08**.

---

## 1b. Plan vs. reality after S0–S4 `[V]`

*Added 2026-09-18 after three slices; extended 2026-09-19 after S3 and S4. Read this before trusting
any `[P]` in the package.*

**Shipped: S0, S1, S2, S3, S4 — all five gates passed.** 56/56 automation tests, exit 0. The plan's
architecture held; its *factual claims about the Godot source* did not — and S4 added a second failure
mode: **two documents prescribing the same impossible thing in two different shapes.**

| | |
|---|---|
| Documents **never needing a correction** | 6 of 16 — `00`, `01`, `02`, `06`, `09`, `11` (+ `ADR-0001`) |
| Documents corrected | 9 — `03`, `04`, `05`, `07`, `08`, `10`, `12`, `13`, `MASTER_PLAN` |
| Corrections folded in | S0 (4) · S1 (3) · S2 (6) · **S3 (5)** · **S4 (9)** = **27** |

**The pattern is the useful part, and it held across all five slices:**

> **Structural judgments were right. Empirical claims about the existing build were wrong roughly
> whenever they were not marked `[V]`.**

Everything load-bearing survived contact: the module split with `BMCore` free of `Engine`; extracting
golden vectors before writing logic; "the strategic simulation is authoritative"; the gate-per-slice
discipline; deferring splats. **Nothing in `00`, `02` or `ADR-0001` has needed a word changed.**

What broke, every time, was a *detail about how Godot actually behaves* that nobody had measured:

| # | Claim | Reality | Cost |
|---|---|---|---|
| 1 | `_avalanche` is splitmix64 (per its own comment) | **MurmurHash3 `fmix64`** | **Red gate.** Hash matched 1719/1719 while avalanche matched 0/1719 |
| 2 | Do the mix in `uint64`, "where the shift is unambiguous" | Shifts are **arithmetic**; pure-`uint64` matches **0 of 3123** | Caught pre-commit |
| 3 | `String.hash()` over bytes | Over **UTF-32 code points** — byte-wise passes every current id and breaks on the first non-ASCII one ever authored | Caught by adversarial corpus |
| 4 | Rival tick is `Relationships → Rival`, and this "preserves observed behavior" | **`Rival → Relationships`** — measured by enumerating the live signal connections | Not yet exercised (S5) |
| 5 | Disruption ramp `(h−0.3)/0.7` | `(h − Grace)/(1 − Grace)` — equal today, divergent once Grace is retuned | Dormant bug with a scheduled trigger |
| 6 | Trajectory measured at 1260 ticks | **1800** — 1260 is the *slice retune*, and the quoted reference values were themselves tick-1800 | Contradiction inside one document |
| 7 | `USTRUCT`/`UENUM` for the state structs | Plain C++ — reflection needs `CoreUObject`, which is the wall | Divergence recorded in `05` §5 |
| 8 | `BM.RunProbe` assumed to exist | Did not; unbudgeted | Added to S2 scope |
| 9 | A follow-up scheduled by a job expiring inside `AdvanceTick` "keeps the FULL lead" | **`LEAD − 1`** — deadlines run first, then the pass decrements every entry including the new one | **An assertion written from the prose passed the MUTANT and would have failed the correct port** |
| 10 | Dedupe-before-cap ordering is a behavior worth a test | **It is not.** Both guards are side-effect-free predicates; swapping them is unobservable | Would have added a bogus assertion chasing nothing |
| 11 | `UBMSaveGame : USaveGame` with `UPROPERTY() TArray<FBMDistrictState>` | **Cannot compile.** Reflection needs `CoreUObject`; BMCore has `Core` alone — the wall. `USTRUCT` appears **0 times** in `Source/` | **Prescribed in TWO documents, in TWO different shapes** (`04` mirror types, `05` live structs), both contradicting code that shipped in S2 |
| 12 | The save version check is a typed comparison | **A coercion** — `int(version)`, so a *string* `"1"` and a *float* `1.0` both LOAD | Unreproducible in binary; recorded as a bounded divergence |
| 13 | "Byte-identical state" as an unconditional gate | **Conditional.** A load that cannot rebuild a job DROPS it and still returns true | Two contracts conflated → a false pass or a false fail |
| 14 | `JSON.stringify` is fine for fixture floats | **Truncates float64 to 15 digits** — `0.1+0.2` becomes `"0.3"`, a different number | Caught in Step 1; would have failed a **correct** port at `==` |
| 15 | `FCustomVersion` formalizes additive tolerance | Only for *reflected* serialization; there is none. Default member initializers do it | Prescription dropped |
| 16 | `FBMId` / `FBMDistrictId` strong-id types | **Never built through S4** — ids are plain `FString` | Sketch kept, marked unbuilt; introducing it later is a save-format change |

**Seven lessons now priced in, not guesses:**

1. **A decimal literal beats the name of the algorithm above it.** Claim 1 shipped a compiling,
   deterministic, *wrong* game and only the gate caught it.
2. **A `[P]` about the Godot build is a hypothesis.** Every one that mattered was wrong. `[V]` claims
   held up throughout.
3. **First-run green is weak evidence here.** S2's layers all passed immediately; mutation-testing the
   gate then exposed three holes, two of which would have shipped a silently different game.
4. **When a gate cannot pass, measure why instead of loosening it.** S2's trajectory comparison
   failed at 1800 ticks; the diagnosis (the oracle's exposure exceeds this world's zero-disruption
   ceiling → the surplus is the rival, which is S5) turned a blocked gate into a *scoped* one. The
   alternative — widening tolerances until green — produces a gate that cannot fail, which is not a
   gate.

5. **`[V]` "Prove the assertion can FAIL" — "add an assertion" is not enough.** S4 found three gaps by
   mutation and they were **three different failure modes**, not one mistake repeated: one compared
   against an expectation the mutation had already corrupted (and so hid a *real defect* — `Encode`
   mutating the live campaign through a `const_cast`, which would have made quicksaving alter the
   running game); one chased an order that is not a behavior; one asserted something **true by
   construction** (`Num() == 0` on a map the test never populated). Across S2–S4 that is **ten gaps
   found by mutation and zero by a gate failing.**
6. **`[V]` When a document prescribes something impossible, check whether ANOTHER document prescribes
   it too — differently.** `UBMSaveGame` appeared in `04` §8 over mirror types and in `05` §7 over the
   live structs. Two sketches, one impossibility, and they were never two readings of one design.
   **Correcting only the one you happened to open leaves the other as authority.**
7. **`[V]` A gate can be STRICTER than the oracle, and then the oracle's tests are no guide.**
   `var_to_str` sorts dictionary keys, so field order is not part of the Godot save format and its
   round-trip runner *could not* catch a reordered encode. In a binary archive field order **is** the
   format, and the reader and writer are the same function body — so a reorder leaves **55 of 56 tests
   green**. That needed a committed-binary fixture the oracle never had.

**Unchanged by all of this:** the roadmap's slice order, every acceptance gate, all stop conditions,
and the open decisions (D-02 / D-10 by S12, D-07 after Gate B). No re-planning is owed.

> `[V]` **The one thing S4 changed about HOW to work, not just what is true:** run mutations **as each
> step lands**, not in a batch at the end. Deferring them means building later steps on tests that might
> measure nothing — and S4's first gap was in Step 2's tests, which Steps 3–5 would have been built on.

---

## 2. Locked decisions

Not reopened by this package (from the task prompt):

1. Godot repo preserved as archived reference, never deleted · 2. New sibling repo `black-meridian-ue` ·
3. Clean implementation, not translation · 4. Windows PC first, Steam · 5. Unreal **C++** project ·
6. Authoritative simulation + deterministic rules in C++ · 7. Blueprints own presentation ·
8. Level Blueprints own **no** authoritative state · 9. City is not a life simulation ·
10. No open world · 11. No tactical combat in the slice · 12. No drivable vehicles ·
13. No runtime generative video or LLM calls · 14. Godot formulas/tests are **evidence**, not code to copy ·
15. **No final art before the greybox slice passes its gates** · 16. First slice = **The Intercepted
Shipment** · 17. Unreal must be justified by **embodied cinematic consequence**, not a heavier UI.

### One conflict, resolved explicitly

`[Verified]` **Brief §13.1 mandates Godot and forbids an engine switch unless the splat spike fails —
and the spike passed.** The locked decisions outrank the brief; §13.1 is **consciously superseded, not
merged**, and recorded in [ADR-0001](ADR-0001-UNREAL-REBOOT.md).

---

## 3. The plan in one paragraph

Rebuild the **validated simulation** in Unreal C++ against golden vectors extracted from the Godot
build (behavioral equivalence, not bit-identity), then build the **one thing Godot could not**: a
small, high-fidelity, performed warehouse confrontation wired to authoritative state. Prove the
strategy loop on greybox (**Gate A**), prove the embodied scene beats the Godot version (**Gate B** —
the decisive one), then make content data-driven, polish, and package (**Gate C**).

---

## 4. Document index

| Document | What it answers |
|---|---|
| [00_EXECUTIVE_DECISION.md](00_EXECUTIVE_DECISION.md) | Why reboot · why Unreal · what's preserved/abandoned · success · non-goals · go/no-go |
| [01_SOURCE_AUDIT.md](01_SOURCE_AUDIT.md) | What exists · test results run this session · debt · stale docs · what must not shape the port |
| [02_PRODUCT_CONTRACT.md](02_PRODUCT_CONTRACT.md) | Player fantasy · loops · both layers · camera · narrative · scope |
| [03_BEHAVIORAL_PORT_MATRIX.md](03_BEHAVIORAL_PORT_MATRIX.md) | Every system: PRESERVE / ADAPT / REDESIGN / CUT / DEFER, with evidence, owner and test |
| [04_UNREAL_ARCHITECTURE.md](04_UNREAL_ARCHITECTURE.md) | Modules · subsystems · tick order · events · transitions · save · logging · what is *not* adopted |
| [05_DATA_MODEL.md](05_DATA_MODEL.md) | Types, ids, enums, **all balance constants**, authored vs mutable vs derived |
| [06_VERTICAL_SLICE.md](06_VERTICAL_SLICE.md) | The Intercepted Shipment: flow, consequences, UI, environments, budgets, acceptance, cut list |
| [07_IMPLEMENTATION_ROADMAP.md](07_IMPLEMENTATION_ROADMAP.md) | S0–S16 with dependencies, tests, commands, gates, rollback, prohibited shortcuts |
| [08_TEST_STRATEGY.md](08_TEST_STRATEGY.md) | Golden vectors · the hash problem · equivalence tolerances · functional/perf/failure tests |
| [09_ASSET_AND_CHARACTER_PIPELINE.md](09_ASSET_AND_CHARACTER_PIPELINE.md) | Canon-gated character pipeline · environment kit · validation · licensing |
| [10_RISK_REGISTER.md](10_RISK_REGISTER.md) | 18 risks with probability, impact, detection, mitigation, owner, trigger, fallback |
| [11_CANONICAL_REFERENCE_INTAKE.md](11_CANONICAL_REFERENCE_INTAKE.md) | Cast as it exists · every `[MISSING]` canonical input |
| [12_DECISIONS_REQUIRED.md](12_DECISIONS_REQUIRED.md) | 10 decisions only Cem can make |
| [13_REPOSITORY_BOOTSTRAP.md](13_REPOSITORY_BOOTSTRAP.md) | Exact steps to create the repo — **not executed** |
| [ADR-0001](ADR-0001-UNREAL-REBOOT.md) | The engine decision, alternatives, rollback boundary |

---

## 5. Implementation order

```
S0  Repository + project bootstrap
S1  Determinism core (hash, constants, golden-vector harness)     ← highest risk, done FIRST
S2  Economy · heat · evidence · central pressure
S3  Job system (lifecycle, resolution, generation)
S4  Save / load                                                   ← early, so all later work stays save-safe
S5  Rival AI          ┐
S6  Loyalty/betrayal  ├─ parallel after S4
S7  Night Cycle       ┘
S8  Narrative spine
S9  Strategic presentation (city, camera, HUD)
S10 Playable greybox                    ★ GATE A — is the loop still fun?
S11 Transition + embodied stub
S12 Hero character                      (blocked on canon — D-10)
S13 The embodied scene                  ★ GATE B — DOES THE REBOOT HOLD?
S14 Content → Data Assets
S15 Polish, settings, accessibility
S16 Package + QA                        ★ GATE C — slice complete
```

---

## 6. First executable action after approval

> ### **S0 COMPLETE — 2026-09-18.** Evidence: `Docs/gates/S0.md` in the Unreal repo.
>
> | | |
> |---|---|
> | **Unreal repo** | `D:\black-meridian-ue` -> `EsimOmni/black-meridian-ue` (private, LFS, no CI — D-05) |
> | **Godot repo** | preserved, tagged **`godot-final`**, still runs (headless exit 0) — D-08 |
> | **Checklist** | 11/11 passed, including packaging and Godot integrity |
>
> S0 produced **four corrections to this package** — D-01's premise ([12](12_DECISIONS_REQUIRED.md)),
> the `.gitattributes` globs ([10](10_RISK_REGISTER.md) R-07 / [13](13_REPOSITORY_BOOTSTRAP.md) §4.1),
> the non-existent glTF Importer plugin (§1.1) and the .NET 10 build path (§0, §8). All are folded in.
>
> **Next: S1 — Determinism Core.** Not started; it needs the D-01 IDE half for debugging, and the
> golden-vector extraction run against the Godot oracle.

The executed sequence, for the record:
1. ~~Confirm **D-05**~~ — approved; private GitHub repo under EsimOmni, LFS, no CI.
2. ~~Create `D:\black-meridian-ue`~~ — Blank **C++**, UE 5.8.2, plugins per §1.1 (as corrected).
3. ~~Commit `.gitattributes` + `.gitignore` **before any asset**~~ — first commit `1da360f`.
4. ~~Build `BlackMeridianEditor Win64 Development`~~ — succeeded, 0 warnings.
5. ~~Run `BM.Smoke`~~ — `Result={Success}`, exit 0.
6. ~~Run the S0 validation checklist (§11)~~ — 11/11, Godot repo verified unchanged and runnable.

WARNING: step 2 could not proceed until the **NetFx SDK** was installed — see
[13 §0.1](13_REPOSITORY_BOOTSTRAP.md). **D-01** is therefore half-done (SDK yes, IDE still open);
**D-08/D-09** are complete.

---

## 7. Acceptance gates

| Gate | Slice | Condition | Judge |
|---|---|---|---|
| **S0** | Bootstrap | Editor builds, smoke test passes, LFS active, Godot repo untouched | Automated — **PASSED 2026-09-18** |
| **S1** | Determinism | **Every hash golden vector matches exactly** | Automated |
| **S2–S8** | Simulation | All golden vectors + unit tests pass per slice | Automated |
| **★ A** | S10 Greybox | Full 20–30 min cycle is fun **on cubes**, and **at least as good as the Godot build**; the four legibility questions answerable | **Cem** |
| **S11** | Transition | Scene changes persistent state; survives save/load before, during, after | Automated |
| **★ B** | S13 Embodied | **Does the Unreal scene deliver what the Godot version could not?** A/B against `cinematic_view_probe.tscn` | **Cem** |
| **S14** | Data | Zero hardcoded content; **all golden vectors still pass** after migration | Automated |
| **★ C** | S16 Package | On a clean machine: launches, saves, loads, completes a cycle, enters/exits the scene, reaches an ending. No critical defects. Budgets met | **Cem** |

---

## 8. Stop conditions

Hit one → **stop and escalate**. These are real, not ceremonial.
(`SC-n` = stop condition, distinct from `Sn` = roadmap slice.)

| # | Condition | Response |
|---|---|---|
| **SC-1** | Gate B fails — the embodied scene does not beat the Godot back-room | **Stop the reboot.** Return to the Godot build (ADR-0001 rollback) |
| **SC-2** | Determinism cannot be re-established after a genuine attempt | Escalate; consider the documented re-baseline ([08](08_TEST_STRATEGY.md) §4.3) |
| **SC-3** | Gate A judged *worse* than the Godot loop | Stop; fix the simulation before any further work |
| **SC-4** | Performance below floor on greybox | Stop; re-scope rendering before adding content |
| **SC-5** | Hero character cannot reach bar within budget | Fall back to a stylized/masked design (R-02/R-17) |
| **SC-6** | Authoritative state found in a Blueprint | Fix immediately; recurrence → remove Blueprint write access |
| **SC-7** | Any non-goal enters the build | Cut it |

**Rollback boundary:** the decision is **fully reversible through Gate A**, reversible at cost through
Gate B, and effectively committed after Gate B passes.

---

## 9. Open approvals

| # | Decision | Recommendation | Blocks |
|---|---|---|---|
| **D-05** | Repo hosting, LFS, CI | GitHub private + LFS, no CI | **DONE in S0** — `EsimOmni/black-meridian-ue` |
| **D-08** | Uncommitted P20 work | Commit, then archive | Clean archive |
| **D-09** | `docs/astra-recovery/` (misnamed log dumps) | Delete or rename | Archive clarity |
| **D-01** | Visual Studio IDE | Install VS 2022 Community | S1 debugging |
| **D-10** | Canonical character package | Supply, else authorize the masked-character fallback | **S12** |
| **D-02** | Hero character route | Local Hunyuan + noir-forward design | S12 / Gate B ceiling |
| **D-04** | Voice acting | ~10–20 key lines | S13 |
| **D-03** | Council location | Framed static view | S15 |
| **D-07** | Do splats return? | Cut; revisit after Gate B | Full-game pipeline |
| **D-06** | Aiko's long-term authority | Remain constrained; defer | Post-slice narrative |

**Only D-05 blocks the first action.** D-08 and D-09 are housekeeping on the Godot side.

---

## 10. The honest summary

**What is strong here.** The simulation is not a design document — it is a passing test suite with
byte-identical replay, every constant extracted, and four gate notes recording how it was proven. That
makes the strategy half of this port a transcription problem with an oracle, which is about the best
position a re-implementation can start from.

**What is genuinely at risk.** Three things, and they are not evenly weighted:
1. **The thesis itself** (R-18). If the Unreal warehouse doesn't land harder than the Godot box room,
   the reboot had no reason to exist. Gate B is scheduled early precisely so this answer arrives before
   the largest investments.
2. **Scope and character cost** (R-01, R-02 — both rated High probability). Both are Cem's to own. The
   Godot project *already* chose to abandon 3D characters rather than pay this cost; the reboot
   re-opens exactly that bill.
3. **The hash port** (R-03). A silent failure mode — a subtly wrong hash yields a game that is still
   deterministic, just different. Hence S1 before all other logic.

**What this package deliberately does not do.** It does not invent character canon, does not claim
bit-identical cross-engine floats, does not pretend brief §13.1 agrees with it, and does not treat
Gate B as a formality.

---

**Prepared by:** Claude Opus 5 (1M context), acting as principal game architect / technical director.
**Validation:** see the final report — only `docs/unreal-reboot/` was created; no gameplay code, no
documentation and no working-tree state was modified.
