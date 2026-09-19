# 10 — Risk Register

Each risk: probability, impact, **detection** (how we find out *before* it hurts), mitigation, owner,
trigger, and fallback. Ordered by expected damage.

**Scale.** Probability: Low <25% · Medium 25–60% · High >60%.
Impact: Low (annoying) · Medium (slice delayed) · High (slice fails) · Critical (project fails).

**Owner.** "Cem" = a decision only he can make. "Architect" = the technical lead role (Claude or a
future engineer). Detection without an owner is a wish.

Tags: `[V]` Verified from repository · `[I]` Inferred · `[P]` Proposed

---

## R-01 — Scope explosion

| | |
|---|---|
| **Probability** | **High** |
| **Impact** | **Critical** |
| **Why it's first** | `[V]` The brief names it as *the* failure mode for a tiny studio (§12), and Unreal makes every excluded thing *easy to start* — World Partition is a checkbox, Chaos vehicles are a plugin, a second cinematic location is an afternoon that becomes a month |
| **Detection** | Non-goal list ([00](00_EXECUTIVE_DECISION.md) §7) reviewed at **every gate**; any new plugin, level or system requires a written justification against an observed requirement; watch for "while I'm in here" work |
| **Mitigation** | Hard cut list ([06](06_VERTICAL_SLICE.md) §11); gates that can fail; one hero character; one embodied location; Level Streaming not World Partition; Godot's ship-first rule — *the polish notebook does not open* |
| **Owner** | Cem (authority), Architect (flagging) |
| **Trigger** | Any non-goal enters the build; slice content grows past §11; a gate slips twice |
| **Fallback** | Freeze the slice at its current state, cut to the minimum that proves Gates A and B, ship that |

---

## R-02 — Character production cost explodes

| | |
|---|---|
| **Probability** | **High** |
| **Impact** | **High** |
| **Evidence** | `[V]` The Godot project **abandoned 3D characters entirely** rather than pay this cost (ship-first, 2026-07-12) — it is the one thing the reboot re-opens, so the cost is real and already demonstrated |
| **Detection** | Track hours/cost on `bengal_lt` through S12; a hard checkpoint at "base mesh approved" — if the face is not right by then, it will not get cheaper |
| **Mitigation** | **One** hero rig; local Hunyuan3D first (zero cost, proven); others stay portraits + voice; the animation set is cut to the six states the scene uses; canonical references locked before any geometry |
| **Owner** | Cem (D-02, quality bar), Architect (pipeline) |
| **Trigger** | Hero character not at bar after two full production attempts; or cost exceeds the agreed ceiling |
| **Fallback** | **Stylized/masked/silhouetted** character design that sidesteps facial-identity difficulty — a masked or backlit lieutenant can carry a confrontation. If even that fails, Gate B fails and stop condition **SC-5** fires |

---

## R-03 — Determinism broken by the hash port

| | |
|---|---|
| **Probability** | **Medium** |
| **Impact** | **High** |
| **Evidence** | `[V]` Determinism rests on splitmix64 over Godot's `String.hash()` with signed 64-bit wraparound, driving rival tie-breaks and job variants. Naïve C++ gives a *different but still deterministic* game — **a silent failure with no symptom** |
| **Detection** | `Test_Hash_MatchesGodotVectors` in **S1, before any other logic**; `LogBMDeterminism` verbose traces; double-run probe comparison |
| **Mitigation** | Extract golden vectors from Godot **first**; implement in explicit `uint64`; one shared `FBMHash`; static scan for RNG; ordered containers on every ordering path |
| **Owner** | Architect |
| **Trigger** | Any hash vector mismatches |
| **Fallback** | Re-baseline on a clean documented hash and regenerate all vectors from Unreal — **with Cem's sign-off**, accepting that two systems' arbitrary-but-stable choices diverge from the Godot build ([08](08_TEST_STRATEGY.md) §4.3) |

---

## R-04 — Overbuilding the cinematic system

