# 00 — Executive Decision: the Unreal reboot

**Status:** Proposed — awaiting Cem's approval.
**Scope of this document:** why the reboot exists, what Unreal must earn, what survives, what dies,
and the conditions under which we stop.

Evidence tags used throughout this package:
`[Verified from repository]` · `[Inferred]` · `[Proposed]` · `[Unverified]`

---

## 1. The decision in one line

> Black Meridian rebuilds in Unreal as a **character-driven cinematic crime strategy game**: the
> Godot build proved the simulation is *fun*; the reboot exists to make its consequences **embodied**.

The Godot repository is not a failure being escaped. It is a **validated behavioral reference** —
a working, deterministic, gate-passed simulation whose numbers and state machines are the specification
the Unreal build must satisfy. We are re-implementing a proven design in an engine that can carry the
half of the product Godot could only gesture at.

---

## 2. Why the reboot exists

### 2.1 The honest read of the Godot build

`[Verified from repository]` The Godot project succeeded at exactly what its own gates asked of it:

| Gate | Condition | Result |
|---|---|---|
| Month 1 | 15-min greybox loop playable | PASSED (`docs/prompts/notes/P04-month1-gate.md`) |
| Month 2 | Night Cycle **fun with cubes** | PASSED — verdict "fun, there's stress, very good" (`docs/prompts/notes/P08-month2-gate.md`) |
| Month 3 | Repeatable asset delivery | PASSED (`docs/prompts/notes/P14b-month3-gate.md`) |
| Month 4 | Cinematic **changes persistent state** + survives save/load | PASSED on evidence (`docs/prompts/notes/P18-month4-gate.md`) |

`[Verified from repository — run in this session]` 24/24 unit tests pass; the save round-trip runner
proves byte-identical restore, deterministic replay, and clean version refusal; two independent
1800-tick full-cycle probe runs produced **byte-identical output**. The simulation is real, deterministic
and alive. See [01_SOURCE_AUDIT.md](01_SOURCE_AUDIT.md) for commands and raw results.

### 2.2 What the Godot build could not become

`[Verified from repository]` The product's fourth design pillar — *"Walk through the consequence"*
(brief §6) — is the reason this game is not a spreadsheet. In the Godot build it currently resolves to:

- an **8×6 m primitive-box back room** built in code (`src/presentation/mesh_world_provider.gd`),
- **greybox capsule/crate actors** standing in for characters,
- a **2D portrait roster** with no 3D cast at all (ship-first decision, `docs/NOW.md`),
- **one room reused** for both the confrontation and the crime scene,
- a missing verb: brief §6 lists *plant / remove*; only **remove** exists
  (`docs/prompts/notes/P18-month4-gate.md` — "Known trims").

That is not a criticism of the work — it was the correct ship-first call for a solo studio in Godot.
But it means the emotional payload the whole design is built to deliver is currently **asserted, not
experienced**. A strategy game whose distinguishing promise is embodied consequence cannot ship with
capsules in the room where the consequence lands.

### 2.3 The reboot thesis

The reboot is justified **only** if Unreal is used to build the thing Godot could not:
small, high-fidelity, *performed* dramatic spaces, wired to authoritative strategic state. If the
Unreal build ends up being the same management UI in a heavier engine, the reboot has failed by
definition — this is Locked Decision #17 and it is the standing kill condition of the whole project.

---

## 3. Why Unreal, specifically

`[Verified from repository]` **This directly contradicts the authoritative brief.** Brief §13.1 says:
*"Use Godot 4.7 Forward+. Do not reconsider Unity unless the Gaussian-splat technical spike fails and
splat-native first-person sequences remain non-negotiable after testing the mesh fallback."*
And the splat spike **passed** (SPLAT_OK, 542k splats @ 483 fps). On the brief's own logic, the
engine question was closed in Godot's favour.

