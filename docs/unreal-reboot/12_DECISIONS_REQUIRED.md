# 12 — Decisions Required

Only decisions that **genuinely require Cem**. Anything answerable from repository evidence was
answered in the other documents and is not here.

Each: the exact question · recommendation · alternatives · consequences · **latest responsible
decision point** (the slice after which the decision becomes expensive or impossible).

---

## D-01 — Install a full Visual Studio IDE, or stay on Build Tools?

**Question.** The dev machine has **Visual Studio Build Tools 2022 17.14.37411.7** with MSVC 14.44
(`cl.exe` present) — `[V]` verified — but **no full VS IDE**. Unreal C++ development normally assumes
the IDE for debugging, IntelliSense and hot reload. Install VS 2022 Community, use an alternative
(Rider / VS Code + clangd), or work without a debugger?

**Recommended: install Visual Studio 2022 Community** (free for this use) with the "Game development
with C++" workload.

**Why.** The first non-trivial determinism bug will need a breakpoint in
`FBMRivalScoring::ChooseMove`, and printf-debugging a hash mismatch across 1260 ticks is a bad trade.
R-03 is a Medium/High risk specifically because it is *silent*; a debugger is the main tool against it.

> ### ⚠️ RESOLVED IN PART DURING S0 — this question's premise was wrong
>
> This section originally read *"Build Tools can compile, so S0 will succeed."* **It does not.**
> `UnrealEd.Build.cs` depends unconditionally on `SwarmInterface`, which requires the **.NET Framework
> 4.6+ SDK** — absent from a standalone Build Tools install. The S0 editor build fails outright with
> `Could not find NetFxSDK install dir`. **S0 was itself blocked by D-01**, not merely S1.
>
> Resolved 2026-09-18 by adding `Microsoft.Net.Component.4.8.SDK` + targeting packs to the existing
> Build Tools — see [13 §0.1](13_REPOSITORY_BOOTSTRAP.md) for the exact command and its traps. The
> editor target, `BM.Smoke` and the packaged Shipping build all pass on Build Tools + NetFx SDK.
>
> **What remains open is only the IDE question above** — a debugger for S1+ determinism work. That is
> still a real need and still recommended; it is simply no longer a prerequisite for S0.

**Alternatives.**
- **JetBrains Rider** — arguably better UE tooling; paid (personal licence ~$15/mo).
- **VS Code + clangd** — free, lighter, weaker UE debugging.
- **Build Tools only** — zero install, no debugger. Not recommended.

**Consequences.** ~10–20 GB install and some setup time, versus materially slower diagnosis of exactly
the class of bug this port is most exposed to.

**Latest responsible decision point:** **before S1.** The determinism core is where a debugger first
earns its keep.

---

## D-02 — Hero character: production route and quality bar

**Question.** One hero-grade rigged character (`bengal_lt`) is the slice's largest art cost and the
thing Gate B is judged on. Which route?

**Recommended: local Hunyuan3D → Blender → Unreal, with a deliberately noir-forward design**
(hat/collar/low light) that reduces facial-identity load.

**Why.** `[V]` The local pipeline is **proven** (hero geometry *and* texture, zero credit, no OOM on
the 16 GB 5060 Ti). `[V]` The Godot project abandoned 3D characters rather than pay this cost — so the
risk is demonstrated, not theoretical (R-02, High/High). A design that carries menace through
silhouette and lighting rather than facial micro-detail is both cheaper and, for a confrontation in a
dark warehouse, better.

**Alternatives.**
- **MetaHuman** — highest fidelity, fastest to a good face. ⚠️ `[U]` **Licensing for a commercial Steam
  release was not verified in this session** and must be checked before adoption. Also pulls in a heavy
  dependency and a distinctive look.
- **Meshy Pro one-month burst** (~$20) — a middle path if local output misses the bar.
- **Purchased character asset** — fast, but identity is then not original; conflicts with brief §2's
  original-IP posture and with §20 #5's canonical approval.
- **Stylized/masked character** — the R-17/R-02 fallback; cheapest, and viable dramatically.

**Consequences.** This decision sets the ceiling on Gate B. Choosing MetaHuman without the licence
check risks a late, expensive reversal.

**Latest responsible decision point:** **before S12**, and ideally at the same time as D-10 (canon),
since I-02…I-05 constrain the route.

---

## D-03 — Does the Council phase get its own embodied location?

**Question.** The slice's COUNCIL phase is 3 minutes of strategic review. Build
`L_Council_Embodied` as a second walkable space, a framed static view (camera + backdrop + characters,
no movement), or keep COUNCIL purely in the management UI?

**Recommended: a framed static view** — a composed camera on a small dressed set, with the Regent
present, and no player locomotion.

**Why.** It gives the Council a face and a place for perhaps 10% of a walkable level's cost, and
directly serves R-01/R-04 (a second walkable space is exactly how "one embodied location" becomes
two). `[V]` Brief §12.1 allows only one cinematic sequence in the slice; a static framing is not a
second sequence.

**Alternatives.**
- **Full walkable council** — better presence, roughly doubles embodied-environment cost, invites scope creep.
- **UI only** — cheapest; the Council phase then has no human presence at all, which weakens the
  "character-driven" positioning the reboot is built on.