| | |
|---|---|
| **Probability** | **Medium-High** |
| **Impact** | **High** |
| **Why** | `[P]` The reboot's justification *is* the cinematic layer, which makes it the most seductive place to overinvest. A dialogue system, a branching conversation editor, a facial-performance toolchain, and a camera-blocking framework are each defensible individually and fatal collectively |
| **Detection** | Any cinematic tooling that isn't used by the **one** warehouse scene is scope creep; count Sequencer assets and dialogue nodes against what the scene actually plays |
| **Mitigation** | Build the scene, **not a system** — hand-author with Sequencer; extract a system only if a second scene proves the need; Sequencer stages but never decides ([04](04_UNREAL_ARCHITECTURE.md) §7.4) |
| **Owner** | Architect |
| **Trigger** | Cinematic tooling work exceeds the scene work it serves |
| **Fallback** | Delete the tooling, hand-author the scene, ship it |

---

## R-05 — Abandoning gameplay for visuals

| | |
|---|---|
| **Probability** | **Medium** |
| **Impact** | **High** |
| **Why** | `[P]` Unreal makes visual progress *feel* like progress. The strategy layer — the half that already works — can quietly stop improving while the renderer gets attention |
| **Detection** | Gate A is a **gameplay** gate judged on greybox; if visual work happens before it passes, the rule is already broken. Track: is the last week's work testable by the simulation suite? |
| **Mitigation** | Locked #15; Gate A before any art; the strategic loop must be judged *at least as good* as the Godot build (stop condition SC-3) |
| **Owner** | Cem (judgement), Architect (sequencing) |
| **Trigger** | Art produced before Gate A; or Gate A judged worse than Godot |
| **Fallback** | Stop art, return to the simulation until the loop is at least as good as the reference build |

---

## R-06 — Blueprint sprawl / ownership ambiguity

| | |
|---|---|
| **Probability** | **Medium** |
| **Impact** | **Medium-High** |
| **Why** | `[V]` The Godot build's zero-violation authority invariant was maintained by *discipline in a readable language*. `.uasset` Blueprints are binary, un-diffable, and make a stray `SET` on a state variable invisible in review |
| **Detection** | `Test_Arch_NoStateWritesFromPresentation`; Blueprint audit at each gate; state structs live in C++ with no `BlueprintReadWrite` on authoritative fields |
| **Mitigation** | Locked #6/#8; authoritative state `BlueprintReadOnly` at most; verbs are the only write surface; Level Blueprints stay empty; Common UI view models are read-only structs |
| **Owner** | Architect |
| **Trigger** | Any authoritative write found in a Blueprint (stop condition **SC-6**) |
| **Fallback** | Move the logic to C++; if the pattern recurs, remove Blueprint write access entirely |

---

## R-07 — Source-control growth / `.uasset` chaos

| | |
|---|---|
| **Probability** | **High** |
| **Impact** | **Medium** |
| **Evidence** | `[V]` The Godot repo is already 155 MB with mostly text assets. An Unreal project with a hero character, a kit and an interior will be multiples of that, in **binary** files that don't delta-compress |
| **Detection** | Repo size checked at every gate; `git count-objects -vH`; LFS pointer audit (`git lfs ls-files`) |
| **Mitigation** | LFS configured **before the first asset** ([13](13_REPOSITORY_BOOTSTRAP.md) §4); `Saved/`, `Intermediate/`, `DerivedDataCache/`, `Binaries/` ignored; source art (`.blend`, hi-res source) kept **outside** the repo `[V]` — the Godot `.gitignore` already does this for `.ply`/`.spz` |
| **Owner** | Architect |
| **Trigger** | Repo >5 GB, or a binary committed outside LFS |
| **Fallback** | LFS migrate (rewrites history — coordinate); or split art into a separate repo/drive |