**Conflict resolution** (per the authority order in the task prompt): the prompt's locked decisions
outrank the brief. The brief's §13.1 reasoning is hereby **consciously superseded, not merged** — and
the record of that supersession is [ADR-0001](ADR-0001-UNREAL-REBOOT.md). What follows is the honest
case for the new decision, including where the brief's original reasoning still bites.

### 3.1 What Unreal actually buys us

| Capability | Why it matters *for this product* | Evidence |
|---|---|---|
| **Sequencer** | The embodied scenes are *performances* — staged blocking, camera cuts, held beats. Godot has no equivalent authoring surface; the current scenes are hand-coded transforms. | `[Verified]` `scenes/cinematic/reveal_scene.gd` builds its scene procedurally |
| **Control Rig + Anim Blueprints + MetaHuman-class facial** | Brief §9.3 requires "four character identities stable across portrait, roster and cinematic use". The Godot build has **zero rigged characters**. | `[Verified]` `docs/prompts/notes/P14b-month3-gate.md` — "1 char anim: out of scope" |
| **Lumen / virtual shadow maps** | "Rain-lacquered noir" (brief §9.1) in a small interior is exactly the case dynamic GI wins. | `[Inferred]` |
| **Automation + Functional Test framework** | The determinism contract (§5) needs first-class test tooling; the Godot suite is hand-rolled runners. | `[Verified]` `tests/` is bespoke scripts |
| **Mature packaging / crash reporting** | Brief §18 "Commercial" acceptance requires crash reporting + version display. | `[Inferred]` |

### 3.2 What Unreal costs us — stated plainly

`[Verified from repository]` The brief's pro-Godot arguments do not evaporate; they become **risks we
now own**, and each is tracked in [10_RISK_REGISTER.md](10_RISK_REGISTER.md):

- **Iteration speed on data-driven strategy systems drops.** GDScript hot-reload is replaced by C++
  compile cycles. Mitigated by: sim in C++ but *content* in DataAssets/DataTables, and Live Coding.
- **`.uasset` binary source control** replaces readable `.gd`/`.tres` diffs. This is the single biggest
  day-to-day regression; [13_REPOSITORY_BOOTSTRAP.md](13_REPOSITORY_BOOTSTRAP.md) exists mostly to contain it.
- **The splat investment is stranded.** GDGS v2.2.0 + the bespoke Godot-4.7 push-constant patch
  (`docs/prompts/notes/P01-splat-benchmark.md`) does not transfer. See the CUT list below.
- **Repo weight.** The Godot repo is 155 MB `.git`; an Unreal project with real assets will be
  multiples of that and *requires* LFS discipline from commit #1.
- **Six months of accumulated tooling** (godot-ai MCP rail, GLBValidator, probe harnesses) must be
  rebuilt or replaced.

### 3.3 The honest verdict

`[Proposed]` Unreal is justified **for this product** because the product's differentiator is embodied
cinematic consequence, and that is precisely the axis where Godot forced a trim at every single gate.
It is **not** justified by the strategy layer, which Godot ran deterministically and well. That
asymmetry is the whole argument, and it is also the discipline: *every hour spent in Unreal on the
management UI is an hour spent on the half that was already working.*

---

## 4. What is preserved

`[Verified from repository]` These are carried across as **behavioral specifications** — verified
numbers, state machines and invariants — not as code. Full disposition in
[03_BEHAVIORAL_PORT_MATRIX.md](03_BEHAVIORAL_PORT_MATRIX.md).

1. **The authority invariant.** "The strategic simulation is authoritative; presentation visualizes it
   but does not own it." Verified to hold with **zero violations** across every presentation and UI
   script in the Godot build. This is the architecture's spine and it is non-negotiable.
2. **Determinism with zero gameplay RNG.** No random number generator exists anywhere in the
   simulation. Variety comes from *hash-derived* values (splitmix64 avalanche over stable ids).
3. **The economic tension** (brief §7.2): dirty vs clean, laundering capacity as the real constraint,
   unlaundered overflow → exposure → heat.
4. **Heat → evidence → central pressure**, with the latched, re-arming inspection hysteresis.
5. **Deterministic, telegraphed, preventable betrayal** — the two-gate motive network (pressure AND
   opportunity), never an untelegraphed roll.