**Consequences.** Affects S15 scope and the environment budget.

**Latest responsible decision point:** **before S15.** (S13 must not absorb it.)

---

## D-04 — Voice acting in the slice?

**Question.** The confrontation is the emotional core. Full VO for the scene, a few key lines,
non-verbal vocalizations only, or text only?

**Recommended: a small set of recorded key lines for the lieutenant** (roughly 10–20), text for
everything else.

**Why.** `[P]` A performed voice does more for Gate B than almost any visual upgrade — and a *silent*
confrontation with subtitles reads as a prototype. Scoping to key lines avoids committing to a VO
pipeline. `[V]` Brief §12.3 explicitly cuts *"a fully voiced 15-hour branching screenplay for
version 1.0"* — it does not cut a handful of slice lines.

**Alternatives.**
- **Full scene VO** — better, but needs casting, direction and a pipeline.
- **Non-verbal only** (breath, movement, incidental) — cheap, surprisingly effective with good sound design.
- **Text only** — cheapest; weakest for Gate B.

**Consequences.** Casting is bounded by I-07 (voice direction), which is `[MISSING]`.
Synthetic/AI voice would need an explicit decision — note `[V]` Locked #13 forbids *runtime*
generation, not authored pre-production assets, but the commercial licensing of a synthetic voice is
its own question.

**Latest responsible decision point:** **before S13.**

---

## D-05 — Repository hosting, LFS storage, and CI

**Question.** `[V]` The Godot repo is `EsimOmni/black-meridian` (private, GitHub). The Unreal repo
will be LFS-heavy. Same GitHub org with paid LFS, a different host, or local-only with external backup?
And is any CI wanted?

**Recommended: same GitHub org, private, Git LFS, no CI initially.**

**Why.** Continuity of workflow and access. `[P]` GitHub's free LFS quota (1 GB storage / 1 GB
bandwidth per month) **will not be enough** — a data pack is likely needed. `[V]` CI was never used on
the Godot project and local pre-commit verification worked; adding a self-hosted UE build agent now
would cost more than it returns (R-07, R-08).

**Alternatives.**
- **Azure DevOps** — generous free LFS, good UE fit; new workflow to learn.
- **Perforce** — the industry standard for UE binary assets; heavy for a solo developer.
- **Local + external drive backup** — zero cost, zero redundancy. `[V]` 1.2 TB free on D:.

**Consequences.** Changing hosts after history exists is painful. LFS must be configured **before the
first asset commit** — retrofitting rewrites history.

**Latest responsible decision point:** **before S0.** This one gates repository creation.

---

## D-06 — Aiko's long-term authority (brief §20 #1)

**Question.** `[V]` Brief §20 asks: should the player remain a constrained operator serving the Regent,
or eventually overthrow and replace them?

**Recommended: remain a constrained operator** — and **defer the long-term answer**.

**Why.** `[V]` It is the current implemented assumption and nothing supersedes it. The slice ends at
the Meridian Accord stance decision, which does not touch succession. Deciding the campaign's shape now
would be speculative.