> ### ⚠️ `[V]` S0 near-miss — the mitigation itself was defective
>
> The `.gitattributes` prescribed in [13](13_REPOSITORY_BOOTSTRAP.md) §4.1 wrote its art rules as
> **space-separated globs** on one line:
>
> ```
> *.fbx *.glb *.gltf *.blend *.obj    filter=lfs diff=lfs merge=lfs -text
> ```
>
> Git reads **one pattern per line** and treats the rest as attributes. Only `*.fbx` would have been
> tracked; `.glb`, `.png`, `.wav`, `.psd` and every other type would have entered the repository as
> **raw blobs** — this exact risk, realised, while the file that was supposed to prevent it sat in the
> repo looking correct. It would have surfaced only as unexplained repo growth, fixable then only by a
> history rewrite.
>
> Corrected before the first asset (S0 finding 2). **Detection is now mandatory, not optional:** run
> `git check-attr filter -- Content/X.uasset Content/Y.png Source/Z.cpp` after any `.gitattributes`
> edit and confirm `lfs`/`lfs`/`unspecified`. An LFS rule file is not evidence that LFS works.

---

## R-08 — Shader compilation / iteration drag

| | |
|---|---|
| **Probability** | **High** |
| **Impact** | **Medium** |
| **Evidence** | `[V]` Known UE behavior; the dev machine is an 8-core/16-thread 8700F — capable, not a build farm |
| **Detection** | Time a cold editor open and a material change; budget ≤20 min cold ([06](06_VERTICAL_SLICE.md) §9) |
| **Mitigation** | Local DDC on the NVMe (1.2 TB free `[V]`); limit shader permutations; few master materials + many instances; don't enable unused renderer features; avoid gratuitous material variants |
| **Owner** | Architect |
| **Trigger** | Cold compile >45 min, or a routine material tweak costing >5 min |
| **Fallback** | Shared DDC directory; reduce quality levels; strip unused platforms from config |

---

## R-09 — C++ compile-time drag

| | |
|---|---|
| **Probability** | **Medium** |
| **Impact** | **Medium** |
| **Why** | `[V]` This is the concrete cost of leaving GDScript's hot-reload, and the brief's pro-Godot argument that survives the reboot |
| **Detection** | Time a one-line change in BMCore vs BMGame; watch for header-fanout creep |
| **Mitigation** | Module split ([04](04_UNREAL_ARCHITECTURE.md) §2) keeps BMCore small and Engine-free; forward declarations; balance values in a DataTable so tuning needs **no recompile**; Live Coding for gameplay iteration |
| **Owner** | Architect |
| **Trigger** | Incremental build >3 min routinely |
| **Fallback** | Further module splits; move more tuning to data |

---

## R-10 — Save-schema instability

| | |
|---|---|
| **Probability** | **Medium** |
| **Impact** | **Medium** |
| **Why** | `[V]` The policy is **hard refusal, no migration** — correct and simple, but it means a careless field change invalidates every existing save, including playtesters' |
| **Detection** | `[V]` **S4, as built:** `Test_Save_AdditiveField` + `Test_Save_FixtureStillLoads` against the committed `Tests/Fixtures/Saves/v1.bmsav` (extension is `.bmsav`, not `.sav`), which is **never regenerated** — regenerating it is what turns the guard into theatre. Plus the version-bump checklist ([05](05_DATA_MODEL.md) §7). **A binary archive's field ORDER is the format**, so an insertion is a silent break the fixture is the only thing that sees — proved by mutation, see `Docs/gates/S4.md` |
| **Mitigation** | Additive-only within a version; **append-only enums AND append-only struct fields** — `[V]` S4 proved the second half by mutation: swapping two same-type fields inside `Serialize()` left 55 of 56 tests green and was caught by the committed fixture alone. Save/load built early (S4) so every later slice is tested against it; jobs store runtime state only. ⚠️ **S5 is the first test of this**: the seven rival faction fields must be APPENDED to `SerializeFaction`, never inserted |
| **Owner** | Architect |
| **Trigger** | Two version bumps within one slice |
| **Fallback** | Accept save invalidation during development (playtests are short); never after a public build |

---

## R-11 — Performance below floor