6. **Rival utility AI** — scored argmax over a fixed action list with hash tie-breaking and a
   telegraph→land window.
7. **Systemic job generation** with the four-stage lifecycle and ids that encode their own targeting
   (enabling byte-identical rebuild-from-save).
8. **The authored narrative spine**: Intercepted Shipment → Inspector's Ledger → Lieutenant's Debt →
   Meridian Accord → three endings.
9. **Save architecture**: source-of-truth vs rebuilt-on-load split; hard version refusal, no silent migration.
10. **The Night Cycle**: COUNCIL → OPERATIONS → CRISIS → RECKONING.
11. **All balancing constants**, as golden test vectors.

## 5. What is deliberately abandoned

| Abandoned | Reason | Disposition |
|---|---|---|
| **All GDScript source** | Clean-room re-implementation (Locked #3, #14) | Reference only |
| **GDGS splat rendering + the 4.7 push-constant patch** | Godot-specific; does not transfer | CUT — see §5.1 |
| **godot-ai MCP authoring rail** | Engine-specific tooling | CUT |
| **`GLBValidator` (GDScript)** | Re-implemented as an Unreal asset-validation commandlet | REDESIGN |
| **Bespoke probe/test runners** | Replaced by Automation + Functional Tests | REDESIGN |
| **2D-portrait-only roster** | The ship-first trim that the reboot exists to reverse | REDESIGN |
| **Godot `var_to_str` save format** | UE binary archives preserve float precision natively | ADAPT |
| **"One room serves both scene types"** | Ship-first trim; reboot needs two distinct spaces | REDESIGN |

### 5.1 The splat decision — a real loss, named

`[Verified from repository]` P01 spent real effort proving GDGS could run 542k splats at 483 fps and
patching it for Godot 4.7. That work **does not come with us**. The reboot's embodied scenes are
built as **authored, lit 3D environments** (Unreal's native strength), not captured splats.

`[Proposed]` This is the right trade — brief §7.7 itself lists everything a splat *cannot* supply
(characters, moving doors, handheld objects, evidence items, collision, navigation), which is most of
what a *performed* dramatic scene needs. But it should be recorded as a cost, not spun as a win.
Gaussian splatting is deferred, not forbidden: [12_DECISIONS_REQUIRED.md](12_DECISIONS_REQUIRED.md) D-07
asks whether splats remain part of the commercial identity.

---

## 6. Success definition

The reboot succeeds when a packaged Windows build of **The Intercepted Shipment** slice
(20–30 min) demonstrates all of:

1. **Strategic loop is enjoyable** on greybox — the Godot Month-2 bar, re-cleared in Unreal.
2. **The embodied scene adds value unavailable in the Godot presentation** — a played, lit,
   *performed* scene with a rigged character, judged side-by-side against the Godot back-room.
   *This is the reboot's reason to exist; failing it fails the reboot.*
3. **Strategic and world state stay synchronized** across every transition.
4. **Save/load survives** entry, exit, and mid-scene.
5. **Content is data-driven** — no authored operation lives in a Blueprint or a widget.
6. **Architecture scales without becoming an open world.**
7. **Behavioral equivalence with the Godot golden vectors** on every preserved system
   (equivalence, not bit-identity — see [08_TEST_STRATEGY.md](08_TEST_STRATEGY.md)).
8. **Performance budgets met** on the target machine (§ below).

## 7. Explicit non-goals

Carried from brief §12.3 and the locked decisions — these are **cuts to protect**, not deferrals:

- No tactical combat, no character combat, no shooting.
- No open world, no street-level free roam, no entering arbitrary buildings.
- No drivable vehicles.
- No city-scale life simulation, no individual citizen schedules.
- No runtime generative video, no runtime LLM calls, no runtime AI asset generation.
- No multiplayer, no co-op, no live service.
- No console ports before PC validation.
- No World Partition / open-world streaming (see [04_UNREAL_ARCHITECTURE.md](04_UNREAL_ARCHITECTURE.md) §9).
- No MetaHuman-scale cast: **one** hero-grade rigged character in the slice.
- No final art before the greybox vertical slice passes its gates (Locked #15).
- No second engine for cinematics.

## 8. Performance budgets

`[Proposed]` Targets for the verified dev machine — Ryzen 7 8700F, 64 GB DDR5, **RTX 5060 Ti 16 GB**,
Win 11, NVMe. Rationale and method in [06_VERTICAL_SLICE.md](06_VERTICAL_SLICE.md) §9.

| Context | Target | Floor (fail gate) |
|---|---|---|
| Strategic city view, packaged, 1080p High | 60 fps | 45 fps |
| Embodied scene, packaged, 1080p High | 60 fps | 45 fps |
| Editor PIE, city view | 30 fps | 20 fps |
| Level transition (city → embodied) | ≤ 3.0 s | 5.0 s |
| Save write / load | ≤ 250 ms / ≤ 1.5 s | 500 ms / 3 s |
| Packaged build size | ≤ 8 GB | 15 GB |
| Strategic tick CPU cost | ≤ 2.0 ms | 4.0 ms |
| Shader compile, cold editor open | ≤ 20 min | 45 min |

**VRAM is the binding constraint** (16 GB, 128-bit bus — from the user's hardware record). Budget
≤ 10 GB VRAM in the embodied scene to leave editor headroom.

## 9. Go / no-go conditions

### 9.1 Go — all must hold before writing Unreal code

- [ ] **G1** Cem approves this package and the decisions in [12_DECISIONS_REQUIRED.md](12_DECISIONS_REQUIRED.md).
- [ ] **G2** UE version pinned. `[Verified]` **UE 5.8.2** (`Release-5.8`, CL 56702186) is installed at
      `C:\Program Files\Epic Games\UE_5.8`.
- [ ] **G3** C++ toolchain verified. `[Verified]` MSVC **14.44.35207** (`cl.exe` present) via
      **Visual Studio Build Tools 2022 17.14.37411.7**; Windows SDK **10.0.26100.0**; .NET **8.0.425**.
      ⚠️ Only *Build Tools* is installed — no full VS IDE. See D-01.
- [ ] **G4** Git LFS available. `[Verified]` **git-lfs 3.7.0**.
- [ ] **G5** Disk headroom. `[Verified]` D: has **1.2 TB free**.
- [ ] **G6** The Godot repo is archived read-only and never deleted (Locked #1).

### 9.2 No-go / stop conditions — hit one, stop and escalate

- **SC-1 — The reboot thesis fails.** The first embodied scene, side-by-side against the Godot
  back-room, does not read as materially better to Cem. *Stop. The reboot has no justification.*
- **SC-2 — Determinism cannot be re-established.** Golden-vector equivalence cannot be met within
  tolerance after a genuine attempt. Escalate before proceeding.
- **SC-3 — Strategic loop regresses.** The Unreal greybox loop is *less* fun than the Godot build.
- **SC-4 — Performance floor breached** on the target machine with greybox content.
- **SC-5 — Character production cost explodes.** One hero character cannot be produced to bar within
  the agreed budget. (Highest-probability commercial risk — R-02.)
- **SC-6 — Blueprint sprawl.** Authoritative state found in a Blueprint or Level Blueprint (Locked #8).
- **SC-7 — Scope breach.** Any non-goal in §7 enters the build.

---

## 10. What this package does *not* decide

Deferred to Cem in [12_DECISIONS_REQUIRED.md](12_DECISIONS_REQUIRED.md): the character-canon source of
truth, the facial/rig pipeline, whether splats return, IDE tooling, repo/LFS hosting, and the fate of
the uncommitted P20 work in the Godot tree.

**Next document:** [01_SOURCE_AUDIT.md](01_SOURCE_AUDIT.md) · **Control document:** [MASTER_PLAN.md](MASTER_PLAN.md)