**Alternatives.** Commit to a succession arc (changes the ending structure and the Regent's role);
or commit to permanent constraint (forecloses a strong narrative option).

**Consequences.** **None for the slice.** Listed because brief §20 flags it as requiring approval, and
because the Meridian Accord endings are the seed of whatever comes next.

**Latest responsible decision point:** after the slice, before full-game narrative design.

---

## D-07 — Do Gaussian splats ever return?

**Question.** `[V]` P01 proved GDGS ran 542k splats at 483 fps and the splat route was the brief's
preferred cinematic technique (§7.7). This package **CUTs** splats. Is that permanent, or is splat
rendering part of the commercial identity?

**Recommended: cut for the slice; revisit only after Gate B.**

**Why.** `[P]` The embodied scenes need characters, moving doors, handheld objects, evidence items,
collision and navigation — `[V]` precisely the list brief §7.7 says a splat **cannot** supply. Authored
3D is the better fit for a *performed* scene. And Gate B will answer empirically whether authored
environments deliver the needed weight.

**Alternatives.**
- **Keep splats as a goal** — needs an Unreal splat solution and re-opens Marble Pro spend (~$35/mo).
- **Hybrid** (splat backdrop + authored foreground) — technically interesting, adds real complexity.

**Consequences.** `[V]` Brief §20 #3 asks whether *"true Gaussian-splat rendering is mandatory for the
commercial identity even if it narrows hardware support."* If the answer is yes, that changes the
environment pipeline and this package's §5.1 cut must be revisited. `[P]` The `IBMCinematicWorldProvider`
seam is preserved specifically so a splat provider remains a later addition, not a rewrite.

**Latest responsible decision point:** after Gate B; before full-game environment production.

---

## D-08 — The uncommitted P20 work in the Godot repository

**Question.** `[V]` The Godot working tree holds uncommitted P20 work: 5 modified files + 4 new scripts
(`settings_service.gd`, `settings_panel.gd`, `onboarding_nudges.gd`, `audio_cues.gd`) +
`assets/audio/` (5 WAVs). It reads as complete but is unshipped and unrecorded in `docs/NOW.md`.
Commit it, leave it, or discard it?

**Recommended: commit it to the Godot repository** (after a quick verify pass), then archive.

**Why.** `[P]` The Godot repo becomes the **archived behavioral reference** (Locked #1). An archive
with uncommitted work in its tree is a bad archive — the work is either lost or ambiguous. `[V]` It is
also genuine reference material: it implements rebinding, text scaling, performance tiers and
onboarding nudges, all of which S15 must reproduce.

**Alternatives.**
- **Leave uncommitted** — risks silent loss; the archive is not a clean snapshot.
- **Discard** — throws away a working P20 slice that S15 would otherwise re-derive.

**Consequences.** Committing requires a verify pass (`--import`, unit suite, boot smoke) per the
project's own definition of done. ⚠️ **This task did not modify, commit or stage anything** — the
working tree is exactly as found.

**Latest responsible decision point:** **before archiving the Godot repository**, i.e. before or
during S0.

---

## D-09 — `docs/astra-recovery/` — delete, rename, or keep?

**Question.** `[V]` This untracked directory contains 7 files with authoritative planning names
(`01_REPOSITORY_REALITY.md`, `05_RECOVERY_EXECUTION_PLAN.md`, `06_DECISIONS_REQUIRED.md`, …) whose
contents are **Godot headless stdout dumps** — engine banners and test logs. They are redirected-output
accidents.

**Recommended: delete the directory** (or rename to `scratchpad/logs-2026-09/`).

**Why.** `[P]` It is an actively misleading artifact: a future reader opening `06_DECISIONS_REQUIRED.md`
expecting decisions finds a test log. This package deliberately creates a file with the **same name**
in `docs/unreal-reboot/`, and the two are unrelated — a collision worth eliminating before the repo is
archived as a reference.

**Alternatives.** Rename (preserves the probe log in `README.md`, which has some value); keep and add
a `README` explaining what they are.

**Consequences.** None functional — the directory is untracked and referenced by nothing.

**Latest responsible decision point:** before archiving the Godot repository.
⚠️ **This task did not delete or move it** (the prompt forbids it).

---

## D-10 — Canonical character package: does one exist?

**Question.** `[V]` The cast is species placeholders and the world-bible identity lock has not
happened. The task prompt warns against merging with "later OMNI Sapient characters," but
`[V]` **no OMNI Sapient reference exists anywhere in this repository.**

Is there an external canonical character package for Black Meridian's cast — and does it relate to
OMNI Sapient at all?

**Recommended: supply the package if it exists; otherwise authorize the R-17 fallback** — build the
hero as a deliberately non-identity-revealing character (masked, backlit, silhouetted) so S12/S13 are
not blocked.

**Why.** `[V]` Brief §20 #5 requires canonical approval **before** hero-character production, and
`[V]` brief §9.3 warns that an identity change after approval forces revalidation of every derived
asset. Starting geometry without canon risks exactly that rework (R-15). But blocking Gate B — the
decision that justifies the whole reboot — on a document that may not exist is worse.

**Alternatives.**
- **Wait for canon** — safest for identity, blocks the reboot's decisive gate.
- **Proceed with the existing placeholders** — fastest, highest rework risk.

**Consequences.** This is the **gating input for S12** and the most likely schedule risk (R-17,
Medium-High). Whatever the answer, it should be recorded, since the intake manifest
([11](11_CANONICAL_REFERENCE_INTAKE.md) §4) currently lists I-01…I-08 as `[MISSING]`.

**Latest responsible decision point:** **before S12.**

---

## Summary

| # | Decision | Recommendation | Latest point | Blocks |
|---|---|---|---|---|
| **D-05** | Repo hosting + LFS + CI | GitHub private + LFS, no CI | **Before S0** | Repository creation |
| **D-08** | Uncommitted P20 work | Commit, then archive | Before archiving | Clean archive |
| **D-09** | `docs/astra-recovery/` | Delete or rename | Before archiving | Clarity |
| **D-01** | VS IDE | Install VS 2022 Community | **Before S1** | Debugging determinism. ⚠️ NetFx SDK half was **mandatory for S0** and is DONE; IDE half still open. |
| **D-10** | Canonical character package | Supply, else authorize the fallback | **Before S12** | Hero character |
| **D-02** | Hero character route | Local Hunyuan + noir-forward design | Before S12 | Gate B ceiling |
| **D-04** | Voice acting | ~10–20 key lines | Before S13 | Scene impact |
| **D-03** | Council location | Framed static view | Before S15 | Environment budget |
| **D-07** | Splats return? | Cut; revisit after Gate B | After Gate B | Full-game pipeline |
| **D-06** | Aiko's authority | Remain constrained; defer | After the slice | Full-game narrative |

**Only three decisions block the immediate next step (S0):** D-05, plus D-08 and D-09 if the Godot
repo is to be archived cleanly at the same time. Everything else has room.

---

**Next:** [13_REPOSITORY_BOOTSTRAP.md](13_REPOSITORY_BOOTSTRAP.md)