| | |
|---|---|
| **Probability** | **Medium** |
| **Impact** | **Medium-High** |
| **Evidence** | `[V]` RTX 5060 Ti 16 GB on a **128-bit bus** — VRAM and bandwidth are the named ceiling for local work. Lumen + VSM are not free |
| **Detection** | Perf tests from S10 onward, in the **packaged** build; `stat RHI` for VRAM; budgets in [06](06_VERTICAL_SLICE.md) §9 |
| **Mitigation** | Small bounded spaces; no open world; city and embodied never co-resident; ISM/HISM proxies for traffic and crowds; `[V]` the camera-driven simplifications (simplified rear façades, aggressive LODs hidden by rain) |
| **Owner** | Architect |
| **Trigger** | <45 fps packaged at 1080p High, or >13 GB VRAM |
| **Fallback** | Drop Lumen to screen-traces or baked lighting in the interior; reduce proxy density; lower texture budgets |

---

## R-12 — Content bottleneck (one person, one pipeline)

| | |
|---|---|
| **Probability** | **Medium** |
| **Impact** | **Medium** |
| **Why** | `[V]` The AI 90 / human 10 doctrine works, but the 10% is *curation and taste* and does not parallelize — it is one person's attention |
| **Detection** | Track elapsed time per asset through the S14 migration and S13 dressing |
| **Mitigation** | Modular kit (12 modules → 40 buildings); trim sheets; re-import the already-validated Godot assets; Sketchfab CC-BY for proxy dressing; one hero space only |
| **Owner** | Cem |
| **Trigger** | Environment dressing exceeds the character work it supports |
| **Fallback** | Reduce dressing to the camera-visible set; the warehouse is the only space that must be finished |

---

## R-13 — Asset licensing violation

| | |
|---|---|
| **Probability** | **Low** |
| **Impact** | **High** (legal, on a commercial release) |
| **Evidence** | `[V]` The ledger is well-maintained, which is exactly why the risk is *low but not zero* — the danger is a new asset imported in a hurry during S13 dressing |
| **Detection** | `Test_Asset_LicenseLedgerComplete`; licence recorded **at import**, not retroactively |
| **Mitigation** | CC0/CC-BY only; NC and SA forbidden; credit lines verbatim in-game; migrate the existing ledger intact |
| **Owner** | Cem |
| **Trigger** | Any imported asset without a ledger entry |
| **Fallback** | Remove the asset and replace it |

---

## R-14 — Animation quality below the bar

| | |
|---|---|
| **Probability** | **Medium** |
| **Impact** | **Medium-High** |
| **Why** | `[P]` Gate B is judged on *dramatic weight*. A well-modelled character with stiff animation fails the gate as surely as a bad model — and animation is the skill least covered by the existing pipeline |
| **Detection** | Play the confrontation with placeholder animation early in S13; if it reads as a mannequin, act then, not at the gate |
| **Mitigation** | Six states only; Control Rig for hand-tuned key poses; Sequencer for authored timing; a still, heavy performance beats a busy bad one — *stillness is cheap and reads as menace* |
| **Owner** | Cem (bar), Architect (execution) |
| **Trigger** | Animation reads as mannequin at first playable |
| **Fallback** | Lean on staging: low light, silhouette, camera framing, audio and text. `[P]` A confrontation can be carried by a figure half in shadow who barely moves |

---

## R-15 — Identity drift

| | |
|---|---|
| **Probability** | **Medium** |
| **Impact** | **Medium** |
| **Evidence** | `[V]` Brief §9.3 explicitly warns portraits must not be regenerated after a 3D character is approved without revalidation — the project already anticipated this |
| **Detection** | Three-way identity QA ([09](09_ASSET_AND_CHARACTER_PIPELINE.md) §7) at every character change |
| **Mitigation** | Canon locked before geometry; immutable property sheet; portraits derived from the approved model, not regenerated independently |
| **Owner** | Cem |
| **Trigger** | Portrait and in-scene character read as different people |
| **Fallback** | Re-derive the portrait from the approved model |

---

## R-16 — Plugin dependency

| | |
|---|---|
| **Probability** | **Low** |
| **Impact** | **Medium** |
| **Evidence** | `[V]` A direct, expensive lesson: GDGS needed a bespoke Godot-4.7 push-constant patch, with a standing instruction to re-apply it on every plugin update — and that entire investment is now **stranded** by the engine change |
| **Detection** | Audit the enabled-plugin list at every gate; prefer first-party |
| **Mitigation** | First-party Epic plugins only for the slice; no marketplace dependency in the critical path; any third-party plugin needs a written fallback |
| **Owner** | Architect |
| **Trigger** | A third-party plugin enters the critical path |
| **Fallback** | Remove it; implement the minimum needed in-project |

---

## R-17 — Canon blocks character production

| | |
|---|---|
| **Probability** | **Medium-High** |
| **Impact** | **Medium** |
| **Evidence** | `[V]` The cast is species placeholders; brief §20 #5 requires approval before hero production; `docs/NOW.md` confirms the world-bible identity lock has **not** happened. The repository may not hold the latest external canon |
| **Detection** | [11_CANONICAL_REFERENCE_INTAKE.md](11_CANONICAL_REFERENCE_INTAKE.md) checklist; S12 is explicitly blocked on it |
| **Mitigation** | Keep identities **modular** — `UBMCharacterDefinition` references art via soft pointers, so swapping identity is a data change, not a code change; simulation uses ids, never appearance |
| **Owner** | Cem |
| **Trigger** | S12 ready to start with canon unresolved |
| **Fallback** | Build the scene with a **deliberately non-identity-revealing** character (masked, backlit, silhouette) that can later be swapped — this also de-risks R-02 and R-14 |

---

## R-18 — The reboot thesis fails (Gate B)

| | |
|---|---|
| **Probability** | **Low-Medium** |
| **Impact** | **Critical** |
| **Why it's listed** | `[P]` This is the risk the whole package is organized around. If the Unreal scene doesn't beat the Godot back-room in *felt weight*, the reboot has no justification — and that must remain a real possible outcome, not a formality |
| **Detection** | **Gate B** — direct A/B against `cinematic_view_probe.tscn`, judged by Cem |
| **Mitigation** | Sequence Gate B as early as possible (S13, right after the first hero character) so the answer arrives before the largest investments; keep the Godot build archived and runnable for the comparison |
| **Owner** | Cem |
| **Trigger** | Gate B judged "no" |
| **Fallback** | **Stop.** Return to the Godot build, which is a working game, and reconsider. Stop condition **SC-1** |

---

## Summary

| Risk | P | I | Owner |
|---|---|---|---|
| R-01 Scope explosion | High | Critical | Cem |
| R-02 Character cost | High | High | Cem |
| R-18 Thesis fails | Low-Med | **Critical** | Cem |
| R-03 Determinism broken | Med | High | Architect |
| R-04 Overbuilt cinematics | Med-High | High | Architect |
| R-05 Gameplay abandoned for visuals | Med | High | Cem |
| R-06 Blueprint sprawl | Med | Med-High | Architect |
| R-11 Performance | Med | Med-High | Architect |
| R-14 Animation quality | Med | Med-High | Cem |
| R-07 Repo growth | High | Med | Architect |
| R-08 Shader compile | High | Med | Architect |
| R-17 Canon blocks production | Med-High | Med | Cem |
| R-09 C++ compile drag | Med | Med | Architect |
| R-10 Save schema | Med | Med | Architect |
| R-12 Content bottleneck | Med | Med | Cem |
| R-15 Identity drift | Med | Med | Cem |
| R-13 Licensing | Low | High | Cem |
| R-16 Plugin dependency | Low | Med | Architect |

**The honest read:** the top three risks are all **Cem's** to own, and two of them (R-01, R-02) are
rated High probability. The technical risks are real but tractable; the project risks are behavioral —
scope discipline and a willingness to let Gate B fail.

---

**Next:** [11_CANONICAL_REFERENCE_INTAKE.md](11_CANONICAL_REFERENCE_INTAKE.md)
